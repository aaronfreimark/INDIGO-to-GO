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
    var hasLocation: Bool { return self.timeUntilSunriseSeconds() > 0 }
    var solar: Solar?
    var isPreview: Bool
    // solar.sunrise
    // solar.astronomicalSunrise
    
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

            /// Give me tomorrow' sunrise, not today's
            
            self.solar = Solar(for: Date.tomorrow, coordinate: location.coordinate)

            print("Found user's location: \(location)")
            print("Sunrise: \(self.solar)")
        }
    }

    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        print("Failed to find user's location: \(error.localizedDescription)")
    }
    
    
    func timeUntilSunriseSeconds() -> Float {
        if self.isPreview { return 60*60*2.25 }

        guard let sunrise = self.solar?.sunrise else { return 0 }
        let seconds = Float(sunrise.timeIntervalSince(Date()))
        return seconds
    }
    
    func timeUntilAstronomicalSunriseSeconds() -> Float {
        if self.isPreview { return 60*60*2 }

        guard let sunrise = self.solar?.astronomicalSunrise else { return 0 }
        let seconds = Float(sunrise.timeIntervalSince(Date()))
        return seconds
    }
    
    func sunrise() -> String {
        if self.isPreview { return timeString(date: Date().addingTimeInterval(TimeInterval(self.timeUntilSunriseSeconds()))) }

        guard let sunrise = self.solar?.sunrise else { return "Unknown" }
        return timeString(date: sunrise)
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
        ContentView(client: client)
    }
}

