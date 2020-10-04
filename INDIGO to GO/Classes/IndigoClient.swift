//
//  File.swift
//  INDIGO Status
//
//  Created by Aaron Freimark on 9/10/20.
//

import Foundation
import SwiftyJSON
import SwiftUI
import Combine
import Network

class IndigoClient: Hashable, Identifiable, ObservableObject, IndigoConnectionDelegate {
    var id = UUID()
    let queue = DispatchQueue(label: "Client connection Q")

    @ObservedObject var bonjourBrowser: BonjourBrowser = BonjourBrowser()
    @Published var properties: IndigoProperties
    var connections: [String: IndigoConnection] = [:]
    var userSettings = UserSettings()

    var serversToDisconnect: [String] = []
    var serversToConnect: [String] = []
    var receivedRemainder = "" // partial text while receiving INDI
    
    var anyCancellable: AnyCancellable? = nil

 
    
    init(isPreview: Bool = false) {
        
        self.properties = IndigoProperties(queue: self.queue, isPreview: isPreview)
        
        // Combine publishers into the main thread.
        // https://stackoverflow.com/questions/58437861/
        anyCancellable = Publishers.CombineLatest(bonjourBrowser.objectWillChange, properties.objectWillChange).sink { [weak self] (_) in
            self?.objectWillChange.send()
        }

        if !isPreview {
            // Start up Bonjour, let stuff populate
            DispatchQueue.main.asyncAfter(deadline: .now(), execute: {
                self.bonjourBrowser.seek()
            })

            // after 1 second search for whatever is in serverSettings.servers to try to reconnect
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                self.reinit(servers: [self.userSettings.imager, self.userSettings.guider, self.userSettings.mount])
            }
        } else {
            self.updateUI()
        }

    }
        
    func reinit(servers: [String]) {
        print("ReInit with servers \(servers)")
        
        // 1. Disconnect all servers
        // 2. Once disconnected, remove all properties
        // 3. Connect to all servers
        // 4. Profit
        
        self.serversToConnect = servers.removingDuplicates()
        
        // clear out all properties!
        self.properties.removeAll()

        self.serversToDisconnect = self.allServers()
        
        if self.serversToDisconnect.count > 0 {
            self.disconnectAll()
            // Connect will happen after all servers are disconnected
        }
        else {
            self.connectAll()
        }
    }

    // =============================================================================================

    func allServers() -> [String] {
            return Array(self.connections.keys)
    }

    func connectedServers() -> [String] {
        var connectedServers: [String] = []
        for (name,connection) in self.connections {
            if connection.isConnected() { connectedServers.append(name) }
        }
        return connectedServers
    }

    func updateUI() {
        self.properties.updateUI()
    }
    
    
    func printProperties() {
        self.properties.printProperties()
    }
    
    func hash(into hasher: inout Hasher) {
        hasher.combine(properties)
    }
    
    static func == (lhs: IndigoClient, rhs: IndigoClient) -> Bool {
        return lhs.hashValue == rhs.hashValue
    }
    
    
    // =============================================================================================


    func emergencyStopAll() {
        self.queue.async {
            for (_, connection) in self.connections {
                connection.mountPark()
                connection.imagerDisableCooler()
            }
        }
    }

    func enableAllPreviews() {
        self.queue.async {
            for (_, connection) in self.connections {
                connection.enablePreviews()
            }
        }
    }

    // =============================================================================================

    
    func connectAll() {
        print("Connecting to servers: \(self.serversToConnect)")
        for server in self.serversToConnect {
            // Make sure each agent is unique. We don't need multiple connections to an endpoint!
            if server != "None" && !self.connectedServers().contains(server)  {
                if let endpoint = self.bonjourBrowser.endpoint(name: server) {
                    self.queue.async {
                        self.connections[server] = IndigoConnection(name: server, endpoint: endpoint, queue: self.queue, delegate: self)
                        if self.connections[server]!.endpoint != nil {
                            print("\(self.connections[server]!.name): Setting Up...")
                            self.connections[server]!.start()

                        } else {
                            print("\(self.connections[server]!.name): IndigoClient not ready to start.")
                        }
                    }
                }
            }
        }

        self.serversToConnect = []
    }

    // =============================================================================================

    func receiveMessage(data: Data?, context: NWConnection.ContentContext?, isComplete: Bool, error: NWError?) {
        if let data = data, !data.isEmpty {
            if let message = String(data: data, encoding: .utf8) {
                // print ("Received: \(message ?? "-" )")
                // print ("Received \(message.count) bytes")
                
                if let dataFromString = message.data(using: .ascii, allowLossyConversion: false) {
                    do {
                        let json = try JSON(data: dataFromString)
                        self.properties.injest(json: json)
                    } catch {
                        print ("Really bad JSON error.")
                    }
                }
            }
        }
    }

    // =============================================================================================


    func connectionStateHasChanged(_ name: String, _ state: NWConnection.State) {
        guard let connection = self.connections[name] else {
            print("Unknown connection from delegate: \(name)")
            return
        }
        
        // TODO if a connected is removed (.failed, .cancelled) we need to clean up properties!
        
        switch state {
        case .ready:
            // Upgrade to a websocket if it isn't one now.
            
            var path = connection.connection?.currentPath?.remoteEndpoint
            print("Path: \(path)")
            
            connection.hello()
            connection.enablePreviews()
        case .setup:
            break
        case .waiting:
            break
        case .preparing:
            break
        case .failed, .cancelled:
            print("\(name): State cancelled or failed.")
            // expected or unexpected? If unexpected, try to reconnect.
            
            if self.serversToDisconnect.contains(name) {
                print("==== Expected disconnection ====")
                self.connections.removeValue(forKey: name)
                self.serversToDisconnect.removeAll(where: { $0 == name } )
                if self.serversToDisconnect.isEmpty {
                    print("=== Beginning reconnections ===")
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                        self.connectAll()
                    }
                }

            } else {
                print("==== Unexpected disconnection ====")
                self.connections.removeValue(forKey: name)
                reinit(servers: self.connectedServers())
            }
            break
        default:
            break
        }
    }

    // =============================================================================================

    func disconnect(connection: IndigoConnection) {
        print("\(connection.name): Disconnecting client...")
        connection.stop()
    }
    
    func disconnectAll() {
        print("Disconnecting \(self.serversToDisconnect)...")
        for name in self.serversToDisconnect {
            self.queue.async {
                if let connection = self.connections[name] {
                    self.disconnect(connection: connection)
                }
            }
        }
    }
     
}

struct IndigoClient_Previews: PreviewProvider {
    static var previews: some View {
        let client = IndigoClient(isPreview: true)
        ContentView(client: client)
    }
}

extension Array where Element: Hashable {
    func removingDuplicates() -> [Element] {
        var addedDict = [Element: Bool]()

        return filter {
            addedDict.updateValue(true, forKey: $0) == nil
        }
    }

    mutating func removeDuplicates() {
        self = self.removingDuplicates()
    }
}
