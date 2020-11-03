//
//  RemoteClient.swift
//  INDIGO to GO
//
//  Created by Aaron Freimark on 11/3/20.
//

import Foundation
import SwiftyJSON
import SwiftUI
import Combine
import Network
import Firebase
import CryptoKit

class RemoteIndigoClient: ObservableObject, IndigoPropertyService, IndigoConnectionService {

    var endpoints: [String: NWEndpoint] = [:]


    // MARK: Properties
    
    var systemIcon = "antenna.radiowaves.left.and.right"
    var id = UUID()
    let queue = DispatchQueue(label: "Client connection Q")
    var lastUpdate: Date?

    private var properties: [String: IndigoItem] = [:]

    /// Properties for the image preview
    var imagerLatestImageURL: URL?
    var guiderLatestImageURL: URL?

    var anyCancellable: AnyCancellable? = nil

    /// Properties for Firebase syncing
    var firebase: DatabaseReference?
    var firebaseUID: String?
    var firebaseRefHandle: DatabaseHandle?
    
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
        
        reinit(servers: [])
                
    }
    
    func reinit(servers: [String]) {
        print("ReInit Remote")
        
        // clear out all properties!
        self.removeAll()
//        self.firebaseRefHandle?.removeObserverWithHandle

        if let fb = self.firebasePrefix() {
            self.firebaseRefHandle = fb.observe(.value, with: { (snapshot) in
                for child in snapshot.children {
                    let snap = child as! DataSnapshot
                    let dict = snap.value as! [String: Any]
                    let key = dict["key"] as? String ?? ""
                    let value = dict["value"] as? String ?? ""
                    let state = dict["state"] as? String ?? ""
                    let target = dict["target"] as? String ?? ""
                    
                    self.setValue(key: key, toValue: value, toState: state, toTarget: target)
                }
            })
        }

    }

    
    // MARK: - Connection Collections

    func allServers() -> [String] {
            return ["Remote"]
    }

    func connectedServers() -> [String] {
        return ["Remote"]
    }
    
    // MARK: - Server Commands


    func emergencyStopAll() {
        self.queue.async {
//            for (_, connection) in self.connections {
//                connection.mountPark()
//                connection.imagerDisableCooler()
//            }
        }
    }

    func enableAllPreviews() {
        self.queue.async {
//            for (_, connection) in self.connections {
//                connection.enablePreviews()
//            }
        }
    }


    // MARK: - Connection Management
    


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
    
    
    func firebasePrefix() -> DatabaseReference? {
        guard let uid = self.firebaseUID, let firebase = self.firebase else { return nil }
        return firebase.child("users/\(uid)/properties")
    }

}




