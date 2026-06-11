# RemindMe Release Guide

Follow these steps to build, package, and publish a new release of RemindMe.

## 1. Update the Version
Before running the build script, update the version number and build number inside the `build_dmg.sh` Info.plist generation template.

- **File**: `build_dmg.sh`
- **Lines to modify**:
  ```xml
    <key>CFBundleShortVersionString</key>
    <string>2.1.0</string> <!-- Set new version tag here -->
    <key>CFBundleVersion</key>
    <string>3</string>       <!-- Increment build number here -->
  ```

## 2. Commit the Version Bump
Commit the changes to the Git repository and push them to the main branch:
```bash
git add build_dmg.sh
git commit -m "chore: bump version to v2.1.0"
git push origin main
```

## 3. Run the Build Script
Run the automated build script to compile the application and package separate binaries for both **Apple Silicon** (`arm64`) and **Intel Mac** (`x86_64`) architectures. This script compiles the source code, signs the binaries, packages them into DMG/ZIP archives, and handles Apple notarization/stapling:
```bash
./build_dmg.sh
```
This generates the following release assets in the repository root:
- `RemindMe_Silicon.dmg` & `RemindMe_Silicon.zip` (For Apple Silicon)
- `RemindMe_Intel.dmg` & `RemindMe_Intel.zip` (For Intel Macs)

## 4. Tag the Version
Tag the commit in Git and push it to GitHub:
```bash
git tag v2.1.0
git push origin v2.1.0
```

## 5. Create the GitHub Release
Use the GitHub CLI (`gh`) to publish the release and attach the four built assets.

### For a Production Release:
```bash
gh release create v2.1.0 \
  --title "RemindMe v2.1.0" \
  --notes "Summary of changes and features in this release..." \
  RemindMe_Silicon.dmg RemindMe_Silicon.zip RemindMe_Intel.dmg RemindMe_Intel.zip
```

### For a Pre-release (Beta/Alpha):
```bash
gh release create v2.1.0 \
  --prerelease \
  --title "RemindMe v2.1.0 (Pre-release)" \
  --notes "Release notes detailing new beta features..." \
  RemindMe_Silicon.dmg RemindMe_Silicon.zip RemindMe_Intel.dmg RemindMe_Intel.zip
```
