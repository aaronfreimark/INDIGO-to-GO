/*
 AF 2020-09-10
 With help from https://medium.com/better-programming/build-a-dominoes-game-in-swiftui-part-2-188b825cc35a
*/

import UIKit
import Combine
import Network

final class BonjourBrowser: NSObject, ObservableObject, Identifiable {
    
    var browser: NWBrowser!
    
    var discovered: [BonjourEndpoint] = [] {
        willSet {
            objectWillChange.send()
        }
    }
        
    func endpoint(name: String) -> NWEndpoint? {
        for endpoint in discovered {
            if endpoint.name == name { return endpoint.endpoint }
        }
        return nil
    }

    func foundNone() -> Bool {
        return self.discovered.isEmpty
    }
    
    func seek() {
        if self.foundNone() {
            let bonjourTCP = NWBrowser.Descriptor.bonjour(type: "_indigo._tcp" , domain: nil)
            let bonjourParms = NWParameters.init()
            browser = NWBrowser(for: bonjourTCP, using: bonjourParms)
            browser.stateUpdateHandler = { newState in
                switch newState {
                case .ready:
                    print("Bonjour new connection")
                case .cancelled:
                    print("Bonjour canceled.")
                default:
                    break
                }
            }
            
            browser.browseResultsChangedHandler = { ( results, changes ) in
                self.discovered.removeAll()
                // self.discovered = [BonjourEndpoint()]
                for result in results {
                    let endpoint = result.endpoint
                    let endpointObject = BonjourEndpoint(endpoint: endpoint)
                    self.discovered.append(endpointObject)
                    print("New Bonjour Endpoint: \(endpointObject.name)")
                }
            }
            
            self.browser.start(queue: DispatchQueue.main)
        }
    }
}


class BonjourEndpoint: Hashable, ObservableObject {
    var endpoint: NWEndpoint?
    var name: String
    
    init(endpoint: NWEndpoint) {
        self.endpoint = endpoint
        if case let NWEndpoint.service(name: name, type: _, domain: _, interface: _) = endpoint {
            self.name = name
        } else {
            self.name = "Unknown"
        }
    }

    init() {
        self.name = "None"
        self.endpoint = nil
    }
    
    func hash(into hasher: inout Hasher) {
        hasher.combine(endpoint)
    }

    static func == (lhs: BonjourEndpoint, rhs: BonjourEndpoint) -> Bool {
        return lhs.hashValue == rhs.hashValue
    }

}


