# Your First iOS App: Complete Step-by-Step Guide

**Goal**: Build a simple iOS app with 3 tabs, each containing a button that shows an alert.

This guide assumes zero iOS development knowledge but deep understanding of accessibility concepts.

---

## Part 1: Understanding the iOS App Structure

Before we create anything, let's understand what makes up an iOS app:

### Key Concepts

1. **SwiftUI** - Apple's declarative UI framework (like XAML for Windows)
   - You describe WHAT the UI should look like, not HOW to draw it
   - UI updates automatically when data changes

2. **Views** - Building blocks of UI
   - Everything you see is a View (buttons, text, images, containers)
   - Views are structs that conform to the `View` protocol
   - They have a `body` property that returns other Views

3. **App Entry Point** - Where your app starts
   - A struct marked with `@main` 
   - Returns a `WindowGroup` containing your first view

4. **Project Structure**:
   ```
   MyApp.xcodeproj/     <- Project file (like .sln in Visual Studio)
   MyApp/               <- Source code folder
      MyApp.swift       <- App entry point (@main)
      ContentView.swift <- Main UI view
      Assets.xcassets/  <- Images, icons, colors
      Info.plist        <- App configuration (bundle ID, version, etc.)
   ```

---

## Part 2: Creating the Project (The Manual Way)

### Option A: Using Xcode GUI (Recommended for Learning)

1. **Open Xcode** (from /Applications)

2. **Create New Project**:
   - File → New → Project (or press ⇧⌘N)
   - Choose **iOS** tab at top
   - Select **App** template
   - Click **Next**

3. **Configure Project**:
   - **Product Name**: `MyFirstApp`
   - **Team**: Select your developer account (or leave as "None" for simulator only)
   - **Organization Identifier**: `com.yourname` (reverse domain, like package names)
   - **Bundle Identifier**: Auto-fills as `com.yourname.MyFirstApp`
   - **Interface**: **SwiftUI** (NOT Storyboard - that's old way)
   - **Language**: **Swift**
   - **Storage**: **None** (we don't need Core Data)
   - **Testing**: Uncheck both boxes for simplicity
   - Click **Next**

4. **Choose Location**:
   - Save wherever you want (Desktop is fine for learning)
   - **Create Git repository**: Optional (uncheck for simplicity)
   - Click **Create**

### Option B: Understanding What Xcode Created

When Xcode creates a project, you'll see:

**Left sidebar (Navigator)**:
- `MyFirstApp.xcodeproj` - The project file
- `MyFirstApp/` folder containing:
  - `MyFirstAppApp.swift` - Entry point (note: AppApp is not a typo!)
  - `ContentView.swift` - Main UI
  - `Assets.xcassets` - Asset catalog
  - `Preview Content/` - Assets for Xcode previews only

**Middle area (Editor)**:
- Shows selected file's code
- Has **Canvas** on right side for live preview

**Right sidebar (Inspectors)**:
- File inspector, attribute inspector, etc.

---

## Part 3: Understanding the Default Code

### File 1: MyFirstAppApp.swift (Entry Point)

```swift
import SwiftUI

@main
struct MyFirstAppApp: App {  // Name pattern: <ProjectName>App
    var body: some Scene {
        WindowGroup {
            ContentView()  // Your first view loads here
        }
    }
}
```

**What this means**:
- `@main` - "This is where the app starts" (like `Main()` in C#)
- `App` protocol - Required for app entry points
- `WindowGroup` - Container for your app's windows
- `ContentView()` - Creates an instance of your main view

### File 2: ContentView.swift (Default UI)

```swift
import SwiftUI

struct ContentView: View {  // View is a protocol
    var body: some View {   // Must return a View
        VStack {            // Vertical stack container
            Image(systemName: "globe")
                .imageScale(.large)
                .foregroundStyle(.tint)
            Text("Hello, world!")
        }
        .padding()
    }
}

#Preview {  // Shows in Canvas for development
    ContentView()
}
```

**What this means**:
- `struct ContentView: View` - Define a new view type
- `body` - Required property, describes the UI
- `VStack` - Arranges children vertically (like StackPanel in WPF)
- `Image(systemName:)` - Built-in SF Symbol icon
- `.imageScale()`, `.foregroundStyle()` - Modifiers (like properties)
- `.padding()` - Applies to entire VStack
- `#Preview` - Only for Xcode canvas, not compiled into app

---

## Part 4: Building Your Tabbed App

Now let's replace the default code with our tabbed interface.

### Step 1: Modify ContentView.swift

**Replace entire file** with this:

```swift
import SwiftUI

struct ContentView: View {
    @State private var selectedTab = 0  // Track which tab is selected
    @State private var showingAlert = false
    @State private var alertMessage = ""
    
    var body: some View {
        TabView(selection: $selectedTab) {
            // Tab 1
            Tab1View()
                .tabItem {
                    Label("First", systemImage: "1.circle")
                }
                .tag(0)  // Matches selectedTab value
            
            // Tab 2
            Tab2View()
                .tabItem {
                    Label("Second", systemImage: "2.circle")
                }
                .tag(1)
            
            // Tab 3
            Tab3View()
                .tabItem {
                    Label("Third", systemImage: "3.circle")
                }
                .tag(2)
        }
    }
}

// Tab 1 Content
struct Tab1View: View {
    @State private var showingAlert = false
    
    var body: some View {
        VStack(spacing: 20) {
            Text("This is Tab 1")
                .font(.largeTitle)
            
            Button("Activate Button 1") {
                showingAlert = true
            }
            .buttonStyle(.borderedProminent)
        }
        .alert("Alert from Tab 1", isPresented: $showingAlert) {
            Button("OK") { }
        } message: {
            Text("You've activated the button in Tab 1")
        }
    }
}

// Tab 2 Content
struct Tab2View: View {
    @State private var showingAlert = false
    
    var body: some View {
        VStack(spacing: 20) {
            Text("This is Tab 2")
                .font(.largeTitle)
            
            Button("Activate Button 2") {
                showingAlert = true
            }
            .buttonStyle(.borderedProminent)
        }
        .alert("Alert from Tab 2", isPresented: $showingAlert) {
            Button("OK") { }
        } message: {
            Text("You've activated the button in Tab 2")
        }
    }
}

// Tab 3 Content
struct Tab3View: View {
    @State private var showingAlert = false
    
    var body: some View {
        VStack(spacing: 20) {
            Text("This is Tab 3")
                .font(.largeTitle)
            
            Button("Activate Button 3") {
                showingAlert = true
            }
            .buttonStyle(.borderedProminent)
        }
        .alert("Alert from Tab 3", isPresented: $showingAlert) {
            Button("OK") { }
        } message: {
            Text("You've activated the button in Tab 3")
        }
    }
}

#Preview {
    ContentView()
}
```

### Understanding This Code

**New Concepts**:

1. **`@State`** - Marks a variable that triggers UI updates when changed
   - Like `INotifyPropertyChanged` in WPF
   - Must be `private` and only used in this view
   - `$variableName` creates a "binding" (two-way connection)

2. **`TabView`** - Container that shows tabs at bottom (iOS) or top (macOS)
   - `selection: $selectedTab` - Binds to @State variable
   - `.tag(0)` - Associates this tab with value 0

3. **`Label`** - Combines text + icon (accessibility-friendly)
   - `systemImage` - Built-in SF Symbol name

4. **`.tabItem { }`** - Defines what appears in the tab bar

5. **`.alert()`** - Shows system alert dialog
   - `isPresented: $showingAlert` - Shows when this becomes true
   - Alert automatically sets it back to false when dismissed

6. **Struct organization**:
   - Each tab's content is a separate struct
   - Keeps code organized and reusable
   - Could be in separate files for larger apps

---

## Part 5: Building and Running

### Build for Simulator

1. **Select Destination** (top bar near center):
   - Click the device dropdown
   - Choose **iPhone 15 Pro** (or any simulator)
   - You'll see "iPhone 15 Pro" or similar

2. **Build and Run**:
   - Press **⌘R** (or click Play ▶ button)
   - First build takes ~20 seconds
   - Simulator launches automatically
   - Your app appears!

3. **What Happens**:
   - Xcode compiles Swift → machine code
   - Creates .app bundle
   - Installs in simulator
   - Launches the app

### Build for Mac Catalyst

To test VoiceOver on Mac:

1. **Change Destination**:
   - Click device dropdown
   - Choose **My Mac (Designed for iPad)**
   - You might see a signing error - that's next step

2. **Configure Signing**:
   - Click project name in left sidebar (blue icon)
   - Select target "MyFirstApp" under TARGETS
   - Click **Signing & Capabilities** tab
   - **Team**: Select your Apple ID
   - If you don't have one, keep reading...

3. **No Apple ID? (Simulator Only)**:
   - You can only run on simulator without Apple ID
   - Can't test on Mac Catalyst
   - Can't test on real iPhone
   - Free to create Apple ID, doesn't require paid developer account

4. **Build** (⌘R):
   - Builds macOS version
   - Launches as Mac app
   - Has iPhone/iPad-style layout

---

## Part 6: Understanding the Build System

### What Xcode Does When Building

1. **Compile Phase**:
   ```
   Swift files → Swift compiler (swiftc)
   → LLVM intermediate representation
   → Machine code (.o files)
   ```

2. **Link Phase**:
   ```
   .o files + frameworks → Linker
   → Executable binary
   ```

3. **Bundle Phase**:
   ```
   Executable + Assets + Info.plist
   → .app bundle (actually a folder)
   ```

4. **Sign Phase**:
   ```
   .app bundle → Code signing
   → Signed .app (required for macOS/iOS)
   ```

### Build Locations

Compiled apps go to:
```
~/Library/Developer/Xcode/DerivedData/
  MyFirstApp-<random>/
    Build/
      Products/
        Debug-iphonesimulator/MyFirstApp.app  (iOS)
        Debug-maccatalyst/MyFirstApp.app      (Mac)
```

### Common Build Errors

- **"No such module"**: Missing import or framework
- **"Type has no member"**: Wrong API or typo
- **"Ambiguous use"**: Compiler can't determine type
- **"Code signing failed"**: No team selected or expired certificate

---

## Part 7: Testing with VoiceOver

### On Mac Catalyst

1. **Build** for "My Mac (Designed for iPad)"
2. **Enable VoiceOver**: Press **⌘F5**
3. **Navigate**:
   - **Tab** key moves focus
   - **VO keys** (Control+Option) + arrows for detailed navigation
   - **VO+Space** activates
4. **Test Tabs**:
   - Are they announced as "First tab, 1 of 3"?
   - Does content read before tab bar?
   - Does button announce properly?
5. **Disable VoiceOver**: Press **⌘F5** again

### On iOS Simulator

1. **Build** for iPhone simulator
2. **Enable VoiceOver**: 
   - Simulator menu → Accessibility → VoiceOver
   - Or: Settings app → Accessibility → VoiceOver
3. **Navigate**:
   - **Swipe right/left** to move focus
   - **Double-tap** to activate
   - **Three-finger swipe** changes views

---

## Part 8: Common SwiftUI Patterns

### State Management

```swift
@State private var count = 0        // Simple value in this view
@Binding var count: Int              // Value owned by parent
@ObservedObject var model: MyModel   // Reference type that publishes changes
@EnvironmentObject var settings      // Shared object across whole app
```

### Layout Containers

```swift
VStack { }        // Vertical (like StackPanel orientation=Vertical)
HStack { }        // Horizontal
ZStack { }        // Overlapping (like Grid with overlapping items)
List { }          // Scrollable list (like ListView)
ScrollView { }    // Custom scrollable area
Form { }          // Grouped input sections
```

### Modifiers

```swift
.font(.title)                    // Text size
.foregroundColor(.blue)          // Text/icon color
.background(.gray)               // Background color
.padding()                       // Add space around
.frame(width: 100, height: 50)   // Fixed size
.cornerRadius(10)                // Rounded corners
```

### Navigation

```swift
NavigationView {
    List {
        NavigationLink("Detail", destination: DetailView())
    }
    .navigationTitle("Home")
}
```

### Alerts and Sheets

```swift
.alert("Title", isPresented: $showing) { }      // Alert dialog
.sheet(isPresented: $showing) { DetailView() }  // Modal sheet
.confirmationDialog("Choose") { }               // Action sheet
```

---

## Part 9: Debugging

### Print Statements

```swift
print("Button tapped!")  // Appears in Xcode console (bottom panel)
```

### Breakpoints

1. Click line number gutter → blue arrow appears
2. Run app (⌘R)
3. When line executes, app pauses
4. Bottom panel shows variables
5. Continue with play button or F6 to step

### Common Issues

**Preview not working**:
- Make sure file has `#Preview { }` block
- Click "Resume" button if preview is paused
- Sometimes need to clean build (⇧⌘K) and rebuild

**App not updating**:
- Stop app (⌘.)
- Clean build folder (⇧⌘K)
- Rebuild (⌘B)
- Run (⌘R)

---

## Part 10: Next Steps

### Making It Better

1. **Add Accessibility**:
```swift
Button("Click Me") {
    showAlert = true
}
.accessibilityLabel("Alert button")
.accessibilityHint("Shows a confirmation message")
```

2. **Add Icons to Buttons**:
```swift
Button {
    showAlert = true
} label: {
    Label("Tap Me", systemImage: "hand.tap")
}
```

3. **Customize Tab Icons**:
- Browse SF Symbols app (comes with Xcode)
- Use any icon name in `systemImage:`

4. **Add More Content**:
```swift
VStack {
    Text("This is Tab 1")
    Image(systemName: "star.fill")
    Text("Some description")
    Button("Activate") { }
}
```

### Learning Resources

- **Apple's SwiftUI Tutorials**: developer.apple.com/tutorials/swiftui
- **Hacking with Swift**: hackingwithswift.com (free, excellent)
- **SF Symbols App**: Search for icon names
- **Human Interface Guidelines**: Accessibility best practices

---

## Part 11: Understanding the Differences from Windows

### Declarative vs. Imperative

**Windows (WPF/WinForms)**:
```csharp
// You tell HOW to change UI
button.Text = "New Text";
button.Enabled = false;
```

**iOS (SwiftUI)**:
```swift
// You declare WHAT UI should look like based on state
@State private var isEnabled = false

Button(isEnabled ? "Click Me" : "Disabled") {
    // action
}
.disabled(!isEnabled)
```

### No Event Handlers

**Windows**:
```csharp
button.Click += Button_Click;  // Wire up event
void Button_Click(object sender, EventArgs e) { }
```

**iOS (SwiftUI)**:
```swift
Button("Click") {
    // Action code directly here (closure)
}
```

### Value Types vs. Reference Types

- SwiftUI Views are **structs** (value types)
- Copied when passed around, not referenced
- Very lightweight, recreated frequently
- Use `@State` to persist across recreations

### Layout System

**Windows**: Absolute positioning, measured in pixels/DIPs

**iOS**: Flexible, constraint-based, measured in points
- Views expand to fit content
- Modifiers add constraints
- No x/y positioning (usually)

---

## Appendix: Quick Reference

### Essential Keyboard Shortcuts

- **⌘R** - Run
- **⌘.** - Stop
- **⌘B** - Build
- **⇧⌘K** - Clean Build Folder
- **⌘0** - Show/hide Navigator
- **⌘⌥0** - Show/hide Inspector
- **⌘/** - Comment/Uncomment
- **⌘F** - Find in file
- **⇧⌘F** - Find in project

### File Operations

- **⌘N** - New file
- **⌘S** - Save
- **⌘W** - Close tab
- **⌘⇧Y** - Show/hide console

### Building Blocks Cheat Sheet

```swift
// View with state
struct MyView: View {
    @State private var text = "Hello"
    
    var body: some View {
        Text(text)
    }
}

// Button
Button("Title") { /* action */ }

// Text input
TextField("Placeholder", text: $binding)

// Toggle
Toggle("Label", isOn: $binding)

// List
List {
    ForEach(items) { item in
        Text(item.name)
    }
}

// Navigation
NavigationLink("Go", destination: OtherView())

// Alert
.alert("Title", isPresented: $showing) {
    Button("OK") { }
}
```

---

## Your Mission

Now that you understand the structure:

1. **Create** a new project following Part 2
2. **Replace** ContentView.swift with the code from Part 4
3. **Build** for simulator (⌘R)
4. **Test** the three tabs and buttons
5. **Build** for Mac Catalyst
6. **Enable** VoiceOver (⌘F5)
7. **Document** what VoiceOver does with the tabs - does it announce them properly? Does content read before tabs? This will help you understand what's actually happening vs. what you expect.

Understanding the actual behavior will make it much easier to research specific solutions or ask targeted questions about SwiftUI accessibility APIs.
