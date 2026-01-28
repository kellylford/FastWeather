//
//  HistoricalWeatherView.swift
//  Fast Weather
//
//  Historical weather display component for detail view
//

import SwiftUI

struct HistoricalWeatherView: View {
    let city: City
    let autoLoadToday: Bool // Auto-load today's date in multi-year mode
    @EnvironmentObject var settingsManager: SettingsManager
    
    @State private var historicalData: [HistoricalDay] = []
    @State private var isLoading: Bool = false
    @State private var errorMessage: String?
    @State private var selectedDate: HistoricalDate = .today
    @State private var showDatePicker: Bool = false
    @State private var viewMode: ViewMode = .singleDay
    
    // Default initializer for backward compatibility
    init(city: City, autoLoadToday: Bool = false) {
        self.city = city
        self.autoLoadToday = autoLoadToday
    }
    
    enum ViewMode {
        case singleDay      // Show weather for specific date only
        case multiYear      // Show same day across multiple years
        case dailyBrowse    // Show consecutive days starting from selected date
    }
    
    var body: some View {
        GroupBox(label: Label("Historical Weather", systemImage: "calendar.badge.clock")) {
            VStack(spacing: 16) {
                // Date navigation controls
                dateNavigationControls
                
                // Historical data list
                if isLoading {
                    ProgressView("Loading historical data...")
                        .padding()
                } else if let error = errorMessage {
                    VStack(spacing: 12) {
                        Image(systemName: "exclamationmark.triangle")
                            .font(.system(size: 32))
                            .foregroundColor(.orange)
                        Text(error)
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                    }
                    .padding()
                } else if historicalData.isEmpty {
                    VStack(spacing: 12) {
                        Image(systemName: "calendar.badge.clock")
                            .font(.system(size: 32))
                            .foregroundColor(.secondary)
                        Text("Tap 'Load History' to view")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    .padding()
                } else {
                    historicalDataList
                }
            }
            .padding(.vertical, 8)
        }
        .padding(.horizontal)
        .sheet(isPresented: $showDatePicker) {
            DatePickerSheet(selectedDate: $selectedDate, onLoad: loadHistoricalData)
        }
        .onAppear {
            // Auto-load today's date in multi-year mode when opened via VoiceOver action
            if autoLoadToday && historicalData.isEmpty {
                selectedDate = .today
                viewMode = .multiYear
                loadHistoricalData()
            }
        }
    }
    
    // MARK: - Date Navigation Controls
    
    private var dateNavigationControls: some View {
        VStack(spacing: 12) {
            // Current date display
            VStack(spacing: 4) {
                Text(selectedDate.displayString)
                    .font(.headline)
                    .accessibilityLabel("Viewing history for \(selectedDate.displayString)")
                
                if viewMode == .multiYear {
                    Text("Showing \(historicalData.count) years")
                        .font(.caption)
                        .foregroundColor(.secondary)
                } else if viewMode == .dailyBrowse {
                    Text("Showing \(historicalData.count) days")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            
            // Navigation buttons
            HStack(spacing: 8) {
                Button(action: previousDay) {
                    Label("Previous Day", systemImage: "chevron.left")
                        .labelStyle(.iconOnly)
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
                .accessibilityLabel(previousButtonLabel)
                
                Button(action: { showDatePicker = true }) {
                    Label("Select Date", systemImage: "calendar")
                        .font(.caption)
                }
                .buttonStyle(.bordered)
                .accessibilityLabel("Open calendar to select a specific date")
                
                Button(action: { selectedDate = .today; loadHistoricalData() }) {
                    Label("Today", systemImage: "arrow.uturn.backward")
                        .font(.caption)
                }
                .buttonStyle(.bordered)
                .accessibilityLabel("Return to today's date")
                
                Button(action: nextDay) {
                    Label("Next Day", systemImage: "chevron.right")
                        .labelStyle(.iconOnly)
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
                .disabled(isToday)
                .accessibilityLabel(nextButtonLabel)
            }
            
            // Load button
            if historicalData.isEmpty {
                Button(action: loadHistoricalData) {
                    Label("Load History", systemImage: "arrow.down.circle")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .accessibilityLabel("Load historical weather data for \(selectedDate.displayString)")
            } else {
                // View mode switcher
                VStack(spacing: 8) {
                    HStack(spacing: 8) {
                        if viewMode == .singleDay {
                            Button(action: { switchToSingleDay() }) {
                                Label("Single Day", systemImage: "calendar.badge.clock")
                                    .font(.caption)
                            }
                            .buttonStyle(BorderedProminentButtonStyle())
                            .accessibilityLabel("View weather for \(selectedDate.displayString) only")
                        } else {
                            Button(action: { switchToSingleDay() }) {
                                Label("Single Day", systemImage: "calendar.badge.clock")
                                    .font(.caption)
                            }
                            .buttonStyle(BorderedButtonStyle())
                            .accessibilityLabel("View weather for \(selectedDate.displayString) only")
                        }
                        
                        if viewMode == .dailyBrowse {
                            Button(action: { switchToDailyBrowse() }) {
                                Label("Browse Days", systemImage: "list.bullet.rectangle")
                                    .font(.caption)
                            }
                            .buttonStyle(BorderedProminentButtonStyle())
                            .accessibilityLabel("Browse consecutive days starting from \(selectedDate.displayString)")
                        } else {
                            Button(action: { switchToDailyBrowse() }) {
                                Label("Browse Days", systemImage: "list.bullet.rectangle")
                                    .font(.caption)
                            }
                            .buttonStyle(BorderedButtonStyle())
                            .accessibilityLabel("Browse consecutive days starting from \(selectedDate.displayString)")
                        }
                        
                        if viewMode == .multiYear {
                            Button(action: { switchToMultiYear() }) {
                                Label("History", systemImage: "clock.arrow.circlepath")
                                    .font(.caption)
                            }
                            .buttonStyle(BorderedProminentButtonStyle())
                            .accessibilityLabel("View \(selectedDate.monthName) \(selectedDate.day) across multiple years")
                        } else {
                            Button(action: { switchToMultiYear() }) {
                                Label("History", systemImage: "clock.arrow.circlepath")
                                    .font(.caption)
                            }
                            .buttonStyle(BorderedButtonStyle())
                            .accessibilityLabel("View \(selectedDate.monthName) \(selectedDate.day) across multiple years")
                        }
                    }
                }
            }
        }
    }
    
    // MARK: - Historical Data List
    
    private var historicalDataList: some View {
        ScrollView {
            LazyVStack(spacing: 0) {
                ForEach(Array(historicalData.enumerated()), id: \.element.id) { index, day in
                    HistoricalDayRow(
                        day: day,
                        settingsManager: settingsManager
                    )
                    
                    if index < historicalData.count - 1 {
                        Divider()
                    }
                }
            }
            .padding(.horizontal, 4)
        }
        .frame(maxHeight: 300)
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Historical weather data")
    }
    
    // MARK: - Actions
    
    private func loadHistoricalData() {
        isLoading = true
        errorMessage = nil
        
        Task {
            do {
                let data: [HistoricalDay]
                
                if viewMode == .singleDay {
                    // Fetch just the specific date
                    let dateString = selectedDate.dateString
                    let response = try await WeatherService.shared.fetchHistoricalWeather(for: city, startDate: dateString, endDate: dateString)
                    
                    // Parse single day
                    if !response.daily.time.isEmpty {
                        let dateFormatter = DateFormatter()
                        dateFormatter.dateFormat = "yyyy-MM-dd"
                        
                        if let timeString = response.daily.time[0],
                           let date = dateFormatter.date(from: timeString),
                           let weatherCode = response.daily.weatherCode[0],
                           let tempMax = response.daily.temperature2mMax[0],
                           let tempMin = response.daily.temperature2mMin[0],
                           let apparentTempMax = response.daily.apparentTemperatureMax[0],
                           let apparentTempMin = response.daily.apparentTemperatureMin[0],
                           let sunrise = response.daily.sunrise[0],
                           let sunset = response.daily.sunset[0],
                           let precipitationSum = response.daily.precipitationSum[0],
                           let rainSum = response.daily.rainSum[0],
                           let snowfallSum = response.daily.snowfallSum[0],
                           let precipitationHours = response.daily.precipitationHours[0],
                           let windSpeedMax = response.daily.windSpeed10mMax[0] {
                            let historicalDay = HistoricalDay(
                                date: date,
                                year: selectedDate.year,
                                weatherCode: weatherCode,
                                tempMax: tempMax,
                                tempMin: tempMin,
                                apparentTempMax: apparentTempMax,
                                apparentTempMin: apparentTempMin,
                                sunrise: sunrise,
                                sunset: sunset,
                                precipitationSum: precipitationSum,
                                rainSum: rainSum,
                                snowfallSum: snowfallSum,
                                precipitationHours: precipitationHours,
                                windSpeedMax: windSpeedMax
                            )
                            data = [historicalDay]
                        } else {
                            data = []
                        }
                    } else {
                        data = []
                    }
                } else if viewMode == .multiYear {
                    // Fetch multi-year history
                    let monthDay = selectedDate.monthDayKey
                    let yearsBack = settingsManager.settings.historicalYearsBack
                    data = try await WeatherService.shared.fetchSameDayHistory(for: city, monthDay: monthDay, yearsBack: yearsBack, endYear: selectedDate.year)
                } else {
                    // Fetch consecutive days (dailyBrowse mode)
                    let calendar = Calendar.current
                    let dateFormatter = DateFormatter()
                    dateFormatter.dateFormat = "yyyy-MM-dd"
                    
                    // Get start date
                    guard let startDate = dateFormatter.date(from: selectedDate.dateString) else {
                        data = []
                        throw NSError(domain: "HistoricalWeather", code: -1, userInfo: [NSLocalizedDescriptionKey: "Invalid start date"])
                    }
                    
                    // Calculate end date (30 days from start)
                    guard let endDate = calendar.date(byAdding: .day, value: 30, to: startDate) else {
                        data = []
                        throw NSError(domain: "HistoricalWeather", code: -1, userInfo: [NSLocalizedDescriptionKey: "Invalid end date"])
                    }
                    
                    let startString = dateFormatter.string(from: startDate)
                    let endString = dateFormatter.string(from: endDate)
                    
                    // Fetch the date range
                    let response = try await WeatherService.shared.fetchHistoricalWeather(for: city, startDate: startString, endDate: endString)
                    
                    // Parse all days in the range
                    var parsedDays: [HistoricalDay] = []
                    for (index, timeString) in response.daily.time.enumerated() {
                        guard let timeString = timeString,
                              let date = dateFormatter.date(from: timeString),
                              let weatherCode = response.daily.weatherCode[index],
                              let tempMax = response.daily.temperature2mMax[index],
                              let tempMin = response.daily.temperature2mMin[index],
                              let apparentTempMax = response.daily.apparentTemperatureMax[index],
                              let apparentTempMin = response.daily.apparentTemperatureMin[index],
                              let sunrise = response.daily.sunrise[index],
                              let sunset = response.daily.sunset[index],
                              let precipitationSum = response.daily.precipitationSum[index],
                              let rainSum = response.daily.rainSum[index],
                              let snowfallSum = response.daily.snowfallSum[index],
                              let precipitationHours = response.daily.precipitationHours[index],
                              let windSpeedMax = response.daily.windSpeed10mMax[index] else {
                            continue
                        }
                        
                        let components = calendar.dateComponents([.year], from: date)
                        let historicalDay = HistoricalDay(
                            date: date,
                            year: components.year ?? 0,
                            weatherCode: weatherCode,
                            tempMax: tempMax,
                            tempMin: tempMin,
                            apparentTempMax: apparentTempMax,
                            apparentTempMin: apparentTempMin,
                            sunrise: sunrise,
                            sunset: sunset,
                            precipitationSum: precipitationSum,
                            rainSum: rainSum,
                            snowfallSum: snowfallSum,
                            precipitationHours: precipitationHours,
                            windSpeedMax: windSpeedMax
                        )
                        parsedDays.append(historicalDay)
                    }
                    data = parsedDays
                }
                
                await MainActor.run {
                    historicalData = data
                    isLoading = false
                    let unit = viewMode == .singleDay ? "day" : (viewMode == .multiYear ? "years" : "days")
                    print("📊 Loaded \(data.count) \(unit) of historical data")
                }
            } catch {
                await MainActor.run {
                    errorMessage = "Failed to load: \(error.localizedDescription)"
                    isLoading = false
                }
            }
        }
    }
    
    private func switchToSingleDay() {
        viewMode = .singleDay
        loadHistoricalData()
    }
    
    private func switchToMultiYear() {
        viewMode = .multiYear
        loadHistoricalData()
    }
    
    private func switchToDailyBrowse() {
        viewMode = .dailyBrowse
        loadHistoricalData()
    }
    
    private func previousDay() {
        if viewMode == .dailyBrowse {
            // In browse mode, go back 30 days (previous group)
            selectedDate.addDays(-30)
        } else if viewMode == .multiYear {
            // In multi-year mode, shift the year window back
            let yearsBack = settingsManager.settings.historicalYearsBack
            selectedDate.year -= yearsBack
        } else {
            // In single day mode, go back 1 day
            selectedDate.addDays(-1)
        }
        loadHistoricalData() // Automatically reload with new date
    }
    
    private func nextDay() {
        guard !isToday else { return }
        if viewMode == .dailyBrowse {
            // In browse mode, go forward 30 days (next group)
            selectedDate.addDays(30)
        } else if viewMode == .multiYear {
            // In multi-year mode, shift the year window forward
            let yearsBack = settingsManager.settings.historicalYearsBack
            selectedDate.year += yearsBack
        } else {
            // In single day mode, go forward 1 day
            selectedDate.addDays(1)
        }
        loadHistoricalData() // Automatically reload with new date
    }
    
    private var isToday: Bool {
        selectedDate == .today
    }
    
    private var previousButtonLabel: String {
        switch viewMode {
        case .dailyBrowse:
            return "Previous 30 days"
        case .multiYear:
            return "Previous \(settingsManager.settings.historicalYearsBack) years"
        default:
            return "Previous day"
        }
    }
    
    private var nextButtonLabel: String {
        switch viewMode {
        case .dailyBrowse:
            return "Next 30 days"
        case .multiYear:
            return "Next \(settingsManager.settings.historicalYearsBack) years"
        default:
            return "Next day"
        }
    }
}

// MARK: - Historical Day Row

struct HistoricalDayRow: View {
    let day: HistoricalDay
    let settingsManager: SettingsManager
    
    private var dateLabel: String {
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "MMM d"
        return dateFormatter.string(from: day.date)
    }
    
    var body: some View {
        HStack(spacing: 12) {
            // Date or Year (show month/day for consecutive days, year for multi-year)
            VStack(alignment: .leading, spacing: 2) {
                Text(dateLabel)
                    .font(.caption.weight(.semibold))
                Text(String(day.year))
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .frame(width: 60, alignment: .leading)
            
            // Weather icon
            if let weatherCode = day.weatherCodeEnum {
                Image(systemName: weatherCode.sfSymbol)
                    .font(.title3)
                    .foregroundColor(.blue)
                    .frame(width: 32)
                    .accessibilityLabel(weatherCode.description)
            }
            
            // Temperature range
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 4) {
                    Image(systemName: "arrow.up")
                        .font(.caption2)
                        .foregroundColor(.red)
                        .accessibilityHidden(true)
                    Text(formatTemperature(day.tempMax))
                        .font(.body.weight(.semibold))
                        .accessibilityLabel("High \(formatTemperature(day.tempMax))")
                }
                
                HStack(spacing: 4) {
                    Image(systemName: "arrow.down")
                        .font(.caption2)
                        .foregroundColor(.blue)
                        .accessibilityHidden(true)
                    Text(formatTemperature(day.tempMin))
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .accessibilityLabel("Low \(formatTemperature(day.tempMin))")
                }
            }
            
            Spacer()
            
            // Precipitation (if any)
            if day.precipitationSum > 0 {
                VStack(alignment: .trailing, spacing: 2) {
                    HStack(spacing: 4) {
                        Image(systemName: "drop.fill")
                            .font(.caption)
                            .foregroundColor(.blue)
                            .accessibilityHidden(true)
                        Text(formatPrecipitation(day.precipitationSum))
                            .font(.caption)
                            .accessibilityLabel("Precipitation \(formatPrecipitation(day.precipitationSum))")
                    }
                }
            }
        }
        .padding(.vertical, 8)
        .padding(.horizontal, 4)
        .accessibilityElement(children: .combine)
    }
    
    private func formatTemperature(_ celsius: Double) -> String {
        let temp = settingsManager.settings.temperatureUnit.convert(celsius)
        return String(format: "%.0f%@", temp, settingsManager.settings.temperatureUnit.rawValue)
    }
    
    private func formatPrecipitation(_ mm: Double) -> String {
        let precip = settingsManager.settings.precipitationUnit.convert(mm)
        return String(format: "%.1f %@", precip, settingsManager.settings.precipitationUnit.rawValue)
    }
}

// MARK: - Date Picker Sheet

struct DatePickerSheet: View {
    @Environment(\.dismiss) var dismiss
    @Binding var selectedDate: HistoricalDate
    let onLoad: () -> Void
    
    @State private var tempYear: Int
    @State private var tempMonth: Int
    @State private var tempDay: Int
    
    init(selectedDate: Binding<HistoricalDate>, onLoad: @escaping () -> Void) {
        self._selectedDate = selectedDate
        self.onLoad = onLoad
        self._tempYear = State(initialValue: selectedDate.wrappedValue.year)
        self._tempMonth = State(initialValue: selectedDate.wrappedValue.month)
        self._tempDay = State(initialValue: selectedDate.wrappedValue.day)
    }
    
    var body: some View {
        NavigationView {
            Form {
                Section {
                    Picker("Year", selection: $tempYear) {
                        ForEach((1940...Calendar.current.component(.year, from: Date())).reversed(), id: \.self) { year in
                            Text(String(year)).tag(year)
                        }
                    }
                    .pickerStyle(.menu)
                    .accessibilityLabel("Year, \(tempYear)")
                    
                    Picker("Month", selection: $tempMonth) {
                        ForEach(1...12, id: \.self) { month in
                            Text(monthName(month)).tag(month)
                        }
                    }
                    .pickerStyle(.menu)
                    .accessibilityLabel("Month, \(monthName(tempMonth))")
                    
                    Picker("Day", selection: $tempDay) {
                        ForEach(1...daysInMonth(month: tempMonth, year: tempYear), id: \.self) { day in
                            Text(String(day)).tag(day)
                        }
                    }
                    .pickerStyle(.menu)
                    .accessibilityLabel("Day, \(tempDay)")
                }
                
                Section {
                    Text("Selected: \(formattedDate)")
                        .font(.headline)
                        .accessibilityLabel("Selected date: \(formattedDate)")
                }
            }
            .navigationTitle("Select Date")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Load") {
                        selectedDate = HistoricalDate(year: tempYear, month: tempMonth, day: tempDay)
                        dismiss()
                        onLoad()
                    }
                }
            }
        }
    }
    
    private func monthName(_ month: Int) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMMM"
        var components = DateComponents()
        components.month = month
        return formatter.string(from: Calendar.current.date(from: components) ?? Date())
    }
    
    private func daysInMonth(month: Int, year: Int) -> Int {
        var components = DateComponents()
        components.year = year
        components.month = month
        
        guard let date = Calendar.current.date(from: components),
              let range = Calendar.current.range(of: .day, in: .month, for: date) else {
            return 31
        }
        
        return range.count
    }
    
    private var formattedDate: String {
        HistoricalDate(year: tempYear, month: tempMonth, day: tempDay).displayString
    }
}

#Preview {
    let city = City(
        id: UUID(),
        name: "Madison",
        displayName: "Madison, Wisconsin, United States",
        latitude: 43.074761,
        longitude: -89.3837613,
        state: "Wisconsin",
        country: "United States"
    )
    
    HistoricalWeatherView(city: city)
        .environmentObject(SettingsManager())
}
