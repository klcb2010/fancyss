#!/usr/bin/env bash

set -Eeuo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

PROJECT="klzgrad/naiveproxy"
API_URL="https://api.github.com/repos/${PROJECT}/releases/latest"
WORK_DIR="$(mktemp -d)"
trap 'rm -rf "$WORK_DIR"' EXIT

echo ">>> Query latest stable NaiveProxy release"
RELEASE_JSON="$WORK_DIR/release.json"
curl -fsSL --retry 3 --retry-delay 2 "$API_URL" -o "$RELEASE_JSON"

TAG="$(jq -er '.tag_name | select(type == "string" and startswith("v"))' "$RELEASE_JSON")"
LATEST_VERSION="${TAG#v}"
RELEASE_DIR="$SCRIPT_DIR/v${LATEST_VERSION}"
STAGE_DIR="$WORK_DIR/stage"
mkdir -p "$STAGE_DIR" "$RELEASE_DIR"

echo ">>> NaiveProxy release: $TAG"

download_binary() {
    local arch="$1"
    local openwrt_arch="$2"
    local upx_bin="$3"
    local asset="naiveproxy-${TAG}-openwrt-${openwrt_arch}.tar.xz"
    local url digest archive extract_dir binary backup listing member

    url="$(jq -er --arg name "$asset" '.assets[] | select(.name == $name) | .browser_download_url' "$RELEASE_JSON")"
    digest="$(jq -er --arg name "$asset" '.assets[] | select(.name == $name) | .digest // empty' "$RELEASE_JSON")"

    case "$digest" in
        sha256:*) digest="${digest#sha256:}" ;;
        *) echo "ERROR: missing SHA-256 digest for $asset"; return 1 ;;
    esac

    archive="$WORK_DIR/$asset"
    extract_dir="$WORK_DIR/extract-$arch"
    mkdir -p "$extract_dir"

    echo ">>> Download $asset"
    curl -fL --retry 3 --retry-delay 2 "$url" -o "$archive"

    echo "$digest  $archive" | sha256sum -c -

    listing="$WORK_DIR/archive-$arch.list"
    tar -tJf "$archive" > "$listing"
    member="$(awk '$NF == "naive" { print; exit }' "$listing")"
    if [ -z "$member" ]; then
        echo "ERROR: archive has no naive executable: $asset"
        return 1
    fi
    tar -xJf "$archive" -C "$extract_dir" "$member"
    binary="$(find "$extract_dir" -type f -name naive -print -quit)"
    if [ -z "$binary" ] || [ ! -s "$binary" ]; then
        echo "ERROR: archive does not contain a valid naive binary: $asset"
        return 1
    fi

    install -m 755 "$binary" "$STAGE_DIR/naive_$arch"

    # UPX is optional. Keep the verified upstream executable if the matching
    # packer is unavailable or cannot safely compress this architecture.
    if command -v "$upx_bin" >/dev/null 2>&1; then
        backup="$STAGE_DIR/naive_$arch.uncompressed"
        cp -f "$STAGE_DIR/naive_$arch" "$backup"
        if "$upx_bin" --lzma --ultra-brute "$STAGE_DIR/naive_$arch"; then
            rm -f "$backup"
        else
            echo "WARNING: UPX failed for $arch; restoring the original binary."
            mv -f "$backup" "$STAGE_DIR/naive_$arch"
        fi
    else
        echo "WARNING: $upx_bin unavailable; keeping uncompressed $arch binary."
    fi

    rm -f "$archive"
}

# Match each firmware family to the correct upstream OpenWrt target:
# ARMv8 -> Cortex-A53 static; ARMv7 -> Cortex-A9 static;
# ARMv5TE soft-float -> ARM926EJ-S (not Cortex-A9).
download_binary arm64 aarch64_cortex-a53-static upx-5.0.2
download_binary armv7 arm_cortex-a9-static upx-5.0.2
download_binary armv5 arm_arm926ej-s upx-4.2.4

for arch in arm64 armv7 armv5; do
    if [ ! -s "$STAGE_DIR/naive_$arch" ]; then
        echo "ERROR: missing staged NaiveProxy binary for $arch"
        exit 1
    fi
done

for arch in arm64 armv7 armv5; do
    install -m 755 "$STAGE_DIR/naive_$arch" "$RELEASE_DIR/naive_$arch"
done

(
    cd "$RELEASE_DIR"
    rm -f md5sum.txt
    md5sum naive_arm64 naive_armv7 naive_armv5 > md5sum.txt
    md5sum -c md5sum.txt
)

printf '%s' "$TAG" > "$SCRIPT_DIR/latest.txt"
echo ">>> NaiveProxy $TAG binaries are ready."
