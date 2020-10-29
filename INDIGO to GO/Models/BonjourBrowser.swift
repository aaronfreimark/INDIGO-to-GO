/*
 AF 2020-09-10
 With help from https://medium.com/better-programming/build-a-dominoes-game-in-swiftui-part-2-188b825cc35a
*/

import UIKit
import Combine
import Network

final class BonjourBrowser: NSObject, ObservableObject, Identifiable {
    
    var browser: NWBrowser!
    var discovered: [BonjourEndpoint] = [BonjourEndpoint()] {
        didSet { publisher.send(discovered) }
    }
    let publisher = PassthroughSubject<[BonjourEndpoint], Never>()
        
    func endpoint(name: String) -> NWEndpoint? {
        for endpoint in self.discovered {
            if endpoint.name == name {
                return endpoint.endpoint
            }
        }
        return nil
    }

    func names() -> [String] {
        var names: [String] = []
        for endpoint in discovered {
            names.append(endpoint.name)
        }
        return names
    }
    
    func foundNone() -> Bool {
        return self.discovered.count == 1 && self.discovered[0].name == "None"
        //return self.discovered.isEmpty
    }
    
    func cancel() {
        print("BonjourBrowser: Canceling...")
        self.browser.cancel()
    }
    
    func seek() {
        self.discovered = [BonjourEndpoint()]
        
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
        
        browser.browseResultsChangedHandler = { ( _, changes ) in
            for change in changes {
                switch change {
                case let .added(result):
                    let endpoint = BonjourEndpoint(endpoint: result.endpoint)
                    print("New Bonjour Endpoint: \(endpoint.name)")
                    self.discovered.append(endpoint)
                    break
                case let .removed(result):
                    // TODO: if the selected item goes away, go back to "None"
                    let endpoint = BonjourEndpoint(endpoint: result.endpoint)
                    print("Removing Bonjour Endpoint: \(endpoint.name)")
                    self.discovered.removeAll(where: { $0.name == endpoint.name } )
                    break
                case .identical, .changed:
                    break
                @unknown default:
                    break
                }
            }
        }
        
        print("BonjourBrowser: Starting...")
        self.browser.start(queue: DispatchQueue.main)
    }
}

