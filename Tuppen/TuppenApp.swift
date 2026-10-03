//
//  TuppenApp.swift
//  Tuppen
//
//  Created by Ferdinand Majcherek on 30.09.26.
//

import SwiftUI

@main
struct TuppenApp: App {
    @State private var model = AppModel()
    @State private var preferences = AppPreferences()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(model)
                .environment(preferences)
                .environment(\.locale, preferences.locale)
                .tint(Color(red: 0.12, green: 0.40, blue: 0.34))
        }
    }
}
