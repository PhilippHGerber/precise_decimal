#!/usr/bin/env bash

set -o errexit
set -o nounset
set -o pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
ZIP_URL="https://speleotrove.com/decimal/dectest.zip"
SUPPORTED_OUTPUT_DIR="$ROOT_DIR/test/testdata/dectest"
ALL_OUTPUT_DIR="$ROOT_DIR/test/testdata/dectest-all"
MODE="supported"
OUTPUT_DIR="$SUPPORTED_OUTPUT_DIR"

usage() {
  cat <<'EOF'
Usage: tool/download_dectest.sh [--supported|--all] [--output DIR]

  --supported   Extract only the milestone-1 fixture subset into test/testdata/dectest.
  --all         Extract the full upstream archive into test/testdata/dectest-all.
  --output DIR  Override the output directory.
EOF
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --supported)
      MODE="supported"
      OUTPUT_DIR="$SUPPORTED_OUTPUT_DIR"
      ;;
    --all)
      MODE="all"
      OUTPUT_DIR="$ALL_OUTPUT_DIR"
      ;;
    --output)
      shift
      if [[ $# -eq 0 ]]; then
        echo "Missing value for --output" >&2
        exit 1
      fi
      OUTPUT_DIR="$1"
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      echo "Unknown argument: $1" >&2
      usage >&2
      exit 1
      ;;
  esac
  shift
done

mkdir -p "$OUTPUT_DIR"

SUPPORTED_FILES=(
  abs.decTest
  add.decTest
  compare.decTest
  comparetotal.decTest
  comparetotmag.decTest
  divide.decTest
  divideint.decTest
  max.decTest
  maxmag.decTest
  min.decTest
  minmag.decTest
  minus.decTest
  multiply.decTest
  plus.decTest
  power.decTest
  reduce.decTest
  remainder.decTest
  rescale.decTest
  squareroot.decTest
  subtract.decTest
  tointegral.decTest
  tointegralx.decTest
)

tmpdir="$(mktemp -d)"
trap 'rm -rf "$tmpdir"' EXIT

archive_path="$tmpdir/dectest.zip"

curl --fail --location --silent --show-error \
  "$ZIP_URL" \
  --output "$archive_path"

find "$OUTPUT_DIR" -maxdepth 1 -type f -name '*.decTest' -delete

if [[ "$MODE" == "all" ]]; then
  unzip -oqj "$archive_path" -d "$OUTPUT_DIR"
  file_count="$(find "$OUTPUT_DIR" -maxdepth 1 -type f -name '*.decTest' | wc -l | tr -d ' ')"
  echo "Downloaded $file_count decTest files into $OUTPUT_DIR"
else
  unzip -oqj "$archive_path" "${SUPPORTED_FILES[@]}" -d "$OUTPUT_DIR"
  echo "Downloaded ${#SUPPORTED_FILES[@]} supported decTest files into $OUTPUT_DIR"
  echo "Use --all to extract the complete upstream archive into $ALL_OUTPUT_DIR"
fi