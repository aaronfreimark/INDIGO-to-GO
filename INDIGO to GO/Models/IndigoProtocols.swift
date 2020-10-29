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
    
    // Property Management
    func getKeys() -> [String]
    func getValue(_ key: String) -> String?
    func getTarget(_ key: String) -> String?
    func getState(_ key: String) -> StateValue?
    
    // Actions
    func emergencyStopAll()

    // Connections
    var endpoints: [String: NWEndpoint] { get set }
    func connectedServers() -> [String]
    func reinitSavedServers()

    // FIXME: Move to its own model
    var imagerLatestImageURL: URL? { get }
    var guiderLatestImageURL: URL? { get }
    
    // FIXME: Move to ViewModel
    var defaultImager: String { get set }
    var defaultGuider: String { get set }
    var defaultMount: String { get set }
}


protocol IndigoConnectionService {
    // Connection Management
}
