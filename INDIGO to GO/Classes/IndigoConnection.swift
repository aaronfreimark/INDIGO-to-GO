//
//  IndigoConnection.swift
//  INDIGO Status
//
//  Created by Aaron Freimark on 9/18/20.
//

import Foundation
import Network
import SwiftyJSON

class IndigoConnection {
    
    var name = ""
    var endpoint: NWEndpoint?
    var connection: NWConnection?
    var parameters: NWParameters?

    var didStopCallback: ((Error?) -> Void)? = nil

    var delegate: IndigoConnectionDelegate?
    var queue: DispatchQueue

    init(name: String, endpoint: NWEndpoint, queue: DispatchQueue, delegate: IndigoConnectionDelegate) {
        self.name = name
        self.endpoint = endpoint
        self.queue = queue
        self.delegate = delegate
    }
    
    func start() {

        self.parameters = NWParameters.tcp
        self.parameters!.allowLocalEndpointReuse = true
        self.parameters!.includePeerToPeer = true
        let websocketOptions = NWProtocolWebSocket.Options()
        websocketOptions.autoReplyPing = true
        self.parameters!.defaultProtocolStack.applicationProtocols.insert(websocketOptions, at: 0)
        
        //        self.connection = NWConnection(to: self.endpoint!, using: self.parameters!)
        let endpoint: NWEndpoint = .url(URL(string: "ws://Mr-T.local.:59469/")!)
        self.connection = NWConnection(to: endpoint, using: self.parameters!)
        
        self.didStopCallback = didStopCallback(error:)
        self.connection!.stateUpdateHandler = stateDidChange(to:)

        // setupReceive
        self.setupReceive()

        print("\(self.name): Client starting... ")
        self.connection!.start(queue: self.queue)
    }

    
    private func setupReceive() {
        self.connection!.receiveMessage { [weak self] (data, context, isComplete, error) in
            if let data = data, !data.isEmpty {
                self!.delegate!.receiveMessage(data: data, context: context, isComplete: isComplete, error: error)
            }
            if let error = error {
                self!.connectionDidFail(error: error)
            } else {
                self!.setupReceive()
            }
        }
    }

    // =================================================

    func stop() {
        print("\(self.name): Client stopping...")
        stop(error: nil)
    }
    
    func send(data: Data) {

        // https://github.com/MichaelNeas/perpetual-learning/blob/master/ios-sockets/SwiftWebSockets/SwiftWebSockets/Networking/NWWebSocket.swift
        let metadata = NWProtocolWebSocket.Metadata(opcode: .text)
        let context = NWConnection.ContentContext(identifier: "textContext", metadata: [metadata])

        self.connection!.send(content: data, contentContext: context, completion: .contentProcessed( { error in
            if let error = error {
                self.connectionDidFail(error: error)
                return
            }
//            print("\(self.name): Connection did send, data: \(String(describing: String(data: data, encoding: .utf8)))")
        }))
    }

    private func stateDidChange(to state: NWConnection.State) {
        self.delegate?.connectionStateHasChanged(self.name, state)
    }

    func didStopCallback(error: Error?) {
        if error == nil {
            // exit(EXIT_SUCCESS)
        } else {
            // exit(EXIT_FAILURE)
        }
    }
    
    func connectionDidFail(error: Error) {
        print("\(self.name): Connection did fail, error: \(error)")
        self.delegate?.connectionStateHasChanged(self.name, .cancelled)
        self.stop(error: error)
    }
    
    func connectionDidEnd() {
        print("\(self.name): Connection did end")
        self.delegate?.connectionStateHasChanged(self.name, .cancelled)
        self.stop(error: nil)
    }
    
    private func stop(error: Error?) {
        self.connection!.stateUpdateHandler = nil
        self.connection!.cancel()
        if let didStopCallback = self.didStopCallback {
            self.didStopCallback = nil
            didStopCallback(error)
        }
    }
    
    func isConnected() -> Bool {
        if self.connection == nil { return false }
        return self.connection!.state == .ready
    }
    
    
    // =================================================
    
    
    func enablePreviews() {
        let json: JSON = [ "newSwitchVector": [ "device": "Imager Agent", "name": "CCD_PREVIEW", "items": [ [ "name": "ENABLED", "value": true ]  ]  ] ]
        self.send(data: json.rawString()!.data(using: .ascii)!)
    }

    func hello() {
        let json: JSON = [ "getProperties": [ "version": 512 ] ]
        self.send(data: json.rawString()!.data(using: .ascii)!)
    }

    func mountPark() {
        let json: JSON = [ "newSwitchVector": [ "device": "Mount Agent", "name": "MOUNT_PARK", "items": [ [ "name": "PARKED", "value": true ] ] ] ]
        self.send(data: json.rawString()!.data(using: .ascii)!)
    }
    func imagerDisableCooler() {
        let json: JSON = [ "newSwitchVector": [ "device": "Imager Agent", "name": "CCD_COOLER", "items": [ [ "name": "OFF", "value": true ] ] ] ]
        self.send(data: json.rawString()!.data(using: .ascii)!)
    }

    
}

protocol IndigoConnectionDelegate {
    func connectionStateHasChanged(_ name: String, _ state: NWConnection.State)
    func receiveMessage(data: Data?, context: NWConnection.ContentContext?, isComplete: Bool, error: NWError?)
}

