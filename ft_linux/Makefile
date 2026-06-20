# =============================================================================
# ft_linux — Makefile (thin wrapper over run-all.sh)
# =============================================================================
# Authored on macOS by agent A8. This Makefile contains NO build logic: every
# target simply dispatches to ./run-all.sh with the right phase filter, or to a
# host-side helper script. The single source of truth for the build sequence is
# run-all.sh's phase registry; the source of truth for versions/paths is env/.
#
# Most targets must run as ROOT inside the build VM (run-all.sh enforces this).
# Prefix with sudo, e.g.:  sudo make all
#
# Pass flags through with ARGS, e.g.:   sudo make all ARGS="--dry-run"
#                                       sudo make final ARGS="--yes"
#   (the build/destructive targets already imply --yes; see below.)
#
# Run `make help` for the catalogue.
# =============================================================================

# The orchestrator and host-side helpers.
RUN_ALL := ./run-all.sh
SHELL    := /bin/bash

# Extra flags forwarded to run-all.sh (e.g. ARGS="--dry-run").
ARGS ?=

# `--yes` is required for the destructive partition phase and harmless elsewhere
# (it only bypasses interactive confirmation; run-all.sh still guards the disk).
YES := --yes

.DEFAULT_GOAL := help

# Phony: none of these are files.
.PHONY: help vm download verify-sources prep toolchain temp-tools chroot \
        final config kernel grub finalize all status list dry-run \
        bonus verify checksum clean-state

# -----------------------------------------------------------------------------
help: ## Show this help (target catalogue)
	@echo "ft_linux build — make targets (thin wrappers over run-all.sh)"
	@echo "Run inside the build VM as root (sudo make <target>). See docs/RUNBOOK.md."
	@echo
	@grep -E '^[a-zA-Z0-9_-]+:.*##' $(MAKEFILE_LIST) \
		| sed -E 's/:.*## /\t/' \
		| awk -F'\t' '{ printf "  \033[36m%-14s\033[0m %s\n", $$1, $$2 }'
	@echo
	@echo "Flag passthrough:  sudo make all ARGS=\"--dry-run\""

# --- Host-side, BEFORE the build (not run-all phases) ------------------------

vm: ## (HOST) How to create the VirtualBox build VM + target disk
	@echo "vm/ scripts run on the HOST (macOS), not via run-all.sh. Create the VM with:"
	@echo "    bash vm/create-build-vm.sh        # or: cd vm && vagrant up"
	@echo "Then provision the build host and attach the second (target) disk; see vm/README.md and docs/01-vm-setup.md."

download: ## (in VM) Download all source tarballs into \$$LFS/sources
	@bash sources/download-sources.sh

# --- run-all.sh phase dispatchers (in VM, as root) ---------------------------

verify-sources: ## Preflight: verify source tarball checksums + host tools
	$(RUN_ALL) --only preflight $(ARGS)

prep: ## Ch.2/4: partition (DESTRUCTIVE) + format + lfs user/env
	$(RUN_ALL) --only partition $(YES) $(ARGS)
	$(RUN_ALL) --only format $(YES) $(ARGS)
	$(RUN_ALL) --only prep-env $(YES) $(ARGS)

toolchain: ## Ch.5: cross-toolchain (as the lfs user)
	$(RUN_ALL) --only toolchain $(YES) $(ARGS)

temp-tools: ## Ch.6: cross-compiled temporary tools (as the lfs user)
	$(RUN_ALL) --only temp-tools $(YES) $(ARGS)

chroot: ## Ch.7: prepare virtual FS + stage repo + in-chroot temp tools
	$(RUN_ALL) --only chroot-prep $(YES) $(ARGS)
	$(RUN_ALL) --only chroot-tools $(YES) $(ARGS)

final: ## Ch.8: build the full final system (every package in _order.txt)
	$(RUN_ALL) --only final $(YES) $(ARGS)

config: ## Ch.9: system configuration (network/hostname/locale/fstab)
	$(RUN_ALL) --only config $(YES) $(ARGS)

kernel: ## Ch.10: build + install the -skapers kernel
	$(RUN_ALL) --only kernel $(YES) $(ARGS)

grub: ## Ch.10: install GRUB + write grub.cfg
	$(RUN_ALL) --only grub $(YES) $(ARGS)

finalize: ## Ch.11: strip/clean + write ft_linux identity files
	$(RUN_ALL) --only finalize $(YES) $(ARGS)

all: ## Full end-to-end build (all phases except bonus)
	$(RUN_ALL) $(YES) $(ARGS)

# --- Status / inspection -----------------------------------------------------

status: ## Show recorded done markers (resume state)
	$(RUN_ALL) --status

list: ## Show the phase registry (build order)
	$(RUN_ALL) --list

dry-run: ## Preview the full build without executing anything
	$(RUN_ALL) --dry-run $(YES) $(ARGS)

# --- Post-reboot: verify, bonus, submit --------------------------------------

verify: ## (booted ft_linux, root) Run the compliance self-check (gate for bonus)
	@bash verify/verify.sh

bonus: ## (booted ft_linux) Build the Xorg + WM bonus (gated on verify.sh == 0)
	$(RUN_ALL) --only bonus $(ARGS)

checksum: ## (HOST, VM powered off) Produce CHECKSUM.txt from the disk image
	@bash submit/checksum.sh $(ARGS)

# --- Maintenance -------------------------------------------------------------

clean-state: ## Clear ALL done-markers (forces a full rebuild next run)
	@echo "Clearing all done-markers under the state dir (full rebuild next run)…"
	@bash -c 'source env/lfs.env; source lib/common.sh; source lib/state.sh; clear_all_state; echo "state cleared."'
