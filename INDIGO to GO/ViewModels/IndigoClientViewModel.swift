//
//  IndigoClientViewModel.swift
//  INDIGO to GO
//
//  Created by Aaron Freimark on 10/22/20.
//

import Foundation
import Combine
import SwiftUI
import Network
import Firebase

class IndigoClientViewModel: ObservableObject {
    
    var client: IndigoPropertyService?
    var location: Location
    var name: String { return client?.name ?? "None" }
    var systemIcon: String { return client?.systemIcon ?? "Bonjour" }

    var anyCancellable: AnyCancellable? = nil

    /// Saved Prefs
    var agentSelection: SettingsView.AgentSelection {
        let defaultAgentSelection = UserDefaults.standard.object(forKey: "agentSelection") as? String ?? "local"
        return SettingsView.AgentSelection(rawValue: defaultAgentSelection) ?? .local
    }

    /// Firebase
    var isPublishedToRemote: Bool { didSet { UserDefaults.standard.set(isPublishedToRemote, forKey: "isPublishedToRemote") } }
    @Published var isFirebaseSignedIn = false

    /// Generally useful properties
    @Published var isImagerConnected = false
    @Published var isGuiderConnected = false
    @Published var isMountConnected = false
    @Published var isAnythingConnected = false
    @Published var isMountTracking = false
    @Published var isMountHALimitEnabled = false
    var isMountParked = false
    var isCoolerOn = false
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
    @Published var mountSecondsUntilMeridian: Int = 0
    @Published var mountSecondsUntilHALimit: Int = 0
    
    /// properties for the Status Rows
    @Published var srSequenceStatus: StatusRowText?
    @Published var srStart: StatusRowTime?
    @Published var srEstimatedCompletion: StatusRowTime?
    @Published var srHALimit: StatusRowTime?
    @Published var srMeridianTransit: StatusRowTime?
    @Published var srSunrise: StatusRowTime?
    @Published var srSunset: StatusRowTime?

    @Published var srGuidingStatus: StatusRowText?
    @Published var srRAError: StatusRowText?
    @Published var srDecError: StatusRowText?
    @Published var srCoolingStatus: StatusRowText?
    @Published var srMountStatus: StatusRowText?
    var timeStatusRows: [StatusRowTime] {
        return [
            self.srStart,
            self.srEstimatedCompletion,
            self.srHALimit,
            self.srMeridianTransit,
            self.srSunrise,
            self.srSunset
        ]
        .compactMap { $0 }
        .sorted()
    }
    
    /// properties for button
    @Published var parkButtonTitle = "Park and Warm"
    @Published var parkButtonDescription = "Immediately park the mount and turn off imager cooling, if possible."
    @Published var parkButtonOK = "Park"
    @Published var isParkButtonEnabled = false
    
    /// Properties for the image preview
    @Published var imagerLatestImageURL: URL?
    @Published var guiderLatestImageURL: URL?

    
    /// Properties for sunrise & sunset
    let secondsInDay: Int = 24 * 60 * 60
    @Published var daylight: (start: Daylight, end: Daylight)?
    var hasDaylight: Bool { daylight != nil }
    
    
    // Bonjour
    let bonjourBrowser = BonjourBrowser()
    var endpoints: [String: NWEndpoint] = [:]
    

    // MARK: - Init
    
    init(client: IndigoPropertyService?) {
        self.isPublishedToRemote = UserDefaults.standard.bool(forKey: "isPublishedToRemote")
        self.location = Location()

        // Bonjour
        anyCancellable = self.bonjourBrowser.publisher
            .sink { endpoints in
                self.endpoints.removeAll()
                for endpoint in endpoints {
                    self.endpoints[endpoint.name] = endpoint.endpoint
                }
                self.client?.endpoints = self.endpoints
                self.objectWillChange.send()
            }

        // Firebase
        _ = Auth.auth().addStateDidChangeListener { (_, user) in
            self.isFirebaseSignedIn = user != nil
        }

        if client != nil {
            self.client = client
            self.update()
        } else {
            self.reinit()
        }
        
    }
    
    func reinit() {
        
        self.reset()

        switch self.agentSelection {
        case .local:
            self.client = LocalIndigoClient()
            self.client?.endpoints = self.endpoints
            self.client?.restart()

            break

        case .remote:
            self.client = RemoteIndigoClient()

            
        case .simulator:
            self.reset()
            self.client = IndigoSimulatorClient()
            break
            
        }

        
    }
        
    /// Shifts times for Meridian & HA Limit over if sequence is running, so these count from start of sequence instead of now()
    func elapsedTimeIfSequencing() -> Int {
        if self.imagerState != .Stopped {
            return Int(self.imagerElapsedTime)
        } else {
            return 0
        }
    }
    
    // MARK: - Update Properties
    
    func update() {
        updateGeneralProperties()
        updateImagerProperties()
        updateSequenceProperties()
        updateGuiderProperties()
        updateMountProperties()
        updateMeridianProperties()
        updateButtonProperties()
        updateLocation()
        updateImages()
    }
    
    private func updateGeneralProperties() {
        guard let client = self.client else { return }
        let keys = client.getKeys()
        self.isImagerConnected = keys.contains { $0.hasPrefix("Imager Agent") }
        self.isGuiderConnected = keys.contains { $0.hasPrefix("Guider Agent") }
        self.isMountConnected = keys.contains { $0.hasPrefix("Mount Agent") }
        self.isAnythingConnected = self.isImagerConnected || self.isGuiderConnected || self.isMountConnected
    }
    
    private func updateImagerProperties() {
        guard let client = self.client else { return }

        let sequence = "Imager Agent | AGENT_START_PROCESS | SEQUENCE"
        let pause = "Imager Agent | AGENT_PAUSE_PROCESS | PAUSE"
        
        /// imageState & sequence status
        if client.getValue(pause) == "false" && client.getState(pause) == .Busy {
            self.imagerState = .Paused
            self.srSequenceStatus = StatusRowText(
                text: "Sequence Paused",
                status: .custom("pause.circle.fill")
            )
        } else if client.getValue(sequence) == "true" && client.getState(sequence) == .Busy {
            self.imagerState = .Sequencing
            self.srSequenceStatus = StatusRowText(
                text: "Sequence in Progress",
                status: .ok
            )
        } else {
            self.imagerState = .Stopped
            self.srSequenceStatus = StatusRowText(
                text: "Sequence Stopped",
                status: .alert
            )
        }
        
        /// filename of last image
        //        self.imagerImageLatest = client.getValue("Imager Agent | CCD_IMAGE_FILE | FILE") ?? ""
        
        /// cooler status
        let coolerTemperature = client.getValue("Imager Agent | CCD_TEMPERATURE | TEMPERATURE") ?? ""
        self.isCoolerOn = client.getValue("Imager Agent | CCD_COOLER | ON") == "true"
        let isAtTemperature = client.getState("Imager Agent | CCD_TEMPERATURE | TEMPERATURE") == .Ok
        
        if !isCoolerOn {
            self.srCoolingStatus = StatusRowText(
                text: "Cooling Off",
                status: .alert
            )
        } else if isAtTemperature {
            self.srCoolingStatus = StatusRowText(
                text: "Cooling",
                status: .ok
            )
        } else {
            self.srCoolingStatus = StatusRowText(
                text: "Cooling In Progress",
                status: .warn
            )
        }
        self.srCoolingStatus!.value = "\(coolerTemperature) °C"
        self.srCoolingStatus!.isSet = self.isImagerConnected
    }
    
    private func updateSequenceProperties() {
        guard let client = self.client else { return }

        /// sequence times
        var imagerBatchInProgress = 0
        if let imagerBatchInProgressString = client.getValue("Imager Agent | AGENT_IMAGER_STATS | BATCH") {
            imagerBatchInProgress = Int(imagerBatchInProgressString) ?? 0
        }
        
        var imagerFrameInProgress: Float = 0
        if let imagerFrameInProgressString = client.getValue("Imager Agent | AGENT_IMAGER_STATS | FRAME") {
            imagerFrameInProgress = Float(imagerFrameInProgressString) ?? 0
        }
        
        var totalTime: Float = 0
        var elapsedTime: Float = 0
        var thisBatch = 1
        var imagesTotal = 0
        var imagesTaken = 0
        var percentCompletedThisImage: Float = 0.0
        
        // Sequences can "Keep" the same exposure and count settings as the prior sequence, so we do not reset then between sequences.
        var exposure: Float = 0;
        var count: Float = 0;
        var filter: String = "";
        var imagePlans: [Int:IndigoSequence] = [:]   /// Used to hold the sequences 01...16 in the Agent
        var imageTimes: [IndigoSequence] = []   /// Used to hold the specific sequences we are using in this image run, including repititions
        
        /// Read all "Imager Agent | AGENT_IMAGER_SEQUENCE | XX" routines, then parse the intended sequence.
        for seqNum in 1...16 {
            if let sequence = client.getValue("Imager Agent | AGENT_IMAGER_SEQUENCE | " + String(format: "%02d",seqNum)) {
                for prop in sequence.components(separatedBy: ";") {
                    if prop.prefix(9) == "exposure=" { exposure = Float(prop.replacingOccurrences(of: "exposure=", with: ""))! }
                    if prop.prefix(6) == "count=" { count = Float(prop.replacingOccurrences(of: "count=", with: ""))! }
                    if prop.prefix(7) == "filter=" { filter = prop.replacingOccurrences(of: "filter=", with: "") }
                }
                imagePlans[seqNum] = IndigoSequence(count: count, seconds: exposure, filter: filter)
            }
        }
        
        if let sequences = client.getValue("Imager Agent | AGENT_IMAGER_SEQUENCE | SEQUENCE") {
            for seq in sequences.components(separatedBy: ";") {
                if let seqNum = Int(seq) {
                    imageTimes.append(imagePlans[seqNum]!)
                    let sequenceTime = imagePlans[seqNum]!.totalTime
                    totalTime += sequenceTime
                    imagesTotal += Int(imagePlans[seqNum]!.count)
                    
                    if thisBatch < imagerBatchInProgress {
                        elapsedTime += sequenceTime
                        imagesTaken += Int(imagePlans[seqNum]!.count)
                    }
                    if thisBatch == imagerBatchInProgress {
                        
                        let imagesCompletedThisBatch = imagerFrameInProgress - 1.0
                        let secondsCompletedThisBatch = imagePlans[seqNum]!.seconds * imagesCompletedThisBatch
                        let secondsRemainingThisFrame = client.getValue("Imager Agent | AGENT_IMAGER_STATS | EXPOSURE") ?? "0"
                        let secondsCompletedThisFrame = imagePlans[seqNum]!.seconds - (Float(secondsRemainingThisFrame) ?? 0)
                        
                        elapsedTime += secondsCompletedThisBatch
                        elapsedTime += secondsCompletedThisFrame
                        
                        imagesTaken += Int(imagerFrameInProgress)

                        // used for pie chart
                        percentCompletedThisImage = secondsCompletedThisFrame / imagePlans[seqNum]!.seconds
                        if self.imagerState == .Sequencing {
                            self.srSequenceStatus?.status = .pie(percentCompletedThisImage)
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
        
        self.srStart = StatusRowTime(
            isSet: self.isImagerConnected,
            text: "Sequence Start",
            status: .custom("rectangle.leftthird.inset.fill"),
            date: self.imagerStart
        )

        self.srEstimatedCompletion = StatusRowTime(
            isSet: self.isImagerConnected,
            text: "Estimated Completion",
            status: .custom("rectangle.rightthird.inset.fill"),
            date: self.imagerFinish
        )
    }
    
    private func updateGuiderProperties() {
        guard let client = self.client else { return }

        let isGuiding = client.getValue("Guider Agent | AGENT_START_PROCESS | GUIDING") == "true"
        let isDithering = Float(client.getValue("Guider Agent | AGENT_GUIDER_STATS | DITHERING") ?? "0") ?? 0 > 0
        let isCalibrating = client.getValue("Guider Agent | AGENT_START_PROCESS | CALIBRATION") == "true"
        
        var guiderTrackingText = ""
        var guiderTrackingStatus = StatusRowStatus.unknown
        
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
        
        let guiderDriftX = Float(client.getValue("Guider Agent | AGENT_GUIDER_STATS | DRIFT_X") ?? "0") ?? 0
        let guiderDriftY = Float(client.getValue("Guider Agent | AGENT_GUIDER_STATS | DRIFT_Y") ?? "0") ?? 0
        let guiderDriftMaximum = max(abs(guiderDriftX),abs(guiderDriftY))
        let guiderDriftMax = String(format: "%.2f px", guiderDriftMaximum)
        
        if isGuiding && guiderDriftMaximum > 1.5 {
            guiderTrackingStatus = .warn
        }
        
        self.srGuidingStatus = StatusRowText(
            text: guiderTrackingText,
            value: guiderDriftMax,
            status: guiderTrackingStatus
        )
        
        /// RA & Dec Error
        let guiderRSMERA = Float(client.getValue("Guider Agent | AGENT_GUIDER_STATS | RMSE_RA") ?? "0") ?? 0
        let guiderRSMEDec = Float(client.getValue("Guider Agent | AGENT_GUIDER_STATS | RMSE_DEC") ?? "0") ?? 0
        let guiderRSMERAStatus = guiderRSMERA < 0.2 ? StatusRowStatus.ok : StatusRowStatus.warn
        let guiderRSMEDecStatus = guiderRSMEDec < 0.2 ? StatusRowStatus.ok : StatusRowStatus.warn
        
        self.srRAError = StatusRowText(
            text: "RA Error (RSME)",
            value: String(guiderRSMERA),
            status: guiderRSMERAStatus
        )
        self.srDecError = StatusRowText(
            text: "DEC Error (RSME)",
            value: String(guiderRSMEDec),
            status: guiderRSMEDecStatus
        )
    }
    
    private func updateMountProperties() {
        guard let client = self.client else { return }

        if client.getValue("Mount Agent | MOUNT_PARK | PARKED") == "true" {
            self.srMountStatus = StatusRowText(
                text: "Mount Parked",
                status: .alert
            )
            self.isMountParked = true
            self.isMountTracking = false
        } else if client.getValue("Mount Agent | MOUNT_TRACKING | ON") == "true" {
            self.srMountStatus = StatusRowText(
                text: "Mount Tracking",
                status: .ok
            )
            self.isMountTracking = true
            self.isMountParked = false
        } else if client.getValue("Mount Agent | MOUNT_TRACKING | OFF") == "true" {
            self.srMountStatus = StatusRowText(
                text: "Mount Not Tracking",
                status: .warn
            )
            self.isMountTracking = false
            self.isMountParked = false
        } else {
            self.srMountStatus = StatusRowText(
                text: "Mount State Unknown",
                status: .unknown
            )
            self.isMountParked = false
            self.isMountParked = false
        }
        self.srMountStatus!.isSet = self.isMountConnected
    }
    
    private func updateMeridianProperties() {
        guard let client = self.client else { return }

        /// Meridian Time
        
        let hourAngle = Float(client.getValue("Mount Agent | AGENT_LIMITS | HA_TRACKING") ?? "0")!
        var secondsUntilMeridian = Int(3600 * (24.0 - hourAngle))
        
        /// Too far in advance? Rewind the clock.
        while secondsUntilMeridian >= secondsInDay { secondsUntilMeridian -= secondsInDay }
        
        let mountMeridianTime = Date().addingTimeInterval(TimeInterval(secondsUntilMeridian))
        
        /// If sequencing, add the elapsed time so it displays as expected.
        secondsUntilMeridian += elapsedTimeIfSequencing()
        
        self.mountSecondsUntilMeridian = secondsUntilMeridian
        
        self.srMeridianTransit = StatusRowTime(
            isSet: isMountTracking && mountMeridianTime <= self.imagerFinish ?? Date.distantFuture,
            text: "Meridian Transit",
            status: .custom("togglepower"),
            date: mountMeridianTime
        )
        
        
        /// HA Limit
        
        let HALimit = Float(client.getTarget("Mount Agent | AGENT_LIMITS | HA_TRACKING") ?? "0")!
        self.isMountHALimitEnabled = self.isMountConnected && (HALimit != 24.0 && HALimit != 0)
        
        var secondsUntilHALimit = Int(3600 * (HALimit - hourAngle))
        
        /// Too far in advance? Rewind the clock.
        while secondsUntilHALimit >= secondsInDay { secondsUntilHALimit -= secondsInDay }
        
        let mountHALimitTime = Date().addingTimeInterval(TimeInterval(secondsUntilHALimit))
        
        /// If sequencing, add the elapsed time so it displays as expected.
        secondsUntilHALimit += elapsedTimeIfSequencing()
        
        self.mountSecondsUntilHALimit = secondsUntilHALimit
        
        self.srHALimit = StatusRowTime(
            isSet: isMountTracking  && mountHALimitTime <= self.imagerFinish ?? Date.distantFuture,
            text: "HA Limit",
            status: .custom("exclamationmark.arrow.circlepath"),
            date: mountHALimitTime
        )
        
    }
    
    private func updateButtonProperties() {
        
        if self.isMountConnected && self.isImagerConnected {
            self.parkButtonDescription = "Immediately park the mount and turn off imager cooling, if possible."
            self.isParkButtonEnabled = !self.isMountParked || self.isCoolerOn
            
        } else if self.isMountConnected && !self.isImagerConnected {
            self.parkButtonDescription = "Immediately park the mount, if possible."
            self.isParkButtonEnabled = !isMountParked
            
        } else if !self.isMountConnected && self.isImagerConnected {
            self.parkButtonDescription = "Immediately turn off imager cooling, if possible."
            self.parkButtonOK = "Warm"
            self.isParkButtonEnabled = self.isCoolerOn
            
        } else {
            self.parkButtonDescription = "Immediately park the mount and turn off imager cooling, if possible."
            self.isParkButtonEnabled = false
        }
    }
    
    
    
    
    private func updateLocation() {
        // Sunrise, Sunset
        
        if self.isSimulatedServer() {
            /// Special stuff for the preview...
            
            self.daylight = (
                start: Daylight(
                    asr: nil,
                    sr: Date().addingTimeInterval(-60*60*5),
                    ss: Date().addingTimeInterval(60*5),
                    ass: Date().addingTimeInterval(60*25)
                ),
                end: Daylight(
                    asr: Date().addingTimeInterval(60*60*2),
                    sr: Date().addingTimeInterval(60*60*2.25),
                    ss: Date().addingTimeInterval(60*60*6),
                    ass: nil
                )
            )
            location.hasLocation = true
            
            self.srSunrise = StatusRowTime(
                isSet: true,
                text: "Sunrise",
                status: .custom("sunrise"),
                date: self.daylight?.end.day?.start
            )
            self.srSunset = StatusRowTime(
                isSet: true,
                text: "Sunset",
                status: .custom("sunset"),
                date: self.daylight?.start.day?.end
            )

        } else if let start = self.imagerStart, let end = self.imagerFinish {
            /// Normal Flow. The "daylight" structure is used to store sunrise, sunset, etc. times for the start and end of the sequence. Items that fall outside the image sequence are set to nil
            
            let sequenceInterval = DateInterval(start: start, end: end)
            self.daylight = self.location.calculateDaylight(interval: sequenceInterval)
            
            if let nextSunrise = self.location.nextSunrise(from: self.imagerStart), sequenceInterval.contains(nextSunrise) {
                self.srSunrise = StatusRowTime(
                    isSet: location.hasLocation,
                    text: "Sunrise",
                    status: .custom("sunrise"),
                    date: nextSunrise
                )
            }
        
            if let nextSunset = self.location.nextSunset(from: self.imagerStart), sequenceInterval.contains(nextSunset) {
                self.srSunset = StatusRowTime(
                    isSet: location.hasLocation,
                    text: "Sunset",
                    status: .custom("sunset"),
                    date: self.location.nextSunset(from: self.imagerStart)
                )
            }

        } else {
            /// Sometimes we don't have an image sequence
            self.daylight = nil
        }
        
    }

    private func updateImages() {
        guard let client = self.client else { return }

        self.imagerLatestImageURL = client.imagerLatestImageURL
        self.guiderLatestImageURL = client.guiderLatestImageURL
    }
    

    func emergencyStopAll() {
        guard let client = self.client else { return }
        client.emergencyStopAll()
    }
    
    
    // MARK: - Connection Management
    
    func connectedServers() -> [String] {
        guard let client = self.client else { return [] }
        return client.connectedServers()
    }

    func isSimulatedServer() -> Bool {
        guard let client = self.client else { return false }
        return client.name == "Simulator"
    }
    
    private func reset() {
//        self.endpoints = [:]
        
        self.isImagerConnected = false
        self.isGuiderConnected = false
        self.isMountConnected = false
        self.isAnythingConnected = false
        self.isMountTracking = false
        self.isMountHALimitEnabled = false
        self.isMountParked = false
        self.isCoolerOn = false
        self.lastUpdate = nil
        
        /// properties for the progress display
        self.imagerState = ImagerState.Stopped
        self.imagerStart = nil
        self.imagerFinish = nil
        self.sequences = []
        self.imagerTotalTime = 0
        self.imagerElapsedTime = 0
        self.mountSecondsUntilMeridian  = 0
        self.mountSecondsUntilHALimit = 0
        
        /// properties for the Status Rows
        self.srSequenceStatus = nil
        self.srStart = nil
        self.srEstimatedCompletion = nil
        self.srHALimit = nil
        self.srMeridianTransit = nil
        self.srSunrise = nil
        self.srSunset = nil

        self.srGuidingStatus = nil
        self.srRAError = nil
        self.srDecError = nil
        self.srCoolingStatus = nil
        self.srMountStatus = nil
        
        /// properties for button
        self.parkButtonTitle = "Park and Warm"
        self.parkButtonDescription = "Immediately park the mount and turn off imager cooling, if possible."
        self.parkButtonOK = "Park"
        self.isParkButtonEnabled = false
        
        /// Properties for the image preview
        self.imagerLatestImageURL = nil
        self.guiderLatestImageURL = nil
        
        /// Properties for sunrise & sunset
        self.daylight = nil

    }
         
}

struct IndigoClientViewModel_Previews: PreviewProvider {
    static var previews: some View {
        let client = IndigoClientViewModel(client: IndigoSimulatorClient())
        MainTabView()
            .environmentObject(client)
    }
}
