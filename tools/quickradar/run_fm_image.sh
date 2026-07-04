#!/bin/bash
# run_fm_image.sh — describe one or more images with Apple Foundation Models.
#
#   ./run_fm_image.sh <promptFile> <image1> [image2 ...]
#
# Wraps fm_image.swift, pinning the Xcode-beta toolchain + MacOSX27 SDK that
# ships the FoundationModels image-attachment API (the default toolchain lacks
# it). Prints the model's description to stdout.

set -e
DIR="$(cd "$(dirname "$0")" && pwd)"
BETA=/Applications/Xcode-beta.app/Contents/Developer
SDK="$BETA/Platforms/MacOSX.platform/Developer/SDKs/MacOSX27.sdk"

DEVELOPER_DIR="$BETA" swift -sdk "$SDK" "$DIR/fm_image.swift" "$@"
