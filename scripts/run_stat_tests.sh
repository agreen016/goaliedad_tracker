#!/usr/bin/env bash
set -euo pipefail

# Runs only the focused stat coverage and edge-case tests.
# Usage: bash scripts/run_stat_tests.sh

echo "Running stat coverage tests..."
flutter test test/stat_coverage_test.dart test/stat_edgecases_test.dart --reporter=expanded

echo "Stat tests completed." 
