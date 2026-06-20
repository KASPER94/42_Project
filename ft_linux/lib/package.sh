# shellcheck shell=bash
#
# lib/package.sh — the canonical LFS/BLFS package build helper
# =============================================================================
# Source AFTER env/lfs.env and lib/common.sh:
#     source "<repo>/env/lfs.env"
#     source "<repo>/lib/common.sh"
#     source "<repo>/lib/package.sh"
#
# build_package encapsulates the extract -> configure -> build -> check ->
# install -> log -> cleanup pattern shared by ~100 builder scripts, with one
# code path per build system. See .claude/skills/lfs-package/SKILL.md for the
# authoring contract and copy-paste templates.
#
# Callers run with `set -euo pipefail`. build_package itself manages -e
# carefully so it can report clean errors and keep `make check` non-fatal by
# default.
# =============================================================================

# Guard against double-sourcing.
[ -n "${_FT_PACKAGE_SH_LOADED:-}" ] && return 0
_FT_PACKAGE_SH_LOADED=1

# -----------------------------------------------------------------------------
# extract_only <tarball>
#   Extract <tarball> (relative to $SOURCES_DIR, or an absolute path) into
#   $SOURCES_DIR and echo the absolute path of the resulting top-level source
#   directory to STDOUT. Use for packages that need manual configure/build
#   steps build_package cannot express (e.g. GCC's bundled-lib unpack, Glibc,
#   the kernel). Does NOT cd, build, install, log, or clean up — that's yours.
#
#   Example:
#       src=$(extract_only "binutils-$BINUTILS_VERSION.tar.xz")
#       cd "$src"; mkdir build; cd build; ../configure ...; make; make install
# -----------------------------------------------------------------------------
extract_only() {
	_eo_tarball="$1"
	: "${SOURCES_DIR:?SOURCES_DIR not set — source env/lfs.env first}"

	# Resolve to an absolute tarball path.
	case "$_eo_tarball" in
		/*) _eo_path="$_eo_tarball" ;;
		*) _eo_path="$SOURCES_DIR/$_eo_tarball" ;;
	esac
	[ -f "$_eo_path" ] || die "extract_only: tarball not found: $_eo_path"

	# Snapshot the directory listing, extract, then diff to find what appeared.
	# This robustly discovers the top-level dir even when it != tarball stem.
	_eo_before="$(mktemp)"
	_eo_after="$(mktemp)"
	( cd "$SOURCES_DIR" && ls -1A ) >"$_eo_before"

	# tar autodetects compression (--auto-compress / -a is for create; for
	# extract modern GNU tar autodetects xz/gz/bz2 from the stream). Use -x.
	tar -xf "$_eo_path" -C "$SOURCES_DIR" \
		|| die "extract_only: failed to extract $_eo_path"

	( cd "$SOURCES_DIR" && ls -1A ) >"$_eo_after"
	_eo_newdir="$(comm -13 "$_eo_before" "$_eo_after" | head -n1)"
	rm -f "$_eo_before" "$_eo_after"

	[ -n "$_eo_newdir" ] || die "extract_only: could not determine source dir for $_eo_path"
	printf '%s\n' "$SOURCES_DIR/$_eo_newdir"
	unset _eo_tarball _eo_path _eo_before _eo_after _eo_newdir
}

# -----------------------------------------------------------------------------
# build_package — build & install one package end-to-end
# -----------------------------------------------------------------------------
# SIGNATURE
#     build_package <name> <tarball> [OPTIONS...]
#
#   <name>     log/idempotency slug, e.g. "binutils" or "final/ncurses".
#   <tarball>  source archive, relative to $SOURCES_DIR or absolute.
#
# OPTIONS (any order, all optional)
#   --type=<t>            build system: autotools (default) | cmake | meson
#                         | make | perl
#   --prefix=<dir>        install prefix (default /usr). NEVER /usr/local for
#                         system packages — see the skill.
#   --configure-args="…"  extra args appended to the configure/cmake/meson
#                         invocation, verbatim. Quote the whole thing.
#   --make-args="…"       extra args passed to the build (make/ninja) step.
#   --install-args="…"    extra args passed to the install step.
#   --check-target=<t>    test target name (default "check"; e.g. "test").
#   --no-check            skip the test phase entirely.
#   --srcdir=<dir>        if the extracted top dir differs from the auto-found
#                         one, force it (rarely needed).
#
# BUILD SYSTEMS
#   autotools : ./configure --prefix=PFX --sysconfdir=/etc --localstatedir=/var
#                 <args>  &&  make <margs>  &&  make <check>  &&  make install
#   cmake     : out-of-tree build/ dir; cmake -DCMAKE_INSTALL_PREFIX=PFX
#                 -DCMAKE_BUILD_TYPE=Release <args> .. && make && ctest && make install
#   meson     : meson setup build --prefix=PFX --buildtype=release <args>
#                 && ninja && meson test (unless --no-check) && ninja install
#   make      : (suckless-style) make <margs> && make PREFIX=PFX install
#                 — no configure, no check unless --check-target given.
#   perl      : perl Makefile.PL <args> && make && make test && make install
#
# BEHAVIOR
#   * Idempotent via lib/state.sh: if is_done <name> and FORCE!=1, skip.
#   * Extracts the tarball into a throwaway dir under $SOURCES_DIR, builds
#     there, tee's ALL output to $FT_LOG_DIR/<name>.log.
#   * `make check`/test failures are a WARNING by default (LFS tests are noisy
#     and some are expected to fail). Set STRICT=1 to make them fatal.
#   * On success: rm -rf the extracted source dir, mark_done <name>, return 0.
#   * On a build/configure/install failure: leave the source dir in place for
#     debugging, do NOT mark done, return non-zero.
#
# ENVIRONMENT KNOBS
#   FORCE=1      rebuild even if marked done.
#   STRICT=1     treat test-suite failures as fatal.
#   KEEP_BUILD=1 do not delete the source dir even on success (debugging).
#   MAKEFLAGS    parallelism (from env/lfs.env).
#
# EXAMPLES
#   build_package final/zlib   "zlib-$ZLIB_VERSION.tar.gz"
#   build_package final/ncurses "ncurses-$NCURSES_VERSION.tar.gz" \
#       --configure-args="--with-shared --without-debug --enable-widec"
#   build_package final/dbus   "dbus-$DBUS_VERSION.tar.xz" --type=meson \
#       --configure-args="-Dsystemd=enabled"
#   build_package final/dwm    "dwm-$DWM_VERSION.tar.gz"   --type=make
#   build_package final/xml-parser "XML-Parser-$XML_PARSER_VERSION.tar.gz" --type=perl
# -----------------------------------------------------------------------------
build_package() {
	# --- parse positionals ---
	[ "$#" -ge 2 ] || die "build_package: usage: build_package <name> <tarball> [options]"
	_bp_name="$1"; shift
	_bp_tarball="$1"; shift

	# --- defaults ---
	_bp_type=autotools
	_bp_prefix=/usr
	_bp_cfg_args=""
	_bp_make_args=""
	_bp_install_args=""
	_bp_check_target=""      # set per-type below if still empty
	_bp_no_check=0
	_bp_force_srcdir=""

	# --- parse options ---
	while [ "$#" -gt 0 ]; do
		case "$1" in
			--type=*) _bp_type="${1#--type=}" ;;
			--prefix=*) _bp_prefix="${1#--prefix=}" ;;
			--configure-args=*) _bp_cfg_args="${1#--configure-args=}" ;;
			--make-args=*) _bp_make_args="${1#--make-args=}" ;;
			--install-args=*) _bp_install_args="${1#--install-args=}" ;;
			--check-target=*) _bp_check_target="${1#--check-target=}" ;;
			--no-check) _bp_no_check=1 ;;
			--srcdir=*) _bp_force_srcdir="${1#--srcdir=}" ;;
			*) die "build_package($_bp_name): unknown option '$1'" ;;
		esac
		shift
	done

	: "${SOURCES_DIR:?SOURCES_DIR not set — source env/lfs.env first}"
	: "${FT_LOG_DIR:?FT_LOG_DIR not set — source env/lfs.env first}"

	# --- idempotent skip ---
	if is_done "$_bp_name" && [ "${FORCE:-0}" != "1" ]; then
		log_info "SKIP  $_bp_name — already built (FORCE=1 to rebuild)"
		return 0
	fi

	# --- log path ---
	_bp_log="$FT_LOG_DIR/$_bp_name.log"
	mkdir -p "$(dirname -- "$_bp_log")"

	log_info "BUILD $_bp_name (type=$_bp_type prefix=$_bp_prefix) -> $_bp_log"

	# Everything below is run inside a subshell so its failure is captured by
	# PIPESTATUS without aborting the caller, and so a cd never leaks out. All
	# of the subshell's stdout+stderr is tee'd to the per-package log. We save
	# and restore the caller's errexit state rather than clobbering it.
	case "$-" in *e*) _bp_had_e=1 ;; *) _bp_had_e=0 ;; esac
	set +e
	(
		set -e

		# Resolve & extract. extract_only echoes the absolute source dir.
		if [ -n "$_bp_force_srcdir" ]; then
			case "$_bp_force_srcdir" in
				/*) _src="$_bp_force_srcdir" ;;
				*) _src="$SOURCES_DIR/$_bp_force_srcdir" ;;
			esac
			# Still extract if the dir does not yet exist.
			[ -d "$_src" ] || _src="$(extract_only "$_bp_tarball")"
		else
			_src="$(extract_only "$_bp_tarball")"
		fi

		echo "===== build_package: $_bp_name ====="
		echo "source dir: $_src"
		echo "started:    $(date -u +%Y-%m-%dT%H:%M:%SZ)"
		echo

		cd "$_src"

		case "$_bp_type" in
		# ---------------------------------------------------------------------
		autotools)
			[ -z "$_bp_check_target" ] && _bp_check_target=check
			# shellcheck disable=SC2086  # word-splitting of *_args is intended
			./configure \
				--prefix="$_bp_prefix" \
				--sysconfdir=/etc \
				--localstatedir=/var \
				$_bp_cfg_args
			# shellcheck disable=SC2086
			make $_bp_make_args
			if [ "$_bp_no_check" -ne 1 ]; then
				if ! make "$_bp_check_target"; then
					if [ "${STRICT:-0}" = "1" ]; then
						echo "STRICT=1: test failures are fatal" >&2
						exit 1
					fi
					echo "WARNING: '$_bp_name' test suite reported failures (non-fatal; set STRICT=1 to enforce)" >&2
				fi
			fi
			# shellcheck disable=SC2086
			make install $_bp_install_args
			;;
		# ---------------------------------------------------------------------
		cmake)
			mkdir -p build && cd build
			# shellcheck disable=SC2086
			cmake \
				-DCMAKE_INSTALL_PREFIX="$_bp_prefix" \
				-DCMAKE_BUILD_TYPE=Release \
				-G "Unix Makefiles" \
				$_bp_cfg_args \
				..
			# shellcheck disable=SC2086
			make $_bp_make_args
			if [ "$_bp_no_check" -ne 1 ]; then
				if ! ctest --output-on-failure; then
					if [ "${STRICT:-0}" = "1" ]; then exit 1; fi
					echo "WARNING: '$_bp_name' ctest reported failures (non-fatal)" >&2
				fi
			fi
			# shellcheck disable=SC2086
			make install $_bp_install_args
			;;
		# ---------------------------------------------------------------------
		meson)
			# shellcheck disable=SC2086
			meson setup build \
				--prefix="$_bp_prefix" \
				--buildtype=release \
				$_bp_cfg_args
			# shellcheck disable=SC2086
			ninja -C build $_bp_make_args
			if [ "$_bp_no_check" -ne 1 ]; then
				if ! meson test -C build; then
					if [ "${STRICT:-0}" = "1" ]; then exit 1; fi
					echo "WARNING: '$_bp_name' meson test reported failures (non-fatal)" >&2
				fi
			fi
			# shellcheck disable=SC2086
			ninja -C build install $_bp_install_args
			;;
		# ---------------------------------------------------------------------
		make)
			# suckless-style: no configure. PREFIX is passed on the make line.
			# shellcheck disable=SC2086
			make PREFIX="$_bp_prefix" $_bp_make_args
			if [ "$_bp_no_check" -ne 1 ] && [ -n "$_bp_check_target" ]; then
				if ! make "$_bp_check_target"; then
					if [ "${STRICT:-0}" = "1" ]; then exit 1; fi
					echo "WARNING: '$_bp_name' '$_bp_check_target' reported failures (non-fatal)" >&2
				fi
			fi
			# shellcheck disable=SC2086
			make PREFIX="$_bp_prefix" install $_bp_install_args
			;;
		# ---------------------------------------------------------------------
		perl)
			# CPAN-style. INSTALLDIRS=vendor keeps modules out of /usr/local.
			# shellcheck disable=SC2086
			perl Makefile.PL $_bp_cfg_args
			# shellcheck disable=SC2086
			make $_bp_make_args
			if [ "$_bp_no_check" -ne 1 ]; then
				if ! make test; then
					if [ "${STRICT:-0}" = "1" ]; then exit 1; fi
					echo "WARNING: '$_bp_name' perl 'make test' reported failures (non-fatal)" >&2
				fi
			fi
			# shellcheck disable=SC2086
			make install $_bp_install_args
			;;
		# ---------------------------------------------------------------------
		*)
			echo "build_package($_bp_name): unknown --type '$_bp_type'" >&2
			exit 2
			;;
		esac

		echo
		echo "finished: $(date -u +%Y-%m-%dT%H:%M:%SZ)"
	) 2>&1 | tee -a "$_bp_log"
	_bp_rc=${PIPESTATUS[0]}
	[ "$_bp_had_e" = "1" ] && set -e

	if [ "$_bp_rc" -eq 0 ]; then
		# Clean up the extracted source dir on success unless asked to keep it.
		# Re-derive the path the same way the subshell did, then remove it.
		if [ "${KEEP_BUILD:-0}" != "1" ]; then
			# Find any dir matching the package by re-reading the log's "source
			# dir:" line — robust against tarball-stem mismatch.
			_bp_srcline="$(sed -n 's/^source dir: //p' "$_bp_log" | tail -n1)"
			if [ -n "$_bp_srcline" ] && [ -d "$_bp_srcline" ] \
				&& [ "$_bp_srcline" != "$SOURCES_DIR" ] \
				&& [ "$_bp_srcline" != "/" ]; then
				rm -rf "$_bp_srcline"
			fi
			unset _bp_srcline
		fi
		mark_done "$_bp_name" 0
		log_ok "BUILT $_bp_name"
	else
		log_error "FAILED $_bp_name (exit $_bp_rc) — source kept for debugging; see $_bp_log"
	fi

	unset _bp_name _bp_tarball _bp_type _bp_prefix _bp_cfg_args _bp_make_args \
		_bp_install_args _bp_check_target _bp_no_check _bp_force_srcdir _bp_log \
		_bp_had_e
	return "$_bp_rc"
}
