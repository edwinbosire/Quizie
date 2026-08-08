#!/bin/zsh

set -euo pipefail

PROJECT_ROOT="${0:A:h:h}"
PROJECT_PATH="$PROJECT_ROOT/Quizie.xcodeproj"
SCHEME="QuizieAppStoreScreenshots"
OUTPUT_DIR="$PROJECT_ROOT/artifacts/app-store-screenshots"
RUN_DIR="$(mktemp -d "${TMPDIR:-/tmp}/quizie-app-store-captures.XXXXXX")"
DERIVED_DATA="$RUN_DIR/DerivedData"

cleanup() {
    rm -rf "$RUN_DIR"
}
trap cleanup EXIT

SIMULATOR_ID="${SIMULATOR_ID:-$(
    xcrun simctl list devices available --json |
        jq -r '[.devices[][] | select(.name == "iPhone 17 Pro Max" and .isAvailable == true)] | last | .udid // empty'
)}"

if [[ -z "$SIMULATOR_ID" ]]; then
    print -u2 "No available iPhone 17 Pro Max Simulator was found."
    exit 1
fi

mkdir -p "$OUTPUT_DIR"
open -a Simulator
xcrun simctl boot "$SIMULATOR_ID" 2>/dev/null || true
xcrun simctl bootstatus "$SIMULATOR_ID" -b

print "Building $SCHEME for iPhone 17 Pro Max…"
xcodebuild \
    -project "$PROJECT_PATH" \
    -scheme "$SCHEME" \
    -destination "platform=iOS Simulator,id=$SIMULATOR_ID" \
    -derivedDataPath "$DERIVED_DATA" \
    -only-testing:QuizieUITests/HandbookReaderQuizUITests \
    build-for-testing

for APPEARANCE in light dark; do
    RESULT_BUNDLE="$RUN_DIR/$APPEARANCE.xcresult"
    ATTACHMENTS_DIR="$RUN_DIR/$APPEARANCE-attachments"
    TEST_NAME="testAppStoreScreenshots${(C)APPEARANCE}"

    print "Capturing $APPEARANCE mode…"
    xcrun simctl ui "$SIMULATOR_ID" appearance "$APPEARANCE"
    xcodebuild \
        -project "$PROJECT_PATH" \
        -scheme "$SCHEME" \
        -destination "platform=iOS Simulator,id=$SIMULATOR_ID" \
        -derivedDataPath "$DERIVED_DATA" \
        -resultBundlePath "$RESULT_BUNDLE" \
        -only-testing:"QuizieUITests/HandbookReaderQuizUITests/$TEST_NAME" \
        test-without-building

    mkdir -p "$ATTACHMENTS_DIR"
    xcrun xcresulttool export attachments \
        --path "$RESULT_BUNDLE" \
        --output-path "$ATTACHMENTS_DIR"

    jq -r '.[] | .attachments[] | select(.suggestedHumanReadableName | test("^[0-9]{2}-")) | [.exportedFileName, (.suggestedHumanReadableName | capture("^(?<name>[0-9]{2}-[a-z]+-(?:light|dark))").name)] | @tsv' \
        "$ATTACHMENTS_DIR/manifest.json" |
        while IFS=$'\t' read -r EXPORTED_FILE CAPTURE_NAME; do
            cp -f "$ATTACHMENTS_DIR/$EXPORTED_FILE" "$OUTPUT_DIR/$CAPTURE_NAME.png"
        done
done

print "Captured screenshots:"
find "$OUTPUT_DIR" -maxdepth 1 -type f -name '*.png' -print | sort
