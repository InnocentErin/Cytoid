#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TAG="${GITHUB_REF_NAME:-}"

if [[ -z "$TAG" && -n "${GITHUB_REF:-}" ]]; then
  TAG="${GITHUB_REF#refs/tags/}"
fi

VERSION="${TAG#v}"
if [[ -z "$VERSION" || "$VERSION" == "$TAG" ]]; then
  echo "Not on a v* release tag; leaving pubspec.yaml unchanged."
  exit 0
fi

if [[ ! "$VERSION" =~ ^[0-9]+\.[0-9]+\.[0-9]+([+-][A-Za-z0-9._-]+)?$ ]]; then
  echo "Refusing to sync invalid release version: $VERSION" >&2
  exit 2
fi

perl -0pi -e "s/^version:\\s*.*$/version: $VERSION/m" "$ROOT_DIR/pubspec.yaml"
echo "Synced flutter_plugin/pubspec.yaml to $VERSION"
