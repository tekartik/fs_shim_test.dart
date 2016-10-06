#!/bin/bash

# Fast fail the script on failures.
set -e

dartanalyzer --fatal-warnings \
  lib/context.dart \
  lib/context_io.dart \
  lib/test.dart \
  lib/test_io.dart \

pub run test -p vm,chrome
# pub run test -p content-shell -j 1
# pub run test -p firefox -j 1 --reporter expanded