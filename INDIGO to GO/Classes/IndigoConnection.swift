//
//  IndigoConnection.swift
//  INDIGO Status
//
//  Created by Aaron Freimark on 9/18/20.
//

import Foundation
import Network

class IndigoConnection {
    
    var name = ""
    var endpoint: NWEndpoint?
    var connection: NWConnection?
    var didStopCallback: ((Error?) -> Void)? = nil
    
    var delegate: IndigoConnectionDelegate?
    var queue: DispatchQueue

    init(name: String, endpoint: NWEndpoint, queue: DispatchQueue) {
        self.name = name
        self.endpoint = endpoint
        self.queue = queue
    }
    
    func setup() {
        print("\(self.name): Client setup... ")
        self.didStopCallback = didStopCallback(error:)
        self.connection!.stateUpdateHandler = stateDidChange(to:)
    }

    func start() {
        print("\(self.name): Client starting... ")
        connection!.start(queue: queue)
    }

    func stop() {
        print("\(self.name): Client stopping...")
        stop(error: nil)
    }
    
    func send(data: Data) {
        self.connection!.send(content: data, completion: .contentProcessed( { error in
            if let error = error {
                self.connectionDidFail(error: error)
                return
            }
//            print("\(self.name): Connection did send, data: \(String(describing: String(data: data, encoding: .utf8)))")
            
        }))
    }

    private func stateDidChange(to state: NWConnection.State) {
        self.delegate?.connectionStateHasChanged(self.name, state)
/*
        switch state {
        case .ready:
            print("\(self.name): Client connection ready.")
            self.delegate?.connectionStateHasChanged(self.name, state)
        case .setup:
            break
        case .waiting:
            break
        case .preparing:
            break
        case .failed:
            break
        case .cancelled:
            break
        default:
            break
        }
 */
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
        return self.connection!.state == .ready
    }
    
    
}

protocol IndigoConnectionDelegate {
    func connectionStateHasChanged(_ name: String, _ state: NWConnection.State)
}

