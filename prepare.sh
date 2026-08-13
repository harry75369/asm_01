#!/bin/bash
set -e

# Limine binary release version
LIMINE_VERSION=v12.5.2
TARBALL=limine-binary.tar.xz
URL="https://github.com/Limine-Bootloader/Limine/releases/download/${LIMINE_VERSION}/${TARBALL}"

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "${SCRIPT_DIR}"

echo "==> Downloading ${URL}"
wget -O "${TARBALL}" "${URL}"

echo "==> Extracting ${TARBALL}"
# Remove any previous extraction to keep things clean
rm -rf limine-binary
tar -xf "${TARBALL}"

echo "==> Building limine CLI tool in limine-binary/"
make -C limine-binary

echo "==> Cleaning up tarball"
rm -f "${TARBALL}"

echo "==> Done. limine CLI tool available at: ${SCRIPT_DIR}/limine-binary/limine"
