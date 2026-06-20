#!/usr/bin/env bash
# submit/checksum.sh — HOST-SIDE checksum of the ft_linux disk image
# =============================================================================
# RUN THIS ON THE macOS (or Linux) HOST — *not* inside any VM, and only with
# the build VM POWERED OFF. The disk.vdi must not be changing while we hash it.
#
# What it does (exactly what the spec asks for):
#   The 42 subject (.specs/submission-evaluation.md) says:
#       "For obvious reasons, you will not push your entire virtual machine —
#        push a checksum of your disk image instead. This can be done with
#        something like:  shasum < disk.vdi"
#   So we reproduce that EXACT command (SHA-1, the `shasum` default) and also a
#   stronger SHA-256, print both to stdout, and write them to a tracked
#   CHECKSUM.txt at the repo root. That CHECKSUM.txt is what you commit and push
#   (the .vdi itself is .gitignored — keep it for the peer-evaluation).
#
# Usage:
#   bash submit/checksum.sh [/path/to/disk.vdi]
#     - With an argument: hashes exactly that file.
#     - Without: auto-scans ~/VirtualBox VMs/ft_linux-build/*.vdi for disk.vdi.
#
# Notes:
#   * Pairs with docs/SUBMISSION.md (the rules) and docs/RUNBOOK.md step 10.
#   * `shasum` ships with macOS (Perl) and most Linuxes; on a Linux host without
#     it we fall back to sha1sum / sha256sum.
#   * It WARNS (does not hard-fail) if it cannot confirm the VM is powered off,
#     so you can still hash an exported/copied image.
# =============================================================================
set -euo pipefail

# -----------------------------------------------------------------------------
# Locate the repo root and (optionally) borrow lib/common.sh logging. This is a
# host-side script, so lib/ may not be sourceable on a stripped-down host; we
# fall back to plain printf logging if it is not reachable.
# -----------------------------------------------------------------------------
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$SCRIPT_DIR"
while [ "$REPO_ROOT" != "/" ] && [ ! -f "$REPO_ROOT/env/lfs.env" ]; do
	REPO_ROOT="$(dirname "$REPO_ROOT")"
done

if [ -f "$REPO_ROOT/lib/common.sh" ]; then
	# shellcheck source=/dev/null
	. "$REPO_ROOT/lib/common.sh" 2>/dev/null || true
fi
# Standalone fallbacks (only define if lib/common.sh did not provide them).
command -v log_info  >/dev/null 2>&1 || log_info()  { printf 'INFO  %s\n' "$*" >&2; }
command -v log_warn  >/dev/null 2>&1 || log_warn()  { printf 'WARN  %s\n' "$*" >&2; }
command -v log_error >/dev/null 2>&1 || log_error() { printf 'ERROR %s\n' "$*" >&2; }
command -v log_ok    >/dev/null 2>&1 || log_ok()    { printf 'OK    %s\n' "$*" >&2; }
command -v die       >/dev/null 2>&1 || die()       { log_error "$@"; exit 1; }

# Where the committed checksum file is written (repo root, tracked by git).
CHECKSUM_FILE="$REPO_ROOT/CHECKSUM.txt"

# Default VM name must match vm/create-build-vm.sh's VM_NAME.
VM_NAME="ft_linux-build"

# -----------------------------------------------------------------------------
# Resolve the VDI path: explicit $1, else auto-scan the default VirtualBox dir.
# -----------------------------------------------------------------------------
VDI="${1:-}"

if [ -z "$VDI" ]; then
	# Prefer VirtualBox's configured default machine folder when VBoxManage is
	# present; otherwise fall back to the conventional "~/VirtualBox VMs" path.
	default_folder=""
	if command -v VBoxManage >/dev/null 2>&1; then
		default_folder="$(VBoxManage list systemproperties 2>/dev/null \
			| sed -n 's/^Default machine folder:[[:space:]]*//p')"
	fi
	[ -n "$default_folder" ] || default_folder="$HOME/VirtualBox VMs"

	# The deliverable is named disk.vdi (see vm/create-build-vm.sh: DISK_B).
	candidate="$default_folder/$VM_NAME/disk.vdi"
	if [ -f "$candidate" ]; then
		VDI="$candidate"
	else
		# Last resort: glob any disk.vdi under the VM folder.
		for f in "$default_folder/$VM_NAME"/*.vdi; do
			[ -e "$f" ] || continue
			case "$(basename "$f")" in
				disk.vdi) VDI="$f"; break ;;
			esac
		done
		# If still nothing, take the first .vdi we find and warn.
		if [ -z "$VDI" ]; then
			for f in "$default_folder/$VM_NAME"/*.vdi; do
				[ -e "$f" ] || continue
				VDI="$f"
				log_warn "No file literally named disk.vdi; falling back to: $VDI"
				break
			done
		fi
	fi
fi

[ -n "$VDI" ] || die "Could not locate a disk.vdi. Pass the path explicitly: bash submit/checksum.sh /path/to/disk.vdi"
[ -f "$VDI" ] || die "VDI not found: $VDI"

log_info "Disk image: $VDI"

# -----------------------------------------------------------------------------
# Best-effort power-off check (WARN only — never hard-fail).
# If VBoxManage is available and the VM is registered, refuse-with-warning when
# it is not in the 'poweroff'/'aborted'/'saved' state.
# -----------------------------------------------------------------------------
if command -v VBoxManage >/dev/null 2>&1; then
	if VBoxManage list vms 2>/dev/null | grep -q "\"$VM_NAME\""; then
		state="$(VBoxManage showvminfo "$VM_NAME" --machinereadable 2>/dev/null \
			| sed -n 's/^VMState=//p' | tr -d '"')"
		case "$state" in
			poweroff|aborted|saved|"")
				log_ok "VM '$VM_NAME' state: ${state:-unknown} (safe to hash)." ;;
			*)
				log_warn "VM '$VM_NAME' appears to be '$state' — NOT powered off."
				log_warn "Hashing a running/changing image gives a checksum the evaluator cannot reproduce."
				log_warn "Power it off (VBoxManage controlvm \"$VM_NAME\" acpipowerbutton) and re-run." ;;
		esac
	else
		log_warn "VM '$VM_NAME' is not registered with VirtualBox; cannot confirm power state. Continuing."
	fi
else
	log_warn "VBoxManage not found; cannot confirm the VM is powered off. Continuing."
fi

# -----------------------------------------------------------------------------
# Report image size + mtime (portable across macOS BSD stat and GNU stat).
# -----------------------------------------------------------------------------
if stat -f '%z' "$VDI" >/dev/null 2>&1; then
	# BSD/macOS stat
	vdi_size="$(stat -f '%z' "$VDI")"
	vdi_mtime="$(stat -f '%Sm' "$VDI")"
else
	# GNU/Linux stat
	vdi_size="$(stat -c '%s' "$VDI")"
	vdi_mtime="$(stat -c '%y' "$VDI")"
fi
log_info "Image size : ${vdi_size} bytes"
log_info "Image mtime: ${vdi_mtime}"

# -----------------------------------------------------------------------------
# Compute the checksums.
#   * SHA-1 via `shasum < "$VDI"` — the EXACT command from the spec.
#   * SHA-256 via `shasum -a 256 < "$VDI"` — stronger, for good measure.
# We redirect FROM the file (stdin) exactly as the spec shows, so the output is
# a bare hash with the "-" placeholder filename — reproducible byte-for-byte by
# an evaluator who runs the same command on the same image.
# Fall back to sha1sum/sha256sum on hosts that lack `shasum`.
# -----------------------------------------------------------------------------
log_info "Computing SHA-1 (spec command: shasum < disk.vdi)…"
if command -v shasum >/dev/null 2>&1; then
	sha1_line="$(shasum < "$VDI")"
	sha256_line="$(shasum -a 256 < "$VDI")"
elif command -v sha1sum >/dev/null 2>&1 && command -v sha256sum >/dev/null 2>&1; then
	log_warn "shasum not found; using sha1sum/sha256sum instead (same digests)."
	sha1_line="$(sha1sum < "$VDI")"
	sha256_line="$(sha256sum < "$VDI")"
else
	die "Neither 'shasum' nor 'sha1sum/sha256sum' is available on this host."
fi

# Extract just the hex digest (first whitespace-delimited field) for clarity.
sha1_hex="${sha1_line%% *}"
sha256_hex="${sha256_line%% *}"

# -----------------------------------------------------------------------------
# Print to stdout.
# -----------------------------------------------------------------------------
printf '\n'
printf '================ ft_linux disk image checksum ================\n'
printf 'image   : %s\n' "$VDI"
printf 'size    : %s bytes\n' "$vdi_size"
printf 'mtime   : %s\n' "$vdi_mtime"
printf 'sha1    : %s\n' "$sha1_hex"
printf 'sha256  : %s\n' "$sha256_hex"
printf '==============================================================\n'

# -----------------------------------------------------------------------------
# Write the tracked CHECKSUM.txt (this is what you commit & push).
# -----------------------------------------------------------------------------
{
	printf '# ft_linux disk image checksum\n'
	printf '# Generated by submit/checksum.sh on %s\n' "$(date -u '+%Y-%m-%dT%H:%M:%SZ')"
	printf '# Reproduce (with the same disk.vdi, VM powered off):\n'
	printf '#     shasum < disk.vdi          # SHA-1, the spec command\n'
	printf '#     shasum -a 256 < disk.vdi   # SHA-256\n'
	printf '#\n'
	printf 'image:  %s\n' "$(basename "$VDI")"
	printf 'size:   %s bytes\n' "$vdi_size"
	printf 'mtime:  %s\n' "$vdi_mtime"
	printf 'sha1:   %s\n' "$sha1_hex"
	printf 'sha256: %s\n' "$sha256_hex"
} > "$CHECKSUM_FILE"

log_ok "Wrote $CHECKSUM_FILE"
log_info "Commit it (NOT the .vdi):  git add CHECKSUM.txt && git commit -m 'Add disk image checksum'"
log_info "Keep $VDI accessible for the peer-evaluation (see docs/SUBMISSION.md)."
