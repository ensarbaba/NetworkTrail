#!/bin/bash
# Build phase of NetworkTrailMac: builds NetworkTrailDebug.framework for the iOS Simulator and puts it into
# NetworkTrail.app/Contents/Frameworks. The Simulator snippet loads the framework from there.
#
# The framework is always built in the Debug configuration: NetworkTrailSDK compiles its capture code only under DEBUG.
# `env -i` gives xcodebuild a clean environment, so the macOS settings of this build do not leak into the iOS build.
# A macOS app accepts only versioned framework bundles (Versions/A/...) in Contents/Frameworks, so the script moves
# the binary and Info.plist of the iOS framework into that layout and signs it with the identity of the app.
set -euo pipefail

name="NetworkTrailDebug"
build_dir="$TARGET_TEMP_DIR/${name}Build"
source="$build_dir/Build/Products/Debug-iphonesimulator/$name.framework"
framework="$TARGET_BUILD_DIR/$FRAMEWORKS_FOLDER_PATH/$name.framework"

env -i HOME="$HOME" PATH="$PATH" DEVELOPER_DIR="$DEVELOPER_DIR" xcodebuild \
    -project "$SRCROOT/../../$name/$name.xcodeproj" \
    -scheme "$name" \
    -configuration Debug \
    -destination "generic/platform=iOS Simulator" \
    -derivedDataPath "$build_dir" \
    -quiet \
    build

rm -rf "$framework"
mkdir -p "$framework/Versions/A/Resources"
ditto "$source/$name" "$framework/Versions/A/$name"
ditto "$source/Info.plist" "$framework/Versions/A/Resources/Info.plist"
ln -s A "$framework/Versions/Current"
ln -s "Versions/Current/$name" "$framework/$name"
ln -s Versions/Current/Resources "$framework/Resources"
codesign --force --sign "${EXPANDED_CODE_SIGN_IDENTITY:--}" --timestamp=none "$framework"
