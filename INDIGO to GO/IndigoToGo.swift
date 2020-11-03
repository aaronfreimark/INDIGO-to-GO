//
//  INDIGO_StatusApp.swift
//  INDIGO Status
//
//  Created by Aaron Freimark on 9/9/20.
//

import SwiftUI

@main
struct INDIGO_to_GO: App {
    @StateObject private var client = IndigoClientViewModel(client: LocalIndigoClient())
    @UIApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    var body: some Scene {
        WindowGroup {
            MainTabView()
                .environmentObject(client)
        }
    }
}

