#!/bin/bash

# Fast fail the script on failures.
set -e

dartanalyzer --fatal-warnings lib test

pub run test -p vm,chrome
# pub run test -p content-shell -j 1
# pub run test -p firefox -j 1 --reporter expanded