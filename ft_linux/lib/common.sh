# shellcheck shell=bash
#
# lib/common.sh — shared logging, guards, and the run_step wrapper
# =============================================================================
# Source AFTER env/lfs.env. It auto-sources lib/state.sh (for run_step's
# idempotency integration) if not already loaded.
#
#     source "<repo>/env/lfs.env"
#     source "<repo>/lib/common.sh"
#
# Callers are assumed to run with `set -euo pipefail`. The functions here are
# careful not to abort the shell on benign non-zero returns (e.g. `confirm`).
#
# All log output goes to STDERR (so stdout stays clean for data/pipes) and is
# timestamped. Colors are auto-disabled when stderr is not a TTY or when
# NO_COLOR is set (https://no-color.org).
# =============================================================================

# Guard against double-sourcing.
[ -n "${_FT_COMMON_SH_LOADED:-}" ] && return 0
_FT_COMMON_SH_LOADED=1

# Pull in state helpers (is_done/mark_done) used by run_step. Resolve relative
# to this file so it works no matter the caller's CWD.
_FT_COMMON_DIR="$(CDPATH= cd -- "$(dirname -- "${BASH_SOURCE[0]:-$0}")" && pwd -P)"
if [ -z "${_FT_STATE_SH_LOADED:-}" ]; then
	# shellcheck source=./state.sh
	. "$_FT_COMMON_DIR/state.sh"
fi

# -----------------------------------------------------------------------------
# Color setup
# -----------------------------------------------------------------------------
if [ -t 2 ] && [ -z "${NO_COLOR:-}" ]; then
	_C_RESET=$'\033[0m'
	_C_INFO=$'\033[0;34m'   # blue
	_C_OK=$'\033[0;32m'     # green
	_C_WARN=$'\033[0;33m'   # yellow
	_C_ERR=$'\033[0;31m'    # red
	_C_DIM=$'\033[2m'       # dim (timestamps)
else
	_C_RESET= _C_INFO= _C_OK= _C_WARN= _C_ERR= _C_DIM=
fi

# Internal: emit one timestamped, colored log line to stderr.
#   _log <color> <level> <message...>
_log() {
	_color="$1"; _level="$2"; shift 2
	printf '%s%s%s %s%-5s%s %s\n' \
		"$_C_DIM" "$(date '+%H:%M:%S')" "$_C_RESET" \
		"$_color" "$_level" "$_C_RESET" \
		"$*" >&2
	unset _color _level
}

log_info() { _log "$_C_INFO" "INFO" "$@"; }
log_warn() { _log "$_C_WARN" "WARN" "$@"; }
log_error() { _log "$_C_ERR" "ERROR" "$@"; }
log_ok() { _log "$_C_OK" "OK" "$@"; }

# die <msg...>
#   Log an error and exit 1. Use for unrecoverable conditions.
die() {
	log_error "$@"
	exit 1
}

# -----------------------------------------------------------------------------
# Privilege guards
# -----------------------------------------------------------------------------

# require_root
#   die unless running as uid 0. Use in chroot/system scripts.
require_root() {
	if [ "$(id -u)" -ne 0 ]; then
		die "this step must run as root (try: sudo ...)"
	fi
}

# require_not_root
#   die IF running as uid 0. Use in toolchain steps that must run as the
#   unprivileged `lfs` build user.
require_not_root() {
	if [ "$(id -u)" -eq 0 ]; then
		die "this step must NOT run as root — run it as the 'lfs' build user"
	fi
}

# -----------------------------------------------------------------------------
# confirm <prompt>
#   Interactive y/N guard for destructive operations (e.g. partitioning).
#   Returns 0 on an affirmative answer, 1 otherwise. Defaults to NO.
#   Bypass non-interactively by exporting ASSUME_YES=1 (used by run-all.sh
#   --yes after it has separately confirmed $LFS_DISK).
#   Because callers use `set -e`, ALWAYS test the return value rather than
#   calling it bare:  if confirm "..."; then ...; else ...; fi
# -----------------------------------------------------------------------------
confirm() {
	if [ "${ASSUME_YES:-0}" = "1" ]; then
		return 0
	fi
	printf '%s%s [y/N] %s' "$_C_WARN" "$*" "$_C_RESET" >&2
	# read may return non-zero on EOF; treat that as "no".
	if ! IFS= read -r _ans; then
		_ans=""
	fi
	case "$_ans" in
		[yY] | [yY][eE][sS]) unset _ans; return 0 ;;
		*) unset _ans; return 1 ;;
	esac
}

# -----------------------------------------------------------------------------
# run_step — the core build-step wrapper
# -----------------------------------------------------------------------------
# SIGNATURE
#     run_step <step-id> <description> -- <command> [args...]
#
#   <step-id>      idempotency slug + log filename (e.g. "10-binutils-pass1").
#   <description>  human-readable line shown in the log banner.
#   --             literal separator; everything after it is the command.
#   <command...>   the command to execute. Run via "$@" (no extra shell), so
#                  quoting is preserved and no re-splitting occurs. If you need
#                  a pipeline or shell builtins, wrap with: bash -c '...'.
#
# BEHAVIOR
#   * If is_done <step-id> and FORCE != 1  -> log and SKIP (return 0).
#   * Else: print a banner, record start time, run the command with all
#     output (stdout+stderr) tee'd to $FT_LOG_DIR/<step-id>.log, time it.
#   * On success (exit 0): mark_done <step-id> 0, log_ok with elapsed time,
#     return 0.
#   * On failure (exit N): log_error with the code + log path, return N.
#     The marker is NOT written, so a re-run retries this step.
#
# ENVIRONMENT KNOBS
#   FORCE=1     re-run even if the marker exists (does not clear other steps).
#   FT_LOG_DIR  where the per-step .log is written (from env/paths.sh).
#
# EXAMPLE
#     run_step 00-partition-disk "Partition $LFS_DISK" -- \
#         bash "$FT_REPO_ROOT/scripts/00-partition-disk.sh"
# -----------------------------------------------------------------------------
run_step() {
	_rs_id="$1"; shift
	_rs_desc="$1"; shift
	if [ "${1:-}" != "--" ]; then
		die "run_step: malformed call — expected '--' before the command (id=$_rs_id)"
	fi
	shift   # drop the literal --

	if [ "$#" -eq 0 ]; then
		die "run_step: no command given for step '$_rs_id'"
	fi

	# Idempotent skip.
	if is_done "$_rs_id" && [ "${FORCE:-0}" != "1" ]; then
		log_info "SKIP  $_rs_id — already done (FORCE=1 to re-run)"
		unset _rs_id _rs_desc
		return 0
	fi

	# Ensure the log directory exists; derive the per-step log path. step-ids
	# may contain slashes, so create the subdir.
	_rs_log="${FT_LOG_DIR:?FT_LOG_DIR not set — source env/lfs.env first}/$_rs_id.log"
	mkdir -p "$(dirname -- "$_rs_log")"

	log_info "STEP  $_rs_id — $_rs_desc"
	log_info "      log: $_rs_log"

	_rs_start=$(date +%s)

	# Run the command, tee'ing combined output to the log. We must capture the
	# command's exit status, not tee's, hence the PIPESTATUS dance. Disable -e
	# locally so we can inspect the status and report a clean error — but SAVE
	# and RESTORE the caller's errexit state afterwards (do not clobber it).
	case "$-" in *e*) _rs_had_e=1 ;; *) _rs_had_e=0 ;; esac
	set +e
	{
		printf '===== %s — %s =====\n' "$_rs_id" "$_rs_desc"
		printf 'started: %s\n' "$(date -u +%Y-%m-%dT%H:%M:%SZ)"
		printf 'command: %s\n\n' "$*"
		"$@"
	} 2>&1 | tee -a "$_rs_log"
	_rs_rc=${PIPESTATUS[0]}
	[ "$_rs_had_e" = "1" ] && set -e

	_rs_end=$(date +%s)
	_rs_elapsed=$(( _rs_end - _rs_start ))

	if [ "$_rs_rc" -eq 0 ]; then
		mark_done "$_rs_id" 0
		log_ok "DONE  $_rs_id — ${_rs_elapsed}s"
	else
		log_error "FAIL  $_rs_id — exit $_rs_rc after ${_rs_elapsed}s (see $_rs_log)"
	fi

	unset _rs_id _rs_desc _rs_log _rs_start _rs_end _rs_elapsed _rs_had_e
	return "$_rs_rc"
}
