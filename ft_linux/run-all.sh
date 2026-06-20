#!/bin/bash
# =============================================================================
# run-all.sh — master orchestrator for the ft_linux LFS (systemd) build
# =============================================================================
# Authored on macOS by agent A8 (Orchestrator & Integrator). It is RUN BY THE
# OPERATOR inside the Linux build VM (as root). It ties the ~150 authored files
# into one resumable, idempotent, logged pipeline that walks the LFS book from
# disk partitioning through the final system, kernel, GRUB and finalize.
#
# It NEVER builds anything itself — it sequences the per-phase scripts the
# authoring agents wrote, each of which does the real work. Resumability and
# idempotency come from the A0 state markers ($LFS/.ft_state/<id>.done) via
# run_step/is_done; a crash 18h into a build resumes by fast-forwarding past
# completed steps.
#
# QUICK START (see docs/RUNBOOK.md for the full story)
#     sudo ./run-all.sh --list                 # show the phase registry
#     sudo ./run-all.sh --status               # show recorded done markers
#     sudo ./run-all.sh --dry-run --yes        # print what WOULD run
#     sudo ./run-all.sh --yes                  # full end-to-end build
#     sudo ./run-all.sh --only toolchain --yes # one phase
#     sudo ./run-all.sh --from final --yes     # resume from a phase
#     sudo FORCE=1 ./run-all.sh --only kernel  # re-run a phase ignoring markers
#     sudo ./run-all.sh --redo final/binutils  # clear+rerun ONE step id
#
# The bonus (Xorg + WM) is NOT part of the default run. It is a separate,
# post-reboot, gated step:  sudo ./run-all.sh --only bonus  (or make bonus).
# =============================================================================

# --- Foundation bootstrap (A0 contract — VERBATIM) --------------------------
#!/bin/bash already set above; keep the contract block exactly as A0 prescribes.
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$SCRIPT_DIR"   # run-all.sh lives at repo root
# shellcheck source=env/lfs.env
source "$REPO_ROOT/env/lfs.env"
# shellcheck source=lib/common.sh
source "$REPO_ROOT/lib/common.sh"
# shellcheck source=lib/chroot-helpers.sh
source "$REPO_ROOT/lib/chroot-helpers.sh"

# =============================================================================
# Configuration / constants
# =============================================================================

# Where the repo becomes reachable INSIDE the chroot. We bind-mount (preferred)
# or copy $REPO_ROOT here so enter_chroot can run staged in-chroot scripts via
# their $LFS-relative path /opt/ft_linux/<...>.
CHROOT_REPO_MNT="/opt/ft_linux"                  # path *inside* the chroot ($LFS root = /)
CHROOT_REPO_HOSTPATH="$LFS$CHROOT_REPO_MNT"      # same dir as seen from the host

# The build-host helper account the toolchain/temp-tools phases must run as
# (created by scripts/02-setup-env.sh). Those scripts call require_not_root.
LFS_BUILD_USER="${LFS_BUILD_USER:-lfs}"

# Top-level orchestrator log (in addition to each step's $FT_LOG_DIR/<id>.log).
RUN_ALL_LOG="${FT_LOG_DIR:-./logs}/run-all.log"

# Runtime flags (set by argument parsing below).
OPT_DRY_RUN=0
OPT_ONLY=""        # run only this phase
OPT_FROM=""        # start from this phase (inclusive)
OPT_LIST=0
OPT_STATUS=0
OPT_REDO=""        # a single step-id to clear+rerun

# =============================================================================
# Phase registry
# =============================================================================
# The global build sequence, in order. Each phase has:
#   * a short name (used by --only / --from / make targets)
#   * a one-line description
#   * a "context" tag describing WHERE/AS-WHO it runs:
#       host-root   : on the build host, as root
#       host-lfs    : on the build host, as the 'lfs' user (require_not_root)
#       chroot      : inside the chroot, as root (via enter_chroot)
#       host-root!  : DESTRUCTIVE host-root step (needs --yes + confirmed disk)
#   * a dispatch function (phase_<name>) defined further down.
#
# 'bonus' is intentionally registered LAST and is NEVER included in a default or
# --from run (it is post-reboot + gated); it is reachable only via --only bonus.
#
# Format per line:  <name>|<context>|<description>
PHASE_REGISTRY=(
	"preflight|host-root|Preflight: tool/version + sources checksum checks"
	"partition|host-root!|Ch.2 DESTRUCTIVE: GPT-partition the target disk"
	"format|host-root|Ch.2 Format + mount the target partitions"
	"prep-env|host-root|Ch.4 Create the lfs build user + clean environment"
	"toolchain|host-lfs|Ch.5 Cross-toolchain (binutils/gcc/glibc/libstdc++)"
	"temp-tools|host-lfs|Ch.6 Cross-compiled temporary tools"
	"chroot-prep|host-root|Ch.7 chown + virtual FS + stage repo, ready to chroot"
	"chroot-tools|chroot|Ch.7 In-chroot dirs/files + additional tools + cleanup"
	"final|chroot|Ch.8 Final system: all packages from _order.txt"
	"config|chroot|Ch.9 System config: network/hostname/locale/fstab"
	"kernel|chroot|Ch.10 Build + install the -skapers kernel"
	"grub|chroot|Ch.10 Install GRUB + write grub.cfg"
	"finalize|chroot|Ch.11 Strip/clean + write the ft_linux identity files"
	"bonus|host-root|BLFS Xorg + window manager (post-reboot, GATED, opt-in)"
)

# Phases that comprise a default (no --only) end-to-end in-VM run, in order.
# NB: 'bonus' is deliberately excluded (separate, gated, post-reboot).
DEFAULT_PHASES=(
	preflight partition format prep-env toolchain temp-tools
	chroot-prep chroot-tools final config kernel grub finalize
)

# Lookup helpers over the registry -------------------------------------------
phase_field() { # phase_field <name> <1=name|2=context|3=desc>
	local want="$1" idx="$2" line
	for line in "${PHASE_REGISTRY[@]}"; do
		if [ "${line%%|*}" = "$want" ]; then
			printf '%s\n' "$line" | cut -d'|' -f"$idx"
			return 0
		fi
	done
	return 1
}
phase_exists() { phase_field "$1" 1 >/dev/null 2>&1; }

# =============================================================================
# Orchestrator-level logging (top-level run-all.log, on top of run_step's logs)
# =============================================================================
runlog() { # runlog <message...>  — append to RUN_ALL_LOG with a timestamp
	mkdir -p "$(dirname -- "$RUN_ALL_LOG")" 2>/dev/null || true
	printf '%s %s\n' "$(date -u +%Y-%m-%dT%H:%M:%SZ)" "$*" >>"$RUN_ALL_LOG" 2>/dev/null || true
}

# Phase summary accumulators (parallel arrays).
SUMMARY_PHASES=()
SUMMARY_RESULTS=()
SUMMARY_SECONDS=()

record_phase() { # record_phase <name> <result> <seconds>
	SUMMARY_PHASES+=("$1")
	SUMMARY_RESULTS+=("$2")
	SUMMARY_SECONDS+=("$3")
}

print_summary() {
	local i n result_color
	n="${#SUMMARY_PHASES[@]}"
	[ "$n" -eq 0 ] && return 0
	printf '\n%s========== run-all summary ==========%s\n' "$_C_INFO" "$_C_RESET" >&2
	for ((i = 0; i < n; i++)); do
		case "${SUMMARY_RESULTS[$i]}" in
			OK)      result_color="$_C_OK" ;;
			SKIP)    result_color="$_C_DIM" ;;
			DRY)     result_color="$_C_DIM" ;;
			FAIL)    result_color="$_C_ERR" ;;
			*)       result_color="$_C_WARN" ;;
		esac
		printf '  %s%-6s%s %-14s %ss\n' \
			"$result_color" "${SUMMARY_RESULTS[$i]}" "$_C_RESET" \
			"${SUMMARY_PHASES[$i]}" "${SUMMARY_SECONDS[$i]}" >&2
	done
	printf '%s=====================================%s\n' "$_C_INFO" "$_C_RESET" >&2
}

# =============================================================================
# Cleanup trap: always tear down the virtual filesystems we mounted.
# =============================================================================
_VKFS_MOUNTED=0   # set to 1 once we mount_virtual_fs so the trap knows to unmount

cleanup() {
	local rc=$?
	# Only attempt unmount if we mounted and we are root (we always are in chroot
	# phases). Best-effort; never let cleanup mask the real exit code.
	if [ "$_VKFS_MOUNTED" = "1" ] && [ "$(id -u)" -eq 0 ]; then
		log_info "cleanup: unmounting virtual kernel filesystems"
		umount_virtual_fs || log_warn "cleanup: umount_virtual_fs reported an issue"
	fi
	print_summary
	exit "$rc"
}
trap cleanup EXIT INT TERM

# need_root
#   Like require_root, but a NO-OP under --dry-run so the plan can be previewed
#   on a non-root host (e.g. the macOS host before the VM exists). In a real run
#   it enforces root just like require_root.
need_root() {
	[ "$OPT_DRY_RUN" = "1" ] && return 0
	require_root
}

# =============================================================================
# Generic step runner that respects --dry-run
# =============================================================================
# do_run <step-id> <description> -- <cmd...>
#   Thin wrapper over run_step that honours --dry-run (prints, does not execute)
#   and records nothing extra (run_step already marks/logs). Returns the step rc.
do_run() {
	local id="$1"; shift
	local desc="$1"; shift
	[ "${1:-}" = "--" ] || die "do_run: expected -- before command (id=$id)"
	shift
	if [ "$OPT_DRY_RUN" = "1" ]; then
		if is_done "$id" && [ "${FORCE:-0}" != "1" ]; then
			log_info "DRY  $id — would SKIP (already done)"
		else
			log_info "DRY  $id — would run: $*"
		fi
		return 0
	fi
	run_step "$id" "$desc" -- "$@"
}

# =============================================================================
# CHROOT WIRING (CRITICAL)
# =============================================================================
# stage_repo_into_lfs
#   Make the whole repo (env/, lib/, scripts/, etc.) reachable from INSIDE the
#   chroot at $CHROOT_REPO_MNT (/opt/ft_linux). The in-chroot scripts bootstrap
#   by searching upward for env/lfs.env, so the repo must be visible there.
#   We prefer a bind mount (no copy, always fresh); fall back to a recursive
#   copy on hosts where bind-mounting the repo is awkward. Idempotent.
#
#   We ALSO ensure the sources are visible at /sources inside the chroot. The
#   standard LFS layout keeps tarballs at $LFS/sources, which inside the chroot
#   is simply /sources — so it is already correct. We additionally bind-mount it
#   to be defensive if SOURCES_DIR was overridden to a non-$LFS path, because
#   33-additional-tools.sh and several final-system scripts re-point SOURCES_DIR
#   to /sources when that directory exists.
stage_repo_into_lfs() {
	[ "$OPT_DRY_RUN" = "1" ] && { log_info "DRY  would stage repo at $CHROOT_REPO_HOSTPATH"; return 0; }
	require_root
	: "${LFS:?}"

	mkdir -p "$CHROOT_REPO_HOSTPATH"
	if mountpoint -q "$CHROOT_REPO_HOSTPATH"; then
		log_info "repo already bind-mounted at $CHROOT_REPO_HOSTPATH"
	elif mount --bind "$REPO_ROOT" "$CHROOT_REPO_HOSTPATH" 2>/dev/null; then
		log_ok "repo bind-mounted: $REPO_ROOT -> $CHROOT_REPO_HOSTPATH (in-chroot: $CHROOT_REPO_MNT)"
		# Mark for teardown alongside the vkfs.
		_VKFS_MOUNTED=1
	else
		log_warn "bind mount failed; falling back to copying the repo into $CHROOT_REPO_HOSTPATH"
		# Copy everything except the bulky/host-only artifacts.
		( cd "$REPO_ROOT" && \
		  tar --exclude='./.git' --exclude='./logs' --exclude='*.vdi' \
		      --exclude='*.iso' --exclude='./sources/*.tar.*' -cf - . ) \
		  | ( cd "$CHROOT_REPO_HOSTPATH" && tar -xf - )
		log_ok "repo copied into $CHROOT_REPO_HOSTPATH"
	fi

	# Ensure /sources is populated inside the chroot. With the canonical layout
	# (SOURCES_DIR=$LFS/sources) it already is. If someone set SOURCES_DIR
	# elsewhere, bind it onto $LFS/sources so /sources works in-chroot.
	if [ "$SOURCES_DIR" != "$LFS/sources" ]; then
		mkdir -p "$LFS/sources"
		if ! mountpoint -q "$LFS/sources"; then
			mount --bind "$SOURCES_DIR" "$LFS/sources" 2>/dev/null \
				|| log_warn "could not bind $SOURCES_DIR onto $LFS/sources; ensure tarballs are visible at /sources inside chroot"
		fi
	fi
}

# ensure_chroot_ready
#   Mount the virtual kernel filesystems and stage the repo. Safe to call more
#   than once (mount_virtual_fs + stage_repo_into_lfs are idempotent).
ensure_chroot_ready() {
	[ "$OPT_DRY_RUN" = "1" ] && { log_info "DRY  would mount virtual FS + stage repo under $LFS"; return 0; }
	require_root
	mount_virtual_fs
	_VKFS_MOUNTED=1
	stage_repo_into_lfs
}

# in_chroot_run <step-id> <description> <repo-relative-script>
#   Run one repo script INSIDE the chroot via enter_chroot, addressing it by its
#   $LFS-relative staged path ($CHROOT_REPO_MNT/<repo-relative-script>). The
#   chrooted script re-sources env/lib by searching upward, and writes its own
#   markers/logs under /mnt/lfs/.ft_state and the in-system log dir. We still
#   wrap the enter_chroot call in run_step so the orchestrator records a marker
#   for the whole in-chroot invocation and tees a top-level log. The inner script
#   ALSO records its own finer-grained markers — both are harmless and aid resume.
in_chroot_run() {
	local id="$1" desc="$2" rel="$3"
	local inner="$CHROOT_REPO_MNT/$rel"
	# Verify the script exists on the host side before we try to run it in chroot.
	if [ ! -f "$REPO_ROOT/$rel" ]; then
		die "in_chroot_run: missing script $REPO_ROOT/$rel (registry/path mismatch)"
	fi
	do_run "$id" "$desc" -- enter_chroot "$inner"
}

# host_lfs_run <step-id> <description> <repo-relative-script>
#   Run one repo script on the build HOST as the unprivileged 'lfs' user (the
#   toolchain/temp-tools phases require_not_root). We invoke a login shell for
#   lfs (so its ~/.bash_profile/.bashrc set the clean LFS env + toolchain PATH),
#   then exec our script. We export the shared state/log dirs into that shell so
#   markers + logs stay unified with the root-run phases. The state/log dirs are
#   made writable by lfs in prepare_lfs_writable() before this phase runs.
host_lfs_run() {
	local id="$1" desc="$2" rel="$3"
	local abs="$REPO_ROOT/$rel"
	[ -f "$abs" ] || die "host_lfs_run: missing script $abs (registry/path mismatch)"
	# Build the command the lfs login shell will run. We pass the shared dirs and
	# FORCE/STRICT through explicitly because env -i in .bash_profile wipes them.
	local cmd
	cmd=$(printf 'FT_STATE_DIR=%q FT_LOG_DIR=%q FORCE=%q STRICT=%q ASSUME_YES=%q bash %q' \
		"$FT_STATE_DIR" "$FT_LOG_DIR" "${FORCE:-0}" "${STRICT:-0}" "${ASSUME_YES:-0}" "$abs")
	if [ "$OPT_DRY_RUN" = "1" ]; then
		log_info "DRY  $id — would run as '$LFS_BUILD_USER': $abs"
		return 0
	fi
	# run_step wraps the su invocation so we get a unified marker + top log too.
	run_step "$id" "$desc" -- su - "$LFS_BUILD_USER" -c "$cmd"
}

# prepare_lfs_writable
#   The shared state + log dirs live under $LFS (root-owned, created by
#   01-format-mount.sh). The host-lfs phases run as 'lfs' and must write their
#   markers + logs there, so grant the lfs user access. Idempotent.
prepare_lfs_writable() {
	[ "$OPT_DRY_RUN" = "1" ] && return 0
	require_root
	mkdir -p "$FT_STATE_DIR" "$FT_LOG_DIR"
	if id "$LFS_BUILD_USER" >/dev/null 2>&1; then
		chown -R "$LFS_BUILD_USER" "$FT_STATE_DIR" "$FT_LOG_DIR" 2>/dev/null \
			|| chmod -R a+rwX "$FT_STATE_DIR" "$FT_LOG_DIR" 2>/dev/null || true
	else
		# lfs user not created yet (we are before prep-env): make world-writable
		# so the upcoming phases can write; ownership is fixed once lfs exists.
		chmod -R a+rwX "$FT_STATE_DIR" "$FT_LOG_DIR" 2>/dev/null || true
	fi
}

# =============================================================================
# Per-phase dispatch functions
# =============================================================================
# Each reads the source-of-truth ordering where one exists (_order.txt) and runs
# every script through the right runner (do_run / in_chroot_run / host_lfs_run).

# ---- preflight -------------------------------------------------------------
phase_preflight() {
	need_root
	# version-check.sh exits non-zero if the host is missing required tools.
	do_run "preflight/version-check" "Host tool/version check" -- \
		bash "$REPO_ROOT/vm/version-check.sh"
	# verify-sources.sh checks the downloaded tarballs against md5sums.
	do_run "preflight/verify-sources" "Verify source tarball checksums" -- \
		bash "$REPO_ROOT/sources/verify-sources.sh"
}

# ---- partition (DESTRUCTIVE) ----------------------------------------------
phase_partition() {
	need_root
	# Hard guard: refuse unless the operator confirmed via --yes AND $LFS_DISK is
	# a real block device. This protects the build host's own disk.
	if [ "${ASSUME_YES:-0}" != "1" ]; then
		die "refusing destructive partition of $LFS_DISK without --yes (re-run with --yes once you have CONFIRMED LFS_DISK is the TARGET disk, e.g. /dev/sdb)"
	fi
	# Under --dry-run we only PREVIEW (no disk exists on a macOS preview host), so
	# the block-device + confirm guards are bypassed; they still fire in a real run
	# (and scripts/00-partition-disk.sh re-checks the device + the host-root disk).
	if [ "$OPT_DRY_RUN" != "1" ]; then
		[ -b "$LFS_DISK" ] || die "LFS_DISK ($LFS_DISK) is not a block device — set LFS_DISK to the target disk and re-run"
		log_warn "About to PARTITION (ERASE) $LFS_DISK — boot=$LFS_DISK_BOOT swap=$LFS_DISK_SWAP root=$LFS_DISK_ROOT"
		if ! confirm "Proceed to ERASE and repartition $LFS_DISK?"; then
			die "aborted by operator"
		fi
	fi
	do_run "00-partition-disk" "GPT-partition $LFS_DISK (>=3 partitions)" -- \
		bash "$REPO_ROOT/scripts/00-partition-disk.sh"
}

# ---- format ----------------------------------------------------------------
phase_format() {
	need_root
	do_run "01-format-mount" "Format + mount target partitions under $LFS" -- \
		bash "$REPO_ROOT/scripts/01-format-mount.sh"
}

# ---- prep-env --------------------------------------------------------------
phase_prep_env() {
	need_root
	do_run "02-setup-env" "Create the lfs build user + clean environment" -- \
		bash "$REPO_ROOT/scripts/02-setup-env.sh"
	# Now that lfs exists, hand it the shared state/log dirs for the next phases.
	prepare_lfs_writable
}

# ---- toolchain (run as lfs) -----------------------------------------------
phase_toolchain() {
	need_root   # the orchestrator is root; it drops to lfs per-script.
	prepare_lfs_writable
	local s
	for s in 10-binutils-pass1 11-gcc-pass1 12-linux-api-headers 13-glibc 14-libstdcxx; do
		host_lfs_run "toolchain/$s" "Ch.5 $s" "scripts/toolchain/$s.sh"
	done
}

# ---- temp-tools (run as lfs, order from _order.txt) -----------------------
phase_temp_tools() {
	need_root
	prepare_lfs_writable
	local order="$REPO_ROOT/scripts/temp-tools/_order.txt" f id
	[ -f "$order" ] || die "missing $order"
	while IFS= read -r f; do
		case "$f" in ''|\#*) continue ;; esac
		id="temp-tools/${f%.sh}"
		host_lfs_run "$id" "Ch.6 ${f%.sh}" "scripts/temp-tools/$f"
	done < "$order"
}

# ---- chroot-prep (host root: chown, mount vkfs, stage repo) ----------------
phase_chroot_prep() {
	need_root
	# 30-prepare-virtual-fs.sh does the chown + mount_virtual_fs + device nodes.
	do_run "30-prepare-virtual-fs" "Ch.7 chown + mount virtual FS" -- \
		bash "$REPO_ROOT/scripts/chroot/30-prepare-virtual-fs.sh"
	# After that, virtual FS is mounted; stage the repo so chroot scripts resolve.
	_VKFS_MOUNTED=1
	if [ "$OPT_DRY_RUN" != "1" ]; then
		stage_repo_into_lfs
	else
		log_info "DRY  chroot-prep — would stage repo at $CHROOT_REPO_HOSTPATH"
	fi
}

# ---- chroot-tools (in chroot: 32, 33, 34) ----------------------------------
phase_chroot_tools() {
	need_root
	ensure_chroot_ready
	in_chroot_run "chroot/32-create-dirs-files" "Ch.7 FHS dirs + essential files" \
		"scripts/chroot/32-create-dirs-files.sh"
	in_chroot_run "chroot/33-additional-tools" "Ch.7 additional temp tools" \
		"scripts/chroot/33-additional-tools.sh"
	in_chroot_run "chroot/34-cleanup-temp" "Ch.7 cleanup temp system" \
		"scripts/chroot/34-cleanup-temp.sh"
}

# ---- final (in chroot: every script from _order.txt) -----------------------
phase_final() {
	need_root
	ensure_chroot_ready
	local order="$REPO_ROOT/scripts/final-system/_order.txt" f id
	[ -f "$order" ] || die "missing $order"
	while IFS= read -r f; do
		case "$f" in ''|\#*) continue ;; esac
		id="final-system/${f%.sh}"
		in_chroot_run "$id" "Ch.8 ${f%.sh}" "scripts/final-system/$f"
	done < "$order"
}

# ---- config (in chroot: 50..54) --------------------------------------------
phase_config() {
	need_root
	ensure_chroot_ready
	local s
	for s in 50-network-systemd 51-hostname 52-locale-clock-console 53-fstab 54-inputrc-shells-etc; do
		in_chroot_run "system-config/$s" "Ch.9 $s" "scripts/system-config/$s.sh"
	done
}

# ---- kernel (in chroot: 60,61,62) ------------------------------------------
phase_kernel() {
	need_root
	ensure_chroot_ready
	local s
	for s in 60-kernel-prepare 61-kernel-build 62-kernel-install; do
		in_chroot_run "kernel/$s" "Ch.10 $s" "scripts/kernel/$s.sh"
	done
}

# ---- grub (in chroot: 70,71) -----------------------------------------------
phase_grub() {
	need_root
	ensure_chroot_ready
	local s
	for s in 70-grub-install 71-grub-cfg; do
		in_chroot_run "boot/$s" "Ch.10 $s" "scripts/boot/$s.sh"
	done
}

# ---- finalize (in chroot: 80, 81 — 90 is host-side, EXCLUDED) --------------
phase_finalize() {
	need_root
	ensure_chroot_ready
	in_chroot_run "finalize/80-final-cleanup" "Ch.11 strip + clean" \
		"scripts/finalize/80-final-cleanup.sh"
	in_chroot_run "finalize/81-end-message" "Ch.11 ft_linux identity files" \
		"scripts/finalize/81-end-message.sh"
	log_info "finalize/90-make-checksum.sh is HOST-side (run AFTER reboot+poweroff): make checksum"
}

# ---- bonus (post-reboot, gated, opt-in) ------------------------------------
phase_bonus() {
	# The bonus runs on the BOOTED ft_linux system (post-reboot), not in chroot.
	# We simply hand off to bonus/run-bonus.sh, which gates itself on verify.sh
	# and says so in its header. Not part of any default/--from sequence.
	log_warn "bonus is graded ONLY if mandatory is perfect (verify.sh == 0). It runs on the BOOTED system."
	do_run "bonus/run-bonus" "BLFS Xorg + window manager" -- \
		bash "$REPO_ROOT/bonus/run-bonus.sh"
}

# Dispatch a phase by name -> its function.
dispatch_phase() {
	local name="$1"
	local fn="phase_${name//-/_}"
	if ! declare -F "$fn" >/dev/null 2>&1; then
		die "no dispatch function for phase '$name' (expected $fn)"
	fi
	"$fn"
}

# =============================================================================
# Top-level phase driver (timing + summary + run-all.log)
# =============================================================================
run_phase() {
	local name="$1" desc start end elapsed rc
	desc="$(phase_field "$name" 3 || echo "$name")"
	log_info "PHASE $name — $desc"
	runlog "PHASE START $name — $desc"
	start=$(date +%s)
	rc=0
	dispatch_phase "$name" || rc=$?
	end=$(date +%s)
	elapsed=$(( end - start ))
	if [ "$rc" -eq 0 ]; then
		if [ "$OPT_DRY_RUN" = "1" ]; then
			record_phase "$name" "DRY" "$elapsed"
			runlog "PHASE DRY   $name (${elapsed}s)"
		else
			record_phase "$name" "OK" "$elapsed"
			log_ok "PHASE DONE $name — ${elapsed}s"
			runlog "PHASE OK    $name (${elapsed}s)"
		fi
	else
		record_phase "$name" "FAIL" "$elapsed"
		runlog "PHASE FAIL  $name rc=$rc (${elapsed}s)"
		log_error "PHASE FAIL $name — exit $rc after ${elapsed}s"
		return "$rc"
	fi
}

# Build the ordered list of phases to run given --only / --from.
plan_phases() {
	local p started
	if [ -n "$OPT_ONLY" ]; then
		phase_exists "$OPT_ONLY" || die "unknown phase '$OPT_ONLY' (see --list)"
		printf '%s\n' "$OPT_ONLY"
		return 0
	fi
	if [ -n "$OPT_FROM" ]; then
		phase_exists "$OPT_FROM" || die "unknown phase '$OPT_FROM' (see --list)"
		started=0
		for p in "${DEFAULT_PHASES[@]}"; do
			[ "$p" = "$OPT_FROM" ] && started=1
			[ "$started" = "1" ] && printf '%s\n' "$p"
		done
		return 0
	fi
	# Default: the full in-VM sequence (bonus excluded).
	printf '%s\n' "${DEFAULT_PHASES[@]}"
}

# =============================================================================
# --list / --status / --redo
# =============================================================================
do_list() {
	printf '%sPhase registry (build order):%s\n' "$_C_INFO" "$_C_RESET"
	local line name ctx desc tag
	for line in "${PHASE_REGISTRY[@]}"; do
		name="${line%%|*}"
		ctx="$(printf '%s' "$line" | cut -d'|' -f2)"
		desc="$(printf '%s' "$line" | cut -d'|' -f3)"
		case "$name" in
			bonus) tag="  (opt-in: --only bonus)";;
			*)     tag="";;
		esac
		printf '  %-13s [%-10s] %s%s\n' "$name" "$ctx" "$desc" "$tag"
	done
	printf '\nDefault end-to-end order: %s\n' "${DEFAULT_PHASES[*]}"
	printf 'Run a single phase:  ./run-all.sh --only <name> --yes\n'
	printf 'Resume from a phase: ./run-all.sh --from <name> --yes\n'
}

do_status() {
	printf '%sRecorded done markers (%s):%s\n' "$_C_INFO" "$FT_STATE_DIR" "$_C_RESET"
	if ! list_state | grep -q .; then
		printf '  (none yet)\n'
	else
		list_state
	fi
}

do_redo() {
	local id="$1"
	log_info "clearing marker for step '$id' so it re-runs"
	clear_done "$id"
	log_ok "cleared $id — re-run the owning phase (or full build) to rebuild it"
}

# =============================================================================
# Argument parsing
# =============================================================================
usage() {
	cat <<'EOF'
run-all.sh — ft_linux master orchestrator

USAGE
  sudo ./run-all.sh [flags]

FLAGS
  --list             Print the phase registry (build order) and exit.
  --status           Print recorded done markers (list_state) and exit.
  --only <phase>     Run exactly one phase (see --list for names).
  --from <phase>     Run the default sequence starting at <phase> (inclusive).
  --redo <step-id>   Clear one step's done-marker (e.g. final/binutils) and exit.
  --dry-run          Print what WOULD run; do not execute anything.
  --yes              Assume "yes" (ASSUME_YES=1); REQUIRED for the destructive
                     partition phase. Confirm LFS_DISK first!
  -h, --help         This help.

ENV KNOBS
  FORCE=1            Re-run steps even if their marker exists.
  STRICT=1           Make optional test-suite failures fatal (passed through).
  LFS_DISK=/dev/sdX  Override the target disk (default /dev/sdb).

EXAMPLES
  sudo ./run-all.sh --list
  sudo ./run-all.sh --dry-run --yes
  sudo ./run-all.sh --yes                 # full build
  sudo ./run-all.sh --only toolchain --yes
  sudo ./run-all.sh --from final --yes
  sudo ./run-all.sh --only bonus          # post-reboot, gated

The bonus is never part of a default/--from run; use --only bonus.
See docs/RUNBOOK.md for the full end-to-end procedure.
EOF
}

parse_args() {
	while [ "$#" -gt 0 ]; do
		case "$1" in
			--list) OPT_LIST=1 ;;
			--status) OPT_STATUS=1 ;;
			--dry-run) OPT_DRY_RUN=1 ;;
			--yes) ASSUME_YES=1; export ASSUME_YES ;;
			--only) shift; [ "$#" -gt 0 ] || die "--only needs a phase name"; OPT_ONLY="$1" ;;
			--only=*) OPT_ONLY="${1#*=}" ;;
			--from) shift; [ "$#" -gt 0 ] || die "--from needs a phase name"; OPT_FROM="$1" ;;
			--from=*) OPT_FROM="${1#*=}" ;;
			--redo) shift; [ "$#" -gt 0 ] || die "--redo needs a step-id"; OPT_REDO="$1" ;;
			--redo=*) OPT_REDO="${1#*=}" ;;
			-h|--help) usage; exit 0 ;;
			*) die "unknown argument: $1 (try --help)" ;;
		esac
		shift
	done
	if [ -n "$OPT_ONLY" ] && [ -n "$OPT_FROM" ]; then
		die "--only and --from are mutually exclusive"
	fi
	# Validate phase names HERE (parse_args runs in the main shell), so an unknown
	# name produces a precise error rather than a downstream "no phases to run".
	if [ -n "$OPT_ONLY" ]; then
		phase_exists "$OPT_ONLY" || die "unknown phase '$OPT_ONLY' (see ./run-all.sh --list)"
	fi
	if [ -n "$OPT_FROM" ]; then
		phase_exists "$OPT_FROM" || die "unknown phase '$OPT_FROM' (see ./run-all.sh --list)"
	fi
}

# =============================================================================
# main
# =============================================================================
main() {
	parse_args "$@"

	# Informational / non-executing modes first (no root needed).
	if [ "$OPT_LIST" = "1" ]; then do_list; exit 0; fi
	if [ "$OPT_STATUS" = "1" ]; then do_status; exit 0; fi
	if [ -n "$OPT_REDO" ]; then do_redo "$OPT_REDO"; exit 0; fi

	# Everything below executes build steps -> must be root (we chroot, mount,
	# su to lfs). Allow --dry-run to proceed without root so users can preview.
	if [ "$OPT_DRY_RUN" != "1" ] && [ "$(id -u)" -ne 0 ]; then
		die "run-all.sh must run as root (it partitions, mounts, chroots, and su's to '$LFS_BUILD_USER'). Try: sudo ./run-all.sh ..."
	fi

	log_info "ft_linux orchestrator starting (LFS=$LFS, LFS_DISK=$LFS_DISK, login=$LFS_USER_LOGIN)"
	log_info "state dir: $FT_STATE_DIR   log dir: $FT_LOG_DIR"
	runlog "==== run-all.sh start (only='$OPT_ONLY' from='$OPT_FROM' dry=$OPT_DRY_RUN yes=${ASSUME_YES:-0}) ===="

	# Compute the plan and execute it. A phase failure aborts (resume re-runs it).
	# Read the plan into an array WITHOUT mapfile, so this also works under the
	# older bash (3.2) found on a macOS preview host doing --dry-run.
	local phases=() phase
	while IFS= read -r phase; do
		[ -n "$phase" ] && phases+=("$phase")
	done < <(plan_phases)
	[ "${#phases[@]}" -gt 0 ] || die "no phases to run"

	for phase in "${phases[@]}"; do
		run_phase "$phase"
	done

	log_ok "all requested phases completed"
	if [ -z "$OPT_ONLY" ]; then
		log_info "NEXT: reboot the VM into ft_linux, then run:  bash verify/verify.sh"
		log_info "      (then optionally:  sudo ./run-all.sh --only bonus  and  make checksum)"
	fi
}

main "$@"
