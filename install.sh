#!/bin/sh
# SiteMills CLI installer for macOS and Linux.
#
#   curl -fsSL https://raw.githubusercontent.com/SiteMills/sitemills-cli/main/install.sh | sh
#
# Environment variables:
#   SITEMILLS_VERSION      Install a specific version (e.g. 1.0.2). Default: latest release.
#   SITEMILLS_INSTALL_DIR  Directory to install into. Default: /usr/local/bin if writable
#                          without sudo, otherwise ~/.local/bin.
set -eu

REPO="SiteMills/sitemills-cli"
BIN_NAME="sitemills-cli"

fail() {
    echo "error: $*" >&2
    exit 1
}

need() {
    command -v "$1" >/dev/null 2>&1 || fail "'$1' is required but was not found."
}

need uname
need chmod
need mkdir
need mv

if command -v curl >/dev/null 2>&1; then
    download() { curl -fsSL "$1" -o "$2"; }
elif command -v wget >/dev/null 2>&1; then
    download() { wget -q "$1" -O "$2"; }
else
    fail "curl or wget is required."
fi

os="$(uname -s)"
arch="$(uname -m)"
case "$os" in
    Linux)
        case "$arch" in
            x86_64|amd64) asset="sitemills-linux" ;;
            *) fail "Linux on '$arch' is not supported yet (x86_64 only)." ;;
        esac
        ;;
    Darwin)
        # A shell running under Rosetta reports x86_64; still install the native build.
        if [ "$arch" = "arm64" ] || [ "$(sysctl -n sysctl.proc_translated 2>/dev/null)" = "1" ]; then
            asset="sitemills-macos-arm64"
        else
            asset="sitemills-macos"
        fi
        ;;
    *)
        fail "Unsupported OS '$os'. On Windows, use install.ps1 (see the README)."
        ;;
esac

if [ -n "${SITEMILLS_VERSION:-}" ]; then
    version="${SITEMILLS_VERSION#v}"
    base_url="https://github.com/$REPO/releases/download/v$version"
else
    base_url="https://github.com/$REPO/releases/latest/download"
fi

if [ -n "${SITEMILLS_INSTALL_DIR:-}" ]; then
    install_dir="$SITEMILLS_INSTALL_DIR"
elif [ -d /usr/local/bin ] && [ -w /usr/local/bin ]; then
    install_dir="/usr/local/bin"
else
    install_dir="$HOME/.local/bin"
fi
mkdir -p "$install_dir"

tmp_dir="$(mktemp -d 2>/dev/null || mktemp -d -t sitemills)"
trap 'rm -rf "$tmp_dir"' EXIT INT TERM

echo "Downloading $asset from $base_url ..."
download "$base_url/$asset" "$tmp_dir/$asset" || fail "download failed: $base_url/$asset"
download "$base_url/SHA256SUMS" "$tmp_dir/SHA256SUMS" || fail "download failed: $base_url/SHA256SUMS"

expected="$(grep " $asset\$" "$tmp_dir/SHA256SUMS" | cut -d' ' -f1)"
[ -n "$expected" ] || fail "no checksum for $asset in SHA256SUMS"
if command -v sha256sum >/dev/null 2>&1; then
    actual="$(sha256sum "$tmp_dir/$asset" | cut -d' ' -f1)"
elif command -v shasum >/dev/null 2>&1; then
    actual="$(shasum -a 256 "$tmp_dir/$asset" | cut -d' ' -f1)"
else
    fail "sha256sum or shasum is required to verify the download."
fi
[ "$expected" = "$actual" ] || fail "checksum mismatch for $asset (expected $expected, got $actual)"

chmod +x "$tmp_dir/$asset"
mv "$tmp_dir/$asset" "$install_dir/$BIN_NAME"

echo "Installed $BIN_NAME to $install_dir/$BIN_NAME"
case ":$PATH:" in
    *":$install_dir:"*) ;;
    *)
        echo ""
        echo "$install_dir is not on your PATH. Add this line to your shell profile (~/.zshrc, ~/.bashrc, ...):"
        echo "    export PATH=\"$install_dir:\$PATH\""
        ;;
esac
echo ""
echo "Get started:  $BIN_NAME login"
