#!/bin/bash
# =============================================================================
# scripts/chroot/32-create-dirs-files.sh
#   LFS Ch.7 — Creating Directories + Essential Files and Symlinks.
#
# PURPOSE   Build the full FHS directory tree and the minimal set of files the
#           system needs to function once we start building the final system
#           inside chroot: /etc/{passwd,group,hosts,nsswitch.conf}, the login
#           log files (/var/log/{btmp,lastlog,faillog,wtmp}) with correct perms,
#           and the conventional symlinks (/etc/mtab, /dev/shm handling, etc.).
#           Also creates a temporary /etc/resolv.conf so name resolution works
#           for any in-chroot fetches.
#
# RUN CONTEXT  *** RUNS INSIDE THE CHROOT ***  (root, PID-namespaced under $LFS).
#           It is NOT meant to be run on the host. It does NOT call enter_chroot;
#           the orchestrator (A8) stages it under $LFS and invokes it via
#           31-enter-chroot.sh, e.g.:
#               sudo ./scripts/chroot/31-enter-chroot.sh \
#                    /opt/ft_linux/scripts/chroot/32-create-dirs-files.sh
#
#           Because we are inside the chroot, the chroot root IS "/", so all
#           paths below are absolute against "/" (do NOT prefix with $LFS).
#
# ASSUMPTION  The repo is reachable from inside the chroot (bind-mounted or
#           copied to $LFS/opt/ft_linux by the orchestrator) so env/ + lib/ can
#           be sourced. If not, the bootstrap dies with a clear message.
#
# AUTHORED  on macOS — RUN by the operator (via the orchestrator) inside the VM.
# =============================================================================
set -euo pipefail

# --- Foundation bootstrap (tolerant: must work from inside the chroot) ------
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$SCRIPT_DIR"
while [ "$REPO_ROOT" != "/" ] && [ ! -f "$REPO_ROOT/env/lfs.env" ]; do REPO_ROOT="$(dirname "$REPO_ROOT")"; done
if [ ! -f "$REPO_ROOT/env/lfs.env" ]; then
	echo "FATAL: cannot locate env/lfs.env above $SCRIPT_DIR" >&2
	echo "       This script runs INSIDE the chroot — the orchestrator must stage" >&2
	echo "       the repo under \$LFS first (e.g. bind-mount/copy to /opt/ft_linux)." >&2
	exit 1
fi
# shellcheck source=/dev/null
source "$REPO_ROOT/env/lfs.env"
# shellcheck source=/dev/null
source "$REPO_ROOT/lib/common.sh"

# Inside the chroot we are root. (No require_not_root here.)
require_root

run_step "32-create-dirs-files" "FHS dir tree + essential files (in chroot)" -- bash -c '
	set -euo pipefail

	# --- 1) FHS directory hierarchy (LFS book) ------------------------------
	mkdir -pv /{boot,home,mnt,opt,srv}
	mkdir -pv /etc/{opt,sysconfig}
	mkdir -pv /lib/firmware
	mkdir -pv /media/{floppy,cdrom}
	mkdir -pv /usr/{,local/}{include,src}
	mkdir -pv /usr/lib/locale
	mkdir -pv /usr/local/{bin,lib,sbin}
	mkdir -pv /usr/{,local/}share/{color,dict,doc,info,locale,man}
	mkdir -pv /usr/{,local/}share/{misc,terminfo,zoneinfo}
	mkdir -pv /usr/{,local/}share/man/man{1..8}
	mkdir -pv /var/{cache,local,log,mail,opt,spool}
	mkdir -pv /var/lib/{color,misc,locate}

	# Conventional symlinks.
	ln -sfv /run /var/run
	ln -sfv /run/lock /var/lock
	install -dv -m 0750 /root
	install -dv -m 1777 /tmp /var/tmp

	# --- 2) Essential symlinks the toolchain expects ------------------------
	# /bin/sh -> bash if not already present; /usr/lib/os-release placeholder.
	[ -e /bin/sh ] || ln -sfv bash /bin/sh

	# --- 3) /etc/passwd and /etc/group (minimal, in-chroot build identity) --
	cat > /etc/passwd <<"EOF"
root:x:0:0:root:/root:/bin/bash
bin:x:1:1:bin:/dev/null:/usr/bin/false
daemon:x:6:6:Daemon User:/dev/null:/usr/bin/false
messagebus:x:18:18:D-Bus Message Daemon User:/run/dbus:/usr/bin/false
systemd-journal-gateway:x:73:73:systemd Journal Gateway:/:/usr/bin/false
systemd-journal-remote:x:74:74:systemd Journal Remote:/:/usr/bin/false
systemd-journal-upload:x:75:75:systemd Journal Upload:/:/usr/bin/false
systemd-network:x:76:76:systemd Network Management:/:/usr/bin/false
systemd-resolve:x:77:77:systemd Resolver:/:/usr/bin/false
systemd-timesync:x:78:78:systemd Time Synchronization:/:/usr/bin/false
systemd-coredump:x:79:79:systemd Core Dumper:/:/usr/bin/false
uuidd:x:80:80:UUID Generation Daemon User:/dev/null:/usr/bin/false
systemd-oom:x:81:81:systemd Out Of Memory Daemon:/:/usr/bin/false
nobody:x:65534:65534:Unprivileged User:/dev/null:/usr/bin/false
EOF

	cat > /etc/group <<"EOF"
root:x:0:
bin:x:1:daemon
sys:x:2:
kmem:x:3:
tape:x:4:
tty:x:5:
daemon:x:6:
floppy:x:7:
disk:x:8:
lp:x:9:
dialout:x:10:
audio:x:11:
video:x:12:
utmp:x:13:
cdrom:x:15:
adm:x:16:
messagebus:x:18:
systemd-journal:x:23:
input:x:24:
mail:x:34:
kvm:x:61:
systemd-journal-gateway:x:73:
systemd-journal-remote:x:74:
systemd-journal-upload:x:75:
systemd-network:x:76:
systemd-resolve:x:77:
systemd-timesync:x:78:
systemd-coredump:x:79:
uuidd:x:80:
systemd-oom:x:81:
wheel:x:97:
users:x:999:
nogroup:x:65534:
EOF

	# A non-root user for running the test suites (the book uses "tester").
	echo "tester:x:101:101::/home/tester:/bin/bash" >> /etc/passwd
	echo "tester:x:101:" >> /etc/group
	install -o tester -d /home/tester

	# --- 4) /etc/hosts (hostname is set later by system-config) -------------
	cat > /etc/hosts <<EOF
127.0.0.1  localhost ${LFS_USER_LOGIN}
::1        localhost
EOF

	# --- 5) /etc/nsswitch.conf precursor (final one comes with glibc config) -
	cat > /etc/nsswitch.conf <<"EOF"
passwd: files
group: files
shadow: files
hosts: files dns
networks: files
protocols: files
services: files
ethers: files
rpc: files
EOF

	# --- 6) Login accounting log files with the perms the book mandates -----
	mkdir -pv /var/log
	touch /var/log/{btmp,lastlog,faillog,wtmp}
	chgrp -v utmp /var/log/lastlog
	chmod -v 664  /var/log/lastlog
	chmod -v 600  /var/log/btmp

	# --- 7) Temporary resolv.conf so DNS works for in-chroot fetches --------
	# (system-config replaces this with the systemd-resolved symlink later.)
	cat > /etc/resolv.conf <<"EOF"
nameserver 1.1.1.1
nameserver 8.8.8.8
EOF
'

log_ok "FHS tree + essential files created inside chroot"
