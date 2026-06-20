#!/bin/bash
# =============================================================================
# verify/verify.sh — ft_linux mandatory-compliance self-check (R1–R15)
# =============================================================================
# HOW TO RUN
#     Boot into the finished ft_linux system, log in, then as ROOT:
#         bash verify/verify.sh
#     (from the repo checkout, or copy this single file onto the system — it is
#      designed to stand alone and needs nothing else).
#
# WHY A SEPARATE SCRIPT
#     The authoring agents built ft_linux on a macOS host with NO Linux VM, so
#     they could NOT compile or boot it and therefore could NOT run this check.
#     This script is the user's instrument to confirm, on the real booted
#     system, that every hard requirement of the subject (R1–R15) is satisfied.
#
# WHAT IT DOES
#     Runs one check per requirement, printing  [PASS]/[FAIL]/[WARN] <id>: <msg>.
#     It is data-driven for the 68-package list so a missing package names
#     itself precisely, giving you a punch-list to fix.
#
# EXIT CODE
#     Equals the number of FAILs. 0 == perfect. Only at 0 does it print
#     "MANDATORY PERFECT — bonus may be graded" (bonus is gated on a clean run).
#
# NOTE: we use `set -uo pipefail` but NOT `-e` — verify.sh MUST keep checking
# after a failed assertion so you get the FULL punch-list in one pass.
# =============================================================================
set -uo pipefail

# -----------------------------------------------------------------------------
# Optional: reuse the build suite's logging/colors if the contract is reachable.
# verify.sh must ALSO work fully standalone (copied onto the system on its own),
# so the source is guarded and we define our own colors regardless.
# -----------------------------------------------------------------------------
_VERIFY_DIR="$(CDPATH= cd -- "$(dirname -- "${BASH_SOURCE[0]:-$0}")" 2>/dev/null && pwd -P || echo .)"
_REPO_ROOT="$_VERIFY_DIR"
while [ "$_REPO_ROOT" != "/" ] && [ ! -f "$_REPO_ROOT/env/lfs.env" ]; do
	_REPO_ROOT="$(dirname -- "$_REPO_ROOT")"
done
if [ -f "$_REPO_ROOT/env/lfs.env" ]; then
	# shellcheck disable=SC1091
	. "$_REPO_ROOT/env/lfs.env" 2>/dev/null || true
fi

# Student login: prefer the contract's value, fall back to the fixed literal so
# the script stands alone. (The whole project pins this to "skapers".)
LOGIN="${LFS_USER_LOGIN:-skapers}"

# Colors (independent of the contract; disabled when stderr is not a TTY or
# NO_COLOR is set per https://no-color.org).
if [ -t 1 ] && [ -z "${NO_COLOR:-}" ]; then
	C_RESET=$'\033[0m'; C_OK=$'\033[0;32m'; C_WARN=$'\033[0;33m'; C_ERR=$'\033[0;31m'; C_DIM=$'\033[2m'
else
	C_RESET=; C_OK=; C_WARN=; C_ERR=; C_DIM=
fi

# -----------------------------------------------------------------------------
# Tiny assert framework
# -----------------------------------------------------------------------------
PASS_COUNT=0
WARN_COUNT=0
FAIL_COUNT=0

pass() { # pass <id> <msg>
	PASS_COUNT=$((PASS_COUNT + 1))
	printf '%s[PASS]%s %s: %s\n' "$C_OK" "$C_RESET" "$1" "$2"
}
warn() { # warn <id> <msg>
	WARN_COUNT=$((WARN_COUNT + 1))
	printf '%s[WARN]%s %s: %s\n' "$C_WARN" "$C_RESET" "$1" "$2"
}
fail() { # fail <id> <msg>
	FAIL_COUNT=$((FAIL_COUNT + 1))
	printf '%s[FAIL]%s %s: %s\n' "$C_ERR" "$C_RESET" "$1" "$2"
}

section() { printf '\n%s== %s ==%s\n' "$C_DIM" "$1" "$C_RESET"; }

# have <cmd> : true if command is on PATH
have() { command -v "$1" >/dev/null 2>&1; }

# -----------------------------------------------------------------------------
# R-checks. One function per requirement; IDs R1–R15.
# -----------------------------------------------------------------------------

# R1 — System & environment: MUST run inside a VM. (warn-only: a misdetected
# hypervisor must not fail the mandatory run, but the grader expects a VM.)
chk_vm() {
	local virt=""
	if have systemd-detect-virt; then
		virt="$(systemd-detect-virt 2>/dev/null || true)"
	fi
	if [ -n "$virt" ] && [ "$virt" != "none" ]; then
		pass R1 "running in a virtual machine (systemd-detect-virt: $virt)"
	else
		warn R1 "could not confirm a VM via systemd-detect-virt (got '${virt:-<none>}'); the subject requires a VM"
	fi
}

# R2 — Kernel version string MUST contain the student login.
chk_uname_has_skapers() {
	local r; r="$(uname -r 2>/dev/null || echo '')"
	if printf '%s' "$r" | grep -q -- "-$LOGIN"; then
		pass R2 "uname -r '$r' contains '-$LOGIN'"
	else
		fail R2 "uname -r '$r' does NOT contain '-$LOGIN' (kernel version string must include the login)"
	fi
}

# R3 — Kernel version MUST be >= 4.0.
chk_kver_ge_4() {
	local r major; r="$(uname -r 2>/dev/null || echo '')"
	major="${r%%.*}"
	if printf '%s' "$major" | grep -Eq '^[0-9]+$' && [ "$major" -ge 4 ] 2>/dev/null; then
		pass R3 "kernel major version $major (>= 4) — from uname -r '$r'"
	else
		fail R3 "kernel major version '${major:-?}' is not >= 4 (uname -r '$r')"
	fi
}

# R4 — Kernel sources MUST live in /usr/src/kernel-<version> (symlink accepted).
chk_kernel_src_path() {
	local r ver dir found="" d
	r="$(uname -r 2>/dev/null || echo '')"
	# Strip the "-<login>" localversion suffix to recover the upstream version.
	ver="${r%-$LOGIN}"
	# Preferred exact path for the running kernel's version.
	if [ -e "/usr/src/kernel-$ver" ]; then
		found="/usr/src/kernel-$ver"
	else
		# Accept any /usr/src/kernel-* dir/symlink (version may differ slightly
		# from the localversion-stripped uname). Glob safely.
		for d in /usr/src/kernel-*; do
			[ -e "$d" ] || continue
			if [ -d "$d" ]; then found="$d"; break; fi
		done
	fi
	if [ -n "$found" ]; then
		pass R4 "kernel sources present at $found (/usr/src/kernel-<version>)"
	else
		fail R4 "no /usr/src/kernel-<version> directory found (expected /usr/src/kernel-$ver)"
	fi
}

# R5 — /boot kernel binary MUST be named vmlinuz-<version>-<login>.
chk_boot_binary_name() {
	local f found=""
	for f in /boot/vmlinuz-*-"$LOGIN"; do
		[ -e "$f" ] || continue
		found="$f"; break
	done
	if [ -n "$found" ]; then
		pass R5 "boot kernel binary present: $found (vmlinuz-<version>-$LOGIN)"
	else
		fail R5 "no /boot/vmlinuz-*-$LOGIN found (kernel binary must be named vmlinuz-<version>-$LOGIN)"
	fi
}

# R7 — Hostname MUST be the student login (both live hostname and /etc/hostname).
chk_hostname_skapers() {
	local h fileh
	h="$(hostname 2>/dev/null || cat /proc/sys/kernel/hostname 2>/dev/null || echo '')"
	fileh="$(tr -d '[:space:]' < /etc/hostname 2>/dev/null || echo '')"
	if [ "$h" = "$LOGIN" ]; then
		pass R7 "live hostname is '$LOGIN'"
	else
		fail R7 "live hostname is '$h', expected '$LOGIN'"
	fi
	if [ "$fileh" = "$LOGIN" ]; then
		pass R7 "/etc/hostname is '$LOGIN'"
	else
		fail R7 "/etc/hostname is '${fileh:-<empty/missing>}', expected '$LOGIN'"
	fi
}

# R6 — At least 3 partitions feeding /, /boot, and swap.
chk_three_partitions() {
	local root_src boot_src swap_present=0

	# Source backing "/" and "/boot" (prefer findmnt; fall back to /proc/mounts).
	if have findmnt; then
		root_src="$(findmnt -no SOURCE / 2>/dev/null || echo '')"
		boot_src="$(findmnt -no SOURCE /boot 2>/dev/null || echo '')"
	else
		root_src="$(awk '$2=="/"{print $1}' /proc/mounts 2>/dev/null | head -n1)"
		boot_src="$(awk '$2=="/boot"{print $1}' /proc/mounts 2>/dev/null | head -n1)"
	fi

	# Swap presence (swapon --show, fall back to /proc/swaps).
	if have swapon && [ -n "$(swapon --show=NAME --noheadings 2>/dev/null)" ]; then
		swap_present=1
	elif [ -s /proc/swaps ] && [ "$(grep -c -v '^Filename' /proc/swaps 2>/dev/null)" -gt 0 ] 2>/dev/null; then
		swap_present=1
	fi

	if [ -n "$root_src" ]; then
		pass R6 "root partition present: / backed by $root_src"
	else
		fail R6 "could not determine the partition backing /"
	fi
	if [ -n "$boot_src" ]; then
		pass R6 "/boot partition present: /boot backed by $boot_src"
	else
		fail R6 "/boot does not appear to be a separate mount (at least 3 partitions required: root, /boot, swap)"
	fi
	if [ "$swap_present" -eq 1 ]; then
		pass R6 "swap partition active (swapon/proc/swaps)"
	else
		fail R6 "no active swap found (swapon --show / /proc/swaps both empty)"
	fi
}

# R8 — A kernel-module loader (like udev). systemd variant: systemd-udevd.
chk_module_loader() {
	local active="" lsmod_out=""
	if have systemctl; then
		active="$(systemctl is-active systemd-udevd 2>/dev/null || true)"
	fi
	if [ "$active" = "active" ]; then
		pass R8 "systemd-udevd is active (kernel-module loader / udev replacement)"
	else
		fail R8 "systemd-udevd is not active (is-active='${active:-unknown}'); module loader required"
	fi
	if have modprobe; then
		pass R8 "modprobe present (module load tooling available)"
	else
		fail R8 "modprobe not found on PATH (kmod / module loading missing)"
	fi
	if have lsmod; then
		lsmod_out="$(lsmod 2>/dev/null | tail -n +2)"
		if [ -n "$lsmod_out" ]; then
			pass R8 "lsmod reports loaded modules"
		else
			warn R8 "lsmod is empty (a fully-monolithic kernel can be legitimate, but udev/module support is expected)"
		fi
	else
		fail R8 "lsmod not found (kmod missing)"
	fi
}

# R9 — Central management / configuration software (SysV or SystemD).
chk_init_is_systemd() {
	local initpath state
	initpath="$(readlink -f /sbin/init 2>/dev/null || echo '')"
	if printf '%s' "$initpath" | grep -q 'systemd'; then
		pass R9 "/sbin/init resolves to systemd ($initpath) — PID 1 is systemd"
	else
		fail R9 "/sbin/init resolves to '${initpath:-<none>}', not systemd"
	fi
	if have systemctl; then
		state="$(systemctl is-system-running 2>/dev/null || true)"
		case "$state" in
			running) pass R9 "systemctl is-system-running: running" ;;
			degraded) warn R9 "systemctl is-system-running: degraded (some units failed — inspect 'systemctl --failed')" ;;
			"") warn R9 "systemctl is-system-running returned nothing (still booting?)" ;;
			*) warn R9 "systemctl is-system-running: $state" ;;
		esac
	else
		fail R9 "systemctl not found — systemd is not installed/managing the system"
	fi
}

# R10 — A bootloader (LILO/GRUB). We use GRUB.
chk_grub() {
	local cfg=""
	if [ -f /boot/grub/grub.cfg ]; then
		cfg=/boot/grub/grub.cfg
	elif [ -f /boot/grub2/grub.cfg ]; then
		cfg=/boot/grub2/grub.cfg
	fi
	if [ -n "$cfg" ]; then
		pass R10 "GRUB config present at $cfg"
		if grep -Eq "vmlinuz-.*-$LOGIN" "$cfg" 2>/dev/null; then
			pass R10 "grub.cfg has a menuentry referencing vmlinuz-*-$LOGIN"
		else
			fail R10 "grub.cfg does not reference vmlinuz-*-$LOGIN (bootloader must point at the named kernel)"
		fi
	else
		fail R10 "no /boot/grub/grub.cfg (nor grub2) found"
	fi
	if have grub-mkconfig || have grub2-mkconfig; then
		pass R10 "grub-mkconfig present (GRUB tooling installed)"
	else
		warn R10 "grub-mkconfig not found on PATH (GRUB may still be installed via grub-install)"
	fi
}

# R11 — FHS-compliant filesystem hierarchy.
chk_fhs_dirs() {
	local d missing=0
	for d in /bin /sbin /etc /lib /usr/bin /usr/lib /var /boot /root /home /tmp /proc /sys /dev; do
		if [ -e "$d" ]; then
			:
		else
			fail R11 "required FHS path missing: $d"
			missing=1
		fi
	done
	if [ "$missing" -eq 0 ]; then
		pass R11 "all required FHS directories present (/bin /sbin /etc /lib /usr/bin /usr/lib /var /boot /root /home /tmp /proc /sys /dev)"
	fi
}

# R12 — Connect to the Internet (goals.md). DNS first, then ping.
chk_network() {
	local dns_ok=0
	if have getent && getent hosts gnu.org >/dev/null 2>&1; then
		dns_ok=1
		pass R12 "DNS resolution works (getent hosts gnu.org)"
	else
		fail R12 "DNS resolution failed (getent hosts gnu.org) — networking not configured"
	fi
	# Ping reachability (warn-only when DNS is fine, since ICMP is often blocked).
	if have ping && ping -c1 -W3 gnu.org >/dev/null 2>&1; then
		pass R12 "ping reaches gnu.org (ICMP)"
	elif [ "$dns_ok" -eq 1 ]; then
		warn R12 "ping to gnu.org failed but DNS works (ICMP may be blocked by the network — usually fine)"
	else
		fail R12 "ping to gnu.org failed and DNS also failed — no Internet connectivity"
	fi
}

# R13 — MUST be able to download source code (curl or wget). Eval prerequisite.
chk_download_tool() {
	if have curl; then
		pass R13 "curl present (can download sources)"
	elif have wget; then
		pass R13 "wget present (can download sources)"
	else
		fail R13 "neither curl nor wget found — evaluation requires a download tool"
	fi
}

# R14 — MUST be able to install/build packages: a working build toolchain.
chk_build_toolchain() {
	local c missing=0
	for c in gcc make tar xz patch; do
		if have "$c"; then
			:
		else
			fail R14 "build tool missing: $c"
			missing=1
		fi
	done
	[ "$missing" -eq 0 ] && pass R14 "core build toolchain present (gcc make tar xz patch)"

	# Smoke compile (warn-only — a build env hiccup must not fail the mandatory).
	if have gcc; then
		if printf 'int main(){return 0;}\n' | gcc -xc - -o /tmp/.vt 2>/dev/null && [ -x /tmp/.vt ]; then
			pass R14 "gcc smoke compile succeeded (/tmp/.vt built)"
		else
			warn R14 "gcc smoke compile failed (gcc present but could not build a trivial program)"
		fi
		rm -f /tmp/.vt 2>/dev/null || true
	fi
}

# -----------------------------------------------------------------------------
# R15 — All 68 spec packages installed. Data-driven probe map.
# -----------------------------------------------------------------------------
# Each line of PKG_PROBE is:   <Package label>|<probe-type>:<arg>[;<probe>...]
# Probe types (any one matching = present):
#   bin:NAME     -> command -v NAME            (binary on PATH)
#   lib:NAME     -> ldconfig -p | grep NAME    (shared library known to loader)
#   man:NAME     -> man -w NAME / find manpath (a man page exists)
#   file:PATH    -> [ -e PATH ]                (a specific file/dir exists)
#   svc:UNIT     -> systemctl cat/status UNIT  (a systemd unit exists)
#   mod:NAME     -> perl -M<NAME> -e1          (a Perl module is loadable)
# Multiple alternatives separated by ';' — the package passes if ANY matches.
#
# SUBSTITUTIONS (systemd variant — see docs/03-systemd-deviation.md):
#   Eudev            -> probe systemd-udevd (svc + binary)
#   Udev-lfs Tarball -> covered by systemd-udevd (the udev rules ship with systemd)
#   Sysvinit         -> probe /sbin/init -> systemd
#   Sysklogd         -> probe journalctl (systemd-journald)
# -----------------------------------------------------------------------------
PKG_PROBE='
Acl|bin:getfacl;lib:libacl.so
Attr|bin:getfattr;lib:libattr.so
Autoconf|bin:autoconf
Automake|bin:automake
Bash|bin:bash
Bc|bin:bc
Binutils|bin:ld;bin:as
Bison|bin:bison
Bzip2|bin:bzip2;lib:libbz2.so
Check|lib:libcheck.so;file:/usr/lib/pkgconfig/check.pc;file:/usr/lib64/pkgconfig/check.pc
Coreutils|bin:cat;bin:ls;bin:cp
DejaGNU|bin:runtest
Diffutils|bin:diff
Eudev (-> systemd-udevd)|svc:systemd-udevd;file:/usr/lib/systemd/systemd-udevd;file:/lib/systemd/systemd-udevd;bin:udevadm
E2fsprogs|bin:mke2fs;bin:mkfs.ext4
Expat|lib:libexpat.so
Expect|bin:expect
File|bin:file;lib:libmagic.so
Findutils|bin:find
Flex|bin:flex
Gawk|bin:gawk;bin:awk
GCC|bin:gcc;bin:g++
GDBM|lib:libgdbm.so;bin:gdbmtool
Gettext|bin:gettext;bin:msgfmt
Glibc|lib:libc.so;file:/usr/bin/ldd
GMP|lib:libgmp.so
Gperf|bin:gperf
Grep|bin:grep
Groff|bin:groff
GRUB|bin:grub-install;bin:grub-mkconfig;bin:grub2-install
Gzip|bin:gzip
Iana-Etc|file:/etc/protocols;file:/etc/services
Inetutils|bin:ping;bin:ftp;bin:hostname
Intltool|bin:intltoolize
IPRoute2|bin:ip;bin:ss
Kbd|bin:loadkeys;bin:setfont
Kmod|bin:kmod;bin:modprobe;bin:lsmod
Less|bin:less
Libcap|lib:libcap.so;bin:setcap
Libpipeline|lib:libpipeline.so
Libtool|bin:libtool;lib:libltdl.so
M4|bin:m4
Make|bin:make
Man-DB|bin:man;bin:mandb
Man-pages|file:/usr/share/man/man7/man-pages.7;file:/usr/share/man/man2/open.2;man:ascii
MPC|lib:libmpc.so
MPFR|lib:libmpfr.so
Ncurses|lib:libncursesw.so;lib:libncurses.so;bin:tic
Patch|bin:patch
Perl|bin:perl
Pkg-config|bin:pkg-config;bin:pkgconf
Procps|bin:ps;bin:top;bin:free
Psmisc|bin:killall;bin:fuser;bin:pstree
Readline|lib:libreadline.so
Sed|bin:sed
Shadow|bin:passwd;bin:useradd;bin:login
Sysklogd (-> systemd-journald)|bin:journalctl;svc:systemd-journald;file:/usr/lib/systemd/systemd-journald;file:/lib/systemd/systemd-journald
Sysvinit (-> systemd)|bin:systemctl;file:/usr/lib/systemd/systemd;file:/lib/systemd/systemd
Tar|bin:tar
Tcl|bin:tclsh;lib:libtcl
Texinfo|bin:makeinfo;bin:texi2any;bin:info
Time Zone Data|file:/usr/share/zoneinfo/UTC;file:/etc/localtime
Udev-lfs Tarball (-> systemd-udevd)|file:/usr/lib/udev/rules.d;file:/lib/udev/rules.d;bin:udevadm
Util-linux|bin:mount;bin:lsblk;bin:blkid
Vim|bin:vim;bin:vi
XML::Parser|file:/usr/lib/perl5/site_perl/XML/Parser.pm;mod:XML::Parser
Xz Utils|bin:xz;lib:liblzma.so
Zlib|lib:libz.so
'

# Probe helpers --------------------------------------------------------------
_probe_bin() { command -v "$1" >/dev/null 2>&1; }
_probe_lib() {
	# ldconfig is the authoritative loader cache; fall back to scanning libdirs.
	if have ldconfig && ldconfig -p 2>/dev/null | grep -q -- "$1"; then
		return 0
	fi
	local d
	for d in /usr/lib /usr/lib64 /lib /lib64 /usr/lib/x86_64-linux-gnu; do
		[ -d "$d" ] || continue
		# match e.g. libfoo.so / libfoo.so.1
		if ls "$d"/${1}* >/dev/null 2>&1; then return 0; fi
	done
	return 1
}
_probe_man() {
	if have man && man -w "$1" >/dev/null 2>&1; then return 0; fi
	return 1
}
_probe_file() { [ -e "$1" ]; }
_probe_mod() {
	have perl || return 1
	perl -M"$1" -e1 >/dev/null 2>&1
}
_probe_svc() {
	have systemctl || return 1
	# Unit exists if systemctl can describe it (active OR merely installed).
	systemctl cat "$1" >/dev/null 2>&1 && return 0
	systemctl status "$1" >/dev/null 2>&1 && return 0
	[ "$(systemctl is-active "$1" 2>/dev/null)" = "active" ] && return 0
	return 1
}

# Evaluate one ';'-separated probe spec; return 0 if ANY alternative matches.
_probe_eval() {
	local spec="$1" alt type arg
	local IFS=';'
	for alt in $spec; do
		[ -n "$alt" ] || continue
		type="${alt%%:*}"
		arg="${alt#*:}"
		case "$type" in
			bin)  _probe_bin  "$arg" && return 0 ;;
			lib)  _probe_lib  "$arg" && return 0 ;;
			man)  _probe_man  "$arg" && return 0 ;;
			file) _probe_file "$arg" && return 0 ;;
			mod)  _probe_mod  "$arg" && return 0 ;;
			svc)  _probe_svc  "$arg" && return 0 ;;
			*) : ;;
		esac
	done
	return 1
}

chk_packages() {
	local line label spec count=0 ok=0
	# Read the embedded table line by line.
	while IFS= read -r line; do
		[ -n "$line" ] || continue
		label="${line%%|*}"
		spec="${line#*|}"
		count=$((count + 1))
		if _probe_eval "$spec"; then
			ok=$((ok + 1))
			# Per-package PASS is verbose; keep it but tagged R15 so it is greppable.
			pass R15 "package present: $label"
		else
			fail R15 "package MISSING: $label  (probe: $spec)"
		fi
	done <<EOF
$(printf '%s\n' "$PKG_PROBE")
EOF
	printf '%s   R15 package summary: %d/%d probes satisfied%s\n' "$C_DIM" "$ok" "$count" "$C_RESET"
}

# -----------------------------------------------------------------------------
# Driver
# -----------------------------------------------------------------------------
main() {
	printf '%s' "$C_DIM"
	printf '====================================================================\n'
	printf ' ft_linux verify.sh — mandatory compliance self-check (login=%s)\n' "$LOGIN"
	printf '====================================================================\n'
	printf '%s' "$C_RESET"

	if [ "$(id -u 2>/dev/null || echo 1)" -ne 0 ]; then
		warn R0 "not running as root — some checks (swapon, systemctl, /etc reads) may be incomplete; re-run with: sudo bash verify/verify.sh"
	fi

	section "R1 virtual machine";          chk_vm
	section "R2 kernel version string";    chk_uname_has_skapers
	section "R3 kernel >= 4.0";            chk_kver_ge_4
	section "R4 kernel source path";       chk_kernel_src_path
	section "R5 boot binary name";         chk_boot_binary_name
	section "R6 >= 3 partitions";          chk_three_partitions
	section "R7 hostname";                 chk_hostname_skapers
	section "R8 module loader";            chk_module_loader
	section "R9 init = systemd";           chk_init_is_systemd
	section "R10 bootloader (GRUB)";       chk_grub
	section "R11 FHS hierarchy";           chk_fhs_dirs
	section "R12 internet";                chk_network
	section "R13 download tool";           chk_download_tool
	section "R14 build toolchain";         chk_build_toolchain
	section "R15 all 68 packages";         chk_packages

	# -------------------------------------------------------------------------
	# Summary
	# -------------------------------------------------------------------------
	printf '\n%s====================================================================%s\n' "$C_DIM" "$C_RESET"
	printf '%s%d passed%s, %s%d warnings%s, %s%d failed%s\n' \
		"$C_OK" "$PASS_COUNT" "$C_RESET" \
		"$C_WARN" "$WARN_COUNT" "$C_RESET" \
		"$C_ERR" "$FAIL_COUNT" "$C_RESET"

	if [ "$FAIL_COUNT" -eq 0 ]; then
		printf '%sMANDATORY PERFECT — bonus may be graded%s\n' "$C_OK" "$C_RESET"
	else
		printf '%s%d FAIL(s) above form your punch-list; fix and re-run.%s\n' "$C_ERR" "$FAIL_COUNT" "$C_RESET"
	fi

	# Exit code == number of FAILs (0 == perfect). Bash truncates to 0-255.
	exit "$FAIL_COUNT"
}

main "$@"
