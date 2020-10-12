//
//  IndigoProperties.swift
//  INDIGO Status
//
//  Created by Aaron Freimark on 9/17/20.
//

import Foundation
import SwiftyJSON
import URLImage
import SwiftUI

class IndigoProperties: ObservableObject, Hashable {
    private var properties: [String: IndigoItem] = [:]
    var queue: DispatchQueue

    private var lastUpdate = Date()
    private let tooLongSinceLastUpdate = TimeInterval(-10) // seconds
    
    var serverVersion: String = "Unknown"
    
    @Published var guiderTrackingStatus: String = ""
    @Published var guiderTrackingText: String = ""
    @Published var guiderDriftMax: String = ""
    @Published var guiderRSMEDec: Float = 0
    @Published var guiderRSMERA: Float = 0
    @Published var guiderRSMEDecStatus: String = ""
    @Published var guiderRSMERAStatus:  String = ""

    
    @Published var mountIsTracking = false
    var mountIsParked = false
    @Published var mountTrackingStatus: String = ""
    @Published var mountTrackingText: String = ""
    @Published var mountMeridian: String = ""
    @Published var mountSecondsUntilMeridian: Float = 0
    @Published var mountSecondsUntilHALimit: Float = 0
    @Published var mountHALimit: String = ""
    @Published var isMountHALimitEnabled = false

    var imagerState: ImagerState = .Stopped
    @Published var imagerSequenceText: String = ""
    @Published var imagerSequenceStatus: String = ""

    @Published var imagerCameraTemperature: String = ""
    @Published var imagerCoolingStatus: String = ""
    @Published var imagerCoolingText: String = ""
    var imagerIsCoolerOn = false

    @Published var imagerExpectedFinish: String = ""
    @Published var imagerImagesTotal: Int = 0
    @Published var imagerImagesTaken: Int = 0
    
    @Published var imagerLatestImageURL: URL = URL(string: "https://www.dropbox.com/s/wei6v5vir7adihc/Andromeda-RGB.jpg?raw=1")!
    @Published var imagerImageLatest: String = ""
    @Published var sequences: [IndigoSequence] = []
    @Published var imagerTotalTime: Float = 0
    @Published var imagerElapsedTime: Float = 0

    @Published var imagerVersion: String = ""
    @Published var guiderVersion: String = ""
    @Published var mountVersion: String = ""

    @Published var isImagerConnected = false
    @Published var isGuiderConnected = false
    @Published var isMountConnected = false
    @Published var isAnythingConnected = false
    
    @Published var ParkandWarmButtonTitle = "Park and Warm"
    @Published var ParkandWarmButtonDescription = "Immediately park the mount and turn off imager cooling, if possible."
    @Published var ParkandWarmButtonOK = "Park"
    @Published var isPartAndWarmButtonEnabled = false
    
    init(queue: DispatchQueue, isPreview: Bool = false) {
        self.queue = queue
        if isPreview { self.setUpPreview() }
    }
    
    func isTooLongSinceLastUpdate() -> Bool {
        // timeIntervalSinceNow will be negative
        return self.lastUpdate.timeIntervalSinceNow < self.tooLongSinceLastUpdate
    }
    
    func updateUI() {
        
                        
        self.serverVersion = getValue("Server | INFO | VERSION") ?? "Unknown"
        self.imagerVersion = getValue("Imager Agent | INFO | DEVICE_VERSION") ?? "Unknown"
        self.guiderVersion = getValue("Guider Agent | INFO | DEVICE_VERSION") ?? "Unknown"
        self.mountVersion = getValue("Mount Agent | INFO | DEVICE_VERSION") ?? "Unknown"

        let keys = self.getKeys()
        self.isImagerConnected = keys.contains { $0.hasPrefix("Imager Agent") }
        self.isGuiderConnected = keys.contains { $0.hasPrefix("Guider Agent") }
        self.isMountConnected = keys.contains { $0.hasPrefix("Mount Agent") }
        self.isAnythingConnected = self.isImagerConnected || self.isGuiderConnected || self.isMountConnected


        // =================================================================== IMAGER
        
        /*
         Imager Agent | AGENT_PAUSE_PROCESS | PAUSE
         Imager Agent | AGENT_START_PROCESS | EXPOSURE: false
         Imager Agent | AGENT_START_PROCESS | FOCUSING: false
         Imager Agent | AGENT_START_PROCESS | PREVIEW: false
         Imager Agent | AGENT_START_PROCESS | SEQUENCE: true
        */

        let sequence = "Imager Agent | AGENT_START_PROCESS | SEQUENCE"
        let pause = "Imager Agent | AGENT_PAUSE_PROCESS | PAUSE"

        if getValue(pause) == "false" && getState(pause) == .Busy {
            self.imagerState = .Paused
            self.imagerSequenceText = "Sequence Paused"
            self.imagerSequenceStatus = "pause.circle.fill"
        } else if getValue(sequence) == "true" && getState(sequence) == .Busy {
            self.imagerState = .Sequencing
            self.imagerSequenceText = "Sequence in Progress"
            self.imagerSequenceStatus = "ok"
        } else {
            self.imagerState = .Stopped
            self.imagerSequenceText = "Sequence Stopped"
            self.imagerSequenceStatus = "alert"
        }


        self.imagerImageLatest = getValue("Imager Agent | CCD_IMAGE_FILE | FILE") ?? ""

        self.imagerCameraTemperature = getValue("Imager Agent | CCD_TEMPERATURE | TEMPERATURE") ?? ""
        self.imagerIsCoolerOn = getValue("Imager Agent | CCD_COOLER | ON") == "true"
        
        if !self.imagerIsCoolerOn {
            self.imagerCoolingText = "Cooling Off"
            self.imagerCoolingStatus = "alert"
        } else if getState("Imager Agent | CCD_TEMPERATURE | TEMPERATURE") == .Ok {
            self.imagerCoolingText = "Cooling"
            self.imagerCoolingStatus = "ok"
        } else {
            self.imagerCoolingText = "Cooling In Progress"
            self.imagerCoolingStatus = "warn"
        }

        
        var imagerDitherDelay: Float = 0
        if let imagerDitherDelayString = getValue("Imager Agent | AGENT_IMAGER_DITHERING | DELAY") {
            imagerDitherDelay = Float(imagerDitherDelayString) ?? 0
        }
        
        var imagerBatchInProgress = 0
        if let imagerBatchInProgressString = getValue("Imager Agent | AGENT_IMAGER_STATS | BATCH") {
            imagerBatchInProgress = Int(imagerBatchInProgressString) ?? 0
        }
        
        var imagerFrameInProgress: Float = 0
        if let imagerFrameInProgressString = getValue("Imager Agent | AGENT_IMAGER_STATS | FRAME") {
            imagerFrameInProgress = Float(imagerFrameInProgressString) ?? 0
        }
        
        var totalTime: Float = 0
        var elapsedTime: Float = 0
        var thisBatch = 1
        var imagesTotal = 0
        var imagesTaken = 0
        
        // Sequences can "Keep" the same exposure and count settings as the prior sequence, so we do not reset then between sequences.
        var exposure: Float = 0;
        var count: Float = 0;
        var filter: String = "";
        var imageTimes: [IndigoSequence] = []

        if let sequences = getValue("Imager Agent | AGENT_IMAGER_SEQUENCE | SEQUENCE") {
            for seq in sequences.components(separatedBy: ";") {
                if let seqNum = Int(seq) {
                    if let sequence = getValue("Imager Agent | AGENT_IMAGER_SEQUENCE | " + String(format: "%02d",seqNum)) {
                        for prop in sequence.components(separatedBy: ";") {
                            if prop.prefix(9) == "exposure=" { exposure = Float(prop.replacingOccurrences(of: "exposure=", with: ""))! }
                            if prop.prefix(6) == "count=" { count = Float(prop.replacingOccurrences(of: "count=", with: ""))! }
                            if prop.prefix(7) == "filter=" { filter = prop.replacingOccurrences(of: "filter=", with: "") }
                        }
                        
                        imageTimes.append(IndigoSequence(count: count, seconds: exposure + imagerDitherDelay, filter: filter))
                        //imageTimes.indices.last.map { imageTimes[$0].seconds -= imagerDitherDelay } // no dithering on the last item
                        
                        //let sequenceTime = exposure * count  +  imagerDitherDelay * (count - 1)

                        let sequenceTime = (exposure + imagerDitherDelay ) * count
                        totalTime += sequenceTime
                        imagesTotal += Int(count)

                        if thisBatch < imagerBatchInProgress {
                            elapsedTime += sequenceTime
                            imagesTaken += Int(count)
                        }
                        if thisBatch == imagerBatchInProgress {

                            let remainingTime = getValue("Imager Agent | AGENT_IMAGER_STATS | EXPOSURE")
                            let imagerFrameInProgressTimeElapsed = exposure - (Float(remainingTime ?? "0") ?? 0)

                            let partialTime = exposure * (imagerFrameInProgress - 1.0)  +  imagerDitherDelay * (imagerFrameInProgress - 1.0) + imagerFrameInProgressTimeElapsed

                            elapsedTime += partialTime
                            imagesTaken += Int(imagerFrameInProgress)
                        }
                    }
                }
                thisBatch += 1
            }
        }
        
        self.sequences = imageTimes
        self.imagerTotalTime = totalTime > 0 ? totalTime : 1.0

        let timeRemaining = totalTime - elapsedTime
        
        self.imagerElapsedTime = elapsedTime
        self.imagerImagesTaken = imagesTaken
        self.imagerImagesTotal = imagesTotal

        self.imagerExpectedFinish = timeString(date: Date().addingTimeInterval(TimeInterval(timeRemaining)))
        
        if totalTime == 0 {
            self.imagerExpectedFinish = "—"
        } else if self.imagerState == .Stopped {
            self.imagerExpectedFinish = timeString(date: Date().addingTimeInterval(TimeInterval(totalTime)))
        } else {
            self.imagerExpectedFinish = timeString(date: Date().addingTimeInterval(TimeInterval(timeRemaining)))
        }


        // =================================================================== GUIDER
        
        let isGuiding = getValue("Guider Agent | AGENT_START_PROCESS | GUIDING") == "true"
        let isDithering = Float(getValue("Guider Agent | AGENT_GUIDER_STATS | DITHERING") ?? "0") ?? 0 > 0
        let isCalibrating = getValue("Guider Agent | AGENT_START_PROCESS | CALIBRATION") == "true"
        
        if isGuiding && isDithering {
            self.guiderTrackingText = "Dithering"
            self.guiderTrackingStatus = "ok"
        } else if isGuiding {
            self.guiderTrackingText = "Guiding"
            self.guiderTrackingStatus = "ok"
        } else if isCalibrating {
            self.guiderTrackingText = "Calibrating"
            self.guiderTrackingStatus = "warn"
        } else {
            self.guiderTrackingText = "Guiding Off"
            self.guiderTrackingStatus = "alert"
        }
        
        if self.guiderTrackingText == "Guiding" || self.guiderTrackingText == "Dithering" {
            let guiderDriftX = Float(getValue("Guider Agent | AGENT_GUIDER_STATS | DRIFT_X") ?? "0") ?? 0
            let guiderDriftY = Float(getValue("Guider Agent | AGENT_GUIDER_STATS | DRIFT_Y") ?? "0") ?? 0
            let guiderDriftMaximum = max(abs(guiderDriftX),abs(guiderDriftY))
            self.guiderDriftMax = String(format: "%.2f px", guiderDriftMaximum)
            
            if guiderDriftMaximum > 0 && guiderDriftMaximum <= 1.5 {
                self.guiderTrackingStatus = "ok"
            } else if guiderDriftMaximum > 1.5 {
                self.guiderTrackingStatus = "warn"
            }

            self.guiderRSMERA = Float(getValue("Guider Agent | AGENT_GUIDER_STATS | RMSE_RA") ?? "0") ?? 0
            self.guiderRSMERAStatus = self.guiderRSMERA < 0.2 ? "ok" : "warn"
            self.guiderRSMEDec = Float(getValue("Guider Agent | AGENT_GUIDER_STATS | RMSE_DEC") ?? "0") ?? 0
            self.guiderRSMEDecStatus = self.guiderRSMEDec < 0.2 ? "ok" : "warn"

        } else {
            self.guiderDriftMax = ""
            self.guiderRSMERAStatus = "unknown"
            self.guiderRSMEDecStatus = "unknown"
        }


        //    Guider Agent | AGENT_GUIDER_STATS | RMSE_DEC: 0.077
        //    Guider Agent | AGENT_GUIDER_STATS | RMSE_RA: 0.171


        // =================================================================== MOOUNT

        self.mountMeridian = ""
        
        if getValue("Mount Agent | MOUNT_PARK | PARKED") == "true" {
            self.mountTrackingStatus = "alert"
            self.mountTrackingText = "Mount Parked"
            self.mountIsTracking = false
            self.mountIsParked = true
        } else if getValue("Mount Agent | MOUNT_TRACKING | ON") == "true" {
            self.mountTrackingStatus = "ok"
            self.mountTrackingText = "Mount Tracking"
            self.mountIsTracking = true
            self.mountIsParked = false
        } else if getValue("Mount Agent | MOUNT_TRACKING | OFF") == "true" {
            self.mountTrackingStatus = "warn"
            self.mountTrackingText = "Mount Not Tracking"
            self.mountIsTracking = false
            self.mountIsParked = false
        } else {
            self.mountTrackingStatus = "unknown"
            self.mountTrackingText = "Mount State Unknown"
            self.mountIsTracking = false
            self.mountIsParked = true
        }

        if let HALimit = Float(getTarget("Mount Agent | AGENT_LIMITS | HA_TRACKING") ?? "0") {
            self.isMountHALimitEnabled = HALimit != 24.0
        }
        
        if self.mountIsTracking {
            let secondsInDay = Float(24 * 60 * 60)

            if let hourAngle = Float(getValue("Mount Agent | AGENT_LIMITS | HA_TRACKING") ?? "0") {
                var timeUntilMeridianSeconds = 3600 * (24.0 - hourAngle)
                while timeUntilMeridianSeconds >= secondsInDay {
                    timeUntilMeridianSeconds -= secondsInDay
                }

                let mountMeridianTime = Date().addingTimeInterval(TimeInterval(timeUntilMeridianSeconds))

                timeUntilMeridianSeconds += elapsedTimeIfSequencing()
                
                self.mountSecondsUntilMeridian = timeUntilMeridianSeconds
                self.mountMeridian = timeString(date: mountMeridianTime)
                
                if let HALimit = Float(getTarget("Mount Agent | AGENT_LIMITS | HA_TRACKING") ?? "0") {

                    self.isMountHALimitEnabled = HALimit != 24.0
                    

                    var timeUntilHALimitSeconds = 3600 * (HALimit - hourAngle)
                    while timeUntilHALimitSeconds >= secondsInDay {
                        timeUntilHALimitSeconds -= secondsInDay
                    }
                    
                    let mountHALimitTime = Date().addingTimeInterval(TimeInterval(timeUntilHALimitSeconds))

                    timeUntilHALimitSeconds += elapsedTimeIfSequencing()

                    self.mountSecondsUntilHALimit = timeUntilHALimitSeconds
                    self.mountHALimit = timeString(date: mountHALimitTime)
                }
            }
        } else {
            self.mountMeridian = "Not tracking"
            self.mountHALimit = "Not tracking"
        }

        
        if self.isMountConnected && self.isImagerConnected {
            self.ParkandWarmButtonTitle = "Park and Warm"
            self.ParkandWarmButtonDescription = "Immediately park the mount and turn off imager cooling, if possible."
            self.ParkandWarmButtonOK = "Park"
            self.isPartAndWarmButtonEnabled = !self.mountIsParked || self.imagerIsCoolerOn

        } else if self.isMountConnected && !self.isImagerConnected {
            self.ParkandWarmButtonTitle = "Park Mount"
            self.ParkandWarmButtonDescription = "Immediately park the mount, if possible."
            self.ParkandWarmButtonOK = "Park"
            self.isPartAndWarmButtonEnabled = !self.mountIsParked

        } else if !self.isMountConnected && self.isImagerConnected {
            self.ParkandWarmButtonTitle = "Warm Cooler"
            self.ParkandWarmButtonDescription = "Immediately turn off imager cooling, if possible."
            self.ParkandWarmButtonOK = "Warm"
            self.isPartAndWarmButtonEnabled = self.imagerIsCoolerOn

        } else {
            self.ParkandWarmButtonTitle = "Park and Warm"
            self.ParkandWarmButtonDescription = "Immediately park the mount and turn off imager cooling, if possible."
            self.ParkandWarmButtonOK = "Park"
            self.isPartAndWarmButtonEnabled = false

        }
        
        

        
        /*


         "Imager Agent | AGENT_IMAGER_STATS | BATCH": "1" --- Busy
         "Imager Agent | AGENT_IMAGER_STATS | BATCHES": "3" --- Busy
         "Imager Agent | AGENT_IMAGER_STATS | DELAY": "28" --- Busy
         "Imager Agent | AGENT_IMAGER_STATS | DRIFT_X": "0" --- Busy
         "Imager Agent | AGENT_IMAGER_STATS | DRIFT_Y": "0" --- Busy
         "Imager Agent | AGENT_IMAGER_STATS | EXPOSURE": "0" --- Busy
         "Imager Agent | AGENT_IMAGER_STATS | FRAME": "5" --- Busy
         "Imager Agent | AGENT_IMAGER_STATS | FRAMES": "20" --- Busy

         "Imager Agent | CCD_IMAGE | IMAGE": "/blob/0xb1166c50.fits" --- Ok
         "Imager Agent | CCD_IMAGE_FILE | FILE": "/home/indigo/Eagle_Light_Ha_-20_600s_012.fits" --- Ok

         "Mount Agent | MOUNT_PARK | PARKED": "false" --- Ok

         "Mount Agent | AGENT_LIMITS | HA_TRACKING": "1.61624" --- Ok
         "Mount Agent | AGENT_LIMITS | LOCAL_TIME": "21.1617" --- Ok

         "Mount Agent | MOUNT_LST_TIME | TIME": "19.9318" --- Ok
         */
        
    }

    func setUpPreview() {
        
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
        
        self.imagerState = .Sequencing

        
        setValue(key: "Mount Agent | MOUNT_PARK | PARKED", toValue: "false", toState: "Ok")
        setValue(key: "Mount Agent | MOUNT_TRACKING | ON", toValue: "true", toState: "Ok")
        setValue(key: "Mount Agent | AGENT_LIMITS | HA_TRACKING", toValue: "23.0", toState: "Ok", toTarget: "23.66666666")
        
        switch self.imagerState {
        case .Sequencing:
            setValue(key: "Imager Agent | AGENT_START_PROCESS | SEQUENCE", toValue: "true", toState: "Busy")
            setValue(key: "Imager Agent | AGENT_PAUSE_PROCESS | PAUSE", toValue: "false", toState: "Ok")
            break
        case .Paused:
            setValue(key: "Imager Agent | AGENT_START_PROCESS | SEQUENCE", toValue: "false", toState: "Ok")
            setValue(key: "Imager Agent | AGENT_PAUSE_PROCESS | PAUSE", toValue: "false", toState: "Busy")
            break
        case .Stopped:
            setValue(key: "Imager Agent | AGENT_START_PROCESS | SEQUENCE", toValue: "false", toState: "Ok")
            setValue(key: "Imager Agent | AGENT_PAUSE_PROCESS | PAUSE", toValue: "false", toState: "Ok")
            break
        }
            
        setValue(key: "Imager Agent | AGENT_IMAGER_SEQUENCE | 01", toValue: "exposure=600.0;count=6.0;filter=R;", toState: "Ok")
        setValue(key: "Imager Agent | AGENT_IMAGER_SEQUENCE | 02", toValue: "filter=B;", toState: "Ok")
        setValue(key: "Imager Agent | AGENT_IMAGER_SEQUENCE | 03", toValue: "filter=G;", toState: "Ok")
        
        setValue(key: "Imager Agent | AGENT_IMAGER_SEQUENCE | SEQUENCE", toValue: "1;2;3;", toState: "Ok")
//        setValue(key: "Imager Agent | AGENT_IMAGER_SEQUENCE | SEQUENCE", toValue: "", toState: "Ok")
        
        setValue(key: "Imager Agent | AGENT_IMAGER_STATS | BATCH", toValue: "1", toState: "Busy")
        setValue(key: "Imager Agent | AGENT_IMAGER_STATS | BATCHES", toValue: "3", toState: "Busy")
        setValue(key: "Imager Agent | AGENT_IMAGER_STATS | FRAME", toValue: "3", toState: "Busy")

        setValue(key: "Imager Agent | CCD_COOLER | ON", toValue: "true", toState: "Ok")
        setValue(key: "Imager Agent | CCD_TEMPERATURE | TEMPERATURE", toValue: "-20", toState: "Ok")

        setValue(key: "Guider Agent | AGENT_START_PROCESS | GUIDING", toValue: "true", toState: "Ok")
    }


    func getKeys() -> [String] {
        return self.queue.sync {
            return Array(self.properties.keys)
        }
    }
    
    func getValue(_ key: String) -> String? {
        return self.queue.sync {
            if let item = self.properties[key] {
                return item.value
            }
            return nil
        }
    }
    
    func getTarget(_ key: String) -> String? {
        return self.queue.sync {
            if let item = self.properties[key] {
                return item.target
            }
            return nil
        }
    }

    func getState(_ key: String) -> StateValue? {
        return self.queue.sync {
            if let item = properties[key] {
                if let state = item.state {
                    return state
                }
            }
            return nil
        }
    }

    func setValue(key:String, toValue value:String, toState state:String, toTarget target:String? = nil) {
        let newItem = IndigoItem(theValue: value, theState: state, theTarget: target)
        self.queue.async {
            self.properties[key] = newItem
        }
    }
    
    func delValue(_ key: String) {
        self.queue.async {
            self.properties.removeValue(forKey: key)
        }
    }

    
    /// Shifts times for Meridian & HA Limit over if sequence is running, so these count from start of sequence instead of now()
    func elapsedTimeIfSequencing() -> Float {
        if self.imagerState != .Stopped {
            return self.imagerElapsedTime
        } else {
            return 0.0
        }
    }
    
    func injest(json: JSON, source: IndigoConnection) {
        // if json.rawString()!.contains("RMSE") { print(json.rawString()) }

        for (type, subJson):(String, JSON) in json {
            
            // Is the is "def" or "set" Indigo types?
            if (type.prefix(3) == "def") || (type.prefix(3) == "set") || type.prefix(3) == "del" {
                let device = subJson["device"].stringValue
                //let group = subJson["group"].stringValue
                let name = subJson["name"].stringValue
                let state = subJson["state"].stringValue
                
                // make sure we records only the devices we care about
                if ["Imager Agent", "Guider Agent", "Mount Agent", "Server"].contains(device) {
                    if subJson["items"].exists() {
                        for (_, itemJson):(String, JSON) in subJson["items"] {
                            
                            let itemName = itemJson["name"].stringValue
                            let key = "\(device) | \(name) | \(itemName)"

                            let itemValue = itemJson["value"].stringValue
                            let itemTarget = itemJson["target"].stringValue

                            switch type.prefix(3) {
                            case "def", "set":
                                if !itemName.isEmpty && itemJson["value"].exists() {
                                    self.setValue(key: key, toValue: itemValue, toState: state, toTarget: itemTarget)
                                }
                                
                                // handle special cases
                                if key == "Imager Agent | CCD_PREVIEW_IMAGE | IMAGE" && state == "Ok" && itemValue.count > 0 {
                                    if let urlprefix = source.url {
                                        let url = URL(string: urlprefix + itemValue)!
                                        let placeholder = Bundle.main.url(forResource: "1x1", withExtension: "png")!
                                        DispatchQueue.main.async { self.imagerLatestImageURL = placeholder }
                                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { self.imagerLatestImageURL = url }
                                        print("imagerLatestImageURL: \(url)")
                                    }
                                }
                                
                                break
                            case "del":
                                self.delValue(key)
                                break
                            default:
                                break
                            }
                        }
                    }
                    self.lastUpdate = Date()
                }
            }
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

    func hash(into hasher: inout Hasher) {
        hasher.combine(properties)
    }

    static func == (lhs: IndigoProperties, rhs: IndigoProperties) -> Bool {
        return lhs.hashValue == rhs.hashValue
    }

    
    var timeFormat: DateFormatter {
        let formatter = DateFormatter()
        formatter.dateStyle = .none
        formatter.timeStyle = .short
        return formatter
    }
    
    func timeString(date: Date) -> String {
        let time = timeFormat.string(from: date)
        return time
    }
    
    
}


enum ImagerState: String {
    case Stopped, Sequencing, Paused
}

struct IndigoProperties_Previews: PreviewProvider {
    static var previews: some View {
        let client = IndigoClient(isPreview: true)
        ContentView(client: client)
    }
}
