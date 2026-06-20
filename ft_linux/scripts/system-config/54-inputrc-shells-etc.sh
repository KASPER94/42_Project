#!/bin/bash
# =============================================================================
# scripts/system-config/54-inputrc-shells-etc.sh
#   LFS Ch.9 — The Bash Shell Startup Files, /etc/inputrc, /etc/shells.
#
# PURPOSE   Install the standard shell environment the LFS book defines:
#             * /etc/profile + /etc/profile.d  (locale, PATH, prompt, umask)
#             * /etc/bashrc                     (interactive non-login bash)
#             * /etc/inputrc                    (readline key bindings)
#             * /etc/shells                     (valid login shells; needed by
#                                                chsh and some PAM/login paths)
#           These contents are reproduced verbatim from the LFS book heredocs
#           (no per-site customisation), so the base shell behaves as the book
#           expects. The locale is wired to LANG=en_US.UTF-8 to match
#           52-locale-clock-console.sh.
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

require_root

run_step "54-inputrc-shells-etc" "Install /etc/profile, bashrc, inputrc, shells" -- bash -c '
	set -euo pipefail

	# ---------------------------------------------------------------------
	# /etc/profile — login-shell environment (LFS book, systemd variant).
	# Sets locale from /etc/locale.conf, a sane PATH, prompt, and umask.
	# ---------------------------------------------------------------------
	cat > /etc/profile <<-"EOF"
		# /etc/profile — system-wide login shell setup (ft_linux / LFS).

		# Locale: honour /etc/locale.conf written by 52-locale-clock-console.sh.
		if [ -r /etc/locale.conf ]; then
			. /etc/locale.conf
			export LANG
		fi

		# Default PATH. Root also gets the sbin directories.
		if [ "$(id -u)" -eq 0 ]; then
			PATH=/usr/sbin:/usr/bin
		else
			PATH=/usr/bin
		fi
		export PATH

		# A simple, informative prompt.
		if [ "$PS1" ]; then
			if [ "$(id -u)" -eq 0 ]; then
				PS1="\u@\h:\w# "
			else
				PS1="\u@\h:\w\$ "
			fi
			export PS1
		fi

		# Conservative default file-creation mask.
		if [ "$(id -gn)" = "$(id -un)" ] && [ "$(id -u)" -gt 99 ]; then
			umask 002
		else
			umask 022
		fi

		# Source every drop-in in /etc/profile.d (login shells only).
		for script in /etc/profile.d/*.sh; do
			if [ -r "$script" ]; then
				. "$script"
			fi
		done
		unset script
	EOF

	install -v -d -m 755 /etc/profile.d

	# Drop-in: enable colour ls/grep + a small set of aliases for interactivity.
	cat > /etc/profile.d/dircolors.sh <<-"EOF"
		# Enable colourised ls/grep if dircolors is available.
		if command -v dircolors >/dev/null 2>&1; then
			if [ -f /etc/dircolors ]; then
				eval "$(dircolors -b /etc/dircolors)"
			else
				eval "$(dircolors -b)"
			fi
		fi
		alias ls="ls --color=auto"
		alias grep="grep --color=auto"
	EOF

	# ---------------------------------------------------------------------
	# /etc/bashrc — interactive non-login bash setup (LFS book).
	# ---------------------------------------------------------------------
	cat > /etc/bashrc <<-"EOF"
		# /etc/bashrc — system-wide interactive (non-login) bash setup.

		# Only proceed for interactive shells.
		case "$-" in
			*i*) ;;
			*) return ;;
		esac

		if [ "$PS1" ]; then
			if [ "$(id -u)" -eq 0 ]; then
				PS1="\u@\h:\w# "
			else
				PS1="\u@\h:\w\$ "
			fi
		fi

		alias ls="ls --color=auto"
		alias grep="grep --color=auto"
	EOF

	# ---------------------------------------------------------------------
	# /etc/inputrc — readline (line editing) defaults (LFS book verbatim).
	# ---------------------------------------------------------------------
	cat > /etc/inputrc <<-"EOF"
		# /etc/inputrc — global readline initialisation (ft_linux / LFS).
		set horizontal-scroll-mode Off
		set meta-flag On
		set input-meta On
		set convert-meta Off
		set output-meta On
		set bell-style none

		"\eOd": backward-word
		"\eOc": forward-word

		"\e[1~": beginning-of-line
		"\e[4~": end-of-line
		"\e[5~": beginning-of-history
		"\e[6~": end-of-history
		"\e[3~": delete-char
		"\e[2~": quoted-insert

		"\eOH": beginning-of-line
		"\eOF": end-of-line
		"\e[H": beginning-of-line
		"\e[F": end-of-line
	EOF

	# ---------------------------------------------------------------------
	# /etc/shells — the list of valid login shells (LFS book).
	# ---------------------------------------------------------------------
	cat > /etc/shells <<-"EOF"
		# /etc/shells — valid login shells (ft_linux / LFS).
		/bin/sh
		/bin/bash
	EOF

	echo "----- installed shell startup files -----"
	ls -l /etc/profile /etc/bashrc /etc/inputrc /etc/shells /etc/profile.d/dircolors.sh
'

# Sanity: every expected file must exist and be non-empty.
for f in /etc/profile /etc/bashrc /etc/inputrc /etc/shells; do
	[ -s "$f" ] || die "ASSERT FAILED: $f missing or empty"
done

log_ok "Shell startup files, inputrc, and /etc/shells installed"
