# KFS_1 — all real work happens inside the amd64 build container so that the
# i386/GRUB toolchain is available on this Apple Silicon host.
IMAGE    := kfs1-toolchain
PLATFORM := linux/amd64
ISO      := build/kfs1.iso

# Bind-mount the project into the container at /kfs.
DOCKER     := docker run --rm --platform $(PLATFORM) -v "$(CURDIR)":/kfs -w /kfs $(IMAGE)
DOCKER_TTY := docker run --rm -it --platform $(PLATFORM) -v "$(CURDIR)":/kfs -w /kfs $(IMAGE)
QEMU       := qemu-system-i386

.PHONY: all image build iso run smoke run-gui debug shell clean re

all: iso

## Build the toolchain image (run once, or after editing the Dockerfile).
image:
	docker build --platform $(PLATFORM) -t $(IMAGE) .

## Compile + link the kernel binary (build/kfs1.bin).
build:
	$(DOCKER) bash scripts/build.sh

## Produce the bootable ISO (build/kfs1.iso, enforces <= 10 MB).
iso: build
	$(DOCKER) bash scripts/mkiso.sh

## Boot in QEMU, headless, serial -> stdout (Ctrl-C to quit).
run: iso
	$(DOCKER) $(QEMU) -cdrom $(ISO) -display none -serial stdio -no-reboot

## Headless CI smoke test: boot and assert the serial boot marker appears.
smoke: iso
	$(DOCKER) bash -c 'timeout 20 $(QEMU) -cdrom $(ISO) -display none -serial stdio -no-reboot | tee /dev/stderr | grep -q KFS1_BOOT_OK && echo "SMOKE_OK"'

## Boot with a VGA framebuffer exposed over VNC (connect to localhost:5900).
run-gui: iso
	docker run --rm --platform $(PLATFORM) -p 5900:5900 -v "$(CURDIR)":/kfs -w /kfs $(IMAGE) \
	    $(QEMU) -cdrom $(ISO) -vnc :0 -no-reboot

## Boot and capture the VGA output to build/screen.png (verifies "42" renders).
screenshot: iso
	$(DOCKER) bash scripts/screenshot.sh

## Boot stopped, waiting for gdb on :1234 (use: gdb build/kfs1.bin; target remote :1234).
debug: iso
	docker run --rm --platform $(PLATFORM) -p 1234:1234 -v "$(CURDIR)":/kfs -w /kfs $(IMAGE) \
	    $(QEMU) -cdrom $(ISO) -display none -serial stdio -s -S

## Interactive shell inside the toolchain container.
shell:
	$(DOCKER_TTY) bash

clean:
	rm -rf build target

re: clean all
