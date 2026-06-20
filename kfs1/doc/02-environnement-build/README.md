# Étape 02 — L'environnement de build (Docker amd64)

## Objectif de l'étape

Comprendre pourquoi on ne compile pas « directement » sur la machine, mais dans
un conteneur Docker Linux **amd64**, et comment le `Makefile` orchestre toute la
chaîne d'outils (nasm, GRUB, QEMU, Rust nightly) sans qu'on ait à retenir les
commandes.

## Fichiers concernés

- [`../../Dockerfile`](../../Dockerfile) — l'image de la chaîne d'outils
- [`../../Makefile`](../../Makefile) — les cibles `image` / `build` / `iso` / `run` / `smoke` / `run-gui` / `screenshot` / `debug` / `shell` / `clean` / `re`
- [`../../scripts/build.sh`](../../scripts/build.sh) — assemblage, compilation Rust, édition de liens
- [`../../scripts/mkiso.sh`](../../scripts/mkiso.sh) — création de l'image ISO amorçable
- [`../../scripts/screenshot.sh`](../../scripts/screenshot.sh) — capture VGA via le moniteur QEMU

---

## Pourquoi compiler dans un conteneur ?

### Le problème : l'hôte macOS n'a pas les bons outils

Quand on développe un noyau pour l'architecture i386 (x86 32 bits), on a besoin
d'outils très spécifiques :

- **nasm** — l'assembleur pour écrire le code de démarrage en assembleur x86
- **GRUB** avec ses modules i386-pc — pour créer une ISO amorçable au format Multiboot
- **xorriso** — pour assembler physiquement l'image ISO
- **qemu-system-i386** — pour émuler le matériel x86 et tester le noyau
- **Rust nightly** avec des composants bas niveau — pour compiler du code Rust sans bibliothèque standard

Sur macOS (et surtout sur Apple Silicon), aucun de ces outils n'est disponible
nativement dans la bonne variante. Installer manuellement une chaîne croisée
(cross-toolchain) pour cibler i386-elf sur macOS est complexe, fragile, et
différent d'une machine à l'autre.

### La solution : un conteneur Docker reproductible

Docker permet d'encapsuler l'environnement entier dans une **image** : un système
Debian minimal avec exactement les bons paquets, les bonnes versions, configurés
de la bonne façon. Chaque développeur qui clone le dépôt obtient
**le même environnement de build**, quelle que soit sa machine hôte.

C'est ce qu'on appelle la **reproductibilité** : le build produit le même binaire
sur ton Mac, sur le Mac de quelqu'un d'autre, ou sur un serveur CI.

```
Hôte macOS (arm64 ou x86)
│
└── docker run kfs1-toolchain bash scripts/build.sh
        │
        └── Conteneur Debian amd64
                ├── nasm, ld, grub-mkrescue, xorriso
                ├── qemu-system-i386
                └── rustc nightly (cible i386-kfs)
```

---

## Pourquoi amd64 et pas arm64 ?

C'est la question clé, et la réponse est dans la première ligne du
[`../../Dockerfile`](../../Dockerfile) (ligne 5) :

```dockerfile
FROM --platform=linux/amd64 debian:bookworm-slim
```

Le commentaire en tête du fichier l'explique directement :

> Host is Apple Silicon (arm64); we build an **amd64** image so that
> `grub-pc-bin` (i386-pc GRUB modules) and the standard x86 toolchain are
> available.

### Le paquet `grub-pc-bin` n'existe qu'en amd64

`grub-pc-bin` contient les **modules GRUB compilés pour l'architecture i386-pc**
(le BIOS legacy). Ces modules sont des binaires x86 32 bits. Debian ne les fournit
que dans le dépôt amd64 — il n'existe pas de paquet `grub-pc-bin` pour arm64,
parce qu'il n'a aucun sens d'y installer des modules de chargeur de démarrage BIOS x86.

### Émulation amd64 sous Colima / Docker Desktop

Sur Apple Silicon, Docker utilise **QEMU** (ou Rosetta 2 selon la configuration)
pour émuler une machine amd64. Les performances sont correctes pour notre usage
(compiler et tester un petit noyau). L'option `--platform linux/amd64` dans
chaque commande `docker run` (voir `Makefile`, ligne 8) force explicitement cette
émulation.

> **À ne pas confondre** : on compile un noyau pour **i386** (x86 32 bits), mais
> le conteneur tourne en **amd64** (x86-64). Les outils amd64 savent parfaitement
> produire du code i386, car i386 est un sous-ensemble de x86-64. C'est ce qu'on
> appelle une compilation **croisée** (cross-compilation) — ici de amd64 vers i386.

---

## Ce qu'installe le Dockerfile

Le [`../../Dockerfile`](../../Dockerfile) s'articule en deux blocs principaux.

### Bloc 1 — Paquets système (lignes 9–21)

```dockerfile
RUN apt-get update && apt-get install -y --no-install-recommends \
        build-essential \
        nasm \
        make \
        grub-pc-bin \
        grub-common \
        xorriso \
        mtools \
        qemu-system-x86 \
        gdb \
        curl \
        ca-certificates \
    && rm -rf /var/lib/apt/lists/*
```

| Paquet | Rôle |
|---|---|
| `build-essential` | GCC, `ld` (éditeur de liens), `make`, etc. |
| `nasm` | Assembleur NASM pour compiler `src/boot.s` en objet ELF32 |
| `grub-pc-bin` | Modules GRUB i386-pc (nécessaires à `grub-mkrescue`) |
| `grub-common` | Outils GRUB partagés dont `grub-mkrescue` et `grub-file` |
| `xorriso` | Crée l'image ISO 9660 (utilisé en coulisses par `grub-mkrescue`) |
| `mtools` | Accès aux systèmes de fichiers FAT depuis Linux (requis par GRUB) |
| `qemu-system-x86` | Émulateur x86 ; inclut `qemu-system-i386` |
| `gdb` | Débogueur GNU, connecté à QEMU via `make debug` |
| `curl` + `ca-certificates` | Pour télécharger `rustup` |

### Bloc 2 — Rust nightly (lignes 24–30)

```dockerfile
RUN curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs \
      | sh -s -- -y --default-toolchain nightly --profile minimal \
    && rustup component add rust-src llvm-tools-preview
```

| Composant | Rôle |
|---|---|
| `nightly` | Le canal de développement de Rust ; obligatoire pour `build-std` |
| `rust-src` | Les sources de la bibliothèque standard (`core`, `alloc`, etc.) |
| `llvm-tools-preview` | Outils LLVM (dont `llvm-objcopy`) utilisés pour l'inspection du binaire |

**Pourquoi nightly ?** Notre noyau n'a pas de système d'exploitation hôte : pas
de `libc`, pas de runtime standard. On doit recompiler la bibliothèque `core` de
Rust pour notre cible custom `i386-kfs`. C'est ce que fait l'option
`-Zbuild-std=core,compiler_builtins` (voir `CONTRACTS.md`), et `-Z` signifie
«&nbsp;fonctionnalité instable, nightly uniquement&nbsp;».

### Bloc 3 — netpbm (lignes 33–36)

```dockerfile
RUN apt-get install -y --no-install-recommends netpbm
```

`netpbm` fournit `pamscale` et `pnmtopng`, utilisés par `scripts/screenshot.sh`
pour convertir la capture VGA (format PPM brut) en PNG lisible.

---

## Le motif central du Makefile : `-v $(CURDIR):/kfs`

Ouvre le [`../../Makefile`](../../Makefile) ligne 8 :

```make
DOCKER := docker run --rm --platform $(PLATFORM) -v "$(CURDIR)":/kfs -w /kfs $(IMAGE)
```

Décomposons cette commande :

| Fragment | Signification |
|---|---|
| `docker run --rm` | Lance un conteneur et le supprime automatiquement à la fin |
| `--platform linux/amd64` | Force l'émulation amd64 |
| `-v "$(CURDIR)":/kfs` | **Monte** le répertoire du projet (là où tu as cloné le dépôt) dans le conteneur au chemin `/kfs` |
| `-w /kfs` | Définit le répertoire de travail courant dans le conteneur |
| `$(IMAGE)` | Nom de l'image : `kfs1-toolchain` |

Le paramètre `-v` (volume) est la clé : le code source reste sur ta machine hôte,
mais il est **lu et écrit par les outils du conteneur**. Quand `cargo build`
produit `target/i386-kfs/release/libkfs1.a`, ce fichier apparaît directement dans
ton répertoire local. Le conteneur ne persiste rien — il est jetable.

Chaque cible `make` qui compile, lie ou teste lance **un `docker run` distinct**.
C'est volontairement simple : pas d'état caché dans un conteneur long-vivant.

---

## Tour complet des cibles du Makefile

### `make image`

```make
image:
    docker build --platform $(PLATFORM) -t $(IMAGE) .
```

Construit l'image Docker à partir du `Dockerfile`. À exécuter **une seule fois**
après avoir cloné le dépôt, ou après avoir modifié le `Dockerfile`.

Durée : quelques minutes (téléchargement des paquets + installation de rustup).
Résultat : une image locale nommée `kfs1-toolchain`.

---

### `make build`

```make
build:
    $(DOCKER) bash scripts/build.sh
```

Lance `scripts/build.sh` dans le conteneur. Ce script enchaîne trois étapes
(voir [`../../scripts/build.sh`](../../scripts/build.sh)) :

1. **Assemblage** : `nasm -f elf32 src/boot.s -o build/boot.o`
2. **Compilation Rust** : `cargo build --release` → `target/i386-kfs/release/libkfs1.a`
3. **Édition de liens** : `ld -m elf_i386 -T linker.ld -o build/kfs1.bin build/boot.o libkfs1.a`
4. **Vérification Multiboot** : `grub-file --is-x86-multiboot build/kfs1.bin`

Le résultat est `build/kfs1.bin`, un binaire ELF32 amorçable via GRUB.

Pour le détail de la compilation et de l'édition de liens, voir
[`../08-compilation-link/README.md`](../08-compilation-link/README.md).
Pour la structure de la cible Rust `i386-kfs`, voir
[`../03-cible-rust-i386/README.md`](../03-cible-rust-i386/README.md).

---

### `make iso` (cible par défaut via `all`)

```make
iso: build
    $(DOCKER) bash scripts/mkiso.sh
```

Dépend de `build`. Lance [`../../scripts/mkiso.sh`](../../scripts/mkiso.sh) :

1. Prépare l'arborescence `build/isodir/boot/grub/`
2. Copie `build/kfs1.bin` et `grub/grub.cfg`
3. Appelle `grub-mkrescue -o build/kfs1.iso build/isodir/`
4. **Vérifie que l'ISO fait ≤ 10 Mo** (contrainte du projet)

`grub-mkrescue` crée une image ISO hybride (El Torito + GPT) que QEMU peut démarrer
directement. C'est pourquoi les modules `grub-pc-bin` sont indispensables : ils
sont embarqués dans l'ISO pour que GRUB puisse s'amorcer sans dépendre du firmware
de la machine cible.

---

### `make run`

```make
run: iso
    $(DOCKER) $(QEMU) -cdrom $(ISO) -display none -serial stdio -no-reboot
```

Démarre QEMU en mode **sans affichage** (`-display none`). La sortie série (port
COM1) est redirigée vers le terminal hôte (`-serial stdio`). Pratique pour voir
les messages que le noyau envoie sur COM1 sans ouvrir de fenêtre graphique.

Interrompre avec `Ctrl-C`.

---

### `make smoke`

```make
smoke: iso
    $(DOCKER) bash -c 'timeout 20 $(QEMU) -cdrom $(ISO) -display none \
        -serial stdio -no-reboot | tee /dev/stderr | grep -q KFS1_BOOT_OK \
        && echo "SMOKE_OK"'
```

Test de fumée (smoke test) : démarre QEMU, attend **au maximum 20 secondes**,
et cherche la chaîne `KFS1_BOOT_OK` dans la sortie série. Si elle apparaît, le
test réussit (`SMOKE_OK`). C'est le test de régression minimal utilisé en CI
pour s'assurer que le noyau démarre bien jusqu'au code Rust.

Le marqueur `KFS1_BOOT_OK` est émis par le noyau lui-même via le port série COM1.

---

### `make run-gui`

```make
run-gui: iso
    docker run --rm --platform $(PLATFORM) -p 5900:5900 -v "$(CURDIR)":/kfs -w /kfs $(IMAGE) \
        $(QEMU) -cdrom $(ISO) -vnc :0 -no-reboot
```

Comme `run`, mais expose l'écran VGA via **VNC** sur le port 5900. Se connecter
avec n'importe quel client VNC à `localhost:5900` pour voir l'affichage graphique.
Notez l'option `-p 5900:5900` qui publie le port du conteneur vers l'hôte — absent
des autres cibles qui n'ont pas besoin de ports réseau.

---

### `make screenshot`

```make
screenshot: iso
    $(DOCKER) bash scripts/screenshot.sh
```

Lance [`../../scripts/screenshot.sh`](../../scripts/screenshot.sh). Ce script :

1. Attend 7 secondes que le noyau s'initialise (délai configurable via `$DELAY`)
2. Envoie la commande `screendump build/screen.ppm` au **moniteur QEMU** (une
   interface de contrôle QEMU distincte de la sortie série)
3. Envoie `quit` pour arrêter QEMU
4. Convertit le fichier PPM brut en PNG avec `pamscale 2` + `pnmtopng`

Résultat : `build/screen.png` — une capture 2× agrandie de l'écran VGA au moment
du dump. Utilisé pour vérifier visuellement que le noyau affiche bien `42`.

---

### `make debug`

```make
debug: iso
    docker run --rm --platform $(PLATFORM) -p 1234:1234 -v "$(CURDIR)":/kfs -w /kfs $(IMAGE) \
        $(QEMU) -cdrom $(ISO) -display none -serial stdio -s -S
```

Démarre QEMU avec les options `-s -S` :
- `-s` : ouvre un serveur GDB sur le port 1234
- `-S` : **suspend** l'exécution dès le démarrage (attend que GDB se connecte)

Le port 1234 est publié vers l'hôte (`-p 1234:1234`). Depuis l'hôte (ou depuis
`make shell`), se connecter avec :

```
gdb build/kfs1.bin
(gdb) target remote :1234
(gdb) break kmain
(gdb) continue
```

C'est le workflow de débogage symbolique pas-à-pas au niveau du noyau.

---

### `make shell`

```make
shell:
    $(DOCKER_TTY) bash
```

Ouvre un **shell interactif** dans le conteneur (`-it` pour TTY + stdin interactif).
Utile pour explorer l'environnement, lancer des commandes manuellement, inspecter
les binaires produits avec `objdump`, `readelf`, etc.

```bash
# Exemple : inspecter les sections du binaire
readelf -S build/kfs1.bin
```

---

### `make clean`

```make
clean:
    rm -rf build target
```

Supprime les répertoires `build/` (binaires, ISO) et `target/` (artefacts Cargo).
Repart d'une ardoise vierge.

---

### `make re`

```make
re: clean all
```

Raccourci `clean` + `all` (= `iso`). Reconstruit tout depuis zéro en une commande.

---

## Récapitulatif des flux de données

```
src/boot.s  ──nasm──►  build/boot.o ─┐
                                       ├──ld──► build/kfs1.bin
src/*.rs  ──cargo──► libkfs1.a      ─┘           │
                                               grub-mkrescue
                                                   │
                                             build/kfs1.iso
                                                   │
                                          qemu-system-i386
                                          ┌──────┴──────┐
                                        serial       VGA
                                       (stdout)   (VNC/PPM)
```

---

## En résumé

- Le conteneur Docker **amd64** est la seule façon d'avoir `grub-pc-bin` (modules
  GRUB i386-pc) sur un hôte macOS Apple Silicon : ce paquet Debian n'existe pas en
  arm64.
- Chaque cible `make` est un `docker run --rm` qui monte le projet avec
  `-v "$(CURDIR)":/kfs` : les outils tournent dans le conteneur, les fichiers
  produits apparaissent directement sur la machine hôte.
- Les scripts dans `scripts/` encapsulent les étapes complexes (nasm → ld → grub →
  ISO, ou capture VGA) en commandes reproductibles et versionées.
- Le `Dockerfile` installe deux groupes d'outils : les outils système (nasm, GRUB,
  xorriso, QEMU, gdb) et la chaîne Rust nightly avec `rust-src` + `llvm-tools`.
- `make smoke` est le filet de sécurité minimal : boot headless + assertion du
  marqueur série `KFS1_BOOT_OK` en moins de 20 secondes.

## Pour aller plus loin

- **Étape suivante — la cible Rust i386** : [`../03-cible-rust-i386/README.md`](../03-cible-rust-i386/README.md) —
  comprendre le fichier `i386-kfs.json`, pourquoi `soft-float` et `panic=abort`,
  et ce que fait `-Zbuild-std`.
- **Compilation et édition de liens** : [`../08-compilation-link/README.md`](../08-compilation-link/README.md) —
  détail des trois étapes de `scripts/build.sh` (nasm, cargo, ld) et du script
  de linkage.
- **Documentation Docker officielle** sur le multi-platform :
  <https://docs.docker.com/build/building/multi-platform/>
- **GRUB Multiboot** : <https://www.gnu.org/software/grub/manual/multiboot/multiboot.html>
- **QEMU monitor** (commandes comme `screendump`) :
  <https://www.qemu.org/docs/master/system/monitor.html>
