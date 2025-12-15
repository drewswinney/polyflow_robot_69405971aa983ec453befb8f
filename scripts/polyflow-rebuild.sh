#!/usr/bin/env bash
set -euo pipefail

# Load configuration from metadata.json
METADATA_FILE="/var/lib/polyflow/metadata.json"
if [ -f "$METADATA_FILE" ]; then
  echo "[polyflow-rebuild] Loading configuration from $METADATA_FILE" >&2

  # Use jq to parse JSON
  GITHUB_USER=$(jq -r '.GITHUB_USER // ""' "$METADATA_FILE")
  ROBOT_ID=$(jq -r '.ROBOT_ID // ""' "$METADATA_FILE")

  # Export for flake.nix to pick up
  export GITHUB_USER
  export ROBOT_ID
else
  echo "[polyflow-rebuild] metadata.json not found at $METADATA_FILE, using build-time values" >&2
  GITHUB_USER="@githubUser@"
  ROBOT_ID="@hostname@"
fi

# Fallback to build-time template values if not set
if [ -z "$GITHUB_USER" ]; then
  GITHUB_USER="@githubUser@"
fi

if [ -z "$ROBOT_ID" ]; then
  ROBOT_ID="@hostname@"
  if [ -z "$ROBOT_ID" ]; then
    ROBOT_ID="$(hostname)"
  fi
fi

# Validate values
if [ -z "$GITHUB_USER" ]; then
  echo "[polyflow-rebuild] GitHub user not configured" >&2
  exit 1
fi

if printf '%s' "$GITHUB_USER" | grep -qE '[[:space:]]'; then
  echo "[polyflow-rebuild] Rejecting GitHub user with whitespace" >&2
  exit 1
fi

if [ -z "$ROBOT_ID" ]; then
  echo "[polyflow-rebuild] Robot ID not configured" >&2
  exit 1
fi

if printf '%s' "$ROBOT_ID" | grep -qE '[[:space:]]'; then
  echo "[polyflow-rebuild] Rejecting robot id with whitespace" >&2
  exit 1
fi

GITHUB_REPO="polyflow_robot_${ROBOT_ID}"
WORK_DIR="/tmp/polyflow-rebuild"
REPO_DIR="$WORK_DIR/$GITHUB_REPO"

echo "[polyflow-rebuild] Fetching latest from github:${GITHUB_USER}/${GITHUB_REPO}" >&2

# Clean up any previous checkout
rm -rf "$WORK_DIR"
mkdir -p "$WORK_DIR"

# Clone the repository (shallow clone for speed)
if ! git clone --depth 1 "https://github.com/${GITHUB_USER}/${GITHUB_REPO}.git" "$REPO_DIR"; then
  echo "[polyflow-rebuild] Failed to clone repository" >&2
  exit 1
fi

cd "$REPO_DIR"

echo "[polyflow-rebuild] Building from local checkout with ROBOT_ID=$ROBOT_ID, GITHUB_USER=$GITHUB_USER" >&2

# Rebuild from local flake (environment variables are now accessible)
# Add -L to show build logs in real-time
exec nixos-rebuild switch --flake ".#rpi4" -L
