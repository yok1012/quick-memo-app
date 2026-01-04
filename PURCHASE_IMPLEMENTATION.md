# In-App Purchase Implementation (QuickMemo)

## Scope
- PurchaseManager.swift
- PurchaseView.swift
- ProFeatureViews.swift
- quickMemoApp/quickMemoAppApp.swift
- quickMemoApp/Services/DataManager.swift
- quickMemoApp/Services/CloudKitManager.swift
- quickMemoApp/Services/AuthenticationManager.swift
- quickMemoApp/Services/NotificationManager.swift
- quickMemoApp/Services/iOSWatchConnectivityManager.swift
- quickMemoApp/Services/RewardManager.swift
- quickMemoApp/Views/MainView.swift
- quickMemoApp/Views/SettingsView.swift
- quickMemoApp/Views/EditMemoView.swift
- quickMemoApp/Views/FastInputView.swift
- quickMemoApp/Views/CategoryManagementView.swift
- quickMemoApp/Views/WidgetCategorySettingsView.swift
- quickMemoApp/Views/WatchSettingsView.swift
- quickMemoApp/Views/RewardAdView.swift
- quickMemoWatch Watch App/Services/WatchPurchaseManager.swift
- quickMemoWatch Watch App/Services/WatchConnectivityManager.swift
- quickMemoWatch Watch App/Views/WatchCategorySettingsView.swift
- quickMemoWatch Watch App/Views/WatchFastInputView.swift
- quickMemoWidget/quickMemoWidget.swift
- Configuration.storekit
- StoreKitConfiguration.storekit

## Products and identifiers
- Monthly subscription (auto-renewable): com.yokAppDev.quickMemoApp.pro.month (defined in PurchaseManager.swift, used for sorting in PurchaseView.swift).
- Lifetime license (non-consumable): yokAppDev.quickMemoApp.pro (defined in PurchaseManager.swift, used in PurchaseView.swift and StoreKit config files).
- Product list used for StoreKit calls is allProductIDs in PurchaseManager.swift.
- Local StoreKit config files currently include only the non-consumable product (yokAppDev.quickMemoApp.pro) and no subscription entries.

## StoreKit integration (PurchaseManager.swift)
PurchaseManager is the StoreKit 2 entry point and also registers a StoreKit 1 observer for promoted purchases.

### Initialization flow
- Registers SKPaymentQueue observer for promoted purchases.
- Starts a detached task to listen to StoreKit.Transaction.updates.
- Processes StoreKit.Transaction.unfinished at app start.
- Loads products and updates entitlements, then optionally syncs CloudKit if iCloud is available.
- Sets isLoadingComplete so DataManager can wait for entitlement resolution before iCloud restore logic.

### Product loading
- loadProducts() calls Product.products(for: allProductIDs).
- checkNetworkConnection() currently always returns true (StoreKit handles network errors).

### Purchase flow
- purchase(_:) logs the attempt, checks Transaction.unfinished (without finishing), then calls product.purchase().
- On success with verified transaction: finish(), updatePurchasedProducts(), optionally save subscription status to CloudKit (only when AuthenticationManager.shared.isSignedIn), then sets purchaseState to purchased.
- On success but unverified: sets purchaseState to failed with error.
- On pending: sets purchaseState to notStarted.
- On userCancelled: sets purchaseState to cancelled.

### Restore flow
- restorePurchases() calls AppStore.sync(), then updatePurchasedProducts().
- If signed in, also fetches CloudKit subscription status and sets isProVersion if CloudKit says Pro.
- Sets purchaseState to purchased or failed based on final entitlement state.

### Entitlement update logic
- updatePurchasedProducts() iterates StoreKit.Transaction.currentEntitlements.
- Verified transactions are accepted only if not revoked.
- For auto-renewable: expirationDate must be in the future.
- isProVersion is true when purchasedProductIDs intersects allProductIDs.
- isProVersion is saved to the App Group key isPurchased for watch and widget.

### Transaction listeners
- listenForTransactions() finishes verified updates and refreshes entitlements.
- processUnfinishedTransactions() finishes verified and unverified unfinished transactions, then updates entitlements and CloudKit when signed in.

### StoreKit 1 (promoted purchases)
- paymentQueue(_:shouldAddStorePayment:for:) returns true to allow App Store promotions.
- paymentQueue(_:updatedTransactions:) finishes purchased or restored transactions and refreshes entitlements.

### Purchase state
- PurchaseState enum tracks notStarted, purchasing, purchased, failed, and cancelled.
- purchaseState drives UI alerts and loading indicators in PurchaseView.swift.

## Purchase state persistence and sharing
- isProVersion is a @Published flag in PurchaseManager.swift and posts PurchaseStatusChanged when it changes.
- App Group suite is group.yokAppDev.quickMemoApp.
- isPurchased (App Group key) is used by watch and widget code to read Pro state.
- is_pro_version is a legacy key used only for migration in DataManager.swift and still checked by the widget.

## CloudKit and Sign in with Apple
- CloudKitManager.saveSubscriptionStatus() writes a SubscriptionStatus record to the private database with transactionID, productID, isPro, lastUpdated, deviceID.
- PurchaseManager saves to CloudKit only when AuthenticationManager.shared.isSignedIn is true.
- CloudKitManager.syncSubscriptionStatus() runs at startup (from PurchaseManager) when iCloud is available and after Sign in with Apple succeeds.
- If CloudKit says Pro, PurchaseManager.isProVersion is forced true.
- If local Pro but CloudKit missing, CloudKitManager attempts to save the latest StoreKit entitlement.
- restorePurchases() also checks CloudKit when signed in.
- DataManager attempts iCloud restore on fresh installs even before Pro is confirmed, and if a backup exists it enables iCloudSyncEnabled and treats the user as Pro.

## UI entry points and purchase UX
- PurchaseView.swift shows Pro feature list, products, subscription terms, and privacy/terms links.
- PurchaseView loads products on appear and shows a restore button under the lifetime product.
- PurchaseView sorts products to show the monthly subscription first.
- MainView.swift shows a Pro badge button and can open PurchaseView via deep link or watch request.
- SettingsView.swift shows upgrade and restore actions, plus App Store subscription management link.
- ProFeatureViews.swift provides a generic locked feature view and upgrade button.
- EditMemoView.swift and FastInputView.swift show a tag limit alert with a link to PurchaseView.
- WidgetCategorySettingsView.swift and WatchSettingsView.swift surface upgrade prompts and can open PurchaseView.
- RewardAdView.swift links to PurchaseView as an upgrade option.
- DeepLinkManager in quickMemoAppApp.swift handles quickmemo://purchase to open PurchaseView.
- Watch connectivity can request opening PurchaseView using the "openPurchase" action.

## Feature gating (what Pro changes in code)
### Limits and gating enforced in data layer
- Memo count: free users are limited to 100 memos, with reward memos as an extra pool. DataManager.canAddMemo() and RewardManager handle this.
- Categories: free users are limited to 5 categories. DataManager keeps all categories but the UI enforces the limit.
- Tags per memo: free users are limited to 15 tags per memo. Enforced in DataManager.addMemo(), DataManager.updateMemo(), EditMemoView.swift, and FastInputView.swift.
- Tags per category: free users are limited to 20 tags when auto-adding tags to a category in DataManager.addTagsToCategory().
- iCloud sync and backup: iCloudSyncEnabled is tied to isProVersion, gating Core Data sync and backup/restore functions.
- Widget category customization: DataManager.saveWidgetCategories() returns early when not Pro.
- Data export is not gated by isProVersion in SettingsView.swift even though PurchaseView.swift lists it as a Pro feature.

### Limits and gating enforced in UI
- CategoryManagementView.swift prevents adding more than 5 categories for free users.
- WidgetCategorySettingsView.swift blocks adding categories and shows upgrade prompts for free users.
- WatchSettingsView.swift and WatchCategorySettingsView.swift show only default categories for free users.
- WatchFastInputView.swift uses default categories for free users and selected categories for Pro users.
- SettingsView.swift shows the iCloud backup section only for Pro users.
- MainView.swift blocks memo creation when limits are reached and prompts to upgrade.

### Convenience checks
- PurchaseManager has helper methods such as canCreateMoreMemos(), canCreateMoreCategories(), canCustomizeWidget(), canUseAdvancedFeatures(), and getMaxTagsPerMemo().
- DataManager exposes canUseCalendarIntegration(), canUseAdvancedTags(), and canUseDeepLinks() which all map to the Pro flag.

### Notifications and ads
- quickMemoAppApp.swift only schedules notifications on launch when isProVersion is true and notifications are enabled.
- AdMobManager is initialized only when isProVersion is false (ads for free users).

## Watch and widget synchronization
- PurchaseManager writes isPurchased to the App Group so watch and widget can read Pro state.
- iOSWatchConnectivityManager sends purchaseStatusUpdate to watch and also writes isPurchased to the App Group.
- WatchPurchaseManager reads isPurchased from the App Group and can request a refresh from the phone.
- quickMemoWidget uses isPurchased (and legacy is_pro_version) to decide Pro state and show upgrade links.
- quickMemoWidget loads custom widget categories only when is_pro_version is true, so isPurchased alone does not enable category customization in the widget.

## Debug and testing hooks
- PurchaseManager.debugResetPurchaseState() clears local purchase state and App Group isPurchased.
- PurchaseManager.debugSetSkipStoreKit(true) forces skipping StoreKit entitlement refresh.
- SettingsView.swift (DEBUG only) provides a Pro mode toggle, purchase reset, sandbox clearing, and StoreKit entitlement debug output.
- WatchSettingsView.swift (DEBUG only) supports debugProMode and syncs it to the watch.

## StoreKit configuration files
- Configuration.storekit contains a single non-consumable product yokAppDev.quickMemoApp.pro.
- StoreKitConfiguration.storekit also contains only yokAppDev.quickMemoApp.pro and no subscription products.
- The monthly subscription ID is still referenced in code and should be configured in App Store Connect and any local StoreKit configs used for testing.
