import SwiftUI

struct ContentView: View {
    @State private var selectedTab = 0
    
    var body: some View {
        TabView(selection: $selectedTab) {
            HomeView()
                .tabItem {
                    Image(systemName: "house.fill")
                    Text("Home")
                }
                .tag(0)
                .accessibilityLabel("Home")
                .accessibilityHint("Tab 1 of 3")
                .accessibilityAddTraits(.isButton)
            
            ListsView()
                .tabItem {
                    Image(systemName: "list.bullet")
                    Text("Lists")
                }
                .tag(1)
                .accessibilityLabel("Lists")
                .accessibilityHint("Tab 2 of 3")
                .accessibilityAddTraits(.isButton)
            
            SettingsView()
                .tabItem {
                    Image(systemName: "gear")
                    Text("Settings")
                }
                .tag(2)
                .accessibilityLabel("Settings")
                .accessibilityHint("Tab 3 of 3")
                .accessibilityAddTraits(.isButton)
        }
        .accessibilityElement(children: .contain)
    }
}

struct HomeView: View {
    @State private var counter = 0
    
    var body: some View {
        VStack(spacing: 20) {
            Text("Welcome to Test App")
                .font(.title)
                .accessibilityAddTraits(.isHeader)
            
            HStack(spacing: 8) {
                Text("Counter:")
                Text("\(counter)")
            }
            .font(.headline)
            .accessibilityElement(children: .combine)
            .accessibilityLabel("Counter value: \(counter)")
            
            Button("Increment") {
                counter += 1
            }
            .buttonStyle(.borderedProminent)
            .accessibilityLabel("Increment counter")
            .accessibilityHint("Increases counter by 1. Current value is \(counter)")
            
            Button("Decrement") {
                counter -= 1
            }
            .buttonStyle(.bordered)
            .accessibilityLabel("Decrement counter")
            .accessibilityHint("Decreases counter by 1. Current value is \(counter)")
            
            Toggle("Enable Feature", isOn: .constant(true))
                .padding(.horizontal, 40)
                .accessibilityLabel("Enable feature toggle")
                .accessibilityValue("Enabled")
        }
        .padding()
    }
}

struct ListsView: View {
    let items = ["Apple", "Banana", "Cherry", "Date", "Elderberry"]
    
    var body: some View {
        NavigationView {
            List(items, id: \.self) { item in
                HStack {
                    Image(systemName: "circle.fill")
                        .foregroundColor(.blue)
                        .accessibilityHidden(true)
                    Text(item)
                }
                .accessibilityElement(children: .combine)
                .accessibilityLabel("\(item)")
            }
            .navigationTitle("Fruits")
            .accessibilityLabel("Fruits list")
        }
    }
}

struct SettingsView: View {
    @State private var username = ""
    @State private var notifications = true
    
    var body: some View {
        Form {
            Section {
                TextField("Username", text: $username)
                    .accessibilityLabel("Username text field")
                    .accessibilityHint("Enter your username")
            } header: {
                Text("Profile")
                    .accessibilityAddTraits(.isHeader)
            }
            
            Section {
                Toggle("Notifications", isOn: $notifications)
                    .accessibilityLabel("Notifications toggle")
                    .accessibilityValue(notifications ? "Enabled" : "Disabled")
                
                Picker("Theme", selection: .constant("Light")) {
                    Text("Light").tag("Light")
                    Text("Dark").tag("Dark")
                    Text("Auto").tag("Auto")
                }
                .accessibilityLabel("Theme picker")
                .accessibilityValue("Light theme selected")
            } header: {
                Text("Preferences")
                    .accessibilityAddTraits(.isHeader)
            }
        }
        .navigationTitle("Settings")
    }
}

#Preview {
    ContentView()
}
