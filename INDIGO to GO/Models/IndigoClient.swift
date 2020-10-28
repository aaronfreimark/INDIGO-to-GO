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

class IndigoClient: ObservableObject, IndigoPropertyService, IndigoConnectionService,  IndigoConnectionDelegate {

    // MARK: Properties
    
    var id = UUID()
    let queue = DispatchQueue(label: "Client connection Q")
    var lastUpdate: Date?

    private var properties: [String: IndigoItem] = [:]

    var defaultImager: String {
        didSet { UserDefaults.standard.set(defaultImager, forKey: "imager") }
    }
    var defaultGuider: String {
        didSet { UserDefaults.standard.set(defaultGuider, forKey: "guider") }
    }
    var defaultMount: String {
        didSet { UserDefaults.standard.set(defaultMount, forKey: "mount") }
    }

    /// Properties for the image preview
    @Published var imagerLatestImageURL: URL?
    @Published var guiderLatestImageURL: URL?

    /// Properties for Bonjour
    @Published var bonjourBrowser: BonjourBrowser = BonjourBrowser()
    var connections: [String: IndigoConnection] = [:]
    var serversToDisconnect: [String] = []
    var serversToConnect: [String] = []
    var maxReconnectAttempts = 3

    var receivedRemainder = "" // partial text while receiving INDI
    
    var anyCancellable: AnyCancellable? = nil

    
    // MARK: - Init & Re-Init
    
    init() {
        
        self.defaultImager = UserDefaults.standard.object(forKey: "imager") as? String ?? "None"
        self.defaultGuider = UserDefaults.standard.object(forKey: "guider") as? String ?? "None"
        self.defaultMount = UserDefaults.standard.object(forKey: "mount") as? String ?? "None"

        // Combine publishers into the main thread.
        // https://stackoverflow.com/questions/58437861/
        // https://stackoverflow.com/questions/58406287
        anyCancellable = bonjourBrowser.objectWillChange.sink { [weak self] (_) in
            self?.objectWillChange.send()
        }

        // after 1 second search for whatever is in serverSettings.servers to try to reconnect
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            self.reinitSavedServers()
        }

    }
    
    func reinitSavedServers() {
        self.reinit(servers: [self.defaultImager, self.defaultGuider, self.defaultMount])
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

    
    // MARK: - Connection Collections

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
    
    // MARK: - Server Commands


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


    // MARK: - Connection Management
    
    func connectAll() {
        print("Connecting to servers: \(self.serversToConnect)")
        for server in self.serversToConnect {
            // Make sure each agent is unique. We don't need multiple connections to an endpoint!xwxx
            if server != "None" && !self.connectedServers().contains(server)  {
                if let endpoint = self.bonjourBrowser.endpoint(name: server) {
                    self.queue.async {
                        let connection = IndigoConnection(name: server, endpoint: endpoint, queue: self.queue, delegate: self)
                        print("\(connection.name): Setting Up...")
                        self.connections[server] = connection
                        connection.start()
                    }
                }
            }
        }

        self.serversToConnect = []
    }

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


    func receiveMessage(data: Data?, context: NWConnection.ContentContext?, isComplete: Bool, error: NWError?, source: IndigoConnection) {
        if let data = data, !data.isEmpty {
            if let message = String(data: data, encoding: .utf8) {
                // print ("Received: \(message ?? "-" )")
                // print ("Received \(message.count) bytes")
                
                if let dataFromString = message.data(using: .ascii, allowLossyConversion: false) {
                    do {
                        let json = try JSON(data: dataFromString)
                        self.injest(json: json, source: source)
                    } catch {
                        print ("Really bad JSON error.")
                    }
                }
            }
        }
    }


    func connectionStateHasChanged(_ name: String, _ state: NWConnection.State) {
        guard let connection = self.connections[name] else {
            print("Unknown connection from delegate: \(name)")
            return
        }
        
        switch state {
        case .ready:
            self.queue.asyncAfter(deadline: .now() + 0.25) {
                connection.hello()
            }
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
                print("\(name): Removing connection :(")
                self.connections.removeValue(forKey: name)
                reinit(servers: self.connectedServers())
            }
            break
        default:
            break
        }
    }
    
    func injest(json: JSON, source: IndigoConnection) {
        #if DEBUG
//        if json.rawString()!.contains("CCD_PREVIEW") { print(json.rawString()!) }
        #endif
        
        for (type, subJson):(String, JSON) in json {
            
            // Is the is "def" or "set" Indigo types?
            if (type.prefix(3) == "def") || (type.prefix(3) == "set") || type.prefix(3) == "del" {
                let device = subJson["device"].stringValue
                //let group = subJson["group"].stringValue
                let name = subJson["name"].stringValue
                let state = subJson["state"].stringValue
                
                // make sure we records only the devices we care about
                if ["Imager Agent", "Guider Agent", "Mount Agent", "Server"].contains(device) {
                    if subJson["items"].exists() {
                        for (_, itemJson):(String, JSON) in subJson["items"] {
                            
                            let itemName = itemJson["name"].stringValue
                            let key = "\(device) | \(name) | \(itemName)"

                            let itemValue = itemJson["value"].stringValue
                            let itemTarget = itemJson["target"].stringValue

                            switch type.prefix(3) {
                            case "def", "set":
                                if !itemName.isEmpty && itemJson["value"].exists() {
                                    self.setValue(key: key, toValue: itemValue, toState: state, toTarget: itemTarget)
                                }
                                
                                /// enable previews if offered
                                if key == "Imager Agent | CCD_PREVIEW | ENABLED" && type == "defSwitchVector" {
                                    self.queue.asyncAfter(deadline: .now() + 2.0) {
                                        source.enablePreviews()
                                    }
                                }
                                
                                /// enable previews if offered
                                if key == "Guider Agent | CCD_PREVIEW | ENABLED" && type == "defSwitchVector" {
                                    self.queue.asyncAfter(deadline: .now() + 2.0) {
                                        source.enablePreviews()
                                    }
                                }
                                
                                // handle special cases
                                if key == "Imager Agent | CCD_PREVIEW_IMAGE | IMAGE" && state == "Ok" && itemValue.count > 0 {
                                    if let urlprefix = source.url {
                                        let url = URL(string: "\(urlprefix)\(itemValue)?nonce=\(UUID())")!
                                        DispatchQueue.main.async() {
                                            self.imagerLatestImageURL = url
                                        }
                                        print("imagerLatestImageURL: \(url)")
                                    }
                                }

                                if key == "Guider Agent | CCD_PREVIEW_IMAGE | IMAGE" && state == "Ok" && itemValue.count > 0 {
                                    if let urlprefix = source.url {
                                        let url = URL(string: "\(urlprefix)\(itemValue)?nonce=\(UUID())")!
                                        DispatchQueue.main.async() {
                                            self.guiderLatestImageURL = url
                                        }
                                        print("guiderLatestImageURL: \(url)")
                                    }
                                }
                                

                                break
                            case "del":
                                self.delValue(key)
                                break
                            default:
                                break
                            }
                        }
                    }
                    self.lastUpdate = Date()
                }
            }
        }
    }


    /// =============================================================================================

    
    // MARK: - Low level thread safe funcs

    func getKeys() -> [String] {
        return self.queue.sync {
            return Array(self.properties.keys)
        }
    }
    
    func getValue(_ key: String) -> String? {
        return self.queue.sync {
            if let item = self.properties[key] {
                return item.value
            }
            return nil
        }
    }
    
    func getTarget(_ key: String) -> String? {
        return self.queue.sync {
            if let item = self.properties[key] {
                return item.target
            }
            return nil
        }
    }

    func getState(_ key: String) -> StateValue? {
        return self.queue.sync {
            if let item = properties[key] {
                if let state = item.state {
                    return state
                }
            }
            return nil
        }
    }

    func setValue(key:String, toValue value:String, toState state:String, toTarget target:String? = nil) {
        let newItem = IndigoItem(theValue: value, theState: state, theTarget: target)
        self.queue.async {
            self.properties[key] = newItem
        }
    }
    
    func delValue(_ key: String) {
        self.queue.async {
            self.properties.removeValue(forKey: key)
        }
    }

    
    func printProperties() {
        let sortedKeys = Array(self.getKeys()).sorted(by: <)
        for k in sortedKeys {
            print("\(k): \(self.getValue(k) ?? "nil") - \(String(describing: self.getState(k)))")
        }
    }
    
    func removeAll() {
        self.queue.async {
            self.properties.removeAll()
        }
    }

        

}


struct IndigoClient_Previews: PreviewProvider {
    static var previews: some View {
        let client = IndigoClient()
        MonitorView()
            .environmentObject(client)
    }
}



