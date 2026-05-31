#!/usr/bin/env bash
set -euo pipefail

# Use a project-scoped Gradle home so this build is isolated from
# machine-level ~/.gradle proxy settings.
PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
export GRADLE_USER_HOME="${PROJECT_ROOT}/.gradle-local"

echo "Using GRADLE_USER_HOME=${GRADLE_USER_HOME}"
flutter build appbundle --release "$@"
