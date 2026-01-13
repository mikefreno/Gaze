#!/usr/bin/env python3
"""
Safely add or remove Sparkle package from Xcode project
"""
import sys
import re

SPARKLE_REPO = "https://github.com/sparkle-project/Sparkle"
SPARKLE_VERSION = "2.8.1"

# Consistent IDs for Sparkle references
PKG_REF_ID = "27SPARKLE00000000001"
PKG_PROD_ID = "27SPARKLE00000000002"
BUILD_FILE_ID = "27SPARKLE00000000003"


def remove_sparkle(pbxproj_path):
    """Remove all Sparkle references from project.pbxproj"""
    with open(pbxproj_path, 'r') as f:
        content = f.read()
    
    # Remove Sparkle from packageReferences array
    content = re.sub(r'\t\t\t\t27SPARKLE\d+ /\* XCRemoteSwiftPackageReference "Sparkle" \*/,\n', '', content)
    
    # Remove Sparkle from packageProductDependencies array
    content = re.sub(r'\t\t\t\t27SPARKLE\d+ /\* Sparkle \*/,\n', '', content)
    
    # Remove Sparkle from Frameworks build phase
    content = re.sub(r'\t\t\t\t27SPARKLE\d+ /\* Sparkle in Frameworks \*/,\n', '', content)
    
    # Remove PBXBuildFile section for Sparkle
    content = re.sub(r'\t\t27SPARKLE\d+ /\* Sparkle in Frameworks \*/ = \{isa = PBXBuildFile; productRef = 27SPARKLE\d+ /\* Sparkle \*/; \};\n', '', content)
    
    # Remove XCRemoteSwiftPackageReference section (multi-line) - more flexible pattern
    pattern = r'\t\t27SPARKLE\d+ /\* XCRemoteSwiftPackageReference "Sparkle" \*/ = \{[^}]+\};\n'
    content = re.sub(pattern, '', content, flags=re.DOTALL)
    
    # Remove XCSwiftPackageProductDependency section (multi-line) - match "Sparkle" comment not "XCSwiftPackageProductDependency"
    pattern = r'\t\t27SPARKLE\d+ /\* Sparkle \*/ = \{[^}]+\};\n'
    content = re.sub(pattern, '', content, flags=re.DOTALL)
    
    with open(pbxproj_path, 'w') as f:
        f.write(content)
    
    print("✓ Removed Sparkle references from project.pbxproj")
    return True


def add_sparkle(pbxproj_path):
    """Add Sparkle package to project.pbxproj"""
    with open(pbxproj_path, 'r') as f:
        content = f.read()
    
    # Check if Sparkle package reference already fully exists (should have 9 references like Lottie)
    sparkle_count = content.count('Sparkle')
    if sparkle_count >= 9 and f'{PKG_REF_ID} /* XCRemoteSwiftPackageReference "Sparkle" */ =' in content:
        print("ℹ Sparkle already fully configured in project")
        return True
    
    # Check if partial Sparkle exists and clean it up first
    if 'Sparkle' in content:
        print("ℹ Cleaning up partial Sparkle references...")
        content = re.sub(r'\t\t27SPARKLE\d+ /\* XCRemoteSwiftPackageReference "Sparkle" \*/,\n', '', content)
        content = re.sub(r'\t\t\t\t27SPARKLE\d+ /\* Sparkle \*/,\n', '', content)
        content = re.sub(r'\t\t\t\t27SPARKLE\d+ /\* Sparkle in Frameworks \*/,\n', '', content)
        content = re.sub(r'\t\t27SPARKLE\d+ /\* Sparkle in Frameworks \*/ = \{isa = PBXBuildFile; productRef = 27SPARKLE\d+ /\* Sparkle \*/; \};\n', '', content)
        pattern = r'\t\t27SPARKLE\d+ /\* XCRemoteSwiftPackageReference "Sparkle" \*/ = \{[^}]+\};\n'
        content = re.sub(pattern, '', content, flags=re.DOTALL)
        pattern = r'\t\t27SPARKLE\d+ /\* Sparkle \*/ = \{[^}]+\};\n'
        content = re.sub(pattern, '', content, flags=re.DOTALL)
        # Write cleaned content back
        with open(pbxproj_path, 'w') as f:
            f.write(content)
        print("✓ Cleaned up partial Sparkle references")
        # Re-read for adding fresh references
        with open(pbxproj_path, 'r') as f:
            content = f.read()
    
    # 1. Add PBXBuildFile for Sparkle (after Lottie, before End section)
    pattern = r'(\t\t275915892F132A9200D0E60D /\* Lottie in Frameworks \*/ = \{isa = PBXBuildFile; productRef = 27AE10B12F10B1FC00E00DBC /\* Lottie \*/; \};\n)(/\* End PBXBuildFile section \*/)'
    if re.search(pattern, content):
        replacement = r'\1\t\t' + BUILD_FILE_ID + r' /* Sparkle in Frameworks */ = {isa = PBXBuildFile; productRef = ' + PKG_PROD_ID + r' /* Sparkle */; };' + '\n' + r'\2'
        content = re.sub(pattern, replacement, content)
    else:
        print("⚠ Warning: Could not find PBXBuildFile insertion point")
    
    # 2. Add Sparkle to Frameworks build phase (after Lottie)
    pattern = r'(\t\t\t\t275915892F132A9200D0E60D /\* Lottie in Frameworks \*/,\n)'
    if re.search(pattern, content):
        replacement = r'\1\t\t\t\t' + BUILD_FILE_ID + r' /* Sparkle in Frameworks */,' + '\n'
        content = re.sub(pattern, replacement, content)
    else:
        print("⚠ Warning: Could not find Frameworks build phase insertion point")
    
    # 3. Add Sparkle to packageProductDependencies (after Lottie)
    pattern = r'(packageProductDependencies = \(\n\t\t\t\t27AE10B12F10B1FC00E00DBC /\* Lottie \*/,\n)'
    if re.search(pattern, content):
        replacement = r'\1\t\t\t\t' + PKG_PROD_ID + r' /* Sparkle */,' + '\n'
        content = re.sub(pattern, replacement, content)
    else:
        print("⚠ Warning: Could not find packageProductDependencies insertion point")
    
    # 4. Add Sparkle to packageReferences (after Lottie)
    pattern = r'(packageReferences = \(\n\t\t\t\t27AE10B02F10B1FC00E00DBC /\* XCRemoteSwiftPackageReference "lottie-spm" \*/,\n)'
    if re.search(pattern, content):
        replacement = r'\1\t\t\t\t' + PKG_REF_ID + r' /* XCRemoteSwiftPackageReference "Sparkle" */,' + '\n'
        content = re.sub(pattern, replacement, content)
    else:
        print("⚠ Warning: Could not find packageReferences insertion point")
    
    # 5. Add XCRemoteSwiftPackageReference section (after Lottie entry, before End section)
    sparkle_ref = f'''\t\t{PKG_REF_ID} /* XCRemoteSwiftPackageReference "Sparkle" */ = {{
\t\t\tisa = XCRemoteSwiftPackageReference;
\t\t\trepositoryURL = "{SPARKLE_REPO}";
\t\t\trequirement = {{
\t\t\t\tkind = exactVersion;
\t\t\t\tversion = {SPARKLE_VERSION};
\t\t\t}};
\t\t}};
'''
    # Insert after the Lottie package reference
    pattern = r'(\t\t27AE10B02F10B1FC00E00DBC /\* XCRemoteSwiftPackageReference "lottie-spm" \*/ = \{\n\t\t\tisa = XCRemoteSwiftPackageReference;\n\t\t\trepositoryURL = "https://github\.com/airbnb/lottie-spm\.git";\n\t\t\trequirement = \{\n\t\t\t\tkind = upToNextMajorVersion;\n\t\t\t\tminimumVersion = [^;]+;\n\t\t\t\};\n\t\t\};\n)'
    if re.search(pattern, content):
        replacement = r'\1' + sparkle_ref
        content = re.sub(pattern, replacement, content)
    else:
        print("⚠ Warning: Could not find XCRemoteSwiftPackageReference insertion point, trying fallback")
        # Fallback: insert before End section
        pattern = r'(/\* End XCRemoteSwiftPackageReference section \*/)'
        replacement = sparkle_ref + r'\1'
        content = re.sub(pattern, replacement, content)
    
    # 6. Add XCSwiftPackageProductDependency section (after Lottie entry, before End section)
    sparkle_prod = f'''\t\t{PKG_PROD_ID} /* Sparkle */ = {{
\t\t\tisa = XCSwiftPackageProductDependency;
\t\t\tpackage = {PKG_REF_ID} /* XCRemoteSwiftPackageReference "Sparkle" */;
\t\t\tproductName = Sparkle;
\t\t}};
'''
    # Insert after the Lottie product dependency
    pattern = r'(\t\t27AE10B12F10B1FC00E00DBC /\* Lottie \*/ = \{\n\t\t\tisa = XCSwiftPackageProductDependency;\n\t\t\tpackage = 27AE10B02F10B1FC00E00DBC /\* XCRemoteSwiftPackageReference "lottie-spm" \*/;\n\t\t\tproductName = Lottie;\n\t\t\};\n)'
    if re.search(pattern, content):
        replacement = r'\1' + sparkle_prod
        content = re.sub(pattern, replacement, content)
    else:
        print("⚠ Warning: Could not find XCSwiftPackageProductDependency insertion point, trying fallback")
        # Fallback: insert before End section
        pattern = r'(/\* End XCSwiftPackageProductDependency section \*/)'
        replacement = sparkle_prod + r'\1'
        content = re.sub(pattern, replacement, content)
    
    with open(pbxproj_path, 'w') as f:
        f.write(content)
    
    print("✓ Added Sparkle references to project.pbxproj")
    return True


if __name__ == '__main__':
    if len(sys.argv) != 3:
        print("Usage: .manage_sparkle.py [add|remove] <path/to/project.pbxproj>")
        sys.exit(1)
    
    action = sys.argv[1]
    pbxproj_path = sys.argv[2]
    
    try:
        if action == 'add':
            success = add_sparkle(pbxproj_path)
        elif action == 'remove':
            success = remove_sparkle(pbxproj_path)
        else:
            print(f"Unknown action: {action}")
            sys.exit(1)
        
        sys.exit(0 if success else 1)
    except Exception as e:
        print(f"Error: {e}", file=sys.stderr)
        sys.exit(1)
