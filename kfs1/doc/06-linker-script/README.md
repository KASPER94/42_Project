# Étape 06 — Le script d'édition de liens

## Objectif de l'étape

Comprendre le rôle de l'éditeur de liens et lire `linker.ld` : où le noyau est
chargé en mémoire (1 Mio), dans quel ordre les sections sont disposées, et quels
symboles sont exportés pour le reste du code.

## Fichiers concernés

- [`../../linker.ld`](../../linker.ld) — le script `ld` (fichier entier)
- [`../../src/boot.s`](../../src/boot.s) — consomme `_bss_start` / `_bss_end` ; place `.multiboot_header`
- [`../../scripts/build.sh`](../../scripts/build.sh) — montre l'appel `ld -m elf_i386 -n -T linker.ld …`

---

## Qu'est-ce qu'un éditeur de liens ?

### Le problème : des objets isolés

Quand on compile ou assemble un fichier source, le compilateur/assembleur
produit un **fichier objet** (extension `.o` ou `.a`). Ce fichier contient :

- du **code machine** (section `.text`) ;
- des **données** (sections `.data`, `.rodata`, `.bss`) ;
- une **table de symboles** : la liste des noms définis (fonctions, variables
  globales) et des noms *référencés* mais pas encore résolus (par exemple,
  `boot.o` appelle `kmain` sans savoir où il se trouve).

À ce stade, les adresses sont **fictives** ou **relatives**. Le code ne peut pas
s'exécuter tel quel.

### La mission de `ld`

L'éditeur de liens (`ld`) prend plusieurs fichiers objets en entrée et :

1. **Fusionne** les sections de même nature (`tous les .text` ensemble, tous
   les `.bss` ensemble…) ;
2. **Fixe les adresses définitives** de chaque section et de chaque symbole
   dans l'espace d'adressage final ;
3. **Résout les références croisées** : partout où `boot.o` écrit `call kmain`,
   `ld` remplace le symbole par l'adresse réelle de `kmain` dans `libkfs1.a` ;
4. **Produit un binaire exécutable** (ici, un ELF32 nommé `kfs1.bin`).

Dans notre projet, l'appel concret se trouve dans
[`../../scripts/build.sh`](../../scripts/build.sh) à la ligne 17 :

```bash
ld -m elf_i386 -n -T linker.ld -o build/kfs1.bin \
    build/boot.o \
    target/i386-kfs/release/libkfs1.a
```

| Option | Rôle |
|---|---|
| `-m elf_i386` | Produit un ELF 32 bits pour i386. |
| `-n` | *nmagic* : désactive l'alignement automatique des segments. Nécessaire car on contrôle l'alignement manuellement dans `linker.ld`. |
| `-T linker.ld` | Utilise **notre** script à la place du script par défaut de l'hôte. |
| `-o build/kfs1.bin` | Nom du fichier de sortie. |

---

## Pourquoi interdire le script `.ld` de l'hôte ?

Le sujet l'impose explicitement (voir `.specs/rules.md`, section Linking) :

> « You **cannot** use an existing/host linker script to link your kernel — it
> won't boot. You **must create your own linker file**. »

La raison est simple : le script par défaut de l'hôte est conçu pour des
**programmes Linux en espace utilisateur**. Il place le code à une adresse
virtuelle élevée (par exemple `0x08048000` sur Linux 32 bits), suppose la
présence d'un système d'exploitation, de la libc, d'un chargeur dynamique…
Rien de tout cela n'existe dans un noyau bare-metal. Si on l'utilisait, GRUB
ne trouverait pas le header Multiboot, les adresses seraient fausses, et le
noyau crasherait immédiatement.

Notre `linker.ld` donne à `ld` des instructions précises, adaptées à un noyau
i386 chargé par GRUB : adresse de chargement, ordre des sections, symboles
exportés.

---

## Anatomie de `linker.ld` section par section

### `ENTRY(_start)` — le point d'entrée (ligne 12)

```ld
ENTRY(_start)
```

`ENTRY` dit à `ld` quel symbole constitue le **point d'entrée** du programme,
c'est-à-dire la première instruction qui s'exécutera. Ici, c'est `_start`,
défini dans [`../../src/boot.s`](../../src/boot.s) (ligne 47 : `_start:`).

GRUB lit le champ `e_entry` de l'en-tête ELF pour savoir où sauter ; `ENTRY`
est la façon d'écrire ce champ. Sans lui, `ld` choisirait un point d'entrée
par défaut qui serait incorrect.

> Lien avec l'étape 05 : `_start` est le code d'amorçage qui configure la pile
> et zéro `.bss` avant d'appeler `kmain`.

### `SECTIONS { }` — la commande principale (ligne 14)

```ld
SECTIONS
{
    ...
}
```

Tout ce qui se trouve à l'intérieur de `SECTIONS { }` décrit la **mise en
page** du binaire final : quelles sections existent, dans quel ordre, et à
quelle adresse.

### Le compteur de position `.` (ligne 20)

```ld
. = 1M;
```

Le point `.` est le **compteur de position** (*location counter*). Il représente
l'adresse courante pendant la construction du binaire. En l'affectant à `1M`
(raccourci pour `1 * 1024 * 1024 = 0x00100000`), on dit :

> « La première section que tu vas écrire commencera à l'adresse physique
> 0x00100000. »

Tout ce qui suit sera placé **à partir de 1 Mio**, sauf si on recalcule `.`
explicitement.

#### Pourquoi 1 Mio ?

Le premier mégaoctet de la mémoire physique x86 est **occupé** et ne nous
appartient pas :

| Plage | Contenu |
|---|---|
| `0x00000–0x003FF` | Table des vecteurs d'interruption (IVT, mode réel) |
| `0x00400–0x004FF` | Zone de données BIOS (BDA) |
| `0x07C00–0x07DFF` | MBR / premier chargeur de GRUB |
| `0x0A000–0x0BFFF` | Mémoire vidéo VGA |
| `0x0C000–0x0FFFF` | ROM BIOS |

GRUB lui-même réside en dessous de 1 Mio pendant le chargement. Commencer à
`0x100000` garantit que notre noyau ne **collisionne** avec rien de tout cela.

---

### Section `.multiboot_header` (lignes 26–29)

```ld
.multiboot_header :
{
    KEEP(*(.multiboot_header))
}
```

Cette section accueille le **header Multiboot v1** défini dans `boot.s`
(lignes 23–27 : `section .multiboot_header`, magic, flags, checksum).

Deux points importants :

**Positionnement en premier.** La spécification Multiboot v1 exige que le
magic dword `0x1BADB002` se trouve dans les **8 premiers Kio** du fichier
noyau. En plaçant `.multiboot_header` immédiatement après `. = 1M;`, elle
démarre à l'adresse exacte `0x00100000`, bien dans la fenêtre des 8 Kio.
Si cette section était reléguée après `.text` (souvent plusieurs dizaines de
Kio), GRUB ne trouverait pas le magic et refuserait de charger le noyau.

**`KEEP(…)`.** Par défaut, `ld` peut supprimer les sections qu'il juge
« non référencées » lors d'une optimisation. Le header Multiboot n'est jamais
appelé par le code Rust ou assembleur : il est lu directement par GRUB via
l'adresse physique. Sans `KEEP`, le linker pourrait donc l'éliminer.
`KEEP` force sa conservation inconditionnelle.

> Lien avec l'étape 04 : c'est dans cette section que résident les trois
> `dd` (magic, flags, checksum) qui permettent à GRUB de détecter et charger
> le noyau.

---

### Section `.text` (lignes 32–35)

```ld
.text ALIGN(4K) :
{
    *(.text .text.*)
}
```

`.text` contient le **code exécutable** : le code assembleur de `_start`, et
toutes les fonctions Rust compilées.

`*(.text .text.*)` est un **sélecteur** : il attrape la section `.text` de
**tous les fichiers objets en entrée** (`*`), ainsi que toutes les sous-sections
`.text.foo`, `.text.bar`, etc. (les compilateurs modernes créent souvent une
sous-section par fonction pour permettre la suppression des fonctions
inutilisées — *function-level dead-stripping*).

#### `ALIGN(4K)` — pourquoi aligner ?

`ALIGN(4K)` arrondit l'adresse courante `.` au prochain multiple de 4 096
(une page mémoire x86) **avant** de commencer la section. Cela sert à :

1. **Faciliter la gestion de la mémoire virtuelle future.** La pagination x86
   opère en granularité de 4 Kio ; des sections alignées sur des pages simplifient
   radicalement le mappage et l'attribution d'attributs de protection (lecture
   seule, exécutable…).
2. **Éviter les problèmes de cache et d'alignement du processeur.** Les lignes
   de cache et certaines instructions tirent parti de données alignées.

On retrouve `ALIGN(4K)` devant chaque section majeure (`.text`, `.rodata`,
`.data`, `.bss`) pour la même raison.

---

### Section `.rodata` (lignes 38–41)

```ld
.rodata ALIGN(4K) :
{
    *(.rodata .rodata.*)
}
```

`.rodata` (*read-only data*) contient les **données en lecture seule** :
littéraux de chaînes de caractères, constantes `static` Rust, tables intégrées
dans le binaire…

La séparer de `.text` permet, quand on activera la pagination, de marquer cette
zone *non exécutable* et *en lecture seule* — une bonne pratique de sécurité.

---

### Section `.data` (lignes 44–47)

```ld
.data ALIGN(4K) :
{
    *(.data .data.*)
}
```

`.data` contient les **données globales initialisées** : variables `static mut`
Rust ayant une valeur initiale non nulle, tables, etc.

Ces données sont stockées dans le fichier binaire (elles ont une valeur
initiale) et chargées en RAM par GRUB au moment du boot. Contrairement à
`.bss`, il n'y a rien à initialiser soi-même : c'est déjà fait dans le fichier.

---

### Section `.bss` et les symboles exportés (lignes 53–60)

```ld
.bss ALIGN(4K) :
{
    _bss_start = .;         /* exported: start of BSS (4K-aligned) */
    *(COMMON)               /* tentative (common) symbols from C/Rust */
    *(.bss .bss.*)
    . = ALIGN(4);           /* ensure _bss_end is 4-byte aligned */
    _bss_end = .;           /* exported: one-past-end of BSS */
}
```

`.bss` contient les **données globales non initialisées** (ou initialisées à
zéro). Contrairement à `.data`, ces données n'occupent **aucune place dans le
fichier binaire** : le linker inscrit simplement leur taille dans l'en-tête
ELF. GRUB n'a donc pas besoin de les lire depuis le disque.

**Mais attention :** Multiboot v1 ne garantit **pas** que `.bss` est mis à zéro
avant de sauter à `_start`. Notre code assembleur doit le faire lui-même — d'où
les symboles `_bss_start` et `_bss_end`.

#### `*(COMMON)` — les symboles tentatives

`*(COMMON)` désigne les symboles dits **tentatives** (*tentative definitions*) :
des variables globales que le compilateur C (et parfois Rust) déclare sans les
affecter à une section `.bss` précise, laissant au linker le soin de les
regrouper. Les inclure ici garantit qu'ils font partie de la zone zérisée.

#### `_bss_start` et `_bss_end` — symboles exportés vers `boot.s`

```ld
_bss_start = .;
...
_bss_end = .;
```

Dans un script `ld`, écrire `nom = .;` **crée un symbole global** dont la
valeur est l'adresse courante `.` à cet instant. Ces symboles sont visibles de
tout le code lié, exactement comme une étiquette assembleur ou un `extern` en
C/Rust.

`boot.s` les déclare en ligne 44 :
```nasm
extern _bss_start
extern _bss_end
```
et les utilise lignes 65–70 pour la boucle de mise à zéro :
```nasm
mov edi, _bss_start   ; destination = début de .bss
mov ecx, _bss_end
sub ecx, edi          ; ecx = taille en octets
shr ecx, 2            ; ecx = taille en dwords (÷ 4)
xor eax, eax          ; valeur = 0
rep stosd             ; remplit .bss de zéros, 4 octets par 4 octets
```

`rep stosd` écrit **4 octets à la fois**. Pour que le nombre de dwords soit
exact (sans octets perdus en fin de boucle), il faut que `_bss_end` soit aligné
sur 4 octets. C'est ce que fait `. = ALIGN(4);` juste avant.

> Lien avec l'étape 05 : cette boucle `rep stosd` est le cœur de l'étape 05 ;
> les symboles `_bss_start`/`_bss_end` en sont les deux bornes.

#### `_kernel_end` — symbole exporté (ligne 65)

```ld
_kernel_end = .;
```

Ce symbole, placé **après toutes les sections**, marque la **fin de l'image
noyau** en mémoire physique. Il est défini en dehors du bloc `.bss`, après
l'accolade fermante, donc son adresse pointe sur le premier octet libre après
le noyau.

Sa principale utilité future : un allocateur de mémoire physique (frame
allocator) a besoin de savoir à partir de quelle adresse la RAM est disponible.
`_kernel_end` lui fournit cette borne inférieure sans avoir à la calculer
manuellement.

---

## VMA / LMA — adresse virtuelle et adresse de chargement

Deux notions importantes, même si `linker.ld` ne les distingue pas
explicitement ici :

- **VMA** (*Virtual Memory Address*) : l'adresse à laquelle le code *s'attend*
  à s'exécuter. C'est ce qu'on fixe avec `.`.
- **LMA** (*Load Memory Address*) : l'adresse physique où le chargeur (GRUB)
  copie effectivement la section.

Dans notre noyau en mode physique pur (pas de pagination active), VMA = LMA.
Les deux valent `0x00100000` et au-delà. Si l'on activait la pagination et
remappait le noyau en espace d'adressage haut (par exemple `0xC0100000`), il
faudrait dissocier VMA et LMA avec la syntaxe `AT(lma)` — mais ce n'est pas
le sujet de kfs1.

---

## Vue d'ensemble de la mémoire au démarrage

```
Adresse physique    Contenu
─────────────────   ──────────────────────────────────────────
0x00000000          IVT (mode réel), BDA, ROM, VGA…
          …         Zone réservée — NE PAS ÉCRIRE ICI
0x000FFFFF          Fin du premier Mio

0x00100000  ←  . = 1M;
            ╔═══════════════════════════════╗
            ║  .multiboot_header (≥ 12 o)   ║  ← GRUB lit ici
            ╠═══════════════════════════════╣
            ║  .text    (ALIGN 4K)          ║  code exécutable
            ╠═══════════════════════════════╣
            ║  .rodata  (ALIGN 4K)          ║  chaînes, consts
            ╠═══════════════════════════════╣
            ║  .data    (ALIGN 4K)          ║  données init.
            ╠═══════════════════════════════╣
_bss_start →║  .bss     (ALIGN 4K)          ║  données non init.
            ║    stack_bottom…stack_top     ║  (inclus dans .bss)
_bss_end   →╠═══════════════════════════════╣
_kernel_end →   premier octet libre
            ╚═══════════════════════════════╝
```

---

## Renvois vers d'autres étapes

| Étape | Lien |
|---|---|
| **Étape 04** — Header Multiboot | Le header placé dans `.multiboot_header` par `KEEP` |
| **Étape 05** — `_start` et zéro BSS | `_bss_start` / `_bss_end` consommés par `rep stosd` |
| **Étape 08** — Processus de build | L'appel complet `ld -m elf_i386 -n -T linker.ld …` |

---

## En résumé

- `ld` fusionne les fichiers objets et fixe les adresses définitives. Sans
  script personnalisé, il utiliserait celui de l'hôte — inadapté à un noyau
  bare-metal, qui ne booterait pas.
- `linker.ld` place le noyau à **1 Mio** (en dehors de la zone réservée),
  garantit que le header Multiboot est dans les 8 premiers Kio (`KEEP`),
  aligne chaque section sur une page (`ALIGN(4K)`), et exporte trois symboles
  (`_bss_start`, `_bss_end`, `_kernel_end`) indispensables au code assembleur
  et aux futures extensions du noyau.

---

## Pour aller plus loin

- **OSDev Wiki — Linker Scripts** :
  <https://wiki.osdev.org/Linker_Scripts>
- **GNU `ld` manual — Linker Scripts** :
  <https://sourceware.org/binutils/docs/ld/Scripts.html>
- **Multiboot Specification** (section sur l'en-tête et la fenêtre 8 Kio) :
  <https://www.gnu.org/software/grub/manual/multiboot/multiboot.html>
- **OSDev — Memory Map (x86)** (détail du premier Mio réservé) :
  <https://wiki.osdev.org/Memory_Map_(x86)>
