# shellcheck shell=bash
#
# lib/state.sh — idempotency markers for resumable builds
# =============================================================================
# Each completed step drops a marker file under $FT_STATE_DIR named
# "<step-id>.done". Re-running the suite fast-forwards past steps whose marker
# already exists, so a crash halfway through a 12–24h build resumes cleanly.
#
# Source AFTER env/lfs.env (which defines $FT_STATE_DIR via env/paths.sh):
#     source "<repo>/env/lfs.env"
#     source "<repo>/lib/common.sh"   # optional; provides logging used here
#     source "<repo>/lib/state.sh"
#
# A <step-id> is a short, filename-safe slug, e.g. "10-binutils-pass1",
# "final/binutils", "kernel-build". Slashes are allowed and create
# subdirectories under $FT_STATE_DIR.
#
# Marker file contents (for auditing):
#     done=<ISO-8601 timestamp>
#     status=<exit status that was recorded, normally 0>
#     host=<hostname>
# =============================================================================

# Guard against double-sourcing.
[ -n "${_FT_STATE_SH_LOADED:-}" ] && return 0
_FT_STATE_SH_LOADED=1

# Internal: resolve the marker path for a step id. Creates parent dirs lazily
# at write time, not here.
_ft_marker_path() {
	printf '%s/%s.done' "${FT_STATE_DIR:?FT_STATE_DIR not set — source env/lfs.env first}" "$1"
}

# is_done <step-id>
#   Return 0 (true) if the step's marker exists, non-zero otherwise.
#   Usage: if is_done "final/binutils"; then ...; fi
is_done() {
	[ -f "$(_ft_marker_path "$1")" ]
}

# mark_done <step-id> [status]
#   Record the step as complete. Optional second arg is the exit status to
#   record (default 0). Creates $FT_STATE_DIR and any parent subdirs.
mark_done() {
	_step="$1"
	_status="${2:-0}"
	_marker="$(_ft_marker_path "$_step")"
	mkdir -p "$(dirname -- "$_marker")"
	{
		printf 'done=%s\n' "$(date -u +%Y-%m-%dT%H:%M:%SZ)"
		printf 'status=%s\n' "$_status"
		printf 'host=%s\n' "$(hostname 2>/dev/null || echo unknown)"
	} >"$_marker"
	unset _step _status _marker
}

# clear_done <step-id>
#   Remove a single step's marker so it will re-run next time.
clear_done() {
	rm -f "$(_ft_marker_path "$1")"
}

# clear_all_state
#   Remove ALL markers (full rebuild). Leaves $FT_STATE_DIR itself in place.
clear_all_state() {
	if [ -d "${FT_STATE_DIR:?}" ]; then
		# Remove only our marker files, not anything else a caller stashed here.
		find "$FT_STATE_DIR" -type f -name '*.done' -delete
	fi
}

# list_state
#   Print all recorded done markers (step-id + timestamp) to stdout, sorted.
#   Useful for `run-all.sh --status`.
list_state() {
	[ -d "${FT_STATE_DIR:?}" ] || return 0
	# Strip the $FT_STATE_DIR prefix and the .done suffix to recover step ids.
	find "$FT_STATE_DIR" -type f -name '*.done' 2>/dev/null | sort | while IFS= read -r _m; do
		_id="${_m#"$FT_STATE_DIR"/}"
		_id="${_id%.done}"
		_ts="$(sed -n 's/^done=//p' "$_m" 2>/dev/null | head -n1)"
		printf '%-40s %s\n' "$_id" "${_ts:-?}"
	done
	unset _m _id _ts
}
