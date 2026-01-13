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
    
    # Remove XCRemoteSwiftPackageReference section (multi-line)
    pattern = r'\t\t27SPARKLE\d+ /\* XCRemoteSwiftPackageReference "Sparkle" \*/ = \{\n.*?\n\t\t\};\n'
    content = re.sub(pattern, '', content, flags=re.DOTALL)
    
    # Remove XCSwiftPackageProductDependency section (multi-line)
    pattern = r'\t\t27SPARKLE\d+ /\* XCSwiftPackageProductDependency "Sparkle" \*/ = \{\n.*?\n\t\t\};\n'
    content = re.sub(pattern, '', content, flags=re.DOTALL)
    
    with open(pbxproj_path, 'w') as f:
        f.write(content)
    
    print("✓ Removed Sparkle references from project.pbxproj")
    return True


def add_sparkle(pbxproj_path):
    """Add Sparkle package to project.pbxproj"""
    with open(pbxproj_path, 'r') as f:
        content = f.read()
    
    # Check if Sparkle already exists
    if 'Sparkle' in content:
        print("ℹ Sparkle already in project")
        return True
    
    # 1. Add PBXBuildFile for Sparkle (after Lottie, before End section)
    pattern = r'(\t\t275915892F132A9200D0E60D /\* Lottie in Frameworks \*/ = \{isa = PBXBuildFile; productRef = 27AE10B12F10B1FC00E00DBC /\* Lottie \*/; \};\n)(/\* End PBXBuildFile section \*/)'
    replacement = r'\1\t\t' + BUILD_FILE_ID + r' /* Sparkle in Frameworks */ = {isa = PBXBuildFile; productRef = ' + PKG_PROD_ID + r' /* Sparkle */; };' + '\n' + r'\2'
    content = re.sub(pattern, replacement, content)
    
    # 2. Add Sparkle to Frameworks build phase (after Lottie)
    pattern = r'(\t\t\t\t275915892F132A9200D0E60D /\* Lottie in Frameworks \*/,\n)'
    replacement = r'\1\t\t\t\t' + BUILD_FILE_ID + r' /* Sparkle in Frameworks */,' + '\n'
    content = re.sub(pattern, replacement, content)
    
    # 3. Add Sparkle to packageProductDependencies (after Lottie)
    pattern = r'(packageProductDependencies = \(\n\t\t\t\t27AE10B12F10B1FC00E00DBC /\* Lottie \*/,\n)'
    replacement = r'\1\t\t\t\t' + PKG_PROD_ID + r' /* Sparkle */,' + '\n'
    content = re.sub(pattern, replacement, content)
    
    # 4. Add Sparkle to packageReferences (after Lottie)
    pattern = r'(packageReferences = \(\n\t\t\t\t27AE10B02F10B1FC00E00DBC /\* XCRemoteSwiftPackageReference "lottie-spm" \*/,\n)'
    replacement = r'\1\t\t\t\t' + PKG_REF_ID + r' /* XCRemoteSwiftPackageReference "Sparkle" */,' + '\n'
    content = re.sub(pattern, replacement, content)
    
    # 5. Add XCRemoteSwiftPackageReference section (before End section)
    sparkle_ref = f'''\t\t{PKG_REF_ID} /* XCRemoteSwiftPackageReference "Sparkle" */ = {{
\t\t\tisa = XCRemoteSwiftPackageReference;
\t\t\trepositoryURL = "{SPARKLE_REPO}";
\t\t\trequirement = {{
\t\t\t\tkind = exactVersion;
\t\t\t\tversion = {SPARKLE_VERSION};
\t\t\t}};
\t\t}};
'''
    pattern = r'(/\* End XCRemoteSwiftPackageReference section \*/)'
    replacement = sparkle_ref + r'\1'
    content = re.sub(pattern, replacement, content)
    
    # 6. Add XCSwiftPackageProductDependency section (before End section)
    sparkle_prod = f'''\t\t{PKG_PROD_ID} /* XCSwiftPackageProductDependency "Sparkle" */ = {{
\t\t\tisa = XCSwiftPackageProductDependency;
\t\t\tpackage = {PKG_REF_ID} /* XCRemoteSwiftPackageReference "Sparkle" */;
\t\t\tproductName = Sparkle;
\t\t}};
'''
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
