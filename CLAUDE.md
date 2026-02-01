# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

QuickMemo is a SwiftUI-based iOS/watchOS application for rapid note-taking with calendar integration and Pro features via in-app purchases. The app is currently in App Store review process (Version 1.0, Build 2).

### Key Features
- Shake gesture for quick memo input with Japanese IME support
- watchOS companion app with offline-first sync architecture
- Calendar integration (EventKit) with automatic calendar creation
- Pro version with subscription ($1.99/month) and one-time purchase ($4.99)
- CloudKit sync for Pro users (currently disabled pending configuration)
- Widget extension with category customization
- Multi-language support (Japanese base, English, Simplified Chinese)

## Build and Development Commands

### Archive and Distribution
```bash
# Create archive for App Store submission
xcodebuild -project quickMemoApp.xcodeproj -scheme quickMemoApp -configuration Release archive -archivePath ./build/quickMemoApp.xcarchive

# Export for App Store (requires ExportOptions.plist)
xcodebuild -exportArchive -archivePath ./build/quickMemoApp.xcarchive -exportPath ./build -exportOptionsPlist ExportOptions.plist

# Current version: 1.0, Build: 2
```

### Development Build Commands
```bash
# Clean build (use when encountering dylib errors)
rm -rf ~/Library/Developer/Xcode/DerivedData/*
xcodebuild clean -project quickMemoApp.xcodeproj -scheme quickMemoApp

# Build for simulator (Release mode - avoids debug.dylib issues)
xcodebuild -project quickMemoApp.xcodeproj -scheme quickMemoApp -configuration Release -destination 'platform=iOS Simulator,name=iPhone 17 Pro' build

# Build watchOS app
xcodebuild -project quickMemoApp.xcodeproj -scheme "quickMemoWatch Watch App" -destination 'platform=watchOS Simulator,name=Apple Watch Series 9 (45mm)' build

# Build Widget Extension
xcodebuild -project quickMemoApp.xcodeproj -scheme quickMemoWidgetExtension -destination 'platform=iOS Simulator,name=iPhone 17 Pro' build
```

### Simulator Operations
```bash
# List available simulators
xcrun simctl list devices available

# Install and run (adjust simulator name and DerivedData path as needed)
xcrun simctl boot "iPhone 17 Pro"
xcrun simctl install "iPhone 17 Pro" ~/Library/Developer/Xcode/DerivedData/quickMemoApp-*/Build/Products/Release-iphonesimulator/quickMemoApp.app
xcrun simctl launch "iPhone 17 Pro" yokAppDev.quickMemoApp

# Reset all simulators (fixes launch crashes)
xcrun simctl shutdown all
xcrun simctl erase all
```

### Testing
```bash
# Run unit tests
xcodebuild test -project quickMemoApp.xcodeproj -scheme quickMemoApp -destination 'platform=iOS Simulator,name=iPhone 17 Pro' -only-testing:quickMemoAppTests

# Run specific test
xcodebuild test -project quickMemoApp.xcodeproj -scheme quickMemoApp -destination 'platform=iOS Simulator,name=iPhone 17 Pro' -only-testing:quickMemoAppTests/DataManagerTests/testAddMemo

# Test in-app purchases with StoreKit configuration
xcodebuild -project quickMemoApp.xcodeproj -scheme quickMemoApp -destination 'platform=iOS Simulator,name=iPhone 17 Pro' -StoreKitConfigurationFileReference Configuration.storekit
```

### Debugging & Console Access
```bash
# View app logs in Console.app
osascript -e 'tell application "Console" to activate'

# Filter logs for quickMemoApp
xcrun simctl spawn "iPhone 17 Pro" log stream --predicate 'subsystem contains "yokAppDev.quickMemoApp"'

# Check CloudKit debug output (Pro features)
xcrun simctl spawn "iPhone 17 Pro" log stream --predicate 'subsystem contains "com.apple.cloudkit"'

# Monitor Watch connectivity
xcrun simctl spawn "iPhone 17 Pro" log stream --predicate 'category contains "WCSession"'
```

## Architecture Overview

### Core Data Flow
```
User Action → View (SwiftUI) → Service (Singleton) → DataManager → Storage
                 ↓                    ↓                  ↓            ↓
            @StateObject         Business Logic      Persistence  UserDefaults
                                                                    CloudKit
```

### Storage Strategy
- **Primary**: UserDefaults with JSON encoding (App Group: `group.yokAppDev.quickMemoApp`)
- **Secondary**: CloudKit for Pro users (requires AuthenticationManager sign-in)
- **Unused**: Core Data stack implemented but not integrated

### In-App Purchase Architecture
```
PurchaseManager (StoreKit 2)
    ├── Product IDs:
    │   ├── com.yokAppDev.quickMemoApp.pro.month ($1.99)
    │   └── yokAppDev.quickMemoApp.pro ($4.99)
    ├── StoreKit 1 Observer (App Store promotions)
    └── CloudKitManager (sync purchase status)
```

### Service Layer Singletons
Each service is a singleton with specific responsibilities:

- **DataManager**: Central data operations, memo CRUD, category management
- **PurchaseManager**: StoreKit integration, purchase validation, Pro status (note: file at project root)
- **CalendarService**: EventKit integration, calendar creation, event sync
- **AuthenticationManager**: Sign in with Apple, CloudKit authentication
- **CloudKitManager**: iCloud sync (Pro only), subscription status
- **NotificationManager**: Local notifications, quiet hours, reminder scheduling
- **ExportManager**: CSV/JSON export of memos

### Utils Layer
- **LocalizationManager**: Runtime language switching, locale management
- **TagManager**: Japanese text analysis, smart tag extraction
- **QuickInputManager**: Shake gesture detection and quick input handling
- **ColorExtension**: Color utilities and hex conversion

### Platform-Specific Implementation

#### iOS ↔ watchOS Communication (Asymmetric Architecture)

**Design Philosophy**: Watch works offline-first, iPhone as source of truth

**iOS Implementation** (`iOSWatchConnectivityManager`):
```swift
// Minimal, direct operations only
- sendCategoriesToWatch() - Push latest categories
- sendMemosToWatch() - Push latest 20 memos
- Direct save on memo receipt (no queuing)
- No offline handling (iPhone assumed always available)
```

**watchOS Implementation** (`WatchConnectivityManager`):
```swift
// Full-featured with offline resilience
- Offline queue: pendingMemos array in UserDefaults
- Batch sync when iPhone becomes reachable
- Automatic retry with exponential backoff
- Purchase status cached locally, refreshed periodically
```

**Data Flow Patterns**:
1. **New Memo from Watch**: Queue → Try send → Store if failed → Retry on reachability
2. **Category Update**: iPhone pushes to all watches immediately
3. **Purchase Status**: Watch caches, requests refresh every app launch

#### Widget Extension (`quickMemoWidget/`)
- Shares data via App Group UserDefaults
- Categories selectable in `WidgetCategorySettingsView`
- Timeline refreshes on data changes

#### watchOS App Structure (`quickMemoWatch Watch App/`)
```
├── Models/       - WatchCategory, WatchMemo (simplified data structures)
├── Views/        - WatchMemoListView, WatchMemoInputView
├── Services/     - WatchConnectivityManager (offline-first sync)
└── quickMemoWatchApp.swift
```

### View Architecture

#### Main Navigation Flow
```
quickMemoAppApp (App)
    └── MainView (TabView)
        ├── CategoryView (per category)
        │   └── MemoListView
        ├── FastInputView (shake gesture)
        └── SettingsView
            ├── PurchaseView (Pro upgrade)
            └── CalendarPermissionView
```

#### Purchase UI Changes (Recent)
- Removed "deviceAccessSection" (Sign in with Apple promotion)
- Restore button placed directly under one-time purchase
- Renamed "永久ライセンス" → "買い切りライセンス"
- Simplified purchase flow without cross-device sync UI

## Critical Implementation Details

### Japanese Input Handling
FastInputView requires special handling for Japanese IME:
```swift
// Use TextEditor, not TextField (avoids IME conflicts)
TextEditor(text: $memoText)
    .focused($isTextFieldFocused)

// Custom placeholder with ZStack overlay
ZStack(alignment: .topLeading) {
    if memoText.isEmpty {
        Text("placeholder_text")
            .foregroundColor(.gray)
    }
    TextEditor(text: $memoText)
}

// Track isComposing for IME state
// Prevents tag suggestions during Japanese character composition
if !isComposing && selectedTags.isEmpty {
    showTagSuggestions()
}
```

### Runtime Language Switching
Implemented via `LocalizationManager` instead of standard iOS localization:
```swift
// Language stored in @AppStorage("app_language")
// Options: "device", "ja", "en", "zh-Hans"

// Bundle.setLanguage() switches at runtime
// refreshID UUID forces SwiftUI view updates
// Category metadata updates automatically

// Localized categories have baseKey for tracking:
"work" → Different names/icons per language
"personal" → Consistent category identity across languages
```

### Calendar Permission Flow
```swift
// iOS 17+: requestFullAccessToEvents()
// iOS 16: requestAccess(to: .event, completion:)
// Auto-creates "Quick Memo" calendar
```

### Pro Feature Limits
Enforced in DataManager and UI:
- Memos: 100 (free) / unlimited (pro)
- Categories: 5 (free) / unlimited (pro)
- Tags per memo: 15 (free) / unlimited (pro)
- iCloud sync: Pro only
- Widget customization: Pro only

## App Store Submission

### Current Status
- Version: 1.0
- Build: 2
- Review Status: In-app purchases configured, awaiting review

### In-App Purchase Configuration
Both products must be submitted with:
- App Review screenshot (640×920 minimum)
- Localized display names and descriptions
- Price tier configuration
- Review notes

### Required Metadata
- Terms of Use: https://www.apple.com/legal/internet-services/itunes/dev/stdeula/
- Privacy Policy: https://yok1012.github.io/quickMemoPrivacypolicy/
- Subscription information in app description

### Build Settings
- Bundle ID: `yokAppDev.quickMemoApp`
- Deployment Target: iOS 16.0+, watchOS 11.5+
- Code Signing: Automatic
- Generate Info.plist: YES

## Data Migration & Storage Management

### UserDefaults Size Management
```swift
// Current storage: JSON-encoded arrays in UserDefaults
// Size limit: ~1MB practical limit before performance issues

// Check storage size:
let defaults = UserDefaults(suiteName: "group.yokAppDev.quickMemoApp")
let data = try JSONEncoder().encode(memos)
print("Memos size: \(data.count) bytes")

// Migration strategy when approaching limits:
1. Archive old memos to separate key (archived_memos)
2. Implement pagination in UI (already supports first 100 for free users)
3. Consider Core Data migration (stack already implemented)
```

### Core Data Migration Path (Currently Disabled)
```swift
// Core Data stack exists but unused
// To enable:
1. Update DataManager to use CoreDataStack.shared
2. Migrate existing UserDefaults data
3. Enable CloudKit sync in Core Data model
4. Update App Group container references
```

### Backward Compatibility
```swift
// Custom decoders handle missing fields:
init(from decoder: Decoder) throws {
    // New field with fallback for old data
    title = try container.decodeIfPresent(String.self, forKey: .title) ?? ""
}
```

## Performance Monitoring

### Memory Usage Patterns
```bash
# Monitor memory during bulk operations
xcrun simctl spawn "iPhone 17 Pro" log stream --predicate 'eventMessage contains "Memory"'

# Key areas to monitor:
- Loading 100+ memos in MemoListView
- Widget timeline generation
- Watch sync of large memo sets
- Category icon rendering in lists
```

### Optimization Points
- **Memo List**: Already implements lazy loading with List/ForEach
- **Search**: Filters in-memory, consider indexing for 500+ memos
- **Widget**: Limits to 10 most recent memos per category
- **Watch Sync**: Batches to 20 memos max per transfer

## Known Issues and Technical Debt

1. **UserDefaults Size Limit**: No automatic migration when storage limit reached (see Data Migration section)
2. **CloudKit Container**: Still uses template ID "iCloud.com.yourcompany.quickMemoApp" - needs App Store Connect configuration
3. **Watch Connectivity**: iOS implementation minimal vs full watchOS implementation (intentional asymmetric design)
4. **Category Colors**: Hardcoded in `LocalizedCategories` struct, scattered across views
5. **Test Coverage**: Most test files are placeholders, need comprehensive unit tests
6. **Debug Sections**: #if DEBUG code should be verified before release builds
7. **StoreKit Configuration**: Two config files exist (Configuration.storekit, StoreKitConfiguration.storekit) - verify which is active and matches App Store Connect
8. **Root-level Swift files**: PurchaseManager.swift and PurchaseView.swift are at project root instead of in Services/Views - consider moving

## Project Structure

```
quickMemoApp/
├── quickMemoApp/              # Main iOS app
│   ├── Models/                # DataModels.swift (QuickMemo, Category, ArchivedMemo)
│   ├── Views/                 # SwiftUI views (16 files)
│   ├── Services/              # Business logic singletons
│   ├── Utils/                 # Helper utilities
│   ├── Resources/             # Localizable.strings (ja, en, zh-Hans)
│   └── Widget/                # Widget-related code
├── quickMemoWatch Watch App/  # watchOS companion app
├── quickMemoWidget/           # Widget extension
├── PurchaseManager.swift      # Root-level (should be in Services/)
├── PurchaseView.swift         # Root-level (should be in Views/)
└── *.md                       # Documentation files
```

## Supplementary Documentation

The root directory contains additional `.md` files for specific topics:
- `APP_STORE_*.md` - App Store submission and review guidance
- `CLOUDKIT_*.md` - CloudKit setup and troubleshooting
- `PURCHASE_*.md`, `SANDBOX_*.md` - In-app purchase testing
- `TESTING_GUIDE.md`, `SCREENSHOT_GUIDE.md` - QA procedures
- `WIDGET_SETUP.md` - Widget extension configuration

## Coding Conventions

- Swift 5.9 with four-space indentation
- `PascalCase` for types, `camelCase` for members
- Keep SwiftUI views lightweight; extract logic to `Services/`
- Use `enum` namespaces for constants
- Localize strings via `Resources/<lang>.lproj/Localizable.strings`
- Commit format: `type: summary` (e.g., `feat: Pro版課金機能を実装`)
- Use Swift Testing framework (`@Test` annotations) in `quickMemoAppTests/`

## Troubleshooting

### "quickMemoApp.debug.dylib" crash
```bash
rm -rf ~/Library/Developer/Xcode/DerivedData/*
xcodebuild -configuration Release -project quickMemoApp.xcodeproj build
```

### Simulator issues
```bash
xcrun simctl erase all
xcrun simctl shutdown all
```

### In-App Purchase Testing

#### StoreKit Configuration
```bash
# Test with local StoreKit configuration file
xcodebuild -project quickMemoApp.xcodeproj -scheme quickMemoApp \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro' \
  -StoreKitConfigurationFileReference Configuration.storekit build

# Verify product IDs match exactly:
- Monthly: com.yokAppDev.quickMemoApp.pro.month
- One-time: yokAppDev.quickMemoApp.pro
```

#### Debug Functions (PurchaseManager.swift)
```swift
#if DEBUG
// Available in debug builds:
testPurchaseMonthly() - Simulate monthly purchase
testPurchaseLifetime() - Simulate one-time purchase
testRestorePurchases() - Test restore flow
clearPurchaseStatus() - Reset to free version
#endif
```

#### App Store Connect Verification
- Both products must be "Ready to Submit"
- Screenshots required (640×920 minimum)
- Localized descriptions for all languages
- Review notes explaining Pro features