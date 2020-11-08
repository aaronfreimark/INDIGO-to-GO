//
//  IndigoClientProtocol.swift
//  INDIGO to GO
//
//  Created by Aaron Freimark on 10/22/20.
//

import Foundation
import Combine
import Network

protocol IndigoPropertyService {
    
    var name: String { get }
    var systemIcon: String { get }

    // Property Management
    func getKeys() -> [String]
    func getValue(_ key: String) -> String?
    func getTarget(_ key: String) -> String?
    func getState(_ key: String) -> StateValue?
    
    // Actions
    func emergencyStopAll()

    // Connections
    func restart()
    func connectedServers() -> [String]
    var endpoints: [String: NWEndpoint] { get set }

    // FIXME: Move to its own model
    var imagerLatestImageURL: URL? { get }
    var guiderLatestImageURL: URL? { get }

}


protocol IndigoConnectionService {
    // Connection Management
}
