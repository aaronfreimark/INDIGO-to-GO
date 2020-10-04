//
//  BonjourEndpoint.swift
//  INDIGO to GO
//
//  Created by Aaron Freimark on 10/4/20.
//

import Foundation
import Combine
import Network

class BonjourEndpoint: Hashable, ObservableObject {
    var endpoint: NWEndpoint?
    var name: String
    var type: String
    var domain: String
    
    init(endpoint: NWEndpoint) {
        self.endpoint = endpoint
        if case let NWEndpoint.service(name: name, type: type, domain: domain, interface: _) = endpoint {
            self.name = name
            self.type = type
            self.domain = domain
        } else {
            self.name = "Unknown"
            self.type = "Unknown"
            self.domain = "Unknown"
        }
    }

    init() {
        self.name = "None"
        self.endpoint = nil
        self.type = "None"
        self.domain = "None"
    }
    
    func hash(into hasher: inout Hasher) {
        hasher.combine(endpoint)
    }

    static func == (lhs: BonjourEndpoint, rhs: BonjourEndpoint) -> Bool {
        return lhs.hashValue == rhs.hashValue
    }
}
