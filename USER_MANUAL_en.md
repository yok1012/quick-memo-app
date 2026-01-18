# QuickMemo User Manual

Version: 3.0
Last Updated: January 2025

---

## Table of Contents

1. [About the App](#about-the-app)
2. [Core Features](#core-features)
3. [How to Use](#how-to-use)
4. [AI Features](#ai-features)
5. [Pro Version](#pro-version)
6. [Apple Watch Integration](#apple-watch-integration)
7. [Widgets](#widgets)
8. [Data Management](#data-management)
9. [Settings](#settings)
10. [FAQ](#faq)
11. [Troubleshooting](#troubleshooting)

---

## About the App

**QuickMemo** is a fast memo app that lets you capture thoughts the moment they occur.

### Key Features

- 📱 **Shake Gesture**: Simply shake your device to instantly open the memo input screen
- 📁 **Category Management**: Create custom categories like Work, Personal, and Ideas
- 🏷️ **Smart Tags**: Auto-suggested tags from content, with multiple tags for detailed classification
- 🤖 **AI Features**: Tag extraction, memo arrangement, category summary (API key required)
- 📅 **Calendar Integration**: Automatically record memos to your calendar
- ⌚ **Apple Watch Support**: Input memos directly on your Watch, works offline
- 🔄 **Data Sync**: iCloud sync available with Pro version

---

## Core Features

### Creating Memos

#### Create with Shake Gesture
1. Shake your iPhone lightly
2. The memo input screen opens automatically
3. Enter your text
4. Select category and tags (optional)
5. Tap "Save"

#### Create from Home Screen
1. Tap the "+" button at the bottom
2. Memo is created in the currently selected category
3. Enter text and tap "Save"

### Editing Memos

1. Tap the memo you want to edit from the list
2. Edit the text
3. Change category, tags, or duration as needed
4. Tap "Update" to save

### Deleting Memos

1. Swipe left on a memo in the list
2. Tap "Delete"
3. Or, tap the trash icon in the top right of the edit screen

### Searching Memos

1. Tap the search bar at the top of the memo list
2. Enter keywords
3. Searches through titles, content, and tags

---

## How to Use

### Managing Categories

#### Creating Categories
1. Open Settings
2. Tap "Category Management"
3. Add new category with "+" button
4. Set name, icon, and color

#### Editing Categories
1. Tap a category in Category Management
2. Change name, icon, or color
3. Set default tags

#### Reordering Categories
1. Tap "Edit" in the top right of Category Management
2. Drag and drop to change order

#### Deleting Categories
1. Swipe left on a category in Category Management
2. Tap "Delete"
3. Memos in that category will move to "Other"

### Managing Tags

#### Adding Tags to Memos
1. Open tag section in memo create/edit screen
2. Select from category's default tags
3. Or add new tag with "New" button

#### Deleting Tags
1. Show default tags in category edit screen
2. Swipe left on tag to delete

### Calendar Integration

#### Setting Up Calendar Integration
1. Open Settings
2. Turn on "Calendar Integration"
3. Allow calendar access

#### Setting Memo Duration
1. Open "Duration" section in memo create/edit screen
2. Select 15min, 30min, 1hr, or 2hr
3. Memo is recorded as calendar event

---

## AI Features

QuickMemo supports three AI providers: Gemini, Claude, and ChatGPT.

### Setting Up AI Features

#### Configuring API Keys
1. Open Settings
2. Tap "AI Features"
3. Enter API key for desired AI provider
   - **Gemini**: Used for tag extraction
   - **Claude**: Used for memo arrangement & summary
   - **ChatGPT**: Available for all features

#### How to Get API Keys
- **Gemini**: [Google AI Studio](https://makersuite.google.com/app/apikey)
- **Claude**: [Anthropic Console](https://console.anthropic.com/)
- **ChatGPT**: [OpenAI Platform](https://platform.openai.com/)

### Tag Extraction

AI automatically suggests relevant tags from memo content.

1. Open memo create/edit screen
2. Enter text (20+ characters)
3. Tap "AI Extract" button
4. Select and add from suggested tags

**Note**: Gemini API key required.

### Memo Arrangement

AI reformats memo content into various styles.

1. Tap memo arrange button (wand icon) in edit screen
2. Select from presets:
   - **Summarize**: Condense to 3 lines or less
   - **Business Format**: Convert to formal text
   - **Make Casual**: Make it friendly
   - **Expand Details**: Elaborate more specifically
   - **Bullet Points**: Organize for readability
   - **Translate**: Convert language
3. Or enter custom prompt for custom instructions
4. Review result and tap "Apply" or "Discard"

**Note**: Claude API key required.

### Category Summary

AI analyzes all memos in a category and generates a summary.

1. Tap summary button in category view
2. AI analyzes all memos
3. Shows:
   - Overall summary
   - Key points
   - Trends
   - Statistics

**Note**: Claude API key required. Needs 3+ memos.

### AI Usage Statistics

1. Settings > AI Features > Usage Statistics
2. View requests, tokens, and estimated cost for current month
3. Show usage by feature and provider
4. Export history or reset available

**Note**: API charges are paid directly to each provider.

---

## Pro Version

### Pro Benefits

#### Unlimited Features
- ✅ **Unlimited Memos** (Free: 100)
- ✅ **Unlimited Categories** (Free: 5)
- ✅ **Unlimited Tags** (Free: 15/memo)

#### Sync & Backup
- ☁️ **iCloud Sync**: Auto-sync across all devices
- 💾 **iCloud Backup**: Manual backup & restore

#### Other Benefits
- 🔔 **Regular Reminders**: Notifications to prevent missing memos
- 🎨 **Widget Customization**: Freely choose displayed categories

### How to Purchase Pro

1. Open Settings
2. Tap "Upgrade to Pro"
3. Choose from:
   - **Monthly Plan**: $1.99/month
   - **One-Time License**: $4.99 (permanent access)

### Restore Purchase

If purchased on another device:

1. Open Settings
2. Tap "Upgrade to Pro"
3. Tap "Restore Purchases"
4. Verify signed in with same Apple ID

---

## Apple Watch Integration

### Creating Memos on Apple Watch

1. Open QuickMemo app on Apple Watch
2. Tap "New Memo"
3. Use voice input or scribble (handwriting)
4. Select category
5. Tap "Save"

### About Sync

- Memos automatically sync with iPhone
- When offline, saved locally and synced when connected
- Latest 20 memos stored on Watch

### Checking Pro Status

- Pro purchase status auto-updates when Watch app launches
- After purchasing on iPhone, restart Watch app

---

## Widgets

### Adding Widgets

1. Long press on home screen
2. Tap "+" button in top left
3. Select "QuickMemo"
4. Choose widget size
   - **Small**: Shows memos from 1 category
   - **Medium**: Shows memos from 2 categories
   - **Large**: Shows memos from up to 8 categories

### Customizing Widgets (Pro)

1. Settings > Widget Settings
2. Select categories to display (up to 8)
3. Tap "Save"

**Note**: Free version only displays currently selected category.

---

## Data Management

### Exporting Memos

#### Export Individual Memo
1. Tap share button in memo edit screen
2. Select format:
   - Markdown (.md)
   - Plain Text (.txt)
   - JSON (.json)
3. Choose save location

#### Bulk Export
1. Settings > Export Data
2. Select format:
   - CSV: Open with Excel etc.
   - JSON: Structured data
3. All memos are exported

### Importing Memos

Supported formats:
- Plain Text (.txt)
- Markdown (.md)
- CSV (QuickMemo export format)
- JSON (QuickMemo export format)

#### Import Steps
1. Settings > Import Memos
2. Tap "Select File"
3. Choose file to import
4. Review content in preview
5. Select destination category
6. Tap "Import"

**Notes**:
- Character encoding auto-detected (UTF-8, Shift-JIS, EUC-JP, etc.)
- For memos without category info, selected category is applied
- Free version: 100 limit. Pro: unlimited.

### iCloud Backup (Pro)

#### Creating Backup
1. Settings > iCloud Backup
2. Tap "Backup Now"
3. Last backup date displayed when complete

#### Restoring from Backup
1. Settings > iCloud Backup
2. Tap "Restore from iCloud"
3. Select "Restore" on confirmation screen
4. Backup data merged with current data

**Note**: Must be signed in to iCloud.

---

## Settings

### App Settings

#### Shake Gesture
- **On/Off**: Enable/disable shake to open memo input
- **Sensitivity**: Adjust shake strength (3 levels)

#### Notification Settings
- **Memory Reminder** (Pro): Regular notifications to check memos
- **Quiet Time**: Set time period to stop notifications

#### Language Settings
- **App Language**: Choose Japanese, English, or Simplified Chinese
- **Category Names**: Auto-translated when language changes

### Data & Privacy

- Memo data securely stored on device
- AI API keys encrypted and stored in Keychain
- Data sent to AI providers only when you use features
- Privacy Policy: https://yok1012.github.io/quickMemoPrivacypolicy/

---

## FAQ

### Q1: Shake gesture not responding

**A**: Check the following:
- Settings > Shake Gesture is turned on
- Try changing sensitivity to "High"
- Try shaking iPhone lightly 2-3 times

### Q2: Apple Watch not syncing

**A**: Try these:
- Verify iPhone and Watch connected via Bluetooth
- Restart QuickMemo app on both devices
- Check iPhone Settings > Bluetooth for Watch connection

### Q3: Purchased Pro but features unavailable

**A**:
1. Completely quit and restart app
2. Check Pro status in Settings
3. If still not working, try "Restore Purchases"

### Q4: AI features not working

**A**:
- Verify API key correctly configured
- Check provider API key set for desired feature
  - Tag extraction: Gemini
  - Memo arrange/summary: Claude
- Check API key expiration and usage limits

### Q5: Memos disappeared

**A**:
- Pro version: Settings > iCloud Backup > Restore from iCloud
- Check if archived (Settings > Check Archives)

### Q6: Will memos be deleted when I delete a category?

**A**: No, memos won't be deleted. When you delete a category, its memos automatically move to "Other" category.

### Q7: Can't change widget categories

**A**: Widget customization is a Pro-only feature. Free version only displays currently selected category.

---

## Troubleshooting

### App Won't Launch

1. Completely quit app (double tap home button or swipe up from bottom)
2. Restart iPhone
3. Check App Store for updates
4. If not resolved, reinstall (data will be preserved)

### Data Not Displaying

1. Settings > Category Management to verify correct categories shown
2. Try searching for memos using search bar
3. Pro version: Try restoring from iCloud backup

### Calendar Integration Not Working

1. iPhone Settings > Privacy > Calendar
2. Verify QuickMemo access is enabled
3. App Settings > Calendar Integration is on
4. Check if "Quick Memo" calendar created in Calendar app

### Purchase Not Reflected

1. Verify signed in with same Apple ID in App Store
2. Try "Restore Purchases" button in app
3. Restart iPhone
4. If not reflected within 24 hours, contact Apple Support

### AI Feature Errors

#### "Invalid API Key" error
- Try re-entering API key
- Verify API key is valid in provider's console
- Check API key access permissions

#### "Request limit exceeded" error
- May have exceeded provider's free tier
- Settings > AI Features > Usage Statistics to check usage
- Verify limits and charges in provider's console

---

## Support

### Contact Us

For questions or support regarding the app:

- **Email**: quickmemo.support@example.com
- **Privacy Policy**: https://yok1012.github.io/quickMemoPrivacypolicy/

### Update Information

Check the app page on the App Store for latest updates.

---

## Terms of Use

- Terms: https://www.apple.com/legal/internet-services/itunes/dev/stdeula/
- Privacy Policy: https://yok1012.github.io/quickMemoPrivacypolicy/

---

**QuickMemo** - Your memo partner that never misses a moment

© 2024-2025 QuickMemo. All rights reserved.
