#!/bin/bash

function xcode_test() {
  if has-argument $1; then
    echo "Running xcodebuild test for $1"
    xcodebuild test -workspace $1.xcworkspace -scheme $1 -destination 'platform=iOS Simulator,name=iPhone 6,OS=9.3'
  else
    echo "You need specify the name of the project (eg. AppName for AppName.xcworkspace)"
  fi
}
