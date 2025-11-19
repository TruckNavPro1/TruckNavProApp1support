//
//  TrucknavProApp.swift
//  TrucknavPro
//
//  Created by Derrick Gray on 11/7/25.
//

import SwiftUI
import RevenueCat

@main
struct TrucknavProApp: App {

    init() {
        // CRITICAL: Set log level to .error BEFORE RevenueCat configures
        // This completely disables the test subscription button in TestFlight
        Purchases.logLevel = .error
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
        }
    }
}
