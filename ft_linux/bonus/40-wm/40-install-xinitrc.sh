#!/bin/bash
# bonus/40-wm/40-install-xinitrc.sh — install ~/.xinitrc for the demo user
# =============================================================================
# BLFS bonus. RUNS ON THE BOOTED ft_linux system as root (NOT in chroot),
# AFTER the mandatory build passes `verify/verify.sh` with 0 failures.
# Authored on macOS; chmod +x. Idempotent (run_step marker; safe to re-run).
#
# Materialises bonus/xinitrc.skel into ~$BONUS_DEMO_USER/.xinitrc, substituting
# the @WM@ / @TERMINAL@ / @RESOLUTION@ placeholders from the bonus toggles, and
# fixes ownership so the (non-root) demo user can `startx`.
#
# X must NOT run as root, so we first ensure the demo user exists (helper from
# bonus/00-blfs-env.sh) and own the file.
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

# Ensure the non-root X user exists (and is in video/input groups).
ensure_bonus_demo_user

# Resolve the WM binary name the xinitrc should exec.
case "$BONUS_WM" in
	dwm) _wm_bin=dwm ;;
	i3)  _wm_bin=i3 ;;
	*)   die "40-install-xinitrc.sh: unknown BONUS_WM='$BONUS_WM'" ;;
esac

# Resolution to request (matches xorg.conf.d/10-monitor.conf default).
_resolution="${BONUS_RESOLUTION:-1280x800}"

_home="$(bonus_demo_home)"
[ -n "$_home" ] && [ -d "$_home" ] || die "demo user '$BONUS_DEMO_USER' has no home dir ($_home)"

run_step bonus/install-xinitrc "Install ~$BONUS_DEMO_USER/.xinitrc (WM=$_wm_bin term=$BONUS_TERMINAL)" -- \
	bash -c '
		set -euo pipefail
		repo="$1"; home="$2"; user="$3"; wm="$4"; term="$5"; res="$6"
		dst="$home/.xinitrc"
		sed -e "s/@WM@/$wm/g" \
		    -e "s/@TERMINAL@/$term/g" \
		    -e "s/@RESOLUTION@/$res/g" \
		    "$repo/bonus/xinitrc.skel" > "$dst"
		chmod 0644 "$dst"
		chown "$user":"$user" "$dst"
		echo "installed $dst"
	' _ "$REPO_ROOT" "$_home" "$BONUS_DEMO_USER" "$_wm_bin" "$BONUS_TERMINAL" "$_resolution"

log_ok "~$BONUS_DEMO_USER/.xinitrc installed."
log_info "Demo: log in (or 'su - $BONUS_DEMO_USER') on a text console, then run: startx"
