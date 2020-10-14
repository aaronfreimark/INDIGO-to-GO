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
    private var location: CLLocation?

    var isPreview: Bool
    
    @Published var hasLocation: Bool = false
    @Published var secondsUntilSunrise: Float = 0
    @Published var secondsUntilAstronomicalSunrise: Float = 0
    @Published var secondsUntilSunset: Float = 0
    @Published var secondsUntilAstronomicalSunset: Float = 0
    @Published var sunrise: String = "Unknown"
    
    
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
    
    func updateUI(start: Date?, finish: Date?) {
        if self.isPreview {
            self.secondsUntilSunrise = 60*60*2.25
            self.secondsUntilAstronomicalSunrise = 60*60*2
            self.secondsUntilSunset = 60*60*0.1
            self.secondsUntilAstronomicalSunset = secondsUntilSunset + 18*60
            self.sunrise = timeString(date: Date().addingTimeInterval(TimeInterval(self.secondsUntilSunrise)))
            self.hasLocation = true
        } else {
            if start == nil { return }
            if finish == nil { return }

            guard let finishSolar = Solar(for: finish!, coordinate: self.location!.coordinate) else { return }
            
            guard let sunrise = finishSolar.sunrise else { return }
            self.secondsUntilSunrise = Float(sunrise.timeIntervalSince(Date()))

            guard let astronomicalSunrise = finishSolar.astronomicalSunrise else { return }
            self.secondsUntilAstronomicalSunrise = Float(astronomicalSunrise.timeIntervalSince(Date()))

            // --
            
            guard let startSolar = Solar(for: start!, coordinate: self.location!.coordinate) else { return }

            guard let sunset = startSolar.sunset else { return }
            self.secondsUntilSunset = Float(sunset.timeIntervalSince(Date()))

            guard let astronomicalSunset = startSolar.astronomicalSunset else { return }
            self.secondsUntilAstronomicalSunset = Float(astronomicalSunset.timeIntervalSince(Date()))

            if sunset > sunrise {
                /// Work around a bug in Solar related to timezones. It sometimes picks the wrong day., so we need to go back 24 hrs
                let fixedStart = start?.addingTimeInterval(-24*60*60)
                guard let fixedStartSolar = Solar(for: fixedStart!, coordinate: self.location!.coordinate) else { return }

                guard let sunset = fixedStartSolar.sunset else { return }
                self.secondsUntilSunset = Float(sunset.timeIntervalSince(Date()))

                guard let astronomicalSunset = fixedStartSolar.astronomicalSunset else { return }
                self.secondsUntilAstronomicalSunset = Float(astronomicalSunset.timeIntervalSince(Date()))
            }

            
            self.sunrise = timeString(date: sunrise)
            
//            print("Start: \(start), Finish: \(finish)")
//            print("Sunrise: \(self.secondsUntilSunrise/60/60), Sunset: \(self.secondsUntilSunset/60/60)")

        }
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


// https://stackoverflow.com/questions/44009804/
extension Date {
    static var yesterday: Date { return Date().dayBefore }
    static var tomorrow:  Date { return Date().dayAfter }
    var dayBefore: Date {
        return Calendar.current.date(byAdding: .day, value: -1, to: noon)!
    }
    var dayAfter: Date {
        return Calendar.current.date(byAdding: .day, value: 1, to: noon)!
    }
    var noon: Date {
        return Calendar.current.date(bySettingHour: 12, minute: 0, second: 0, of: self)!
    }
    var month: Int {
        return Calendar.current.component(.month,  from: self)
    }
    var isLastDayOfMonth: Bool {
        return dayAfter.month != month
    }
}



struct LocationProgressView_Previews: PreviewProvider {
    static var previews: some View {
        let client = IndigoClient(isPreview: true)
        ContentView()
            .environmentObject(client)
    }
}

