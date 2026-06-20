#!/bin/bash
# vm/create-build-vm.sh — create the VirtualBox build VM with TWO disks + ISO
# =============================================================================
# Purpose : Create the VirtualBox VM in which the entire LFS build happens.
#           It provisions:
#             * Disk A (build-host.vdi, ~25GB) — the Debian/Ubuntu build host OS
#               you install from the Ubuntu Server ISO.
#             * Disk B (disk.vdi, ~20GB DYNAMIC) — the ft_linux TARGET disk.
#               THIS is the file whose `shasum` is the submission artifact.
#             * An Ubuntu Server ISO attached to the optical drive.
#           NAT networking (build host AND the final ft_linux both reach the
#           internet), BIOS firmware (simplest for GRUB).
# Context : RUNS ON THE macOS/Linux HOST (NOT inside any VM). Needs VBoxManage.
# LFS ref : Chapter 1/2 — host & VM setup. See vm/README.md for the full flow.
# Idempot : Refuses to clobber an existing disk.vdi or an existing VM unless you
#           pass --force; otherwise prints what already exists and exits 0.
# Make exe: chmod +x vm/create-build-vm.sh
# =============================================================================
set -euo pipefail

# --- Resolve repo root & load the contract (for logging only; this is host-side).
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$SCRIPT_DIR"
while [ "$REPO_ROOT" != "/" ] && [ ! -f "$REPO_ROOT/env/lfs.env" ]; do
	REPO_ROOT="$(dirname "$REPO_ROOT")"
done
if [ -f "$REPO_ROOT/env/lfs.env" ]; then
	# shellcheck source=/dev/null
	source "$REPO_ROOT/env/lfs.env"
	# shellcheck source=/dev/null
	source "$REPO_ROOT/lib/common.sh"
else
	log_info()  { printf 'INFO  %s\n' "$*" >&2; }
	log_warn()  { printf 'WARN  %s\n' "$*" >&2; }
	log_error() { printf 'ERROR %s\n' "$*" >&2; }
	log_ok()    { printf 'OK    %s\n' "$*" >&2; }
	die()       { log_error "$@"; exit 1; }
fi

# -----------------------------------------------------------------------------
# Defaults (override via flags).
# -----------------------------------------------------------------------------
VM_NAME="ft_linux-build"
VM_RAM_MB=4096                # >= 4096 per requirement
VM_CPUS=2                     # >= 2 vCPU
DISK_A_SIZE_MB=25600          # ~25 GB build-host OS disk
DISK_B_SIZE_MB=20480          # ~20 GB ft_linux TARGET disk (the deliverable)
GRAPHICS_CONTROLLER="vmsvga"  # VMSVGA or VBoxVGA — needed for the bonus GUI later
ISO_PATH=""                   # required: path to an Ubuntu Server ISO
VM_DIR=""                     # default: VirtualBox's default machine folder
FORCE=0

usage() {
	cat <<EOF
Usage: $0 --iso /path/to/ubuntu-server.iso [options]

Creates the VirtualBox VM "$VM_NAME" with two disks and an attached ISO.

Required:
  --iso PATH            Path to an Ubuntu Server (or Debian) install ISO.

Options:
  --name NAME           VM name            (default: $VM_NAME)
  --ram MB              RAM in MiB          (default: $VM_RAM_MB, min 4096)
  --cpus N              vCPU count          (default: $VM_CPUS, min 2)
  --disk-a-size MB      Build-host disk MiB (default: $DISK_A_SIZE_MB)
  --disk-b-size MB      Target  disk MiB    (default: $DISK_B_SIZE_MB)
  --graphics CTRL       vmsvga | vboxvga    (default: $GRAPHICS_CONTROLLER)
  --vm-dir DIR          Directory for VM files & .vdi (default: VBox default)
  --force               Recreate even if the VM / disk.vdi already exist (DANGER:
                        deletes the existing ft_linux target disk!)
  -h, --help            Show this help.

Disk roles (see vm/README.md):
  Disk A  build-host.vdi  the Debian/Ubuntu build host OS  -> /dev/sda in VM
  Disk B  disk.vdi        the ft_linux TARGET system        -> /dev/sdb in VM
          (\$LFS_DISK defaults to /dev/sdb — this is the file you shasum)
EOF
}

# -----------------------------------------------------------------------------
# Parse flags.
# -----------------------------------------------------------------------------
while [ "$#" -gt 0 ]; do
	case "$1" in
		--iso)          ISO_PATH="${2:?--iso needs a path}"; shift 2 ;;
		--name)         VM_NAME="${2:?}"; shift 2 ;;
		--ram)          VM_RAM_MB="${2:?}"; shift 2 ;;
		--cpus)         VM_CPUS="${2:?}"; shift 2 ;;
		--disk-a-size)  DISK_A_SIZE_MB="${2:?}"; shift 2 ;;
		--disk-b-size)  DISK_B_SIZE_MB="${2:?}"; shift 2 ;;
		--graphics)     GRAPHICS_CONTROLLER="${2:?}"; shift 2 ;;
		--vm-dir)       VM_DIR="${2:?}"; shift 2 ;;
		--force)        FORCE=1; shift ;;
		-h|--help)      usage; exit 0 ;;
		*)              die "unknown argument: $1 (try --help)" ;;
	esac
done

# -----------------------------------------------------------------------------
# Pre-flight: VBoxManage present, sane inputs.
# -----------------------------------------------------------------------------
command -v VBoxManage >/dev/null 2>&1 || die "VBoxManage not found on PATH — install VirtualBox first."
[ -n "$ISO_PATH" ] || { usage; die "--iso is required (path to an Ubuntu/Debian install ISO)."; }
[ -f "$ISO_PATH" ] || die "ISO not found: $ISO_PATH"
[ "$VM_RAM_MB" -ge 4096 ] || log_warn "RAM ${VM_RAM_MB}MB is below the recommended 4096MB."
[ "$VM_CPUS" -ge 2 ]      || log_warn "vCPU count ${VM_CPUS} is below the recommended 2."
case "$GRAPHICS_CONTROLLER" in
	vmsvga|vboxvga|VMSVGA|VBoxVGA) ;;
	*) die "invalid --graphics '$GRAPHICS_CONTROLLER' (use vmsvga or vboxvga)";;
esac

log_info "VBoxManage: $(VBoxManage --version)"

# -----------------------------------------------------------------------------
# Resolve the VM directory and the two disk paths.
# -----------------------------------------------------------------------------
if [ -z "$VM_DIR" ]; then
	# Use VirtualBox's configured default machine folder.
	default_folder="$(VBoxManage list systemproperties | sed -n 's/^Default machine folder:[[:space:]]*//p')"
	[ -n "$default_folder" ] || default_folder="$HOME/VirtualBox VMs"
	VM_DIR="$default_folder/$VM_NAME"
fi
DISK_A="$VM_DIR/build-host.vdi"
DISK_B="$VM_DIR/disk.vdi"

log_info "VM name        : $VM_NAME"
log_info "VM directory   : $VM_DIR"
log_info "Disk A (host)  : $DISK_A  (~${DISK_A_SIZE_MB} MB)"
log_info "Disk B (target): $DISK_B  (~${DISK_B_SIZE_MB} MB)  <-- the deliverable"
log_info "ISO            : $ISO_PATH"

# -----------------------------------------------------------------------------
# Idempotency guards.
# -----------------------------------------------------------------------------
vm_exists() { VBoxManage list vms | grep -q "\"$VM_NAME\""; }

if vm_exists; then
	if [ "$FORCE" -ne 1 ]; then
		log_warn "VM '$VM_NAME' already exists. Re-run with --force to recreate (this DELETES disk.vdi)."
		log_info "Nothing to do."
		exit 0
	fi
	log_warn "--force: unregistering and deleting existing VM '$VM_NAME' (and its disks)…"
	VBoxManage controlvm "$VM_NAME" poweroff 2>/dev/null || true
	VBoxManage unregistervm "$VM_NAME" --delete || die "failed to unregister existing VM"
fi

if [ -f "$DISK_B" ] && [ "$FORCE" -ne 1 ]; then
	die "REFUSING to clobber existing target disk: $DISK_B (use --force to overwrite — this is your deliverable!)"
fi

mkdir -p "$VM_DIR"

# -----------------------------------------------------------------------------
# Create + register the VM. Ubuntu_64 OS type, BIOS firmware (simplest GRUB).
# -----------------------------------------------------------------------------
log_info "Creating and registering VM…"
VBoxManage createvm --name "$VM_NAME" --ostype Ubuntu_64 --basefolder "$(dirname "$VM_DIR")" --register

log_info "Configuring CPU/RAM/firmware/graphics/boot…"
VBoxManage modifyvm "$VM_NAME" \
	--memory "$VM_RAM_MB" \
	--cpus "$VM_CPUS" \
	--firmware bios \
	--graphicscontroller "$GRAPHICS_CONTROLLER" \
	--vram 64 \
	--ioapic on \
	--rtcuseutc on \
	--boot1 dvd --boot2 disk --boot3 none --boot4 none

# NAT networking so BOTH the build host AND the final ft_linux reach the net.
log_info "Configuring NAT networking…"
VBoxManage modifyvm "$VM_NAME" --nic1 nat --nictype1 82540EM --cableconnected1 on

# -----------------------------------------------------------------------------
# Storage controllers: one SATA controller carries both disks; an IDE
# controller carries the optical drive (most compatible for install ISOs).
# -----------------------------------------------------------------------------
log_info "Adding SATA + IDE controllers…"
VBoxManage storagectl "$VM_NAME" --name "SATA" --add sata --controller IntelAhci --portcount 4 --bootable on
VBoxManage storagectl "$VM_NAME" --name "IDE"  --add ide  --controller PIIX4

# Disk A — build host OS. If --force and it exists, remove it first.
if [ -f "$DISK_A" ] && [ "$FORCE" -eq 1 ]; then
	log_warn "--force: removing existing $DISK_A"
	VBoxManage closemedium disk "$DISK_A" --delete 2>/dev/null || rm -f "$DISK_A"
fi
log_info "Creating Disk A (build host OS, dynamic)…"
VBoxManage createmedium disk --filename "$DISK_A" --size "$DISK_A_SIZE_MB" --variant Standard --format VDI

# Disk B — the ft_linux TARGET (dynamic so the .vdi stays small until written).
if [ -f "$DISK_B" ] && [ "$FORCE" -eq 1 ]; then
	log_warn "--force: removing existing $DISK_B (your previous deliverable!)"
	VBoxManage closemedium disk "$DISK_B" --delete 2>/dev/null || rm -f "$DISK_B"
fi
log_info "Creating Disk B (ft_linux TARGET, dynamic)…"
VBoxManage createmedium disk --filename "$DISK_B" --size "$DISK_B_SIZE_MB" --variant Standard --format VDI

log_info "Attaching disks (A=port0 -> /dev/sda, B=port1 -> /dev/sdb)…"
VBoxManage storageattach "$VM_NAME" --storagectl "SATA" --port 0 --device 0 --type hdd --medium "$DISK_A"
VBoxManage storageattach "$VM_NAME" --storagectl "SATA" --port 1 --device 0 --type hdd --medium "$DISK_B"

log_info "Attaching the install ISO to the optical drive…"
VBoxManage storageattach "$VM_NAME" --storagectl "IDE" --port 0 --device 0 --type dvddrive --medium "$ISO_PATH"

log_ok "VM '$VM_NAME' created."

# -----------------------------------------------------------------------------
# Next-step instructions.
# -----------------------------------------------------------------------------
cat <<EOF

==============================================================================
NEXT STEPS
==============================================================================
1. Start the VM and install the build-host OS onto Disk A only (/dev/sda):
       VBoxManage startvm "$VM_NAME"        # or use the VirtualBox GUI
   During the Ubuntu/Debian installer, install to /dev/sda ONLY.
   DO NOT touch /dev/sdb — that is the ft_linux target ($LFS_DISK).

2. After install, detach the ISO so it boots from disk:
       VBoxManage storageattach "$VM_NAME" --storagectl "IDE" --port 0 --device 0 --type dvddrive --medium none

3. Inside the build host, provision it:
       sudo bash vm/provision-build-host.sh        # installs deps, sh->bash, runs version-check.sh

4. Then run the LFS pipeline (partitions /dev/sdb, builds onto it):
       ./run-all.sh --yes

5. The submission artifact is the TARGET disk:
       $DISK_B
   (submit/checksum.sh powers off the VM and shasum's it.)
==============================================================================
EOF
