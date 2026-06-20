#!/bin/bash
# scripts/final-system/400-xml-parser.sh — build XML::Parser (Perl module; needs Expat)
# LFS Ch.8 final system, runs as root inside chroot.
# Authored on macOS; the user RUNS this inside the build VM (in chroot). chmod +x.
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$SCRIPT_DIR"
while [ "$REPO_ROOT" != "/" ] && [ ! -f "$REPO_ROOT/env/lfs.env" ]; do REPO_ROOT="$(dirname "$REPO_ROOT")"; done
source "$REPO_ROOT/env/lfs.env"
source "$REPO_ROOT/lib/common.sh"
source "$REPO_ROOT/lib/package.sh"

# Perl module — build_package's perl path runs:
#   perl Makefile.PL && make && make test && make install
build_package final/xml-parser "XML-Parser-$XML_PARSER_VERSION.tar.gz" --type=perl
