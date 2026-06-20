# SUBMISSION — what to push, and how it is evaluated

This is the authoritative reference for **step 10** of the
[RUNBOOK](RUNBOOK.md#step-10--submit). It states the rule, quotes the spec
verbatim, and explains exactly what gets committed.

---

## The rule (quoted from the spec)

From [`../.specs/submission-evaluation.md`](../.specs/submission-evaluation.md)
(42 subject, chapter VI), verbatim:

> For obvious reasons, you will **not** push your entire virtual machine — push
> a checksum of your disk image instead. This can be done with something like:
>
> ```sh
> shasum < disk.vdi
> ```

The same page also states:

> - Submit your assignment in your `Git` repository as usual.
> - Only the work inside your repository will be evaluated during the defense.
>   Double-check the names of your folders and files to ensure they are correct.
> - Keep your disk image somewhere for the peer-evaluation.

---

## What that means in practice

1. **Do not commit the VM or the disk image.** `disk.vdi` is gigabytes and is
   not "work" git should track. The repo's
   [`../.gitignore`](../.gitignore) already excludes it:
   ```gitignore
   *.vdi
   *.vmdk
   *.vbox
   *.iso
   sources/*.tar.*
   /logs/
   ```
   So the VM image, all source tarballs, and build logs are kept out of git
   automatically.

2. **Commit only scripts, configs, docs, and the checksum file.** That is
   everything in this repo *except* the ignored artifacts: `env/`, `lib/`,
   `vm/`, `sources/` (the scripts and lists, not the tarballs), `scripts/`,
   `bonus/`, `verify/`, `submit/`, `docs/`, plus `README.md`, `CLAUDE.md`,
   `Makefile`, `run-all.sh`, and the generated **`CHECKSUM.txt`**.

3. **The checksum file is the proxy for the disk image.** Generate it on the
   **macOS host** with the VM **powered off**:
   ```sh
   bash submit/checksum.sh                 # auto-finds ~/VirtualBox VMs/ft_linux-build/disk.vdi
   # or pass the path explicitly:
   bash submit/checksum.sh /path/to/disk.vdi
   ```
   [`../submit/checksum.sh`](../submit/checksum.sh) reproduces the spec's exact
   command — `shasum < disk.vdi` (SHA-1) — and also computes
   `shasum -a 256 < disk.vdi` (SHA-256). It prints both to stdout and writes
   them, with the image size and mtime, to `CHECKSUM.txt` at the repo root.
   That file is tracked and committed.

4. **Keep the disk image for the peer-evaluation.** The spec says to keep it
   "somewhere" — you boot the actual `disk.vdi` live during the defense. Do not
   delete it after submitting; the committed checksum only *proves* the image
   you defend with is the one you finished.

---

## Commit & push

```sh
git add -A
git status                 # SANITY: confirm no *.vdi, *.iso, or sources/*.tar.* is staged
git commit -m "ft_linux: build suite + disk image checksum"
git push
```

If `git status` ever shows a `.vdi` staged, **stop** — `.gitignore` should
prevent it; you may have force-added it. Unstage it (`git restore --staged
disk.vdi`) before pushing. Pushing the multi-GB image violates the spec and may
break the submission.

---

## How an evaluator reproduces / verifies

During peer-evaluation:

1. The evaluator boots **your kept `disk.vdi`** in VirtualBox (two-disk setup
   per [`01-vm-setup.md`](01-vm-setup.md), or the image attached as the boot
   disk).
2. They can confirm the image is the one you submitted by re-running the spec
   command on the powered-off image and comparing to `CHECKSUM.txt`:
   ```sh
   shasum < disk.vdi          # compare to the sha1: line in CHECKSUM.txt
   shasum -a 256 < disk.vdi   # compare to the sha256: line
   ```
   The byte-for-byte match proves no tampering between submission and defense.
3. They check the mandatory requirements live on the booted system — the same
   checks `verify/verify.sh` automates (R1–R15; see
   [`../verify/compliance-checklist.md`](../verify/compliance-checklist.md)).
   The bonus is assessed **only if the mandatory part is perfect**
   ([`../.specs/bonus.md`](../.specs/bonus.md)).

> **Reproducibility note.** `shasum < disk.vdi` matches only if the image is
> unchanged — which is why `submit/checksum.sh` warns when the VM is not powered
> off (a running VM mutates the `.vdi`). Always shut down cleanly, then hash.
