# Étape 01 — Vue d'ensemble & cycle de vie du boot

## Objectif de l'étape

Comprendre ce qu'est un noyau « freestanding » (sans OS sous lui), parcourir
l'arborescence du projet pour savoir où vit quoi, et suivre le voyage complet
depuis la mise sous tension jusqu'à l'affichage de `42` à l'écran. Cette étape
est la carte qui situe toutes les suivantes.

## Fichiers concernés

- [`../../README.md`](../../README.md) — présentation et commandes du projet
- [`../../CONTRACTS.md`](../../CONTRACTS.md) — le contrat interne (ABI, mémoire, modules)
- [`../../.specs/README.md`](../../.specs/README.md) — le sujet 42 découpé
- Vue d'ensemble du code : [`../../src/`](../../src/) (`boot.s`, `lib.rs`, `vga.rs`, `console.rs`, `keyboard.rs`, `screens.rs`, `libk/`)

---

## Qu'est-ce qu'un noyau ?

Un **noyau** (ou *kernel*) est le programme qui s'exécute directement sur le
matériel. Il n'y a rien en dessous : pas de système d'exploitation, pas
d'environnement d'exécution, pas de bibliothèque. C'est lui qui *est* le
système d'exploitation, au sens le plus bas.

Quand tu écris un programme normal — en Rust, Python, C — tu t'appuies
silencieusement sur une pile entière : la bibliothèque standard du langage,
la libc, les appels système du noyau, les pilotes matériels. Tout ça existe
déjà quand ton `main` commence.

Un noyau n'a rien de tout ça. Il doit tout construire lui-même : gestion
de la mémoire, affichage, clavier, et même les fonctions de base comme
`memcpy`.

### Le terme « freestanding » ou « bare-metal »

En Rust (et en C), on parle de **cible freestanding** ou **bare-metal**
(*métal nu*) pour désigner une compilation qui ne présuppose aucun OS sous
le programme.

La conséquence la plus directe : tu n'as **pas accès à `std`**. La
bibliothèque standard de Rust dépend d'un OS pour exister (allocation
mémoire, threads, fichiers, réseau…). Sur bare-metal, il n'y a pas d'OS
—donc pas de `std`.

C'est pour ça que le fichier [`../../src/lib.rs`](../../src/lib.rs) commence
par :

```rust
#![no_std]
```

Cette directive dit au compilateur : *n'essaie pas de lier la bibliothèque
standard*. On n'utilise que `core`, le sous-ensemble de Rust qui ne dépend
d'aucun OS (types primitifs, itérateurs, formatage, etc.).

### Pourquoi pas la libc non plus ?

La libc (GNU libc, musl, etc.) n'est pas la bibliothèque standard Rust — c'est
la bibliothèque C du système. Mais elle dépend elle aussi d'appels système :
`malloc` demande de la mémoire au noyau, `printf` écrit via `write()`,
`exit()` appelle le noyau. Sur bare-metal, il n'y a pas de noyau à appeler.
Le noyau, c'est *nous*.

### Pas de `main` non plus

Un programme normal a un `main` qui est *appelé* par le runtime du système
après initialisation (chargement de `argc`/`argv`, initialisation des
constructeurs C, etc.). Sur bare-metal, ce runtime n'existe pas. Notre point
d'entrée s'appelle `_start` (en assembleur, cf. [`../../src/boot.s`](../../src/boot.s))
puis `kmain` (en Rust).

---

## Qu'est-ce que la cross-compilation ?

Quand tu compiles ce noyau, ton ordinateur hôte est probablement un Mac ARM
(Apple Silicon) ou un PC amd64. Mais le noyau doit tourner sur une machine
**i386** (x86 32 bits). Ce ne sont pas les mêmes instructions.

La **cross-compilation** consiste à compiler sur une machine (l'hôte) pour
une architecture différente (la cible). La cible ici est `i386-kfs`, une
cible personnalisée définie dans [`../../i386-kfs.json`](../../i386-kfs.json).

En pratique, tout le build tourne dans un **conteneur Docker Linux amd64**,
parce que les outils GRUB et la chaîne `i386` ne sont pas disponibles nativement
sur macOS ARM. Ce point est détaillé dans [l'étape 02](../02-environnement-build/README.md).

---

## L'arborescence du projet

```
kfs1/
│
├── src/                   ← tout le code source
│   ├── boot.s             ← entrée assembleur (_start), en-tête Multiboot, pile
│   ├── lib.rs             ← entrée Rust (kmain), macros print!, panic handler
│   ├── vga.rs             ← pilote écran texte VGA (0xB8000, 80×25)
│   ├── console.rs         ← glue core::fmt::Write → VGA (backend de print!)
│   ├── keyboard.rs        ← lecture clavier PS/2 en polling (port 0x60)
│   ├── screens.rs         ← 4 écrans virtuels, bascule avec F1–F4
│   └── libk/              ← bibliothèque kernel (types, strlen, strcmp…)
│       ├── mod.rs
│       ├── types.rs
│       └── string.rs
│
├── linker.ld              ← script d'édition de liens (chargement à 1 Mio)
├── i386-kfs.json          ← description de la cible Rust bare-metal i386
├── Cargo.toml             ← manifeste Rust (crate = staticlib, nightly)
├── rust-toolchain.toml    ← épingle la version nightly de Rust
├── Makefile               ← commandes build/run/debug
├── Dockerfile             ← conteneur avec nasm, grub, qemu, Rust nightly
├── grub/grub.cfg          ← configuration du bootloader GRUB
├── scripts/               ← scripts internes appelés par le Makefile
│   └── build.sh           ← assemble, compile, lie, fabrique l'ISO
│
├── CONTRACTS.md           ← contrat inter-modules (ABI, mémoire, interfaces)
├── README.md              ← documentation utilisateur (commandes make)
├── .specs/                ← sujet 42 découpé sémantiquement
└── doc/                   ← documentation pédagogique (ce que tu lis)
```

### Rôle de chaque fichier source

| Fichier | Rôle | Étape dédiée |
|---|---|---|
| `src/boot.s` | Assembleur NASM : en-tête Multiboot, pile 16 Ko, mise à zéro de `.bss`, appel de `kmain` | [Étape 05](../05-boot-asm/README.md) |
| `src/lib.rs` | Crate root `#![no_std]` : point d'entrée `kmain`, macros `print!`/`println!`, panic handler, helpers I/O | [Étape 07](../07-coeur-rust/README.md) |
| `src/vga.rs` | Pilote écran texte : écrit dans le framebuffer à `0xB8000`, gère le défilement, les couleurs, le curseur matériel | [Étape 09](../09-ecran-vga/README.md) |
| `src/console.rs` | Implémente `core::fmt::Write` sur le VGA, permet le formatage `print!("{}", x)` | [Étape 11](../11-bonus-console-printf/README.md) |
| `src/keyboard.rs` | Lit les scancodes PS/2 sur le port `0x60` en polling, décode les touches et modificateurs | [Étape 12](../12-bonus-clavier-ecrans/README.md) |
| `src/screens.rs` | Maintient 4 tampons d'écran virtuels ; bascule entre eux sur F1–F4 | [Étape 12](../12-bonus-clavier-ecrans/README.md) |
| `src/libk/` | Bibliothèque kernel : aliases de types (`paddr`, `vaddr`…), fonctions C-string (`strlen`, `strcmp`, `strncmp`) | [Étape 10](../10-bibliotheque-libk/README.md) |
| `linker.ld` | Positionne les sections à 1 Mio, exporte `_bss_start`/`_bss_end`/`_kernel_end` | [Étape 06](../06-linker-script/README.md) |
| `i386-kfs.json` | Cible Rust personnalisée : i686, `os=none`, soft-float, `panic=abort` | [Étape 03](../03-cible-rust-baremetal/README.md) |
| `Dockerfile` | Image Linux amd64 avec `nasm`, `grub-pc-bin`, `qemu-system-i386`, Rust nightly | [Étape 02](../02-environnement-build/README.md) |
| `Makefile` | Orchestre le build conteneurisé : `make image`, `iso`, `run`, `smoke`… | [Étape 02](../02-environnement-build/README.md) |
| `grub/grub.cfg` | Indique à GRUB le fichier kernel et les options de démarrage | [Étape 04](../04-grub-multiboot/README.md) |

---

## Le cycle de vie complet du boot

Voici le voyage de la mise sous tension jusqu'à l'affichage de `42`. Chaque
bloc est développé dans une étape dédiée.

```
┌─────────────────────────────────────────────────────────────────────┐
│  Mise sous tension                                                  │
└────────────────────────────┬────────────────────────────────────────┘
                             │
                             ▼
                       ┌──────────┐
                       │  BIOS    │  Teste la RAM, le CPU, les périphériques.
                       │  (ROM)   │  Cherche un média amorçable (ISO, disque…).
                       └────┬─────┘  Charge le premier secteur (MBR) en mémoire.
                            │
                            ▼
                       ┌──────────┐
                       │  GRUB    │  Lit notre ISO.
                       │  stage 2 │  Trouve l'en-tête Multiboot dans les 8 premiers
                       └────┬─────┘  Ko du noyau (magic = 0x1BADB002).
                            │        Charge les segments ELF en mémoire physique.
                            │        Passe le CPU en MODE PROTÉGÉ 32 bits.
                            │        Saute à _start avec :
                            │          EAX = 0x2BADB002  (preuve que GRUB a chargé)
                            │          EBX = adresse de la struct multiboot_info
                            ▼
              ┌──────────────────────────┐
              │  _start  (src/boot.s)    │  ← étape 05
              │  [assembleur NASM]       │
              │                         │  1. mov esp, stack_top   → installe la pile
              │                         │  2. Zéro .bss (rep stosd)→ efface les globaux
              └────────────┬────────────┘  3. push EBX, push EAX   → prépare les args
                           │               4. call kmain             → saut vers Rust
                           ▼
              ┌──────────────────────────┐
              │  kmain  (src/lib.rs)     │  ← étape 07
              │  [Rust, #![no_std]]      │
              │                         │  1. screens::init() → initialise les 4 écrans
              │                         │     (appelle vga::init() → efface l'écran)
              │                         │  2. println!("42")  → affiche "42"
              └────┬──────────┬─────────┘  3. keyboard::init()
                   │          │             4. boucle principale
                   │          │
                   ▼          ▼
          ┌──────────────┐  ┌──────────────────────────────┐
          │  vga.rs      │  │  Boucle principale           │  ← étape 12 (bonus)
          │  (0xB8000)   │  │                              │
          │              │  │  loop {                      │
          │  Écrit "42"  │  │    keyboard::poll()          │
          │  dans le     │  │    → screens::handle_key()   │
          │  framebuffer │  │    → echo char / switch Fn   │
          └──────────────┘  └──────────────────────────────┘
               ← étape 09
```

### Pourquoi le mode protégé ?

Le processeur x86 démarre en **mode réel** (16 bits, 1 Mo de mémoire
adressable, héritage du 8086 de 1978). GRUB bascule le CPU en **mode protégé**
32 bits avant de nous passer la main. En mode protégé, on accède à 4 Go de
mémoire, on dispose de la protection des segments (le CPU empêche un programme
utilisateur d'écrire dans la mémoire du noyau), et les registres font 32 bits.

Notre noyau n'a jamais à gérer ce basculement : c'est GRUB qui le fait pour
nous. C'est l'un des services rendus par le standard Multiboot.

### Pourquoi charger à 1 Mio ?

Le premier mégaoctet de mémoire physique est reservé : il contient la table des
vecteurs d'interruption du mode réel, les données du BIOS, le framebuffer VGA
texte (`0xB8000`), etc. GRUB lui-même vit dans cet espace. Notre noyau est donc
chargé à **1 Mio (0x00100000)**, là où la mémoire est libre et disponible.
C'est le script d'édition de liens [`../../linker.ld`](../../linker.ld), ligne 20
(`. = 1M;`), qui impose cette adresse de chargement.

### Qu'est-ce que Multiboot ?

**Multiboot v1** est un standard entre bootloaders et noyaux. Il définit :

1. Un en-tête magique que le noyau doit inclure dans ses 8 premiers Ko.
   Dans [`../../src/boot.s`](../../src/boot.s) lignes 14–27 :
   ```nasm
   MAGIC    equ 0x1BADB002
   CHECKSUM equ -(MAGIC + MBFLAGS)
   ```
2. Ce que le bootloader (GRUB) doit mettre dans les registres avant de sauter
   au noyau : `EAX = 0x2BADB002` (preuve), `EBX = struct multiboot_info`.

Grâce à ce contrat, n'importe quel bootloader compatible Multiboot peut charger
n'importe quel noyau compatible Multiboot. Détails dans [l'étape 04](../04-grub-multiboot/README.md).

### Le rôle de l'assembleur au démarrage

Rust ne peut pas être le tout premier code à s'exécuter. Avant d'entrer dans
`kmain`, il faut :

- Installer une pile (le registre `ESP` doit pointer sur de la RAM valide,
  sinon le premier `push` plante tout).
- Mettre à zéro la section `.bss` (Multiboot v1 ne le garantit pas, mais
  Rust s'attend à ce que ses variables globales non initialisées soient à zéro).

C'est `_start` dans [`../../src/boot.s`](../../src/boot.s) qui s'en charge
(lignes 47–88), avant de passer la main à Rust via `call kmain`.

### L'entrée Rust : `kmain`

`kmain` est déclarée dans [`../../src/lib.rs`](../../src/lib.rs) ligne 100 :

```rust
#[no_mangle]
pub extern "C" fn kmain(_multiboot_magic: u32, _multiboot_info: u32) -> ! {
```

- `#[no_mangle]` : conserve le nom exact `kmain` dans le binaire (sans ça,
  Rust manglerait le nom et l'assembleur ne pourrait pas l'appeler).
- `extern "C"` : utilise la convention d'appel C (cdecl), la même que `boot.s`
  utilise pour passer les arguments.
- `-> !` : le type de retour `!` signifie *cette fonction ne retourne jamais*.
  C'est obligatoire : GRUB n'a nulle part où revenir.

### Le framebuffer VGA texte

L'affichage se fait sans pilote graphique, sans GPU, sans système de fenêtrage.
Le hardware x86 expose un **framebuffer texte** à l'adresse physique `0xB8000`.
C'est simplement une zone de 80×25 = 2000 cellules de 2 octets chacune :

```
octet 0 : code ASCII du caractère
octet 1 : attribut de couleur = (fond << 4) | premier plan
```

Écrire `'4'` blanc sur fond noir à la position (colonne 0, ligne 0) revient
à faire :

```rust
// Adresse de la cellule (0, 0) = 0xB8000 + 0
*(0xB8000 as *mut u8)       = b'4';   // caractère ASCII
*(0xB8001 as *mut u8)       = 0x0F;  // blanc (0xF) sur noir (0x0)
```

C'est exactement ce que fait [`../../src/vga.rs`](../../src/vga.rs) via
`write_volatile` (ligne 113). Détails complets dans [l'étape 09](../09-ecran-vga/README.md).

---

## Résumé de la chaîne de build

```
src/boot.s  ──[nasm]──► boot.o  ─────────────────────────────┐
                                                              │
src/*.rs    ──[cargo]──► libkfs1.a (staticlib, bare-metal) ──┤
i386-kfs.json                                                 │
                                                              ▼
linker.ld   ──────────────────────────────────[ld -m elf_i386]──► kfs1.bin
                                                              │
grub/grub.cfg ──────────────────────────[grub-mkrescue]───── ► kfs1.iso
```

La chaîne complète est détaillée dans [l'étape 08](../08-compilation-link/README.md).

---

## En résumé

- Un noyau freestanding s'exécute sur le matériel nu : pas de `std`, pas de
  libc, pas de runtime — tout doit être construit depuis zéro.
- GRUB prend en charge le démarrage bas niveau (mode protégé, chargement ELF)
  grâce au standard Multiboot v1 ; notre code assembleur `_start` complète
  l'initialisation (pile, `.bss`) avant de sauter en Rust.
- Le point d'entrée Rust `kmain` (dans `lib.rs`) est déclaré `extern "C"` et
  `-> !` : convention cdecl pour recevoir les arguments de `boot.s`, et
  interdiction de retourner.
- L'affichage se fait en écrivant directement dans le framebuffer texte VGA
  à l'adresse physique `0xB8000` — aucun pilote graphique requis.
- Chaque fichier source du projet a une étape dédiée dans cette documentation ;
  l'arborescence ci-dessus indique les liens vers chacune.

## Pour aller plus loin

- **Étape suivante :** [Étape 02 — L'environnement de build (Docker amd64)](../02-environnement-build/README.md)
  — pourquoi tout se compile dans un conteneur, et comment le `Makefile` pilote
  la chaîne d'outils.
- **OSDev Wiki :** [https://wiki.osdev.org/Bare_Bones](https://wiki.osdev.org/Bare_Bones)
  — le tutoriel de référence pour démarrer un noyau x86 minimaliste.
- **Standard Multiboot v1 :** [https://www.gnu.org/software/grub/manual/multiboot/multiboot.html](https://www.gnu.org/software/grub/manual/multiboot/multiboot.html)
  — la spécification complète de l'en-tête et des registres au démarrage.
- **VGA text mode :** [https://wiki.osdev.org/Printing_To_Screen](https://wiki.osdev.org/Printing_To_Screen)
  — explication détaillée du framebuffer texte à `0xB8000`.
