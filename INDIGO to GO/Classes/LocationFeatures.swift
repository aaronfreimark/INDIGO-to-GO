//
//  LocationFeatures.swift
//  INDIGO to GO
//
//  Created by Aaron Freimark on 10/12/20.
//

import Foundation
import SwiftUI
import CoreLocation

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
    
}


struct LocationProgressView_Previews: PreviewProvider {
    static var previews: some View {
        let client = IndigoClient(isPreview: true)
        ContentView()
            .environmentObject(client)
    }
}

