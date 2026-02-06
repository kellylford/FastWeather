//
//  MyCitiesView.swift
//  Fast Weather
//
//  View for displaying saved cities with three view options: Flat, Table, List
//

import SwiftUI

struct MyCitiesView: View {
    @EnvironmentObject var weatherService: WeatherService
    @EnvironmentObject var settingsManager: SettingsManager
    @State private var showingSettings = false
    @State private var showingAddCity = false
    @State private var selectedCityForHistory: City?
    @State private var selectedCityForDetail: City?
    @State private var hasLoadedInitialWeather = false
    
    // Date navigation state
    @State private var dateOffset: Int = 0  // 0 = today, +1 = tomorrow, -1 = yesterday
    private let maxDaysForward = 7
    private let maxDaysBack = 7
    
    // Computed properties for date display
    private var selectedDate: Date {
        let calendar = Calendar.current
        return calendar.date(byAdding: .day, value: dateOffset, to: Date()) ?? Date()
    }
    
    private var dateDisplayString: String {
        if dateOffset == 0 {
            return "Today"
        } else if dateOffset == 1 {
            return "Tomorrow"
        } else if dateOffset == -1 {
            return "Yesterday"
        } else {
            let formatter = DateFormatter()
            formatter.dateFormat = "EEE, MMM d"
            return formatter.string(from: selectedDate)
        }
    }
    
    // MARK: - Computed Properties
    
    @ViewBuilder
    private var mainContent: some View {
        if weatherService.savedCities.isEmpty {
            EmptyStateView()
        } else {
            switch settingsManager.settings.viewMode {
            case .list:
                ListView(
                    selectedCityForHistory: $selectedCityForHistory,
                    dateOffset: dateOffset,
                    selectedDate: selectedDate
                )
            case .flat:
                FlatView(
                    selectedCityForHistory: $selectedCityForHistory,
                    selectedCityForDetail: $selectedCityForDetail,
                    dateOffset: dateOffset,
                    selectedDate: selectedDate
                )
            }
        }
    }
    
    var body: some View {
        NavigationStack {
            mainContent
                .navigationTitle("Fast Weather")
                .navigationDestination(item: $selectedCityForHistory) { city in
                    HistoricalWeatherView(city: city, autoLoadToday: settingsManager.settings.viewMode == .list)
                        .navigationTitle("Historical Weather")
                        .navigationBarTitleDisplayMode(.inline)
                }
                .navigationDestination(item: $selectedCityForDetail) { city in
                    CityDetailView(city: city)
                    }
                .toolbar {
                    toolbarContent
                }
                .sheet(isPresented: $showingAddCity) {
                    AddCitySearchView(initialSearchText: "")
                }
                .refreshable {
                    await refreshAllCities()
                }
                .onChange(of: dateOffset) { oldValue, newValue in
                    Task {
                        await refreshAllCities()
                    }
                }
                .accessibilityScrollAction { edge in
                    switch edge {
                    case .leading:
                        navigateToPreviousDay()
                    case .trailing:
                        navigateToNextDay()
                    default:
                        break
                    }
                }
                .accessibilityAction(named: "Previous Day") {
                    navigateToPreviousDay()
                }
                .accessibilityAction(named: "Next Day") {
                    navigateToNextDay()
                }
                .gesture(swipeGesture)
        }
    }
    
    // MARK: - Helper Methods
    
    private func refreshAllCities() async {
        for city in weatherService.savedCities {
            await weatherService.fetchWeatherForDate(for: city, dateOffset: dateOffset)
        }
    }
    
    private func navigateToPreviousDay() {
        guard dateOffset > -maxDaysBack else { return }
        print("🔙 navigateToPreviousDay: dateOffset changing from \(dateOffset) to \(dateOffset - 1)")
        dateOffset -= 1
        print("🔙 navigateToPreviousDay: dateOffset is now \(dateOffset), display: \(dateDisplayString)")
        UINotificationFeedbackGenerator().notificationOccurred(.success)
        UIAccessibility.post(notification: .announcement, argument: "Viewing weather for \(dateDisplayString)")
    }
    
    private func navigateToNextDay() {
        guard dateOffset < maxDaysForward else { return }
        print("▶️ navigateToNextDay: dateOffset changing from \(dateOffset) to \(dateOffset + 1)")
        dateOffset += 1
        print("▶️ navigateToNextDay: dateOffset is now \(dateOffset), display: \(dateDisplayString)")
        UINotificationFeedbackGenerator().notificationOccurred(.success)
        UIAccessibility.post(notification: .announcement, argument: "Viewing weather for \(dateDisplayString)")
    }
    
    private func navigateToToday() {
        print("📅 navigateToToday: resetting dateOffset from \(dateOffset) to 0")
        dateOffset = 0
        UINotificationFeedbackGenerator().notificationOccurred(.success)
        UIAccessibility.post(notification: .announcement, argument: "Returned to today")
    }
    
    // MARK: - Accessors
    
    private var swipeGesture: some Gesture {
        DragGesture(minimumDistance: 50)
            .onEnded { gesture in
                let horizontalSwipe = gesture.translation.width
                let verticalSwipe = abs(gesture.translation.height)
                
                // Only process horizontal swipes
                guard abs(horizontalSwipe) > verticalSwipe else { return }
                
                // iOS timeline convention: swipe LEFT (negative) = see future, swipe RIGHT (positive) = see past
                if horizontalSwipe > 100 && dateOffset > -maxDaysBack {
                    // Swipe RIGHT = go to previous day (back in time)
                    navigateToPreviousDay()
                } else if horizontalSwipe < -100 && dateOffset < maxDaysForward {
                    // Swipe LEFT = go to next day (forward in time)
                    navigateToNextDay()
                }
            }
    }
    
    @ToolbarContentBuilder
    private var toolbarContent: some ToolbarContent {
        ToolbarItemGroup(placement: .navigationBarLeading) {
            Button(action: navigateToPreviousDay) {
                Image(systemName: "chevron.left")
                    .imageScale(.large)
            }
            .disabled(dateOffset <= -maxDaysBack)
            .accessibilityLabel("Previous day")
            
            Text(dateDisplayString)
                .font(.subheadline)
                .fontWeight(.semibold)
                .accessibilityLabel("Currently viewing \(dateDisplayString)")
            
            Button(action: navigateToNextDay) {
                Image(systemName: "chevron.right")
                    .imageScale(.large)
            }
            .disabled(dateOffset >= maxDaysForward)
            .accessibilityLabel("Next day")
            
            if dateOffset != 0 {
                Button("Today") {
                    navigateToToday()
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
                .accessibilityLabel("Go to today")
            }
        }
        
        ToolbarItem(placement: .navigationBarTrailing) {
            Button {
                showingAddCity = true
            } label: {
                Label("Add City", systemImage: "plus")
            }
            .accessibilityLabel("Add City")
            .accessibilityHint("Opens search to add a new city")
            .keyboardShortcut("n", modifiers: [.command, .shift])
        }
    }
}
struct EmptyStateView: View {
    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: "cloud.sun.fill")
                .font(.system(size: 80))
                .foregroundColor(.blue)
                .accessibilityHidden(true)
            
            Text("No Cities Added")
                .font(.title)
                .fontWeight(.bold)
            
            Text("Browse cities to add your first location")
                .font(.body)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding()
        .accessibilityElement(children: .combine)
        .accessibilityLabel("No cities added. Browse cities to add your first location")
    }
}

#Preview {
    MyCitiesView()
        .environmentObject(WeatherService())
        .environmentObject(SettingsManager())
}
