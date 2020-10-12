//
//  INDIGO_StatusApp.swift
//  INDIGO Status
//
//  Created by Aaron Freimark on 9/9/20.
//

import SwiftUI

@main
struct INDIGO_to_GOApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView(client: IndigoClient())
        }
    }
}

