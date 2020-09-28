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
    
    var userSettings = UserSettings()

    var connections: [String: IndigoConnection] = [:]
    
    var receivedRemainder = "" // partial text while receiving INDI
    
    var anyCancellable: AnyCancellable? = nil

 
    
    init() {
        
        self.properties = IndigoProperties(queue: self.queue)

        // Combine publishers into the main thread.
        // https://stackoverflow.com/questions/58437861/
        anyCancellable = Publishers.CombineLatest(bonjourBrowser.objectWillChange, properties.objectWillChange).sink { [weak self] (_) in
            self?.objectWillChange.send()
        }

        // Start up Bonjour, let stuff populate
        DispatchQueue.main.asyncAfter(deadline: .now(), execute: {
            self.bonjourBrowser.seek()
        })

        // after 1 second search for whatever is in serverSettings.servers to try to reconnect
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            self.reinit(servers: self.userSettings.servers)
        }
    }
    
    func reinit(servers: [String]) {
                       
        var didSomething = false
        // Loop again, disconnecting servers that aren't in the new list
        for (name, connection) in connections {
            if !servers.contains(name) {
                print("\(name): Stopping Client...")
                connection.stop()
                didSomething = true
            }
        }

        if didSomething { self.properties.removeAll() }
        
        for server in servers {
            // Make sure each agent is unique. We don't need multiple connections to an endpoint!
            if server != "None" && !self.connections.keys.contains(server)  {
                if let endpoint = self.bonjourBrowser.endpoint(name: server) {
                    self.connections[server] = IndigoConnection(name: server, endpoint: endpoint, queue: self.queue)
                    self.connections[server]!.delegate = self
                    self.connect(connection: self.connections[server]!)
                }
            }
        }

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

    func hello(connection: IndigoConnection) {
        let json: JSON = [ "getProperties": [ "version": 512 ] ]
        connection.send(data: json.rawString()!.data(using: .ascii)!)
    }
    
    func enableAllPreviews() {
        for (_, connection) in self.connections {
            self.enablePreviews(connection: connection)
        }
    }

    func enablePreviews(connection: IndigoConnection) {
        let json: JSON = [ "newSwitchVector": [ "device": "Imager Agent", "name": "CCD_PREVIEW", "items": [ [ "name": "ENABLED", "value": true ]  ]  ] ]
        connection.send(data: json.rawString()!.data(using: .ascii)!)
    }

        

    func connectionStateHasChanged(_ name: String, _ state: NWConnection.State) {
        guard let connection = self.connections[name] else {
            print("Unknown connection from delegate: \(name)")
            return
        }
        
        // TODO if a connected is removed (.failed, .cancelled) we need to clean up properties! 
        
        switch state {
        case .ready:
            hello(connection: connection)
            enablePreviews(connection: connection)
        case .setup:
            break
        case .waiting:
            break
        case .preparing:
            break
        case .failed:
            self.connections.removeValue(forKey: name)
            print("\(name): State failed & removed connection.")
            break
        case .cancelled:
            self.connections.removeValue(forKey: name)
            print("\(name): State canceled & removed connection.")
        default:
            break
        }
    }
    
    func connect(connection: IndigoConnection) {
        if connection.endpoint != nil {
            connection.connection = NWConnection(to: connection.endpoint!, using: NWParameters.tcp)
            print("Starting Client...")
            self.start(connection: connection)
        } else {
            print("IndigoClient not ready to start.")
        }
    }

    func start(connection: IndigoConnection) {
        connection.setup()
        setupReceive(connection: connection)
        connection.start()
    }

    
    func connectAll() {
        for (_, connection) in self.connections {
            self.connect(connection: connection)
        }
    }
    
    func disconnect(connection: IndigoConnection) {
        print("\(connection.name): Stopping Client...")
        connection.stop()
    }
    
    func disconnectAll() {
        for (_, connection) in self.connections {
            self.disconnect(connection: connection)
        }
    }



    // =============================================================================================



    
    
    private func setupReceive(connection: IndigoConnection) {
        connection.connection!.receive(minimumIncompleteLength: 1, maximumLength: 60*1024) { (data, _, isComplete, error) in
            //nwConnection.receiveMessage() { (data, _, isComplete, error) in
            if let data = data, !data.isEmpty {
                let message = String(data: data, encoding: .utf8)
                // print ("Received: \(message ?? "-" )")
                if let unwrapped = message {
                     // print ("Received \(unwrapped.count) bytes")
                    // Data from server may receive multiple JSON objects, or partial objects. Let's make sure we process only complete {..} objects.
                    var textToParse = self.receivedRemainder + unwrapped
                    
                    while textToParse != "" {
                        guard let extracted = self.extractFullJsonObject(s: textToParse) else { break }
                        
                        // was there no complete JSON object? save the remainder for next time.
                        if extracted.object == "" { textToParse = extracted.remainder; break }
                        
                        let completeJson = extracted.object
                        
                        if let dataFromString = completeJson.data(using: .ascii, allowLossyConversion: false) {
                            do {
                                let json = try JSON(data: dataFromString)
                                self.properties.injest(json: json, connection: connection)
                            } catch {
                                print ("Really bad JSON error.")
                            }
                        }
                        textToParse = extracted.remainder
                    }
                    
                    // save whatever remainder until next time.
                    self.receivedRemainder = textToParse
                    
                }
            }
            if isComplete {
                connection.connectionDidEnd()
            } else if let error = error {
                connection.connectionDidFail(error: error)
            } else {
                self.setupReceive(connection: connection)
            }
        }
    }
    
    
    func extractFullJsonObject(s: String) -> (object: String, remainder: String)? {
        
        if s[s.startIndex] != "{" { return nil }
        var braces = 0

        for i in s.indices {
            if s[i] == "{" { braces += 1 }
            if s[i] == "}" { braces -= 1 }
            if braces == 0 { return (object: String(s[...i]), remainder: String(s[s.index(after: i)..<s.endIndex]))}
        }
        return nil
    }
    

    
    
    
    
}

struct IndigoClient_Previews: PreviewProvider {
    static var previews: some View {
        /*@START_MENU_TOKEN@*/Text("Hello, World!")/*@END_MENU_TOKEN@*/
    }
}
