#!/bin/bash
# =============================================================================
# scripts/kernel/60-kernel-prepare.sh
#   LFS Ch.10.3 — Linux kernel: extract sources + seed the .config.
#
# PURPOSE   Prepare the kernel tree for building:
#             1. Extract linux-$KERNEL_VERSION.tar.xz to the SPEC-MANDATED
#                location  /usr/src/kernel-$KERNEL_VERSION   (spec rule:
#                "The kernel sources MUST live in /usr/src/kernel-$(version)").
#             2. Create the conventional /usr/src/linux convenience symlink.
#             3. `make mrproper`  (pristine tree — removes any stale .config).
#             4. Copy our curated scripts/kernel/kernel-config to .config.
#             5. `make olddefconfig`  to fill in every option the curated config
#                does not pin with its upstream default — yielding a complete,
#                buildable .config.
#
#           The curated config sets CONFIG_LOCALVERSION="-skapers" and
#           CONFIG_LOCALVERSION_AUTO=n, which is what makes `uname -r` end in
#           "-skapers" (spec rule R4). 62-kernel-install.sh asserts this.
#
# RUN AS    root, INSIDE the chroot.
#
# AUTHORED  on macOS — RUN by the operator inside the build VM. chmod +x.
# =============================================================================
set -euo pipefail

# --- Foundation bootstrap (A0 contract — verbatim) --------------------------
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$SCRIPT_DIR"
while [ "$REPO_ROOT" != "/" ] && [ ! -f "$REPO_ROOT/env/lfs.env" ]; do REPO_ROOT="$(dirname "$REPO_ROOT")"; done
[ -f "$REPO_ROOT/env/lfs.env" ] || { echo "FATAL: cannot locate env/lfs.env above $SCRIPT_DIR" >&2; exit 1; }
# shellcheck source=/dev/null
source "$REPO_ROOT/env/lfs.env"
# shellcheck source=/dev/null
source "$REPO_ROOT/lib/common.sh"
# shellcheck source=/dev/null
source "$REPO_ROOT/lib/package.sh"   # for extract_only

require_root

# SPEC-MANDATED source directory — derived from KERNEL_VERSION (defined once).
KERNEL_SRC="/usr/src/kernel-${KERNEL_VERSION}"
CURATED_CONFIG="$SCRIPT_DIR/kernel-config"
[ -f "$CURATED_CONFIG" ] || die "curated kernel config missing: $CURATED_CONFIG"

run_step "60-kernel-prepare" "Extract kernel to $KERNEL_SRC + seed .config" -- bash -c '
	set -euo pipefail
	kver="$1"; kernel_src="$2"; curated="$3"

	mkdir -pv /usr/src

	# Extract into $SOURCES_DIR (extract_only s contract), then MOVE the result
	# to the exact spec-mandated /usr/src/kernel-$kver path. extract_only echoes
	# the extracted top-level dir (e.g. .../linux-6.13.4).
	if [ ! -d "$kernel_src" ]; then
		extracted="$(extract_only "linux-$kver.tar.xz")"
		echo "extracted to: $extracted"
		rm -rf "$kernel_src"
		mv -v "$extracted" "$kernel_src"
	else
		echo "kernel source dir already present: $kernel_src (reusing)"
	fi

	# Convenience symlink /usr/src/linux -> kernel-$kver (does not affect naming).
	ln -sfnv "$kernel_src" /usr/src/linux

	cd "$kernel_src"

	# Pristine tree: remove stale objects/config so our curated config is the
	# sole input.
	make mrproper

	# Seed the curated .config, then let the kernel fill the rest with defaults.
	install -v -m 644 "$curated" .config
	make olddefconfig

	# Show the localversion-related settings actually in effect after
	# olddefconfig (these are the spec-critical ones).
	echo "----- effective localversion settings -----"
	grep -E "^CONFIG_LOCALVERSION(=|_AUTO)" .config || true
' _ "$KERNEL_VERSION" "$KERNEL_SRC" "$CURATED_CONFIG"

# Loud assertions on the resulting .config so a botched seed fails HERE, not at
# the much-later install/boot stage.
CFG="$KERNEL_SRC/.config"
[ -f "$CFG" ] || die "ASSERT FAILED: $CFG was not produced"
grep -q '^CONFIG_LOCALVERSION="-skapers"' "$CFG" \
	|| die "ASSERT FAILED: CONFIG_LOCALVERSION is not \"-skapers\" in $CFG"
grep -q '^# CONFIG_LOCALVERSION_AUTO is not set' "$CFG" \
	|| grep -q '^CONFIG_LOCALVERSION_AUTO=n' "$CFG" \
	|| die "ASSERT FAILED: CONFIG_LOCALVERSION_AUTO is not disabled in $CFG"

# Spec rule: sources MUST live in /usr/src/kernel-<version>.
[ -d "$KERNEL_SRC" ] || die "ASSERT FAILED: kernel sources not at $KERNEL_SRC"

log_ok "Kernel $KERNEL_VERSION prepared at $KERNEL_SRC (localversion=-skapers seeded)"
