# Archive Post-Action Setup (REQUIRED for App Store)

## The Problem

App Store validation fails with:
```
App sandbox not enabled. The following executables must include the 
"com.apple.security.app-sandbox" entitlement...
Sparkle.framework/Versions/B/Autoupdate
Sparkle.framework/Versions/B/Updater.app
...
```

Sparkle.framework **must be physically removed** from the app bundle for App Store distribution.

## Why Build Phase Scripts Don't Work

Build Phase scripts run during compilation when files are code-signed and locked by macOS. Even with `chmod` and `chflags`, you get "Operation not permitted" due to System Integrity Protection.

## The Solution: Archive Post-Action

Archive Post-Actions run **after** the archive completes, when files are no longer locked. This is the correct place to remove Sparkle.

---

## Setup Instructions (2 minutes)

### 1. Open Scheme Editor
In Xcode: **Product → Scheme → Edit Scheme...** (or press **⌘<**)

### 2. Select Archive
Click **Archive** in the left sidebar

### 3. Add Post-Action Script
- At the bottom, under "Post-actions", click the **+** button
- Select **New Run Script Action**

### 4. Configure the Action

**Provide build settings from:** Select **Gaze** from the dropdown (IMPORTANT!)

**Shell:** Leave as `/bin/bash`

**Script:** Copy and paste this entire script:

```bash
if [[ "${OTHER_SWIFT_FLAGS}" == *"APPSTORE"* ]]; then
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "🗑️  Removing Sparkle from archived app..."
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    
    SPARKLE_PATH="${ARCHIVE_PATH}/Products/Applications/Gaze.app/Contents/Frameworks/Sparkle.framework"
    
    if [ -d "$SPARKLE_PATH" ]; then
        echo "📂 Found Sparkle at: $SPARKLE_PATH"
        
        # Make writable and remove
        chmod -R u+w "$SPARKLE_PATH" 2>/dev/null || true
        chflags -R nouchg "$SPARKLE_PATH" 2>/dev/null || true
        rm -rf "$SPARKLE_PATH"
        
        if [ ! -d "$SPARKLE_PATH" ]; then
            echo "✅ Sparkle framework removed successfully!"
        else
            echo "❌ ERROR: Could not remove Sparkle framework"
            echo "   This will cause App Store validation to fail"
            exit 1
        fi
    else
        echo "ℹ️  Sparkle framework not found (already removed)"
    fi
    
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "✅ Archive ready for App Store distribution"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
else
    echo "✓ Self-distribution archive - Sparkle retained"
fi
```

### 5. Save
Click **Close** to save the scheme changes

---

## Verification Steps

### Test the Archive

1. **Switch to App Store mode:**
   ```bash
   ./switch_to appstore
   ```

2. **Archive in Xcode:**
   - **Product → Archive** (or **⌘⇧B** then Archive)
   - Watch the build log - you should see the post-action output

3. **Check the archive contents:**
   - **Window → Organizer**
   - Select your latest Gaze archive
   - Right-click → **Show in Finder**
   - Right-click the `.xcarchive` file → **Show Package Contents**
   - Navigate to: `Products/Applications/Gaze.app/Contents/Frameworks/`
   - **Verify:** Only `Lottie.framework` should be present ✅

4. **Distribute to App Store:**
   - In Organizer, click **Distribute App**
   - Choose **App Store Connect**
   - Complete the distribution wizard
   - **Validation should now pass!** ✅

---

## What You Should See

### In the Build Log (after archiving):
```
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
🗑️  Removing Sparkle from archived app...
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
📂 Found Sparkle at: [path]
✅ Sparkle framework removed successfully!
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
✅ Archive ready for App Store distribution
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
```

### In the Frameworks folder:
```
Gaze.app/Contents/Frameworks/
└── Lottie.framework/
```

No Sparkle.framework! ✅

---

## Troubleshooting

### "I don't see the post-action output"
- Make sure you selected **Gaze** in "Provide build settings from"
- Check View → Navigators → Show Report Navigator (⌘9)
- Select the Archive action to see full logs

### "Sparkle is still in the archive"
- Verify `./switch_to status` shows "App Store" for all items
- Check the script exactly matches (copy/paste the entire script)
- Try cleaning: Product → Clean Build Folder (⌘⇧K)

### "Script says 'Sparkle framework not found'"
- This means Sparkle wasn't embedded (good!)
- Continue with distribution - validation should pass

### "Archive Post-Action section doesn't exist"
- Make sure you're editing the **Archive** section, not Run or Test
- Click the triangle next to "Archive" to expand it

---

## Optional: Remove Old Build Phase Script

If you previously added a Build Phase script (which doesn't work due to file locking), you can remove it:

1. Gaze target → Build Phases
2. Find "Remove Sparkle for App Store" or "Run Script"
3. Click the **X** to delete it

The Archive Post-Action is the correct and only solution needed.

---

## Why This Is Required

Even though:
- ✅ Sparkle code is disabled via `#if !APPSTORE`
- ✅ Info.plist has no Sparkle keys
- ✅ Entitlements have no Sparkle exceptions

App Store validation **still checks** for the physical presence of unsandboxed executables in frameworks. Sparkle contains XPC services that aren't App Store compatible, so the entire framework must be removed.

---

## For Self-Distribution

When building for self-distribution (`./switch_to self`), the script detects the absence of the APPSTORE flag and leaves Sparkle intact. You don't need to change anything!

```bash
./switch_to self
./self_distribute  # Sparkle is retained and works normally
```

---

## Summary

✅ **One-time setup:** Add Archive Post-Action script  
✅ **Works automatically:** Removes Sparkle only for App Store builds  
✅ **Zero maintenance:** Once configured, runs automatically forever  

This is the **correct and only working solution** for removing Sparkle from App Store builds!
