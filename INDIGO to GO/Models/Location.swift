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

class Location: NSObject, CLLocationManagerDelegate {
    let manager = CLLocationManager()
    var location: CLLocation?
    let tz = TimeZone.current

    @Published var hasLocation: Bool = false
    
    
    /*
     
     Sunset day of begining of sequence, sunrise day of end of sequence
     
     */
    
    override init() {
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
            
    func calculateDaylight(interval: DateInterval) -> (start: Daylight, end: Daylight) {
        var start = Daylight()
        var end = Daylight()
        let maxDuration: TimeInterval = 60*60*24

        // longer than 24 hours not allowed
        if interval.duration > maxDuration { return (start: start, end: end) }
        
//        print("Seq Start: \(interval.start)")
//        print("Seq End: \(interval.end)")

        if let location = self.location {
            if let solar = Solar(for: interval.start, coordinate: location.coordinate, timezone: self.tz) {
                start = Daylight(
                    asr: solar.astronomicalSunrise,
                    sr: solar.sunrise,
                    ss: solar.sunset,
                    ass: solar.astronomicalSunset
                )
                start.nullifyIfOutside(interval)
            }

            if let solar = Solar(for: interval.end, coordinate: location.coordinate, timezone: self.tz) {
                end = Daylight(
                    asr: solar.astronomicalSunrise,
                    sr: solar.sunrise,
                    ss: solar.sunset,
                    ass: solar.astronomicalSunset
                )
                
                end.nullifyIfOutside(interval)
            }
        }
        
        if start == end {
            end = Daylight()
        }
        
//        print("start: \(start)")
//        print("end: \(end)")
        return (start: start, end: end)
    }
    
    func nextSunrise(from: Date? = Date()) -> Date? {
        let dateToCheck = from ?? Date()
        
        if let location = self.location {
            let solar = Solar(for: dateToCheck, coordinate: location.coordinate, timezone: self.tz)
            
            if let sunrise = solar?.sunrise {
                if sunrise > dateToCheck {
                    return sunrise
                }
            }
            
            let secondDateToCheck = dateToCheck.addingTimeInterval(24*60*60)
            let secondSolar = Solar(for: secondDateToCheck, coordinate: location.coordinate, timezone: self.tz)
            
            if let sunrise = secondSolar?.sunrise {
                return sunrise
            }
        }
        return nil
    }
    
    func nextSunset(from: Date? = Date()) -> Date? {
        let dateToCheck = from ?? Date()
        
        if let location = self.location {
            let solar = Solar(for: dateToCheck, coordinate: location.coordinate, timezone: self.tz)
            
            if let sunset = solar?.sunset {
                if sunset > dateToCheck {
                    return sunset
                }
            }
            
            let secondDateToCheck = dateToCheck.addingTimeInterval(24*60*60)
            let secondSolar = Solar(for: secondDateToCheck, coordinate: location.coordinate, timezone: self.tz)
            
            if let sunset = secondSolar?.sunset {
                return sunset
            }
        }
        return nil
    }

}


struct LocationProgressView_Previews: PreviewProvider {
    static var previews: some View {
        let client = IndigoClientViewModel(client: MockIndigoClientForPreview(), isPreview: true)
        MonitorView()
            .environmentObject(client)
    }
}

