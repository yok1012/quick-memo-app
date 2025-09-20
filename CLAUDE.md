# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

QuickMemo is a Swift-based iOS and watchOS application for rapid note-taking and memo management. The app features:
- Native iOS app with SwiftUI interface
- watchOS companion app with WatchConnectivity
- Calendar integration via EventKit
- Category-based organization with tags
- Shake gesture for quick input
- Persistent storage using UserDefaults (Core Data implemented but not active)

## Build and Development Commands

### Build
```bash
# Build iOS app (use iPhone 16 for newer simulators)
xcodebuild -project quickMemoApp.xcodeproj -scheme quickMemoApp -destination 'platform=iOS Simulator,name=iPhone 16' build

# Build watchOS app
xcodebuild -project quickMemoApp.xcodeproj -scheme quickMemoWatchApp -destination 'platform=watchOS Simulator,name=Apple Watch Series 9 (45mm)' build

# Clean build
xcodebuild clean -project quickMemoApp.xcodeproj -scheme quickMemoApp
```

### Run Tests
```bash
# Run unit tests
xcodebuild test -project quickMemoApp.xcodeproj -scheme quickMemoApp -destination 'platform=iOS Simulator,name=iPhone 16'

# Run UI tests
xcodebuild test -project quickMemoApp.xcodeproj -scheme quickMemoAppUITests -destination 'platform=iOS Simulator,name=iPhone 16'
```

## Architecture

### Core Components

**Data Layer**
- `DataManager` (quickMemoApp/Services/DataManager.swift): Singleton managing all memo operations and persistence via UserDefaults
- `QuickMemo` & `Category` models (quickMemoApp/Models/DataModels.swift): Core data structures with Codable support
- `PersistenceController` (quickMemoApp/Models/PersistenceController.swift): Core Data stack (implemented but not integrated with DataManager)

**Service Layer**
- `CalendarService` (quickMemoApp/Services/CalendarService.swift): EventKit integration with iOS 17+ compatibility
- `TagManager` (quickMemoApp/Services/TagManager.swift): Smart tag suggestions with Japanese text analysis
- `WatchConnectivityManager`: Asymmetric implementation
  - iOS version (quickMemoApp/Watch/): Simplified placeholder saving directly to DataManager
  - watchOS version (quickMemoWatchApp/Services/): Full WCSession with offline memo queue

**UI Components**
- `MainView` (quickMemoApp/Views/MainView.swift): Primary navigation with category tabs
- `FastInputView` (quickMemoApp/Views/FastInputView.swift): Quick memo input with TextEditor (fixed for Japanese input)
- `CalendarPermissionView` (quickMemoApp/Views/CalendarPermissionView.swift): Calendar access permission flow
- `QuickInputManager` (quickMemoApp/Utils/QuickInputManager.swift): Shake gesture coordinator

### Key Design Patterns

1. **Singleton Pattern**: DataManager, CalendarService, QuickInputManager, WatchConnectivityManager
2. **Publisher-Subscriber**: @Published properties with ObservableObject for reactive UI
3. **ViewModifier Pattern**: QuickInputViewModifier for shake gesture functionality
4. **Extension Pattern**: Calendar event operations as QuickMemo extensions

### Platform-Specific Implementation

**iOS App**
- Full feature set with calendar integration and shake gestures
- Uses TextEditor for Japanese input compatibility
- Calendar permissions configured via INFOPLIST_KEY_NSCalendarsUsageDescription

**watchOS App**
- Simplified UI focused on quick input
- Full WCSession implementation with pending memo storage
- Auto-sync when iPhone connection is available

## Important Technical Details

### Data Storage
- **Active**: UserDefaults with JSON encoding via DataManager (App Group enabled)
- **App Group**: group.yokAppDev.quickMemoApp (for widget data sharing)
- **Inactive**: Core Data stack exists but not integrated
- CloudKit container ID needs updating: "iCloud.com.yourcompany.quickMemoApp"

### Calendar Integration
- Requires iOS 17+ API: `requestFullAccessToEvents()` with fallback to `requestAccess()`
- Creates dedicated "Quick Memo" calendar automatically
- Calendar events linked via `calendarEventId` property

### Japanese Input Handling
- FastInputView uses TextEditor instead of TextField to prevent text loss
- Custom placeholder implementation with ZStack overlay
- IME composition state tracking via `isComposing` flag

### Build Configuration
- Project uses GENERATE_INFOPLIST_FILE = YES (auto-generated Info.plist)
- Calendar permissions set via project build settings (INFOPLIST_KEY_*)
- Watch app uses AppIntents extension architecture

### Known Issues & Considerations

1. **Data Layer Inconsistency**: Two storage systems exist (UserDefaults active, Core Data inactive)
2. **Watch Connectivity Asymmetry**: iOS side has minimal implementation vs full Watch implementation
3. **Japanese Localization**: Categories and UI hardcoded in Japanese without i18n support
4. **Testing Coverage**: Minimal test implementations (placeholders only)
5. **Color Management**: Category colors hardcoded in multiple locations

### Deployment Configuration
- iOS Deployment Target: 16.0+
- watchOS Deployment Target: 11.5+
- Bundle IDs:
  - yokAppDev.quickMemoApp (iOS)
  - yokAppDev.quickMemoWatchApp (Watch)
  - yokAppDev.quickMemoApp.Widget (Widget Extension - needs to be added in Xcode)
- No external dependencies - pure Swift/SwiftUI implementation

### Required Xcode Configuration

#### Widget Extension Setup
1. **Add Widget Extension Target**:
   - File → New → Target → Widget Extension
   - Product Name: QuickMemoWidget
   - Include Configuration Intent: No
   - Team: Your Development Team

2. **App Groups Configuration**:
   - Select main app target → Signing & Capabilities → + Capability → App Groups
   - Add: group.yokAppDev.quickMemoApp
   - Repeat for Widget Extension target

3. **URL Scheme Configuration**:
   - Select main app target → Info → URL Types → +
   - URL Schemes: quickmemo
   - Role: Editor

4. **Widget Files**:
   - Move `/quickMemoApp/Widget/QuickMemoWidget.swift` to Widget Extension target
   - Add DataModels.swift to Widget Extension target (Target Membership)

5. **Build Settings**:
   - Ensure both targets have same iOS Deployment Target (16.0+)