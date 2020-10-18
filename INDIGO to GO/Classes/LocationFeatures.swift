//
//  LocationFeatures.swift
//  INDIGO to GO
//
//  Created by Aaron Freimark on 10/12/20.
//

import Foundation
import SwiftUI
import CoreLocation
import Solar

class LocationFeatures: NSObject, CLLocationManagerDelegate {
    let manager = CLLocationManager()
    var location: CLLocation?

    var isPreview: Bool
    @Published var hasLocation: Bool = false
    
    
    /*
     
     Sunset day of begining of sequence, sunrise day of end of sequence
     
     */
    
    init(isPreview: Bool = false) {
        self.isPreview = isPreview
        super.init()
        manager.delegate = self
        manager.desiredAccuracy = kCLLocationAccuracyKilometer
        manager.requestWhenInUseAuthorization()
        manager.requestLocation()
    }
    
    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        if let location = locations.first {
            print("Found user's location: \(location)")
            self.location = location
            self.hasLocation = true
        }
    }

    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        print("Failed to find user's location: \(error.localizedDescription)")
        self.hasLocation = false
    }
        
    func daylight(sequenceInterval: DateInterval) -> (start: Daylight, end: Daylight) {
        let tz = TimeZone.current
        var start = Daylight()
        var end = Daylight()
        let maxDuration: TimeInterval = 60*60*24

        // longer than 24 hours not allowed
        if sequenceInterval.duration > maxDuration { return (start: start, end: end) }
        
//        print("Seq Start: \(sequenceInterval.start)")
//        print("Seq End: \(sequenceInterval.end)")

        if let location = self.location {
            if let solar = Solar(for: sequenceInterval.start, coordinate: location.coordinate, timezone: tz) {
                start = Daylight(
                    asr: solar.astronomicalSunrise,
                    sr: solar.sunrise,
                    ss: solar.sunset,
                    ass: solar.astronomicalSunset
                )
                start.nullifyIfOutside(sequenceInterval)
            }

            if let solar = Solar(for: sequenceInterval.end, coordinate: location.coordinate, timezone: tz) {
                end = Daylight(
                    asr: solar.astronomicalSunrise,
                    sr: solar.sunrise,
                    ss: solar.sunset,
                    ass: solar.astronomicalSunset
                )
                end.nullifyIfOutside(sequenceInterval)
            }
        }
        
        if start == end {
            end = Daylight()
        }
        
//        print("start: \(start)")
//        print("end: \(end)")
        return (start: start, end: end)
    }
    
    
}


struct LocationProgressView_Previews: PreviewProvider {
    static var previews: some View {
        let client = IndigoClient(isPreview: true)
        ContentView()
            .environmentObject(client)
    }
}

