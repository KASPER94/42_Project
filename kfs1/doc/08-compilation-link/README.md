# Étape 08 — Compilation & édition de liens

## Objectif de l'étape

Suivre concrètement comment les sources deviennent un noyau amorçable : les
trois temps `nasm` → `cargo` → `ld`, puis la fabrication de l'ISO avec GRUB, et
les vérifications (en-tête Multiboot valide, image ≤ 10 Mo).

## Fichiers concernés

- [`../../scripts/build.sh`](../../scripts/build.sh) — assemble, compile, lie ; vérifie le Multiboot
- [`../../scripts/mkiso.sh`](../../scripts/mkiso.sh) — `grub-mkrescue` + contrôle de taille
- [`../../scripts/screenshot.sh`](../../scripts/screenshot.sh) — capture l'écran VGA (vérif visuelle)
- [`../../Makefile`](../../Makefile) — relie tout ça aux cibles `make`

---

## Vue d'ensemble : de la source au binaire amorçable

Construire un noyau bare-metal n'est pas un simple `gcc -o kernel main.c`.
Plusieurs outils distincts interviennent, chacun faisant un travail précis :

```
src/boot.s  ──[nasm]──►  build/boot.o        (1) assemblage
src/*.rs    ──[cargo]──► target/…/libkfs1.a  (2) compilation Rust
                  ↓
build/boot.o + libkfs1.a ──[ld]──► build/kfs1.bin   (3) édition de liens
                  ↓
         [grub-mkrescue]──► build/kfs1.iso           (4) empaquetage ISO
```

Tout cela est orchestré par [`../../scripts/build.sh`](../../scripts/build.sh)
puis [`../../scripts/mkiso.sh`](../../scripts/mkiso.sh), eux-mêmes appelés depuis
le [`../../Makefile`](../../Makefile) **à l'intérieur du conteneur Docker** (voir
[étape 02](../02-environnement-build/README.md)).

---

## Temps 1 — Assembler `boot.s` en objet ELF32

### La commande (ligne 11 de `build.sh`)

```bash
nasm -f elf32 src/boot.s -o build/boot.o
```

### Ce que fait NASM ici

`nasm` est l'assembleur x86 de référence. Il traduit le code assembleur
(`src/boot.s`) en instructions machine binaires enveloppées dans un **fichier
objet** au format ELF32.

- `-f elf32` : choisit le format de sortie. `elf32` signifie *Executable and
  Linkable Format, 32 bits*. C'est le format attendu par l'éditeur de liens et
  par GRUB pour un noyau i386.
- `src/boot.s` : le fichier source (en assembleur x86-32). Il contient l'en-tête
  Multiboot, la mise en place d'une pile, le zéro de la BSS et le saut vers
  `kmain` (voir [étape 04](../04-grub-multiboot/README.md) pour l'en-tête, et
  [étape 05](../05-boot-asm/README.md) pour le détail du code).
- `-o build/boot.o` : le fichier objet produit. Il contient les sections
  `.multiboot_header` et `.text`, mais **pas encore un exécutable** — juste un
  morceau de code relogeable.

> **Pourquoi un fichier objet et pas directement un exécutable ?**
> Parce qu'à ce stade, `boot.s` appelle `kmain`, une fonction définie dans le
> code Rust. NASM ne connaît pas encore son adresse ; l'éditeur de liens résoudra
> ce symbole externe lors de l'étape 3.

---

## Temps 2 — Compiler le noyau Rust en bibliothèque statique

### La commande (ligne 14 de `build.sh`)

```bash
cargo build --release
```

### Ce qui se passe réellement

Simple en apparence, cette commande déclenche une chaîne d'opérations pilotées
par la configuration de [`../../.cargo/config.toml`](../../.cargo/config.toml)
(détaillée à l'[étape 03](../03-cible-rust-baremetal/README.md)) :

1. **Cible custom** : `target = "i386-kfs.json"` dans `.cargo/config.toml` force
   Cargo à utiliser notre specification de cible bare-metal 32 bits, pas la cible
   hôte (arm64 ou amd64).
2. **Recompilation de `core`** : `build-std = ["core", "compiler_builtins"]` —
   Cargo recompile la bibliothèque standard minimale *pour notre cible*, sans
   système d'exploitation sous-jacent.
3. **Mode `--release`** : optimisations activées (`-O3` équivalent), taille de
   code réduite — important pour rester sous les 10 Mo.
4. **Sortie** : `target/i386-kfs/release/libkfs1.a` — une *static library*
   (archive `.a`) qui regroupe tous les fichiers objets Rust compilés.

> **Pourquoi une staticlib et pas directement un exécutable ?**
> `Cargo.toml` déclare `crate-type = ["staticlib"]`. Cela indique à rustc de
> produire une archive `.a` que l'éditeur de liens externe (`ld`) incorporera,
> plutôt que de lier lui-même. C'est nous qui contrôlons entièrement l'édition
> de liens (étape 3).

---

## Temps 3 — Édition de liens : `boot.o` + `libkfs1.a` → `kfs1.bin`

### La commande (lignes 17-19 de `build.sh`)

```bash
ld -m elf_i386 -n -T linker.ld -o build/kfs1.bin \
    build/boot.o \
    target/i386-kfs/release/libkfs1.a
```

### Pourquoi lier nous-mêmes ?

Un compilateur "normal" appelle l'éditeur de liens en votre nom et injecte
silencieusement du code de démarrage (`crt0.o`, `crti.o`…), la bibliothèque C
standard et les bibliothèques runtime. Pour un noyau bare-metal, **tout ce code
suppose un OS existant** (appels système, pile allouée par l'OS, etc.). Il est
donc impératif d'invoquer `ld` directement, sans rien de tout ça.

### Décryptage option par option

| Option | Signification |
|---|---|
| `-m elf_i386` | Choisit l'émulation cible : ELF 32 bits pour i386. Sans cela, `ld` produirait un binaire 64 bits sur une machine hôte amd64. |
| `-n` | **nmagic** — désactive l'alignement automatique des sections sur des pages de 4 Ko dans le fichier. Cela évite un gonflage inutile du fichier binaire, car c'est notre script linker qui gère déjà les alignements. |
| `-T linker.ld` | Utilise **notre** script d'édition de liens (voir [étape 06](../06-linker-script/README.md)) au lieu du script par défaut. Il place le noyau à 1 Mio, ordonne les sections dans le bon ordre (`.multiboot_header` en premier), et exporte `_bss_start`, `_bss_end`, `_kernel_end`. |
| `-o build/kfs1.bin` | Fichier de sortie — l'image brute du noyau, format ELF32. |
| `build/boot.o` | L'objet assembleur (étape 1). Il est listé **en premier** afin que le code de démarrage (`_start`) soit placé au tout début du segment `.text`, et que l'en-tête `.multiboot_header` se retrouve dans les 8 premiers Kio (exigence Multiboot). |
| `target/i386-kfs/release/libkfs1.a` | L'archive statique Rust (étape 2). `ld` extrait automatiquement les objets qui résolvent des symboles non définis (notamment `kmain`). |

### L'avertissement « LOAD segment with RWX permissions »

Lors de la liaison, vous verrez probablement :

```
ld: warning: build/kfs1.bin has a LOAD segment with RWX permissions
```

Cet avertissement signifie que l'un des segments du binaire ELF est marqué à la
fois **Readable**, **Writable** et e**X**ecutable. Dans un système normal, c'est
un signal d'alarme (risque de sécurité). Ici, c'est **inoffensif et attendu** :

- Le noyau s'exécute sans MMU activée au démarrage. Il n'y a pas encore de
  protection de page.
- Notre script `linker.ld` réunit `.text`, `.data` et `.bss` sans déclarer
  explicitement des segments séparés avec des droits distincts — `ld` fusionne
  donc tout en un seul segment RWX.
- Ce comportement disparaîtra dès que l'on configure correctement la pagination
  (étapes futures).

L'option `-n` (nmagic) contribue également à ce comportement en supprimant la
logique de segments séparés par défaut.

---

## Vérification de l'en-tête Multiboot (lignes 22-27 de `build.sh`)

```bash
if grub-file --is-x86-multiboot build/kfs1.bin; then
    echo "   multiboot: OK"
else
    echo "   multiboot: FAILED" >&2
    exit 1
fi
```

### Pourquoi cette vérification ?

`grub-file --is-x86-multiboot` scanne les 8 premiers Kio du binaire à la
recherche de la signature magique Multiboot (`0x1BADB002`). Si elle est absente
ou mal alignée, GRUB refusera de démarrer le noyau — et l'erreur ne sera visible
qu'au boot, pas à la compilation. Cette vérification transforme ce problème en
**erreur de build immédiate**.

C'est le lien direct avec l'[étape 04](../04-grub-multiboot/README.md) qui explique
la structure de l'en-tête dans `boot.s`.

> Si `grub-file` échoue après une modification du linker script, vérifier que
> `.multiboot_header` est toujours la première section — c'est sa position dans
> les 8 premiers Kio qui importe.

---

## Fabrication de l'ISO bootable : `mkiso.sh`

Une fois `build/kfs1.bin` produit et validé, il faut créer une image ISO
amorçable que QEMU (ou un vrai CD/USB) peut utiliser.

### Structure du répertoire ISO (lignes 5-8 de `mkiso.sh`)

```bash
ISODIR=build/isodir
mkdir -p "$ISODIR/boot/grub"
cp build/kfs1.bin "$ISODIR/boot/kfs1.bin"
cp grub/grub.cfg  "$ISODIR/boot/grub/grub.cfg"
```

`grub-mkrescue` attend une arborescence précise :

```
build/isodir/
└── boot/
    ├── kfs1.bin      ← notre noyau
    └── grub/
        └── grub.cfg  ← configuration GRUB (entrée de menu, module multiboot)
```

### `grub-mkrescue` (ligne 10 de `mkiso.sh`)

```bash
grub-mkrescue -o build/kfs1.iso "$ISODIR" 2>/dev/null
```

`grub-mkrescue` est un outil de la suite GRUB qui :

1. Intègre GRUB lui-même (chargeur de premier et deuxième niveau) dans l'ISO.
2. Ajoute le contenu de `$ISODIR` (notre noyau + config).
3. Produit une image ISO 9660 bootable via **El Torito** (standard de démarrage
   depuis CD).

En coulisses, `grub-mkrescue` appelle **`xorriso`** pour construire l'image ISO.
`xorriso` est la bibliothèque/commande qui gère la création d'images ISO 9660
avec les extensions de démarrage. Vous ne l'appelez pas directement, mais c'est
lui qui fait le travail bas-niveau.

### Contrôle de la taille : la contrainte des 10 Mo (lignes 12-19 de `mkiso.sh`)

```bash
size=$(stat -c%s build/kfs1.iso)
printf ">> ISO: build/kfs1.iso (%s bytes, %s)\n" "$size" "$(numfmt --to=iec "$size" 2>/dev/null || echo "${size}B")"
if [ "$size" -le 10485760 ]; then
    echo "   size <= 10 MB: OK"
else
    echo "   ERROR: ISO exceeds 10 MB" >&2
    exit 1
fi
```

`10485760` = 10 × 1024 × 1024 = **10 Mio** (mebibytes).

- `stat -c%s` retourne la taille du fichier en octets.
- `numfmt --to=iec` convertit en notation lisible (ex. `4,2M`).
- Si l'ISO dépasse 10 Mio, le script échoue avec un code d'erreur — le `make`
  s'arrête proprement.

> **Pourquoi 10 Mo ?** C'est la contrainte du sujet 42. Elle garantit que le
> noyau reste léger et qu'on n'embarque pas de dépendances inutiles. GRUB seul
> pèse déjà ~3-4 Mo dans l'ISO ; il reste ~6 Mo pour le noyau.

---

## Capture d'écran VGA : `screenshot.sh`

Ce script permet de **vérifier visuellement** que le noyau affiche bien la
sortie VGA attendue, sans ouvrir de fenêtre graphique.

### Fonctionnement (lignes 10-12 de `screenshot.sh`)

```bash
DELAY="${1:-7}"

( sleep "$DELAY"; printf 'screendump build/screen.ppm\n'; sleep 1; printf 'quit\n' ) \
  | timeout "$(( DELAY + 18 ))" qemu-system-i386 -cdrom build/kfs1.iso \
        -display none -serial null -monitor stdio -no-reboot >/dev/null 2>&1 || true
```

Le mécanisme est ingénieux :

1. **QEMU démarre** avec `-display none` (pas de fenêtre) et `-monitor stdio`
   (le moniteur QEMU — une console de contrôle — est connecté à l'entrée/sortie
   standard).
2. **Un sous-shell** envoie des commandes au moniteur QEMU via le pipe `|` :
   - Attend `$DELAY` secondes (7 par défaut) que le noyau ait fini de démarrer
     et d'afficher son écran.
   - Envoie `screendump build/screen.ppm` : commande QEMU qui capture le
     framebuffer VGA et le sauvegarde au format **PPM** (Portable PixMap, format
     image brut).
   - Attend 1 seconde supplémentaire.
   - Envoie `quit` pour terminer QEMU.
3. `timeout $(( DELAY + 18 ))` garantit que le script ne reste pas bloqué
   indéfiniment.

> **Pourquoi le délai ?** Sans lui, `screendump` capture le framebuffer QEMU
> avant que le noyau n'ait affiché quoi que ce soit — on obtiendrait l'écran
> "display not initialized" de QEMU plutôt que notre sortie. 7 secondes laissent
> le temps à GRUB de démarrer, puis au noyau de s'initialiser et d'écrire en
> mémoire VGA.

### Conversion PPM → PNG (lignes 19-20 de `screenshot.sh`)

```bash
pamscale 2 build/screen.ppm 2>/dev/null | pnmtopng 2>/dev/null > build/screen.png
echo ">> wrote build/screen.png ($(stat -c%s build/screen.png) bytes), mode $(head -c 15 build/screen.ppm | tr '\n' ' ')"
```

- `pamscale 2` : double la résolution (×2) pour une image plus lisible — l'écran
  VGA 80×25 en 720×400 pixels est minuscule en pixels modernes.
- `pnmtopng` : convertit le format PPM/PNM en PNG standard.
- La ligne `echo` affiche la taille du PNG et le mode PPM (ex. `P6 720 400`) —
  utile pour diagnostiquer un problème de capture.

---

## Les cibles `make`

Le [`../../Makefile`](../../Makefile) enchaîne tout cela. Voici le graphe de
dépendances :

```
all
 └── iso
      └── build
           └── (build.sh dans le conteneur)
```

### Tableau des cibles

| Cible | Ce qu'elle fait | Dépend de |
|---|---|---|
| `make image` | Construit l'image Docker `kfs1-toolchain` | — |
| `make build` | Exécute `scripts/build.sh` dans le conteneur → `build/kfs1.bin` | `image` |
| `make iso` | Exécute `scripts/mkiso.sh` dans le conteneur → `build/kfs1.iso` | `build` |
| `make run` | Lance QEMU sans interface graphique, console série sur stdout | `iso` |
| `make smoke` | Boot headless, vérifie que `KFS1_BOOT_OK` apparaît sur le port série | `iso` |
| `make run-gui` | Lance QEMU avec VNC sur `localhost:5900` | `iso` |
| `make screenshot` | Exécute `scripts/screenshot.sh` → `build/screen.png` | `iso` |
| `make debug` | Lance QEMU arrêté, GDB distant sur `:1234` | `iso` |
| `make shell` | Ouvre un shell interactif dans le conteneur | — |
| `make clean` | Supprime `build/` et `target/` | — |
| `make re` | `clean` + `all` | — |

### Le conteneur Docker dans chaque cible

```makefile
DOCKER := docker run --rm --platform $(PLATFORM) -v "$(CURDIR)":/kfs -w /kfs $(IMAGE)
```

Toutes les cibles qui nécessitent la chaîne de compilation (`build`, `iso`,
`screenshot`…) préfixent leur commande avec `$(DOCKER)`. Cela signifie que
`nasm`, `cargo`, `ld`, `grub-mkrescue`, `qemu-system-i386` sont toujours exécutés
**dans le conteneur linux/amd64**, jamais directement sur la machine hôte macOS.
C'est pourquoi la chaîne fonctionne sur Apple Silicon sans rien installer
localement (voir [étape 02](../02-environnement-build/README.md)).

---

## En résumé

Le passage de la source au noyau amorçable suit trois opérations irréductibles :

1. **`nasm -f elf32`** transforme le code assembleur de démarrage en un objet
   ELF32 relogeable. C'est la seule partie écrite en assembleur ; tout le reste
   est en Rust.
2. **`cargo build --release`** compile le noyau Rust en archive statique
   (`libkfs1.a`) pour la cible custom `i386-kfs`, sans aucun runtime OS.
3. **`ld -m elf_i386 -n -T linker.ld`** fusionne ces deux artefacts en un unique
   binaire ELF32 placé à 1 Mio, avec nos sections dans le bon ordre et les
   symboles BSS exportés.

L'ISO est ensuite produite par `grub-mkrescue` (qui embarque GRUB + notre noyau)
et validée par une double vérification : l'en-tête Multiboot (`grub-file`) et la
taille (≤ 10 Mio). Le `Makefile` orchestre tout cela derrière des cibles simples
(`make build`, `make iso`, `make smoke`), en s'assurant que chaque opération se
déroule dans le conteneur Docker approprié.

---

## Pour aller plus loin

- **[Étape 02](../02-environnement-build/README.md)** — Pourquoi et comment le
  conteneur Docker fournit `nasm`, `ld`, `grub-mkrescue` sur macOS.
- **[Étape 03](../03-cible-rust-baremetal/README.md)** — La cible custom `i386-kfs.json`
  et ce que `build-std` implique.
- **[Étape 04](../04-grub-multiboot/README.md)** — La structure de l'en-tête Multiboot
  que `grub-file` vérifie.
- **[Étape 06](../06-linker-script/README.md)** — Le script `linker.ld` : adresse
  de chargement, ordre des sections, symboles exportés.
- Documentation GNU ld : <https://sourceware.org/binutils/docs/ld/>
- Spécification Multiboot 1 : <https://www.gnu.org/software/grub/manual/multiboot/>
- Manuel QEMU (monitor, screendump) : <https://www.qemu.org/docs/master/system/monitor.html>
