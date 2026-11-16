#!/bin/sh

set -eu

flutter build apk --release --split-per-abi
printf '\nAPK output: build/app/outputs/flutter-apk/\n'
