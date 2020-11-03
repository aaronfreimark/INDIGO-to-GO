//
//  MockIndigoClientForPreview.swift
//  INDIGO to GO
//
//  Created by Aaron Freimark on 10/24/20.
//

import Foundation
import Combine
import Network

class MockIndigoClientForPreview: IndigoPropertyService {

    var systemIcon = "ladybug"
    var imagerLatestImageURL: URL?
    var guiderLatestImageURL: URL?

    var endpoints: [String: NWEndpoint] = [:]

    private var properties: [String: IndigoItem] = [:]
    let queue = DispatchQueue(label: "Client connection Q")
    
    init() {

        /*
         *  Preview has HA = 22:00, HA_LIMIT = 23:40
         *  Sequence has dots every 10 minutes, 1 hour per filter, 3 hours total
         *
         *  If start time is midnight:
         *      meridian = 2AM
         *      HA Limit = 1:45AM
         *      End Time = 3AM
         *
         *  Stopped: Count time from Date() i.e. NOW
         *  Sequencing: Count time from Date() - Elapsed Time = sequence start time
         *  Paused: Same as sequencing! Date() will increase with each second, but Elapsed Time will NOT
         *
         */
        
        self.setValue(key: "Mount Agent | MOUNT_PARK | PARKED", toValue: "false", toState: "Ok")
        self.setValue(key: "Mount Agent | MOUNT_TRACKING | ON", toValue: "true", toState: "Ok")
        self.setValue(key: "Mount Agent | AGENT_LIMITS | HA_TRACKING", toValue: "23.0", toState: "Ok", toTarget: "23.66666666")
        
        //        case .Sequencing:
        self.setValue(key: "Imager Agent | AGENT_START_PROCESS | SEQUENCE", toValue: "true", toState: "Busy")
        self.setValue(key: "Imager Agent | AGENT_PAUSE_PROCESS | PAUSE", toValue: "false", toState: "Ok")
        
        //        case .Paused:
        //            self.setValue(key: "Imager Agent | AGENT_START_PROCESS | SEQUENCE", toValue: "false", toState: "Ok")
        //            self.setValue(key: "Imager Agent | AGENT_PAUSE_PROCESS | PAUSE", toValue: "false", toState: "Busy")
        
        //        case .Stopped:
        //            self.setValue(key: "Imager Agent | AGENT_START_PROCESS | SEQUENCE", toValue: "false", toState: "Ok")
        //            self.setValue(key: "Imager Agent | AGENT_PAUSE_PROCESS | PAUSE", toValue: "false", toState: "Ok")
        
        self.setValue(key: "Imager Agent | AGENT_IMAGER_SEQUENCE | 01", toValue: "exposure=600.0;count=6.0;filter=R;", toState: "Ok")
        self.setValue(key: "Imager Agent | AGENT_IMAGER_SEQUENCE | 02", toValue: "filter=B;", toState: "Ok")
        self.setValue(key: "Imager Agent | AGENT_IMAGER_SEQUENCE | 03", toValue: "filter=G;", toState: "Ok")
        
        self.setValue(key: "Imager Agent | AGENT_IMAGER_SEQUENCE | SEQUENCE", toValue: "1;2;3;", toState: "Ok")
        
        self.setValue(key: "Imager Agent | AGENT_IMAGER_STATS | BATCH", toValue: "1", toState: "Busy")
        self.setValue(key: "Imager Agent | AGENT_IMAGER_STATS | BATCHES", toValue: "3", toState: "Busy")
        self.setValue(key: "Imager Agent | AGENT_IMAGER_STATS | FRAME", toValue: "3", toState: "Busy")
        
        self.setValue(key: "Imager Agent | CCD_COOLER | ON", toValue: "true", toState: "Ok")
        self.setValue(key: "Imager Agent | CCD_TEMPERATURE | TEMPERATURE", toValue: "-20", toState: "Ok")
        
        self.setValue(key: "Guider Agent | AGENT_START_PROCESS | GUIDING", toValue: "true", toState: "Ok")
        
        self.imagerLatestImageURL = URL(string: "https://indigotogo.app/Andromeda-RGB-2048.jpg")
        self.guiderLatestImageURL = URL(string: "https://indigotogo.app/SquidStars.jpg")
    }
    
    
    func setValue(key:String, toValue value:String, toState state:String, toTarget target:String? = nil) {
        let newItem = IndigoItem(theValue: value, theState: state, theTarget: target)
        self.properties[key] = newItem
    }
    
    func getKeys() -> [String] {
        return Array(self.properties.keys)
    }
    
    func getValue(_ key: String) -> String? {
        if let item = self.properties[key] {
            return item.value
        }
        return nil
    }
    
    func getTarget(_ key: String) -> String? {
        if let item = self.properties[key] {
            return item.target
        }
        return nil
    }
    
    func getState(_ key: String) -> StateValue? {
        if let item = properties[key] {
            if let state = item.state {
                return state
            }
        }
        return nil
    }
    
    func emergencyStopAll() {
        return
    }
    
    func connectedServers() -> [String] {
        return ["Simulator"]
    }
    
    func reinit(servers: [String]) {
        return
    }

    
}
