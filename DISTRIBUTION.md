# Gaze Distribution Guide

This guide explains how to build and distribute Gaze for both the Mac App Store and direct distribution with auto-updates.

## Distribution Methods

Gaze supports two distribution methods:

1. **Self-Distribution** (Direct Download) - Includes Sparkle for automatic updates
2. **Mac App Store** - Uses Apple's update mechanism, no Sparkle

## Quick Start

### Switching Between Distributions

Use the `switch_to` script to configure the project for each distribution method:

```bash
# For self-distribution with Sparkle auto-updates
./switch_to self

# For Mac App Store submission
./switch_to appstore

# Check current configuration
./switch_to status
```

### What Gets Changed

The `switch_to` script automatically manages:

**Self-Distribution Mode:**
- ✅ Adds Sparkle keys to `Info.plist` (SUPublicEDKey, SUFeedURL, etc.)
- ✅ Adds Sparkle entitlements for XPC services
- ✅ Removes `APPSTORE` compiler flag
- ✅ Enables UpdateManager with Sparkle framework

**App Store Mode:**
- ✅ Removes all Sparkle keys from `Info.plist`
- ✅ Removes Sparkle entitlements
- ✅ Adds `-D APPSTORE` compiler flag
- ✅ Disables Sparkle code at compile time

## Building for Self-Distribution

```bash
# 1. Switch to self-distribution mode
./switch_to self
```

The script will:
- Prompt for version bump (major/minor/patch)
- Build and code sign with Developer ID
- Notarize the app with Apple
- Create a signed DMG
- Generate Sparkle appcast with EdDSA signature
- (Optional) Upload to S3 if credentials are configured

## Building for Mac App Store

```bash
# 1. Switch to App Store mode
./switch_to appstore

# 2. Add Run Script Phase in Xcode (one-time setup)
# See section below

# 3. Archive and distribute via Xcode
# Product → Archive
# Window → Organizer → Distribute App → App Store Connect
```

### Required: Run Script Phase

For App Store builds, you **must** add this Run Script phase in Xcode:

1. Open Gaze.xcodeproj in Xcode
2. Select the Gaze target → Build Phases
3. Click + → New Run Script Phase
4. Name it: "Remove Sparkle for App Store"
5. Place it **after** "Embed Frameworks"
6. Add this script:

```bash
#!/bin/bash
if [[ "${OTHER_SWIFT_FLAGS}" == *"APPSTORE"* ]]; then
    echo "Removing Sparkle framework for App Store build..."
    rm -rf "${BUILT_PRODUCTS_DIR}/${FRAMEWORKS_FOLDER_PATH}/Sparkle.framework"
    echo "Sparkle framework removed successfully"
fi
```

This ensures Sparkle.framework is removed from the app bundle before submission.

## Configuration Files

Configuration backups are stored in `.distribution_configs/`:
- `.distribution_configs/appstore/` - App Store configuration
- `.distribution_configs/self/` - Self-distribution configuration

These backups are created automatically and used when switching between modes.

## Validation

Before submitting to App Store Connect, verify your configuration:

```bash
./switch_to status
```

Expected output for App Store:
```
Info.plist: App Store (no Sparkle keys)
Entitlements: App Store (no Sparkle exceptions)
Build Settings: App Store (has APPSTORE flag)
```

Expected output for Self-Distribution:
```
Info.plist: Self-Distribution (has Sparkle keys)
Entitlements: Self-Distribution (has Sparkle exceptions)
Build Settings: Self-Distribution (no APPSTORE flag)
```

## Troubleshooting

### App Store Validation Fails

**Error: "App sandbox not enabled" with Sparkle executables**
- Solution: Make sure you ran `./switch_to appstore` and added the Run Script phase

**Error: "Bad Bundle Executable" or "CFBundlePackageType"**
- Solution: These are now fixed in the Info.plist

**Error: Still seeing Sparkle in the build**
- Solution: Clean build folder (⌘⇧K) and rebuild

### Self-Distribution Issues

**Sparkle updates not working**
- Verify: `./switch_to status` shows "Self-Distribution" mode
- Check: Info.plist contains SUPublicEDKey and SUFeedURL
- Verify: Appcast is accessible at the SUFeedURL

**Code signing issues**
- Check `.env` file has correct credentials
- Verify Developer ID certificate: `security find-identity -v -p codesigning`

## Environment Variables

For self-distribution, create a `.env` file with:

```bash
# Required for code signing
DEVELOPER_ID_APPLICATION="Developer ID Application: Your Name (TEAM_ID)"
APPLE_TEAM_ID="XXXXXXXXXX"

# Required for notarization
NOTARY_KEYCHAIN_PROFILE="notary-profile"

# Optional for S3 upload
AWS_ACCESS_KEY_ID="your-key"
AWS_SECRET_ACCESS_KEY="your-secret"
AWS_BUCKET_NAME="your-bucket"
AWS_REGION="us-east-1"
```

Setup notarization profile (one-time):
```bash
xcrun notarytool store-credentials "notary-profile" \
  --apple-id "your@email.com" \
  --team-id "TEAM_ID"
```

## Version Management

The `self_distribute` script handles version bumping:
- **Major** (X.0.0) - Breaking changes
- **Minor** (x.X.0) - New features
- **Patch** (x.x.X) - Bug fixes
- **Custom** - Any version string
- **Keep** - Increment build number only

Git tags are created automatically for new versions.

## Testing

### Test Self-Distribution Build
```bash
./switch_to self
# Test the DMG on a clean macOS system
```

### Test App Store Build
```bash
./switch_to appstore
# Archive in Xcode
# Use TestFlight for testing before release
```

## Best Practices

1. **Always use `switch_to`** - Don't manually edit configuration files
2. **Check status before building** - Use `./switch_to status`
3. **Clean builds** - Run Clean Build Folder when switching modes
4. **Test thoroughly** - Test both distribution methods separately
5. **Commit before switching** - Use git to track configuration changes

## Support

For issues or questions:
- GitHub Issues: https://github.com/mikefreno/Gaze/issues
- Check AGENTS.md for development guidelines
