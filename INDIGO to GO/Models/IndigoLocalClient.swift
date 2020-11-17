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
import Firebase
import CryptoKit

class LocalIndigoClient: ObservableObject, IndigoPropertyService, IndigoConnectionService,  IndigoConnectionDelegate {

    // MARK: Properties
    
    var systemIcon = "bonjour"
    var name: String { return connectedServers().joined(separator: ", ") }
    var id = UUID()
    let queue = DispatchQueue(label: "Client connection Q")
    var lastUpdate: Date?

    private var properties: [String: IndigoItem] = [:]

    /// Properties for the image preview
    var imagerLatestImageURL: URL?
    var guiderLatestImageURL: URL?

    /// Properties for connections
    var endpoints: [String: NWEndpoint] = [:]
    var connections: [String: IndigoConnection] = [:]
    var serversToDisconnect: [String] = []
    var serversToConnect: [String] = []
    var maxReconnectAttempts = 3

    var receivedRemainder = "" // partial text while receiving INDI
    
    var anyCancellable: AnyCancellable? = nil

    /// Properties for Firebase syncing
    var firebase: DatabaseReference?
    var firebaseUID: String?
    var firebaseRefHandle: DatabaseHandle?

    let permittedProperties = [
        "Imager Agent | AGENT_START_PROCESS | SEQUENCE",
        "Imager Agent | AGENT_PAUSE_PROCESS | PAUSE",
        "Imager Agent | CCD_TEMPERATURE | TEMPERATURE",
        "Imager Agent | CCD_COOLER | ON",
        "Imager Agent | CCD_TEMPERATURE | TEMPERATURE",
        "Imager Agent | AGENT_IMAGER_STATS | BATCH",
        "Imager Agent | AGENT_IMAGER_STATS | FRAME",
        "Imager Agent | AGENT_IMAGER_SEQUENCE | 00",
        "Imager Agent | AGENT_IMAGER_SEQUENCE | 01",
        "Imager Agent | AGENT_IMAGER_SEQUENCE | 02",
        "Imager Agent | AGENT_IMAGER_SEQUENCE | 03",
        "Imager Agent | AGENT_IMAGER_SEQUENCE | 04",
        "Imager Agent | AGENT_IMAGER_SEQUENCE | 05",
        "Imager Agent | AGENT_IMAGER_SEQUENCE | 06",
        "Imager Agent | AGENT_IMAGER_SEQUENCE | 07",
        "Imager Agent | AGENT_IMAGER_SEQUENCE | 08",
        "Imager Agent | AGENT_IMAGER_SEQUENCE | 09",
        "Imager Agent | AGENT_IMAGER_SEQUENCE | 10",
        "Imager Agent | AGENT_IMAGER_SEQUENCE | 11",
        "Imager Agent | AGENT_IMAGER_SEQUENCE | 12",
        "Imager Agent | AGENT_IMAGER_SEQUENCE | 13",
        "Imager Agent | AGENT_IMAGER_SEQUENCE | 14",
        "Imager Agent | AGENT_IMAGER_SEQUENCE | 15",
        "Imager Agent | AGENT_IMAGER_SEQUENCE | 16",
        "Imager Agent | AGENT_IMAGER_SEQUENCE | SEQUENCE",
        "Imager Agent | AGENT_IMAGER_STATS | EXPOSURE",
        "Guider Agent | AGENT_START_PROCESS | GUIDING",
        "Guider Agent | AGENT_GUIDER_STATS | DITHERING",
        "Guider Agent | AGENT_START_PROCESS | CALIBRATION",
        "Guider Agent | AGENT_GUIDER_STATS | DRIFT_X",
        "Guider Agent | AGENT_GUIDER_STATS | DRIFT_Y",
        "Guider Agent | AGENT_GUIDER_STATS | RMSE_RA",
        "Guider Agent | AGENT_GUIDER_STATS | RMSE_DEC",
        "Mount Agent | MOUNT_PARK | PARKED",
        "Mount Agent | MOUNT_TRACKING | ON",
        "Mount Agent | MOUNT_TRACKING | OFF",
        "Mount Agent | AGENT_LIMITS | HA_TRACKING"
    ]

    // MARK: - Init & Re-Init
    
    init() {

        if let user = Auth.auth().currentUser {
            self.firebase = Database.database().reference()
            self.firebaseUID = user.uid
        }
        _ = Auth.auth().addStateDidChangeListener { (_, user) in
            if let user = user {
                self.firebase = Database.database().reference()
                self.firebaseUID = user.uid
            } else {
                if let firebase = self.firebase {
                    firebase.database.goOffline()
                }
                self.firebaseUID = nil
            }
        }
        
    }
    
    func restart() {
        var servers: [String] = []
        servers.append( UserDefaults.standard.object(forKey: "imager") as? String ?? "None" )
        servers.append( UserDefaults.standard.object(forKey: "guider") as? String ?? "None" )
        servers.append( UserDefaults.standard.object(forKey: "mount") as? String ?? "None" )

        self.reinit(servers: servers)
    }
    
    func reinit(servers: [String]) {

        /// listen for Firebase commands
        // TODO: Move all Firebase commands to a single class (extension?) for easy use
        if let fb = self.firebaseCommandPrefix() {
            self.firebaseRefHandle = fb.observe(.value, with: { (snapshot) in
                for child in snapshot.children {
                    let snap = child as! DataSnapshot
                    let dict = snap.value as! [String: Any]
                    let command = dict["command"] as? String ?? ""
                    let timestamp = dict["timestamp"] as? Double ?? 0
                    
                    let timeNow = Date().timeIntervalSince1970
                    let timeSince = timeNow - timestamp
                    
                    let maxTime: Double = 60*2 // 2 minutes is the oldest we'll accept commands
                    if timeSince < maxTime {

                        switch command {
                        case "emergencyStopAll":
                            self.emergencyStopAll()

                        default:
                            print("Unknown Firebase Command: \(command)")
                        }
                    }

                    /// We've processed this item, so remove it
                    snap.ref.removeValue()
                }
            })
        }

        self.serversToConnect = servers.removingDuplicates()
        print("ReInit with servers \(self.serversToConnect)")
        
        // 1. Disconnect all servers
        // 2. Once disconnected, remove all properties
        // 3. Connect to all servers
        // 4. Profit
        
        self.serversToDisconnect = self.allServers()
        
        // clear out all properties!
        self.removeAll()
        
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
            // Make sure each agent is unique. We don't need multiple connections to an endpoint!
            if server != "None" && !self.connectedServers().contains(server)  {
                if let endpoint = self.endpoints[server] {
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
                                
                                /// enable previews if offered and have not yet been set!
                                if key == "Imager Agent | CCD_PREVIEW | ENABLED" && type == "defSwitchVector" {
                                    self.queue.asyncAfter(deadline: .now() + 2.0) {
                                        source.enablePreviews()
                                    }
                                }
                                
                                /// enable previews if offered
                                if key == "Guider Agent | CCD_PREVIEW | ENABLED" && type == "defSwitchVector" {
                                    self.queue.asyncAfter(deadline: .now() + 2.0) {
                                        source.enableGuiderPreviews()
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
            guard let item = self.properties[key] else { return nil }
            return item.value
        }
    }
    
    func getTarget(_ key: String) -> String? {
        return self.queue.sync {
            guard let item = self.properties[key] else { return nil }
            return item.target
        }
    }

    func getState(_ key: String) -> StateValue? {
        return self.queue.sync {
            guard let item = properties[key], let state = item.state else { return nil }
            return state
        }
    }

    func setValue(key:String, toValue value:String, toState state:String, toTarget target:String? = nil) {
        let newItem = IndigoItem(theValue: value, theState: state, theTarget: target)
        self.queue.async {
            self.properties[key] = newItem
        }
        
        guard let fb = firebasePropertyPrefix(), let keyHash = self.keyHash(key) else { return }
        let value = [
            "key": key,
            "value": value,
            "state": state,
            "target": target
        ]
        fb.child(keyHash).setValue(value)
        firebaseTouch()
    }
    
    func delValue(_ key: String) {
        self.queue.async {
            self.properties.removeValue(forKey: key)
        }

        guard let fb = firebasePropertyPrefix(), let keyHash = self.keyHash(key) else { return }
        fb.child(keyHash).removeValue()
        firebaseTouch()
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

        guard let fb = firebasePropertyPrefix() else { return }
        fb.removeValue()
        firebaseTouch()
    }
    
    func keyHash(_ key: String) -> String? {
//        let keyData = Data(key.utf8)
//        let keyHash: String = SHA256.hash(data: keyData).compactMap { String(format: "%02x", $0) }.joined()

        // We will send only permitted properties, in order to protect user privacy
        guard self.permittedProperties.contains(key) else { return nil }

        let keyHash: String = key
            .replacingOccurrences(of: ".", with: "_")
            .replacingOccurrences(of: "#", with: "")
            .replacingOccurrences(of: "$", with: "")
            .replacingOccurrences(of: "[", with: "")
            .replacingOccurrences(of: "]", with: "")
            .replacingOccurrences(of: "/", with: "_")
        
        return keyHash
    }
    
    func firebasePropertyPrefix() -> DatabaseReference? {
        guard let uid = self.firebaseUID, let firebase = self.firebase else { return nil }
        return firebase.child("users/\(uid)/properties")
    }

    func firebaseCommandPrefix() -> DatabaseReference? {
        guard let uid = self.firebaseUID, let firebase = self.firebase else { return nil }
        return firebase.child("users/\(uid)/commands")
    }

    func firebaseTouch() {
        guard let uid = self.firebaseUID, let firebase = self.firebase else { return }
        firebase.child("users/\(uid)/accessed").setValue(Date().timeIntervalSince1970)
    }

}


struct IndigoClient_Previews: PreviewProvider {
    static var previews: some View {
        let client = LocalIndigoClient()
        MonitorView()
            .environmentObject(client)
    }
}



