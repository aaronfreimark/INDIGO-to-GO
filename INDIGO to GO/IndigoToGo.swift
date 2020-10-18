//
//  INDIGO_StatusApp.swift
//  INDIGO Status
//
//  Created by Aaron Freimark on 9/9/20.
//

import SwiftUI

@main
struct INDIGO_to_GO: App {
    @StateObject private var client = IndigoClient()
    
    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(client)
        }
    }
}

