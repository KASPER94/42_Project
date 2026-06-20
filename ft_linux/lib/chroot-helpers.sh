# shellcheck shell=bash
#
# lib/chroot-helpers.sh — virtual filesystem mounts + chroot entry (LFS Ch.7)
# =============================================================================
# Source AFTER env/lfs.env and lib/common.sh:
#     source "<repo>/env/lfs.env"
#     source "<repo>/lib/common.sh"
#     source "<repo>/lib/chroot-helpers.sh"
#
# These helpers run on the BUILD HOST as root, before/around chroot. They
# manage the kernel virtual filesystems that the chrooted system needs
# (/dev, /dev/pts, /proc, /sys, /run) and provide the canonical chroot
# invocation the LFS book prescribes.
# =============================================================================

# Guard against double-sourcing.
[ -n "${_FT_CHROOT_SH_LOADED:-}" ] && return 0
_FT_CHROOT_SH_LOADED=1

# mount_virtual_fs
#   Bind/mount the kernel virtual filesystems into $LFS so the chroot can use
#   them. Mirrors the LFS systemd-book Ch.7 "Preparing Virtual Kernel File
#   Systems" sequence. Idempotent: re-mounting an already-mounted target via
#   `mountpoint` check is skipped. Must be run as root.
mount_virtual_fs() {
	require_root
	: "${LFS:?LFS not set — source env/lfs.env first}"

	mkdir -p "$LFS"/{dev,proc,sys,run}

	# /dev — bind mount the host's populated devtmpfs.
	if ! mountpoint -q "$LFS/dev"; then
		mount -v --bind /dev "$LFS/dev"
	fi
	# /dev/pts — pseudo-terminals, with the modes the book specifies.
	if ! mountpoint -q "$LFS/dev/pts"; then
		mount -v --bind /dev/pts "$LFS/dev/pts"
	fi
	# /proc, /sys — kernel process & device info.
	if ! mountpoint -q "$LFS/proc"; then
		mount -vt proc proc "$LFS/proc"
	fi
	if ! mountpoint -q "$LFS/sys"; then
		mount -vt sysfs sysfs "$LFS/sys"
	fi
	# /run — tmpfs for runtime state (systemd needs this).
	if ! mountpoint -q "$LFS/run"; then
		mount -vt tmpfs tmpfs "$LFS/run"
	fi

	# Some host /dev/shm setups are symlinks into /run; create the dir so the
	# chroot has working POSIX shared memory.
	if [ -h "$LFS/dev/shm" ]; then
		install -v -d -m 1777 "$LFS$(realpath /dev/shm)"
	elif ! mountpoint -q "$LFS/dev/shm"; then
		mkdir -p "$LFS/dev/shm"
		mount -vt tmpfs -o nosuid,nodev tmpfs "$LFS/dev/shm"
	fi

	log_ok "virtual kernel filesystems mounted under $LFS"
}

# umount_virtual_fs
#   Tear down everything mount_virtual_fs set up, innermost-first. Safe to call
#   even if some are already unmounted. Must be run as root. Call this before
#   unmounting $LFS itself (e.g. before powering off / making the checksum).
umount_virtual_fs() {
	require_root
	: "${LFS:?LFS not set — source env/lfs.env first}"

	# Unmount deepest first to avoid "target is busy".
	for _m in \
		"$LFS/dev/shm" \
		"$LFS/dev/pts" \
		"$LFS/dev" \
		"$LFS/run" \
		"$LFS/sys" \
		"$LFS/proc"; do
		if mountpoint -q "$_m"; then
			umount -v "$_m" || umount -vl "$_m" || log_warn "could not unmount $_m"
		fi
	done
	unset _m
	log_ok "virtual kernel filesystems unmounted from $LFS"
}

# enter_chroot [inner-script]
#   The canonical LFS chroot invocation. Two modes:
#
#   1. INTERACTIVE (no argument):
#        enter_chroot
#      Drops you into an interactive `/bin/bash --login` inside $LFS with the
#      clean, controlled environment the LFS book uses (`env -i`). Exit the
#      shell to return to the host.
#
#   2. NON-INTERACTIVE (one argument = path to a script):
#        enter_chroot scripts/chroot/32-temp-tools.sh
#      Runs that script inside the chroot via `/bin/bash <script>`. The path is
#      interpreted RELATIVE TO THE CHROOT ROOT ($LFS), so copy/stage your
#      script under $LFS first (e.g. into $LFS/root or $LFS/sources) and pass
#      the in-chroot path. Returns the script's exit status.
#
#   Both modes use the book's environment: empty env (`-i`), HOME=/root,
#   TERM passthrough, a fixed PS1, and the in-system PATH (NOT the host
#   build-user PATH from lfs.env — inside chroot the tools live in /usr/bin).
#   Must be run as root, with mount_virtual_fs already applied.
enter_chroot() {
	require_root
	: "${LFS:?LFS not set — source env/lfs.env first}"
	: "${LFS_TGT:?LFS_TGT not set}"

	if ! mountpoint -q "$LFS/proc"; then
		log_warn "virtual filesystems do not appear mounted — call mount_virtual_fs first"
	fi

	if [ "$#" -eq 0 ]; then
		log_info "entering interactive chroot at $LFS (exit to leave)"
		chroot "$LFS" /usr/bin/env -i \
			HOME=/root \
			TERM="${TERM:-linux}" \
			PS1='(lfs chroot) \u:\w\$ ' \
			PATH=/usr/bin:/usr/sbin \
			MAKEFLAGS="${MAKEFLAGS:--j1}" \
			TESTSUITEFLAGS="${TESTSUITEFLAGS:-}" \
			/bin/bash --login
	else
		_inner="$1"
		log_info "running '$_inner' inside chroot at $LFS"
		chroot "$LFS" /usr/bin/env -i \
			HOME=/root \
			TERM="${TERM:-linux}" \
			PS1='(lfs chroot) \u:\w\$ ' \
			PATH=/usr/bin:/usr/sbin \
			MAKEFLAGS="${MAKEFLAGS:--j1}" \
			TESTSUITEFLAGS="${TESTSUITEFLAGS:-}" \
			FT_IN_SYSTEM=1 \
			/bin/bash "$_inner"
		_rc=$?
		unset _inner
		return "$_rc"
	fi
}
