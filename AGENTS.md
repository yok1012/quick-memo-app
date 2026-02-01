# Repository Guidelines

## Project Structure & Module Organization
Primary SwiftUI app code lives inside `quickMemoApp/`, with feature views under `Views/`, data models in `Models/`, reusable helpers in `Utils/`, and app services (notifications, purchases, connectivity) in `Services/`. Localized resources sit in `Resources/<lang>.lproj`, and shared assets in `Assets.xcassets`. Companion targets are separated: the watch experience in `quickMemoWatch Watch App/`, widgets in `quickMemoWidget/`, and their respective test bundles alongside `quickMemoAppTests/` and `quickMemoAppUITests/`.

## Build, Test, and Development Commands
Open the workspace in Xcode with `open quickMemoApp.xcodeproj` and use the `quickMemoApp` scheme for simulator builds. CI-friendly builds run via `xcodebuild -scheme quickMemoApp -destination 'platform=iOS Simulator,name=iPhone 15' build`. Execute unit coverage with `xcodebuild test -scheme quickMemoApp -destination 'platform=iOS Simulator,name=iPhone 15,OS=latest'`. For the watch component, target `quickMemoWatchApp` and ensure the paired simulator is selected before running.

## Coding Style & Naming Conventions
Follow Swift 5.9 conventions with four-space indentation and `PascalCase` types (`MainView`), `camelCase` members (`scheduleNotifications`). Keep SwiftUI view structs lightweight and extend larger logic into `Services/`. Prefer `enum` namespaces for constants, and localize user-facing strings through `Resources` catalogs. When bridging to Objective-C or watch code, mirror existing file naming such as `PurchaseManager.swift`.

## Testing Guidelines
Use the Swift `Testing` framework already imported in `quickMemoAppTests.swift`; group scenarios by feature (`MemoPersistenceTests`) and annotate with `@Test`. Cover new data persistence, notification scheduling, and StoreKit flows before merging. Snapshot or UI flows belong in `quickMemoAppUITests/`; skip fragile sleeps and rely on expectations. Run the full suite with the `xcodebuild test` command above before submitting a PR.

## Commit & Pull Request Guidelines
Existing history mixes conventional commits (`feat: Pro版課金機能を実装`) and Japanese summaries; keep the `type: summary` pattern in imperative voice and include localized detail when helpful. Reference issue IDs in the body, describe user-visible changes, and attach simulator screenshots for UI tweaks or watch complications. Pull requests should outline verification steps (build, tests, StoreKit sandbox) so reviewers can reproduce.

## Configuration & Environment Notes
StoreKit sandbox files (`Configuration.storekit`, `StoreKitConfiguration.storekit`) define product identifiers—update them in tandem with `PurchaseManager`. Notification tuning lives in `DEBUG_PRO_*` guides; follow those when adjusting entitlement gates. When modifying watch connectivity, keep `PurchaseManager.shared` interactions in sync across `Watch/` mirrors before shipping.
