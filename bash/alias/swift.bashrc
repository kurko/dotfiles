#!/bin/bash

function swift_compile_time() {
  if has-argument $1; then
    echo "Running xcodebuild with -debug-time-function-bodies for $1"
    xcodebuild -workspace $1.xcworkspace -scheme $1 clean build OTHER_SWIFT_FLAGS="-Xfrontend -debug-time-function-bodies" | grep [1-9].[0-9]ms | sort -nr > culprits.txt
  else
    echo "You need specify the name of the project (eg. AppName for AppName.xcworkspace)"
  fi
}
