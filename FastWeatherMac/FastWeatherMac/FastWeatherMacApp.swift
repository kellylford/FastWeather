//
//  FastWeatherMacApp.swift
//  FastWeatherMac
//
//  Created on 12/12/2025.
//  Main app entry point
//

import SwiftUI

@main
struct FastWeatherMacApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    
    var body: some Scene {
        WindowGroup {
            ContentView()
                .frame(minWidth: 800, minHeight: 600)
        }
        .commands {
            // Add custom menu commands for accessibility
            CommandGroup(after: .appInfo) {
                Button("About FastWeather") {
                    NSApplication.shared.orderFrontStandardAboutPanel(
                        options: [
                            .applicationName: "FastWeather",
                            .applicationVersion: "1.0.0",
                            .version: "1.0.0",
                            .credits: NSAttributedString(string: "A fast, accessible weather app for macOS\n\nData provided by Open-Meteo.com (CC BY 4.0)")
                        ]
                    )
                }
                .accessibilityLabel("About FastWeather")
            }
            
            CommandGroup(replacing: .help) {
                Button("FastWeather Help") {
                    if let url = URL(string: "https://github.com/yourusername/fastweather") {
                        NSWorkspace.shared.open(url)
                    }
                }
                .accessibilityLabel("Open FastWeather help")
                .keyboardShortcut("?", modifiers: .command)
            }
        }
        
        Settings {
            SettingsView()
        }
    }
}

class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        // Ensure accessibility is enabled
        NSApplication.shared.setActivationPolicy(.regular)
    }
    
    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        return true
    }
}
