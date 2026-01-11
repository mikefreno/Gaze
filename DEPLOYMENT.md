# Gaze Release Deployment Process

## Overview

This document describes the complete process for building and deploying new releases of Gaze with Sparkle auto-update support.

## Prerequisites

- Xcode with Gaze project configured
- `create-dmg` tool installed (`brew install create-dmg`)
- Sparkle EdDSA signing keys in macOS Keychain (see Key Management below)
- AWS credentials configured in `.env` file for S3 upload
- Access to freno.me hosting infrastructure

## Version Management

Version numbers are managed in Xcode project settings:
- **Marketing Version** (`MARKETING_VERSION`): User-facing version (e.g., "0.1.1")
- **Build Number** (`CURRENT_PROJECT_VERSION`): Internal build number (e.g., "1")

These must be incremented before each release and kept in sync with `build_dmg` script.

## Release Checklist

### 1. Prepare Release

- [ ] Update version numbers in Xcode:
  - Project Settings → General → Identity
  - Set Marketing Version (e.g., "0.1.2")
  - Increment Build Number (e.g., "2")
- [ ] Update `VERSION` and `BUILD_NUMBER` in `build_dmg` script
- [ ] Update CHANGELOG or release notes
- [ ] Commit version changes: `git commit -am "Bump version to X.Y.Z"`
- [ ] Create git tag: `git tag v0.1.2`

### 2. Build Application

```bash
# Build the app in Xcode (Product → Archive → Export)
# Or use the run script
./run build

# Verify the app runs correctly
open Gaze.app
```

### 3. Create DMG and Appcast

```bash
# Run the build_dmg script
./build_dmg

# This will:
# - Create versioned DMG file
# - Generate appcast.xml with EdDSA signature
# - Upload to S3 if AWS credentials are configured
# - Display next steps
```

### 4. Verify Artifacts

Check that the following files were created in `./releases/`:
- `Gaze-X.Y.Z.dmg` - Installable disk image
- `appcast.xml` - Update feed with signature
- `Gaze-X.Y.Z.delta` (optional) - Delta update from previous version

### 5. Upload to Hosting (if not using S3 auto-upload)

**DMG File:**
```bash
# Upload to: https://freno.me/downloads/
scp ./releases/Gaze-X.Y.Z.dmg your-server:/path/to/downloads/
```

**Appcast File:**
```bash
# Upload to: https://freno.me/api/Gaze/
scp ./releases/appcast.xml your-server:/path/to/api/Gaze/
```

### 6. Verify Deployment

Test that files are accessible via HTTPS:

```bash
# Test appcast accessibility
curl -I https://freno.me/api/Gaze/appcast.xml
# Should return: HTTP/2 200, content-type: application/xml

# Test DMG accessibility
curl -I https://freno.me/downloads/Gaze-X.Y.Z.dmg
# Should return: HTTP/2 200, content-type: application/octet-stream

# Validate appcast XML structure
curl https://freno.me/api/Gaze/appcast.xml | xmllint --format -
```

### 7. Test Update Flow

**Manual Testing:**
1. Install previous version of Gaze
2. Launch app and check Settings → General → Software Updates
3. Click "Check for Updates Now"
4. Verify update notification appears
5. Complete update installation
6. Verify new version launches correctly

**Automatic Update Testing:**
1. Set `SUScheduledCheckInterval` to a low value (e.g., 60 seconds) for testing
2. Install previous version
3. Wait for automatic check
4. Verify update notification appears

### 8. Finalize Release

- [ ] Push git tag: `git push origin v0.1.2`
- [ ] Create GitHub release (optional)
- [ ] Announce release to users
- [ ] Monitor for update errors in the first 24 hours

## Hosting Configuration

### Current Setup

- **Appcast URL:** `https://freno.me/api/Gaze/appcast.xml`
- **Download URL:** `https://freno.me/downloads/Gaze-{VERSION}.dmg`
- **Hosting:** AWS S3 with freno.me domain
- **SSL:** HTTPS enabled (required by App Transport Security)

### AWS S3 Configuration

Create a `.env` file in the project root with:

```bash
AWS_ACCESS_KEY_ID=your_access_key
AWS_SECRET_ACCESS_KEY=your_secret_key
AWS_BUCKET_NAME=your_bucket_name
AWS_REGION=us-east-1
```

**Note:** `.env` is gitignored to protect credentials.

### S3 Bucket Structure

```
your-bucket/
├── downloads/
│   ├── Gaze-0.1.1.dmg
│   ├── Gaze-0.1.2.dmg
│   └── ...
└── api/
    └── Gaze/
        └── appcast.xml
```

## Key Management

### EdDSA Signing Keys

**Location:**
- **Public Key:** In `Gaze/Info.plist` as `SUPublicEDKey`
- **Private Key:** In macOS Keychain as "Sparkle EdDSA Private Key"
- **Backup:** `~/sparkle_private_key_backup.pem` (keep secure!)

**Current Public Key:**
```
Z2RmohI1y2bgeGQQUDqO9F0HNF2AzFotOt8CwGB6VJM=
```

**Security:**
- Never commit private key to version control
- Keep backup in secure location (password manager, encrypted drive)
- Private key is required to sign all future updates

### Regenerating Keys (Emergency Only)

If private key is lost, you must:
1. Generate new key pair: `./generate_keys`
2. Update `SUPublicEDKey` in Info.plist
3. Release new version with new public key
4. Previous versions won't be able to update (users must manually install)

## Troubleshooting

### Appcast Generation Fails

**Problem:** `generate_appcast` tool not found

**Solution:**
```bash
# Build the app first to generate Sparkle tools
xcodebuild -project Gaze.xcodeproj -scheme Gaze -configuration Release

# Find Sparkle tools
find ~/Library/Developer/Xcode/DerivedData/Gaze-* -name "generate_appcast"
```

### Update Check Fails in App

**Problem:** No updates found or connection error

**Diagnostics:**
```bash
# Check Console.app for Sparkle logs
# Filter by process: Gaze
# Look for:
# - "Downloading appcast..."
# - "Appcast downloaded successfully"
# - Connection errors
# - Signature verification errors
```

**Common Issues:**
- Appcast URL not accessible (check HTTPS)
- Signature mismatch (wrong private key used)
- XML malformed (validate with xmllint)
- Version number not higher than current version

### DMG Not Downloading

**Problem:** Update found but download fails

**Check:**
- DMG URL is correct in appcast
- DMG file is accessible via HTTPS
- File size in appcast matches actual DMG size
- No CORS issues (check browser console)

## Delta Updates

Sparkle automatically generates delta updates when multiple versions exist in `./releases/`:

```bash
# Keep previous versions for delta generation
releases/
├── Gaze-0.1.1.dmg
├── Gaze-0.1.2.dmg
├── Gaze-0.1.1-to-0.1.2.delta  # Generated automatically
└── appcast.xml
```

**Benefits:**
- Much smaller downloads (MB vs GB)
- Faster updates for users
- Generated automatically by `generate_appcast`

**Note:** First-time users still download full DMG.

## Testing with Local Appcast

For testing without deploying:

1. Modify Info.plist temporarily:
```xml
<key>SUFeedURL</key>
<string>file:///Users/mike/Code/Gaze/releases/appcast.xml</string>
```

2. Build and run app
3. Check for updates
4. Revert Info.plist before committing

## Release Notes

Release notes are embedded in appcast XML as CDATA:

```xml
<description><![CDATA[
    <h2>What's New in Version X.Y.Z</h2>
    <ul>
        <li>Feature 1</li>
        <li>Bug fix 2</li>
    </ul>
]]></description>
```

**Tips:**
- Use simple HTML (h2, ul, li, p, strong, em)
- No external resources (images, CSS, JS)
- Keep concise and user-focused
- Highlight breaking changes

## References

- [Sparkle Documentation](https://sparkle-project.org/documentation/)
- [Publishing Updates](https://sparkle-project.org/documentation/publishing/)
- [Sandboxed Apps](https://sparkle-project.org/documentation/sandboxing/)
- [Gaze Repository](https://github.com/YOUR_USERNAME/Gaze)

## Support

For issues with deployment:
1. Check Console.app for Sparkle errors
2. Verify appcast validation with xmllint
3. Test with file:// URL first
4. Check AWS S3 permissions and CORS
