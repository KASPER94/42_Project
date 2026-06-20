#!/bin/bash
# bonus/run-bonus.sh — single entry point for the BLFS bonus (Xorg + WM)
# =============================================================================
#   ███  GATE — READ THIS FIRST  ███
#
#   The bonus is graded ONLY if the MANDATORY part is PERFECT. Per .specs/
#   bonus.md: "The bonus part will only be assessed if the mandatory part is
#   PERFECT. ... If you have not passed ALL the mandatory requirements, your
#   bonus part will not be evaluated at all."
#
#   So DO NOT run this until `verify/verify.sh` reports 0 failures on the booted
#   ft_linux system. This script REFUSES to run otherwise (override only if you
#   know what you are doing, with FORCE_BONUS=1 — see below).
#
# WHAT IT DOES
#   Runs, ON THE BOOTED ft_linux system as ROOT (NOT in chroot), the whole
#   bonus build in order:
#     10-deps/  Xorg dependency chain (libpng -> ... -> libepoxy)
#     20-xorg/  X server (modesetting) + xkeyboard-config + xinit + base fonts
#     30-driver/ VirtualBox vboxvideo+modesetting validation (diagnostic)
#     40-wm/    window manager (dwm default / i3) + terminal (st) + dmenu + xinitrc
#
#   Every sub-script is idempotent (lib/state.sh markers under bonus/*), so
#   this entry point is fully RE-RUNNABLE: a crash mid-build resumes by
#   skipping the steps already marked done. FORCE=1 re-runs even completed steps.
#
# Authored on macOS; the user RUNS this inside the booted VM. chmod +x.
# =============================================================================
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$SCRIPT_DIR"
while [ "$REPO_ROOT" != "/" ] && [ ! -f "$REPO_ROOT/env/lfs.env" ]; do REPO_ROOT="$(dirname "$REPO_ROOT")"; done
source "$REPO_ROOT/env/lfs.env"
source "$REPO_ROOT/lib/common.sh"
source "$REPO_ROOT/lib/package.sh"
source "$REPO_ROOT/bonus/00-blfs-env.sh"

require_root

# ---------------------------------------------------------------------------
# The mandatory-perfect gate. We try to run verify/verify.sh (its exit code is
# the failure count). If it is not present or not yet green, refuse — unless the
# operator explicitly sets FORCE_BONUS=1.
# ---------------------------------------------------------------------------
_verify="$REPO_ROOT/verify/verify.sh"
gate_check() {
	if [ "${FORCE_BONUS:-0}" = "1" ]; then
		log_warn "FORCE_BONUS=1 set — skipping the mandatory-perfect gate. You are on your own."
		return 0
	fi
	if [ ! -f "$_verify" ]; then
		die "gate: $_verify not found. The bonus is graded ONLY if the mandatory part is PERFECT.
     Run the mandatory build + verify first. (Override with FORCE_BONUS=1 at your own risk.)"
	fi
	log_info "Gate: running verify/verify.sh to confirm the mandatory part is perfect..."
	if bash "$_verify"; then
		log_ok "Gate passed: verify/verify.sh reported 0 failures. Proceeding with the bonus."
	else
		_rc=$?
		die "gate: verify/verify.sh reported $_rc failure(s). Per .specs/bonus.md the bonus is
     NOT evaluated unless the mandatory part is PERFECT. Fix the mandatory part first.
     (Override with FORCE_BONUS=1 at your own risk.)"
	fi
}

# ---------------------------------------------------------------------------
# Run one sub-stage script under run_step so it is logged + idempotent at the
# stage level too (the inner build_package calls have their own finer markers).
# ---------------------------------------------------------------------------
run_substage() {
	_id="$1"; _path="$2"
	[ -f "$_path" ] || die "run-bonus: missing sub-stage script: $_path"
	run_step "$_id" "bonus sub-stage $_id" -- bash "$_path"
}

main() {
	log_info "=============================================================="
	log_info " ft_linux BONUS — BLFS Xorg + window manager"
	log_info "   WM=$BONUS_WM  terminal=$BONUS_TERMINAL  mesa-llvm=$BONUS_MESA_LLVM"
	log_info "   demo user=$BONUS_DEMO_USER"
	log_info "=============================================================="

	gate_check

	# Make sure the non-root X user exists up-front (X must not run as root).
	ensure_bonus_demo_user

	# --- 10-deps: Xorg dependency chain (correct BLFS order) ---------------
	run_substage bonus/stage/10-libpng        "$REPO_ROOT/bonus/10-deps/10-libpng.sh"
	run_substage bonus/stage/20-freetype      "$REPO_ROOT/bonus/10-deps/20-freetype.sh"
	run_substage bonus/stage/30-fontconfig    "$REPO_ROOT/bonus/10-deps/30-fontconfig.sh"
	run_substage bonus/stage/40-util-macros   "$REPO_ROOT/bonus/10-deps/40-util-macros.sh"
	run_substage bonus/stage/50-xorgproto     "$REPO_ROOT/bonus/10-deps/50-xorgproto.sh"
	run_substage bonus/stage/60-libXau        "$REPO_ROOT/bonus/10-deps/60-libXau.sh"
	run_substage bonus/stage/70-libXdmcp      "$REPO_ROOT/bonus/10-deps/70-libXdmcp.sh"
	run_substage bonus/stage/80-xcb-proto     "$REPO_ROOT/bonus/10-deps/80-xcb-proto.sh"
	run_substage bonus/stage/90-libxcb        "$REPO_ROOT/bonus/10-deps/90-libxcb.sh"
	run_substage bonus/stage/100-xorg-libs    "$REPO_ROOT/bonus/10-deps/100-xorg-libs.sh"
	run_substage bonus/stage/110-pixman       "$REPO_ROOT/bonus/10-deps/110-pixman.sh"
	run_substage bonus/stage/120-libdrm       "$REPO_ROOT/bonus/10-deps/120-libdrm.sh"
	run_substage bonus/stage/130-mesa         "$REPO_ROOT/bonus/10-deps/130-mesa.sh"
	run_substage bonus/stage/140-libepoxy     "$REPO_ROOT/bonus/10-deps/140-libepoxy.sh"

	# --- 20-xorg: server + keymaps + startx + fonts ------------------------
	run_substage bonus/stage/200-xorg-server  "$REPO_ROOT/bonus/20-xorg/10-xorg-server.sh"
	run_substage bonus/stage/210-xkb          "$REPO_ROOT/bonus/20-xorg/20-xkeyboard-config.sh"
	run_substage bonus/stage/220-xinit        "$REPO_ROOT/bonus/20-xorg/30-xinit.sh"
	run_substage bonus/stage/230-fonts        "$REPO_ROOT/bonus/20-xorg/40-fonts.sh"

	# --- 30-driver: VirtualBox graphics validation (diagnostic) ------------
	run_substage bonus/stage/300-vbox         "$REPO_ROOT/bonus/30-driver/10-vbox-guest-notes.sh"

	# --- 40-wm: window manager + terminal + launcher + xinitrc -------------
	run_substage bonus/stage/400-wm           "$REPO_ROOT/bonus/40-wm/10-wm.sh"
	run_substage bonus/stage/410-terminal     "$REPO_ROOT/bonus/40-wm/20-terminal.sh"
	run_substage bonus/stage/420-launcher     "$REPO_ROOT/bonus/40-wm/30-launcher.sh"
	run_substage bonus/stage/430-xinitrc      "$REPO_ROOT/bonus/40-wm/40-install-xinitrc.sh"

	log_ok "=============================================================="
	log_ok " BONUS BUILD COMPLETE."
	log_ok " Demo: switch to a text console, log in as (or 'su - ') $BONUS_DEMO_USER,"
	log_ok " then run:  startx"
	log_ok " You should get $BONUS_WM with a $BONUS_TERMINAL terminal."
	log_ok "=============================================================="
}

main "$@"
