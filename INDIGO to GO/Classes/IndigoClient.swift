//
//  File.swift
//  INDIGO Status
//
//  Created by Aaron Freimark on 9/10/20.
//

import Foundation
import SwiftyJSON
import SwiftUI
import Combine
import Network
import Solar

class IndigoClient: ObservableObject, IndigoConnectionDelegate {
    var id = UUID()
    var isPreview: Bool
    let queue = DispatchQueue(label: "Client connection Q")

    private var location: LocationFeatures
    private var properties: [String: IndigoItem] = [:]

    var defaultImager: String {
        didSet { UserDefaults.standard.set(defaultImager, forKey: "imager") }
    }
    var defaultGuider: String {
        didSet { UserDefaults.standard.set(defaultGuider, forKey: "guider") }
    }
    var defaultMount: String {
        didSet { UserDefaults.standard.set(defaultMount, forKey: "mount") }
    }
    
    @Published var bonjourBrowser: BonjourBrowser = BonjourBrowser()
    var connections: [String: IndigoConnection] = [:]
    var serversToDisconnect: [String] = []
    var serversToConnect: [String] = []
    var maxReconnectAttempts = 3

    var receivedRemainder = "" // partial text while receiving INDI
    
    var anyCancellable: AnyCancellable? = nil

    /// Generally useful properties
    @Published var isImagerConnected = false
    @Published var isGuiderConnected = false
    @Published var isMountConnected = false
    @Published var isAnythingConnected = false
    @Published var isMountTracking = false
    @Published var isMountHALimitEnabled = false
    var lastUpdate: Date?
    
    /// properties for the progress display
    var imagerState = ImagerState.Stopped
    enum ImagerState: String {
        case Stopped, Sequencing, Paused
    }
    var imagerStart: Date?
    var imagerFinish: Date?
    @Published var sequences: [IndigoSequence] = []
    @Published var imagerTotalTime: Float = 0
    @Published var imagerElapsedTime: Float = 0
    @Published var mountSecondsUntilMeridian: Float = 0
    @Published var mountSecondsUntilHALimit: Float = 0
    
    /// properties for the Status Rows
    @Published var srSequenceStatus: StatusRow?
    @Published var srEstimatedCompletion: StatusRow?
    @Published var srHALimit: StatusRow?
    @Published var srMeridianTransit: StatusRow?
    @Published var srSunrise: StatusRow?

    @Published var srGuidingStatus: StatusRow?
    @Published var srRAError: StatusRow?
    @Published var srDecError: StatusRow?

    @Published var srCoolingStatus: StatusRow?
    @Published var srMountStatus: StatusRow?

    /// properties for button
    @Published var parkButtonTitle = "Park and Warm"
    @Published var parkButtonDescription = "Immediately park the mount and turn off imager cooling, if possible."
    @Published var parkButtonOK = "Park"
    @Published var isParkButtonEnabled = false
    
    /// Properties for the image preview
    @Published var imagerLatestImageURL: URL?

    /// Properties for sunrise & sunset
    var hasLocation: Bool {
        return self.location.hasLocation
    }
    let secondsInDay = Float(24 * 60 * 60)
    let negMillion = -1000000
    @Published var secondsUntilSunrise: Float = -1000000
    @Published var secondsUntilAstronomicalSunrise: Float = -1000000
    @Published var secondsUntilSunset: Float = -1000000
    @Published var secondsUntilAstronomicalSunset: Float = -1000000
    
    
    init(isPreview: Bool = false) {
        
        self.location = LocationFeatures(isPreview: isPreview)
        self.isPreview = isPreview
        
        self.defaultImager = UserDefaults.standard.object(forKey: "imager") as? String ?? "None"
        self.defaultGuider = UserDefaults.standard.object(forKey: "guider") as? String ?? "None"
        self.defaultMount = UserDefaults.standard.object(forKey: "mount") as? String ?? "None"

        // Combine publishers into the main thread.
        // https://stackoverflow.com/questions/58437861/
        // https://stackoverflow.com/questions/58406287
        anyCancellable = bonjourBrowser.objectWillChange.sink { [weak self] (_) in
            self?.objectWillChange.send()
        }

        if isPreview {
            self.updateUI()
        } else {
            // after 1 second search for whatever is in serverSettings.servers to try to reconnect
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                self.reinitSavedServers()
            }
        }

    }
    
    func reinitSavedServers() {
        self.reinit(servers: [self.defaultImager, self.defaultGuider, self.defaultMount])
    }
    
    func reinit(servers: [String]) {
        print("ReInit with servers \(servers)")
        
        // 1. Disconnect all servers
        // 2. Once disconnected, remove all properties
        // 3. Connect to all servers
        // 4. Profit
        
        self.serversToConnect = servers.removingDuplicates()
        
        // clear out all properties!
        self.properties.removeAll()

        self.serversToDisconnect = self.allServers()
        
        if self.serversToDisconnect.count > 0 {
            self.disconnectAll()
            // Connect will happen after all servers are disconnected
        }
        else {
            self.connectAll()
        }
    }

    // =============================================================================================

    func allServers() -> [String] {
            return Array(self.connections.keys)
    }

    func connectedServers() -> [String] {
        var connectedServers: [String] = []
        for (name,connection) in self.connections {
            if connection.isConnected() { connectedServers.append(name) }
        }
        return connectedServers
    }

    func updateUI() {
        self.updateProperties()
        //self.location.updateUI(start: self.imagerStart, finish: self.imagerFinish)
    }
    
    
    
    // =============================================================================================


    func emergencyStopAll() {
        self.queue.async {
            for (_, connection) in self.connections {
                connection.mountPark()
                connection.imagerDisableCooler()
            }
        }
    }

    func enableAllPreviews() {
        self.queue.async {
            for (_, connection) in self.connections {
                connection.enablePreviews()
            }
        }
    }

    // =============================================================================================

    
    func connectAll() {
        print("Connecting to servers: \(self.serversToConnect)")
        for server in self.serversToConnect {
            // Make sure each agent is unique. We don't need multiple connections to an endpoint!
            if server != "None" && !self.connectedServers().contains(server)  {
                if let endpoint = self.bonjourBrowser.endpoint(name: server) {
                    self.queue.async {
                        let connection = IndigoConnection(name: server, endpoint: endpoint, queue: self.queue, delegate: self)
                        print("\(connection.name): Setting Up...")
                        self.connections[server] = connection
                        connection.start()
                    }
                }
            }
        }

        self.serversToConnect = []
    }

    // =============================================================================================

    func receiveMessage(data: Data?, context: NWConnection.ContentContext?, isComplete: Bool, error: NWError?, source: IndigoConnection) {
        if let data = data, !data.isEmpty {
            if let message = String(data: data, encoding: .utf8) {
                // print ("Received: \(message ?? "-" )")
                // print ("Received \(message.count) bytes")
                
                if let dataFromString = message.data(using: .ascii, allowLossyConversion: false) {
                    do {
                        let json = try JSON(data: dataFromString)
                        self.injest(json: json, source: source)
                    } catch {
                        print ("Really bad JSON error.")
                    }
                }
            }
        }
    }

    // =============================================================================================


    func connectionStateHasChanged(_ name: String, _ state: NWConnection.State) {
        guard let connection = self.connections[name] else {
            print("Unknown connection from delegate: \(name)")
            return
        }
        
        switch state {
        case .ready:
            self.queue.asyncAfter(deadline: .now() + 1.0) {
                connection.hello()
                connection.enablePreviews()
            }
        case .setup:
            break
        case .waiting:
            break
        case .preparing:
            break
        case .failed, .cancelled:
            print("\(name): State cancelled or failed.")
            // expected or unexpected? If unexpected, try to reconnect.
            
            if self.serversToDisconnect.contains(name) {
                print("==== Expected disconnection ====")
                self.connections.removeValue(forKey: name)
                self.serversToDisconnect.removeAll(where: { $0 == name } )
                if self.serversToDisconnect.isEmpty {
                    print("=== Beginning reconnections ===")
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                        self.connectAll()
                    }
                }
                
            } else {
                print("==== Unexpected disconnection ====")
                print("\(name): Removing connection :(")
                self.connections.removeValue(forKey: name)
                reinit(servers: self.connectedServers())
            }
            break
        default:
            break
        }
    }

    // =============================================================================================

    func disconnect(connection: IndigoConnection) {
        print("\(connection.name): Disconnecting client...")
        connection.stop()
    }
    
    func disconnectAll() {
        print("Disconnecting \(self.serversToDisconnect)...")
        for name in self.serversToDisconnect {
            self.queue.async {
                if let connection = self.connections[name] {
                    self.disconnect(connection: connection)
                }
            }
        }
    }

    /// =============================================================================================

    
    private func updateProperties() {
                        
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

        /// imageState & sequence status
        if getValue(pause) == "false" && getState(pause) == .Busy {
            self.imagerState = .Paused
            self.srSequenceStatus = StatusRow(
                text: "Sequence Paused",
                status: .custom("pause.circle.fill")
            )
        } else if getValue(sequence) == "true" && getState(sequence) == .Busy {
            self.imagerState = .Sequencing
            self.srSequenceStatus = StatusRow(
                text: "Sequence in Progress",
                status: .ok
            )
        } else {
            self.imagerState = .Stopped
            self.srSequenceStatus = StatusRow(
                text: "Sequence Stopped",
                status: .alert
            )
        }

        /// filename of last image
//        self.imagerImageLatest = getValue("Imager Agent | CCD_IMAGE_FILE | FILE") ?? ""

        /// cooler status
        let coolerTemperature = getValue("Imager Agent | CCD_TEMPERATURE | TEMPERATURE") ?? ""
        let isCoolerOn = getValue("Imager Agent | CCD_COOLER | ON") == "true"
        let isAtTemperature = getState("Imager Agent | CCD_TEMPERATURE | TEMPERATURE") == .Ok

        if !isCoolerOn {
            self.srCoolingStatus = StatusRow(
                text: "Cooling Off",
                status: .alert
            )
        } else if isAtTemperature {
            self.srCoolingStatus = StatusRow(
                text: "Cooling",
                status: .ok
            )
        } else {
            self.srCoolingStatus = StatusRow(
                text: "Cooling In Progress",
                status: .warn
            )
        }
        self.srCoolingStatus!.value = "\(coolerTemperature) °C"
        self.srCoolingStatus!.isSet = self.isImagerConnected


        /// sequence times
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
        self.srSequenceStatus?.value = "\(imagesTaken) / \(imagesTotal)"
        
        if totalTime == 0 {
            self.imagerStart = Date()
            self.imagerFinish = nil
        } else if self.imagerState == .Stopped {
            self.imagerStart = Date()
            self.imagerFinish = Date().addingTimeInterval(TimeInterval(totalTime))
        } else {
            self.imagerStart = Date().addingTimeInterval(TimeInterval(-1.0 * elapsedTime))
            self.imagerFinish = Date().addingTimeInterval(TimeInterval(timeRemaining))
        }

        
        let completionTimeString = totalTime > 0 ? self.imagerFinish!.timeString() : "–"
        self.srEstimatedCompletion = StatusRow(
            isSet: self.isImagerConnected,
            text: "Estimated Completion",
            value: completionTimeString,
            status: .custom("clock")
        )

        // =================================================================== GUIDER
        
        let isGuiding = getValue("Guider Agent | AGENT_START_PROCESS | GUIDING") == "true"
        let isDithering = Float(getValue("Guider Agent | AGENT_GUIDER_STATS | DITHERING") ?? "0") ?? 0 > 0
        let isCalibrating = getValue("Guider Agent | AGENT_START_PROCESS | CALIBRATION") == "true"
        
        var guiderTrackingText = ""
        var guiderTrackingStatus = StatusRow.Status.unknown

        if isGuiding && isDithering {
            guiderTrackingText = "Dithering"
            guiderTrackingStatus = .ok
        } else if isGuiding {
            guiderTrackingText = "Guiding"
            guiderTrackingStatus = .ok
        } else if isCalibrating {
            guiderTrackingText = "Calibrating"
            guiderTrackingStatus = .warn
        } else {
            guiderTrackingText = "Guiding Off"
            guiderTrackingStatus = .alert
        }
        
        let guiderDriftX = Float(getValue("Guider Agent | AGENT_GUIDER_STATS | DRIFT_X") ?? "0") ?? 0
        let guiderDriftY = Float(getValue("Guider Agent | AGENT_GUIDER_STATS | DRIFT_Y") ?? "0") ?? 0
        let guiderDriftMaximum = max(abs(guiderDriftX),abs(guiderDriftY))
        let guiderDriftMax = String(format: "%.2f px", guiderDriftMaximum)
        
        if isGuiding && guiderDriftMaximum > 1.5 {
            guiderTrackingStatus = .warn
        }

        self.srGuidingStatus = StatusRow(
            text: guiderTrackingText,
            value: guiderDriftMax,
            status: guiderTrackingStatus
        )

        /// RA & Dec Error
        let guiderRSMERA = Float(getValue("Guider Agent | AGENT_GUIDER_STATS | RMSE_RA") ?? "0") ?? 0
        let guiderRSMEDec = Float(getValue("Guider Agent | AGENT_GUIDER_STATS | RMSE_DEC") ?? "0") ?? 0
        let guiderRSMERAStatus = guiderRSMERA < 0.2 ? StatusRow.Status.ok : StatusRow.Status.warn
        let guiderRSMEDecStatus = guiderRSMEDec < 0.2 ? StatusRow.Status.ok : StatusRow.Status.warn
        
        self.srRAError = StatusRow(
            text: "RA Error (RSME)",
            value: String(guiderRSMERA),
            status: guiderRSMERAStatus
        )
        self.srDecError = StatusRow(
            text: "DEC Error (RSME)",
            value: String(guiderRSMEDec),
            status: guiderRSMEDecStatus
        )


        //    Guider Agent | AGENT_GUIDER_STATS | RMSE_DEC: 0.077
        //    Guider Agent | AGENT_GUIDER_STATS | RMSE_RA: 0.171


        // =================================================================== MOUNT

        var isMountParked = false

        if getValue("Mount Agent | MOUNT_PARK | PARKED") == "true" {
            self.srMountStatus = StatusRow(
                text: "Mount Parked",
                status: .alert
            )
            isMountParked = true
        } else if getValue("Mount Agent | MOUNT_TRACKING | ON") == "true" {
            self.srMountStatus = StatusRow(
                text: "Mount Tracking",
                status: .ok
            )
            isMountTracking = true
        } else if getValue("Mount Agent | MOUNT_TRACKING | OFF") == "true" {
            self.srMountStatus = StatusRow(
                text: "Mount Not Tracking",
                status: .warn
            )
        } else {
            self.srMountStatus = StatusRow(
                text: "Mount State Unknown",
                status: .unknown
            )
            isMountParked = true
        }
        self.srMountStatus!.isSet = self.isMountConnected
        
        /// Meridian Time
        
        let hourAngle = Float(getValue("Mount Agent | AGENT_LIMITS | HA_TRACKING") ?? "0")!
        var timeUntilMeridianSeconds = 3600 * (24.0 - hourAngle)
        
        /// Too far in advance? Rewind the clock.
        while timeUntilMeridianSeconds >= secondsInDay { timeUntilMeridianSeconds -= secondsInDay }
        
        let mountMeridianTime = Date().addingTimeInterval(TimeInterval(timeUntilMeridianSeconds))
        
        /// If sequencing, add the elapsed time so it displays as expected.
        timeUntilMeridianSeconds += elapsedTimeIfSequencing()
        
        self.mountSecondsUntilMeridian = timeUntilMeridianSeconds
        let meridianValue = isMountTracking ? mountMeridianTime.timeString() : "Not tracking"

        self.srMeridianTransit = StatusRow(
            isSet: self.isMountConnected,
            text: "Meridian Transit",
            value: meridianValue,
            status: .custom("ellipsis.circle")
        )
        
        
        /// HA Limit

        let HALimit = Float(getTarget("Mount Agent | AGENT_LIMITS | HA_TRACKING") ?? "0")!
        self.isMountHALimitEnabled = self.isMountConnected && (HALimit != 24.0 && HALimit != 0)
        
        var timeUntilHALimitSeconds = 3600 * (HALimit - hourAngle)

        /// Too far in advance? Rewind the clock.
        while timeUntilHALimitSeconds >= secondsInDay { timeUntilHALimitSeconds -= secondsInDay }
        
        let mountHALimitTime = Date().addingTimeInterval(TimeInterval(timeUntilHALimitSeconds))

        /// If sequencing, add the elapsed time so it displays as expected.
        timeUntilHALimitSeconds += elapsedTimeIfSequencing()

        self.mountSecondsUntilHALimit = timeUntilHALimitSeconds
        let mountHALimit = isMountTracking ? mountHALimitTime.timeString() : "Not tracking"

        self.srHALimit = StatusRow(
            isSet: isMountHALimitEnabled,
            text: "HA Limit",
            value: mountHALimit,
            status: .custom("exclamationmark.arrow.circlepath")
        )

        
        if self.isMountConnected && self.isImagerConnected {
            self.parkButtonTitle = "Park and Warm"
            self.parkButtonDescription = "Immediately park the mount and turn off imager cooling, if possible."
            self.isParkButtonEnabled = !isMountParked || isCoolerOn

        } else if self.isMountConnected && !self.isImagerConnected {
            self.parkButtonTitle = "Park Mount"
            self.parkButtonDescription = "Immediately park the mount, if possible."
            self.isParkButtonEnabled = !isMountParked

        } else if !self.isMountConnected && self.isImagerConnected {
            self.parkButtonTitle = "Warm Cooler"
            self.parkButtonDescription = "Immediately turn off imager cooling, if possible."
            self.parkButtonOK = "Warm"
            self.isParkButtonEnabled = isCoolerOn

        } else {
            self.parkButtonTitle = "Park and Warm"
            self.parkButtonDescription = "Immediately park the mount and turn off imager cooling, if possible."
            self.isParkButtonEnabled = false
        }
        
        
        /// Sunrise
        var sunrise: Date?
        var sunset: Date?
        var astronomicalSunrise: Date?
        var astronomicalSunset: Date?

        if let finishSolar = Solar(for: self.imagerFinish ?? Date(), coordinate: self.location.location!.coordinate) {
            sunrise = finishSolar.sunrise
            astronomicalSunrise = finishSolar.astronomicalSunrise
            
            self.secondsUntilSunrise = Float(sunrise?.timeIntervalSince(Date()) ?? -1000000) + elapsedTimeIfSequencing()
            self.secondsUntilAstronomicalSunrise = Float(astronomicalSunrise?.timeIntervalSince(Date()) ?? -1000000) + elapsedTimeIfSequencing()
        } else {
            self.secondsUntilSunrise = -1000000
            self.secondsUntilAstronomicalSunrise = -1000000
        }

        if let startSolar = Solar(for: self.imagerStart ?? Date(), coordinate: self.location.location!.coordinate) {
            sunset = startSolar.sunset!
            astronomicalSunset = startSolar.astronomicalSunset!
            
            self.secondsUntilSunset = Float(sunset?.timeIntervalSince(Date()) ?? -1000000) + elapsedTimeIfSequencing()
            self.secondsUntilAstronomicalSunset = Float(astronomicalSunset?.timeIntervalSince(Date()) ?? -1000000) + elapsedTimeIfSequencing()
        } else {
            self.secondsUntilSunset = -1000000
            self.secondsUntilAstronomicalSunset = -1000000
        }

        /// Work around a bug in Solar related to timezones. It sometimes picks the wrong day., so we need to go back 24 hrs
        if secondsUntilSunset > secondsUntilSunrise {
            let fixedStart = self.imagerStart?.addingTimeInterval(-24*60*60)
            let fixedStartSolar = Solar(for: fixedStart!, coordinate: self.location.location!.coordinate)!
            
            sunset = fixedStartSolar.sunset
            astronomicalSunset = fixedStartSolar.astronomicalSunset
            
            self.secondsUntilSunset = Float(sunset?.timeIntervalSince(Date()) ?? -1000000) + elapsedTimeIfSequencing()
            self.secondsUntilAstronomicalSunset = Float(astronomicalSunset?.timeIntervalSince(Date()) ?? -1000000)
        }

        self.srSunrise = StatusRow(
            isSet: self.location.hasLocation,
            text: "Sunrise",
            value: sunrise?.timeString() ?? "Unknown",
            status: .custom("sun.max")
        )

        
        if self.isPreview {
            self.secondsUntilSunrise = 60*60*2.25
            self.secondsUntilAstronomicalSunrise = 60*60*2
            self.secondsUntilSunset = 60*60*0.1
            self.secondsUntilAstronomicalSunset = secondsUntilSunset + 18*60
            self.srSunrise!.value = Date().addingTimeInterval(TimeInterval(self.secondsUntilSunrise)).timeString()
            self.location.hasLocation = true
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
        
        self.imagerState = .Stopped

        
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
                                        let url = URL(string: "\(urlprefix)\(itemValue)?nonce=\(UUID())")!
                                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) { self.imagerLatestImageURL = url }
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

    
    

}


struct IndigoClient_Previews: PreviewProvider {
    static var previews: some View {
        let client = IndigoClient(isPreview: true)
        ContentView()
            .environmentObject(client)
    }
}



