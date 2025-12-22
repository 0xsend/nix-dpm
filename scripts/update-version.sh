#!/usr/bin/env bash
set -euo pipefail

# Update dpm-sources.json with the latest version and hashes
# Usage: ./scripts/update-version.sh [version]
# If no version is provided, fetches the latest from Digital Asset

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(dirname "$SCRIPT_DIR")"
SOURCES_FILE="$REPO_ROOT/dpm-sources.json"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

log_info() { echo -e "${GREEN}[INFO]${NC} $1"; }
log_warn() { echo -e "${YELLOW}[WARN]${NC} $1"; }
log_error() { echo -e "${RED}[ERROR]${NC} $1"; }

# Get current version from sources file
get_current_version() {
    if [[ -f "$SOURCES_FILE" ]]; then
        jq -r '.version' "$SOURCES_FILE"
    else
        echo ""
    fi
}

# Get latest version from Digital Asset
get_latest_version() {
    curl -sS "https://get.digitalasset.com/install/latest"
}

# Compute SHA256 hash for a platform
compute_hash() {
    local version="$1"
    local platform="$2"
    local tarball="dpm-${version}-${platform}.tar.gz"
    local url="https://artifactregistry.googleapis.com/download/v1/projects/da-images/locations/europe/repositories/public-generic/files/dpm-sdk:${version}:${tarball}:download?alt=media"

    log_info "Downloading ${platform}..."
    local hash
    hash=$(curl -SLf "$url" 2>/dev/null | shasum -a 256 | awk '{print $1}')

    if [[ -z "$hash" || "$hash" == "e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855" ]]; then
        log_error "Failed to download or empty file for ${platform}"
        return 1
    fi

    echo "$hash"
}

# Update the sources file with new version and hashes
update_sources() {
    local version="$1"

    log_info "Computing hashes for version ${version}..."

    local darwin_arm64 darwin_amd64 linux_amd64 linux_arm64

    darwin_arm64=$(compute_hash "$version" "darwin-arm64") || exit 1
    darwin_amd64=$(compute_hash "$version" "darwin-amd64") || exit 1
    linux_amd64=$(compute_hash "$version" "linux-amd64") || exit 1
    linux_arm64=$(compute_hash "$version" "linux-arm64") || exit 1

    log_info "Writing ${SOURCES_FILE}..."

    cat > "$SOURCES_FILE" << EOF
{
  "version": "${version}",
  "hashes": {
    "darwin-arm64": "sha256:${darwin_arm64}",
    "darwin-amd64": "sha256:${darwin_amd64}",
    "linux-amd64": "sha256:${linux_amd64}",
    "linux-arm64": "sha256:${linux_arm64}"
  }
}
EOF

    log_info "Updated to version ${version}"
}

main() {
    local target_version="${1:-}"
    local current_version
    local latest_version

    current_version=$(get_current_version)

    if [[ -z "$target_version" ]]; then
        log_info "Checking for latest version..."
        target_version=$(get_latest_version)
    fi

    log_info "Current version: ${current_version:-none}"
    log_info "Target version:  ${target_version}"

    if [[ "$current_version" == "$target_version" ]]; then
        log_info "Already at version ${target_version}, no update needed"
        echo "updated=false" >> "${GITHUB_OUTPUT:-/dev/null}"
        exit 0
    fi

    update_sources "$target_version"

    # Output for GitHub Actions
    echo "updated=true" >> "${GITHUB_OUTPUT:-/dev/null}"
    echo "version=${target_version}" >> "${GITHUB_OUTPUT:-/dev/null}"
    echo "previous_version=${current_version}" >> "${GITHUB_OUTPUT:-/dev/null}"

    log_info "Successfully updated from ${current_version:-none} to ${target_version}"
}

main "$@"
