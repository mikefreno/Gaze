#!/bin/bash

# Gaze Appcast Hosting Validation Script
# Tests that all hosting infrastructure is properly configured

set -e

echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "Gaze Appcast Hosting Validation"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

# Configuration
APPCAST_URL="https://freno.me/api/Gaze/appcast.xml"
DMG_URL="https://freno.me/downloads/Gaze-0.1.1.dmg"

# Test 1: Appcast Accessibility
echo "📋 Test 1: Appcast Accessibility"
echo "Testing: $APPCAST_URL"
APPCAST_STATUS=$(curl -s -o /dev/null -w "%{http_code}" "$APPCAST_URL")

if [ "$APPCAST_STATUS" = "200" ]; then
    echo "✅ Appcast is accessible (HTTP 200)"
    
    # Test content type
    CONTENT_TYPE=$(curl -s -I "$APPCAST_URL" | grep -i "content-type" | awk '{print $2}' | tr -d '\r')
    if [[ "$CONTENT_TYPE" == *"xml"* ]] || [[ "$CONTENT_TYPE" == *"text"* ]]; then
        echo "✅ Content-Type is correct: $CONTENT_TYPE"
    else
        echo "⚠️  Warning: Content-Type might be incorrect: $CONTENT_TYPE"
        echo "   Expected: application/xml or text/xml"
    fi
    
    # Test HTTPS
    if [[ "$APPCAST_URL" == https://* ]]; then
        echo "✅ Using HTTPS (required by App Transport Security)"
    else
        echo "❌ NOT using HTTPS - this will fail on macOS!"
    fi
    
    # Validate XML structure
    echo ""
    echo "Validating XML structure..."
    APPCAST_CONTENT=$(curl -s "$APPCAST_URL")
    
    if echo "$APPCAST_CONTENT" | xmllint --noout - 2>/dev/null; then
        echo "✅ XML is well-formed"
    else
        echo "❌ XML is malformed"
        exit 1
    fi
    
    # Check for required Sparkle elements
    if echo "$APPCAST_CONTENT" | grep -q "sparkle:version"; then
        echo "✅ Contains sparkle:version"
    else
        echo "❌ Missing sparkle:version"
    fi
    
    if echo "$APPCAST_CONTENT" | grep -q "sparkle:shortVersionString"; then
        echo "✅ Contains sparkle:shortVersionString"
    else
        echo "❌ Missing sparkle:shortVersionString"
    fi
    
    if echo "$APPCAST_CONTENT" | grep -q "sparkle:edSignature"; then
        echo "✅ Contains sparkle:edSignature"
    else
        echo "⚠️  Warning: Missing sparkle:edSignature (required for updates)"
    fi
    
elif [ "$APPCAST_STATUS" = "404" ]; then
    echo "⚠️  Appcast not found (HTTP 404)"
    echo "   This is expected before first deployment"
    echo "   Run ./build_dmg and upload appcast.xml to proceed"
else
    echo "❌ Unexpected status: HTTP $APPCAST_STATUS"
    exit 1
fi

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

# Test 2: DMG Accessibility
echo "📦 Test 2: DMG Accessibility"
echo "Testing: $DMG_URL"
DMG_STATUS=$(curl -s -o /dev/null -w "%{http_code}" "$DMG_URL")

if [ "$DMG_STATUS" = "200" ]; then
    echo "✅ DMG is accessible (HTTP 200)"
    
    # Get file size
    DMG_SIZE=$(curl -s -I "$DMG_URL" | grep -i "content-length" | awk '{print $2}' | tr -d '\r')
    if [ -n "$DMG_SIZE" ]; then
        DMG_SIZE_MB=$(echo "scale=2; $DMG_SIZE / 1024 / 1024" | bc)
        echo "✅ DMG size: ${DMG_SIZE_MB} MB (${DMG_SIZE} bytes)"
    fi
    
    # Test HTTPS
    if [[ "$DMG_URL" == https://* ]]; then
        echo "✅ Using HTTPS"
    else
        echo "⚠️  Not using HTTPS"
    fi
    
elif [ "$DMG_STATUS" = "404" ]; then
    echo "⚠️  DMG not found (HTTP 404)"
    echo "   This is expected before first release"
    echo "   Run ./build_dmg and upload DMG to proceed"
else
    echo "❌ Unexpected status: HTTP $DMG_STATUS"
fi

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

# Test 3: Local Infrastructure
echo "🔧 Test 3: Local Infrastructure"

# Check releases directory
if [ -d "./releases" ]; then
    echo "✅ Releases directory exists"
    
    if [ -f "./releases/appcast-template.xml" ]; then
        echo "✅ Appcast template exists"
    else
        echo "⚠️  Appcast template not found"
    fi
else
    echo "❌ Releases directory not found"
    exit 1
fi

# Check build_dmg script
if [ -f "./build_dmg" ]; then
    echo "✅ build_dmg script exists"
    
    if [ -x "./build_dmg" ]; then
        echo "✅ build_dmg is executable"
    else
        echo "⚠️  build_dmg is not executable (run: chmod +x ./build_dmg)"
    fi
else
    echo "❌ build_dmg script not found"
    exit 1
fi

# Check for Sparkle keys (Keychain or backup file)
KEY_IN_KEYCHAIN=false
KEY_IN_FILE=false

if security find-generic-password -l "Sparkle EdDSA Private Key" >/dev/null 2>&1; then
    KEY_IN_KEYCHAIN=true
fi

if [ -f "$HOME/sparkle_private_key_backup.pem" ]; then
    KEY_IN_FILE=true
fi

if [ "$KEY_IN_KEYCHAIN" = true ]; then
    echo "✅ Sparkle EdDSA private key found in Keychain"
elif [ "$KEY_IN_FILE" = true ]; then
    echo "✅ Sparkle EdDSA private key found in backup file"
    echo "   (~/sparkle_private_key_backup.pem)"
else
    echo "❌ Sparkle EdDSA private key not found"
    echo "   Run: ./generate_keys (from Sparkle tools)"
fi

# Check Info.plist configuration
if [ -f "./Gaze/Info.plist" ]; then
    echo "✅ Info.plist exists"
    
    if grep -q "SUFeedURL" "./Gaze/Info.plist"; then
        FEED_URL=$(grep -A 1 "SUFeedURL" "./Gaze/Info.plist" | tail -1 | sed 's/.*<string>\(.*\)<\/string>.*/\1/' | tr -d '\t ')
        echo "✅ SUFeedURL configured: $FEED_URL"
    else
        echo "❌ SUFeedURL not found in Info.plist"
    fi
    
    if grep -q "SUPublicEDKey" "./Gaze/Info.plist"; then
        echo "✅ SUPublicEDKey configured"
    else
        echo "❌ SUPublicEDKey not found in Info.plist"
    fi
else
    echo "❌ Info.plist not found"
fi

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

# Summary
echo "📊 Summary"
echo ""

if [ "$APPCAST_STATUS" = "200" ] && [ "$DMG_STATUS" = "200" ]; then
    echo "✅ Hosting is fully operational"
    echo "   Ready for production updates"
elif [ "$APPCAST_STATUS" = "404" ] || [ "$DMG_STATUS" = "404" ]; then
    echo "⚠️  Hosting partially configured"
    echo "   Next steps:"
    echo "   1. Build the app (./run build)"
    echo "   2. Create DMG and appcast (./build_dmg)"
    echo "   3. Upload files to hosting"
    echo "   4. Run this script again to verify"
else
    echo "❌ Hosting has issues - see errors above"
    exit 1
fi

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
