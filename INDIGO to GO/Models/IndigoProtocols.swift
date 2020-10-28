//
//  IndigoClientProtocol.swift
//  INDIGO to GO
//
//  Created by Aaron Freimark on 10/22/20.
//

import Foundation
import Combine

protocol IndigoPropertyService {
    
    // Property Management
    func getKeys() -> [String]
    func getValue(_ key: String) -> String?
    func getTarget(_ key: String) -> String?
    func getState(_ key: String) -> StateValue?
    
    // Actions
    func emergencyStopAll()

    // Connections
    func connectedServers() -> [String]
    func reinitSavedServers()

    // FIXME: Move to its own model
    var imagerLatestImageURL: URL? { get }
    var guiderLatestImageURL: URL? { get }
    var bonjourBrowser: BonjourBrowser { get set }
    
    // FIXME: Move to ViewModel
    var defaultImager: String { get set }
    var defaultGuider: String { get set }
    var defaultMount: String { get set }

    var objectWillChange: ObservableObjectPublisher { get }
}


protocol IndigoConnectionService {
    // Connection Management
}
