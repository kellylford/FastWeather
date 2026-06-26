#!/bin/bash
# run_test_prompt.sh — Run the prompt test tool against pulled iPhone images
#
# Usage:
#   ./run_test_prompt.sh                    # all images in /tmp/radar_images
#   ./run_test_prompt.sh /path/to/images    # different image dir
#   ./run_test_prompt.sh /path/to/images Madison   # filter to one city
#
# Pull images from phone first:
#   xcrun devicectl device copy from --device "Kelly Ford" \
#     --domain-type appDataContainer \
#     --domain-identifier com.weatherfast.app \
#     --source Documents/radar_images \
#     --destination /tmp/radar_images

set -e
DIR="$(cd "$(dirname "$0")" && pwd)"

DEVELOPER_DIR=/Applications/Xcode-beta.app/Contents/Developer \
swift \
  -sdk /Applications/Xcode-beta.app/Contents/Developer/Platforms/MacOSX.platform/Developer/SDKs/MacOSX27.sdk \
  "$DIR/test_prompt.swift" "$@"
