# Étape 04 — GRUB & le standard Multiboot

## Objectif de l'étape

Comprendre comment un noyau passe de « fichier sur un disque » à « code qui
s'exécute » : le rôle d'un bootloader, ce qu'est le standard **Multiboot v1**,
et comment GRUB trouve et charge notre kernel grâce à un en-tête spécial placé
dans [`../../src/boot.s`](../../src/boot.s).

---

## Fichiers concernés

- [`../../src/boot.s`](../../src/boot.s) — l'en-tête Multiboot v1 (section
  `.multiboot_header`, lignes 23–27) et le point d'entrée `_start`
- [`../../grub/grub.cfg`](../../grub/grub.cfg) — l'entrée de menu GRUB
  (`multiboot /boot/kfs1.bin` + `boot`)
- [`../../scripts/mkiso.sh`](../../scripts/mkiso.sh) — fabrication de l'ISO
  amorçable avec `grub-mkrescue`

---

## 1. Le chemin de démarrage : du BIOS à notre noyau

### 1.1 Ce que fait le BIOS au démarrage

Quand une machine x86 s'allume, le BIOS (ou UEFI en mode legacy) prend la main.
Il effectue un auto-test matériel (POST), puis cherche un **disque amorçable**.
Sur un disque MBR classique, le BIOS charge les tout premiers 512 octets — le
**secteur d'amorçage (MBR)** — à l'adresse physique `0x7C00` et y saute.

À ce stade, le processeur est encore en **mode réel 16 bits** : l'espace
d'adressage est limité à 1 Mio, il n'y a pas de protection mémoire, pas de
gestion des processus. Un noyau moderne ne peut pas vivre ici.

### 1.2 Pourquoi on n'écrit pas notre propre bootloader

Transformer le mode réel en mode protégé 32 bits (ou 64 bits), charger un
fichier ELF depuis un système de fichiers, gérer des périphériques de stockage
variés (SATA, NVMe, USB…) — tout cela représente des milliers de lignes d'ASM
très spécialisé. Des projets entiers (GRUB, Syslinux, limine…) existent pour
faire exactement ce travail.

Le sujet kfs1 l'exige d'ailleurs explicitement :

> *"Write an ASM boot code that handles the multiboot header, and use GRUB to
> init and call the kernel's main function."*
> — `.specs/mandatory.md`

GRUB fait le travail sale ; nous n'avons qu'à lui tendre un noyau conforme.

### 1.3 La chaîne complète

```
Mise sous tension
    │
    ▼
BIOS / UEFI legacy
    │  charge les 512 premiers octets du disque
    ▼
MBR (secteur d'amorçage)  ← installé par grub-install / grub-mkrescue
    │  détecte la partition, charge GRUB stage 1.5 puis stage 2
    ▼
GRUB (stage 2)
    │  lit grub.cfg, présente le menu
    │  trouve "multiboot /boot/kfs1.bin"
    │  → scanne les 8 premiers Kio du fichier, cherche la signature Multiboot
    │  → charge les segments ELF en mémoire physique
    │  → passe en mode protégé 32 bits
    │  → place EAX = 0x2BADB002, EBX = &multiboot_info
    ▼
_start  (notre boot.s, adresse physique 0x100000)
    │  configure la pile, zéro .bss, appelle kmain(magic, info)
    ▼
kmain  (Rust)
```

---

## 2. Le standard Multiboot : un contrat entre bootloader et noyau

### 2.1 Le problème historique

Avant Multiboot, chaque noyau libre imposait ses propres conventions de
démarrage. GRUB devait connaître Linux, FreeBSD, NetBSD… séparément. Et chaque
OS devait gérer sa propre transition mode-réel → mode-protégé.

### 2.2 La solution : un en-tête contractuel

La spécification **Multiboot v1** (Free Software Foundation, 1995) définit :

1. Un **en-tête magique** que le noyau place dans ses premiers 8 Kio.
2. Les **registres garantis** au moment où le bootloader saute au point d'entrée.

Le bootloader détecte n'importe quel noyau conforme simplement en cherchant la
signature `0x1BADB002` dans les premiers 8 Kio du fichier. En échange, le noyau
peut supposer qu'il est en mode protégé 32 bits et que les registres EAX/EBX
contiennent des informations fiables.

---

## 3. L'en-tête Multiboot v1 dans `boot.s`

### 3.1 Les constantes (lignes 14–18)

```nasm
MBALIGN  equ 1 << 0          ; bit 0 : aligner les modules sur des pages (4 Kio)
MEMINFO  equ 1 << 1          ; bit 1 : fournir la carte mémoire via multiboot_info
MBFLAGS  equ MBALIGN | MEMINFO
MAGIC    equ 0x1BADB002      ; signature que GRUB recherche
CHECKSUM equ -(MAGIC + MBFLAGS) ; magic + flags + checksum == 0 (mod 2^32)
```

#### `MAGIC = 0x1BADB002`

C'est la signature Multiboot v1. GRUB scanne le fichier 32 bits par 32 bits ; dès
qu'il trouve cette valeur alignée sur 4 octets dans les 8 premiers Kio, il sait
qu'il s'agit d'un noyau Multiboot.

Le nombre `0x1BADB002` se lit « 1 bad boot 2 » — un clin d'œil humoristique des
auteurs de la spec.

#### `MBFLAGS` : les fanions

Chaque bit activé est une demande au bootloader :

| Bit | Nom      | Effet                                                              |
|-----|----------|--------------------------------------------------------------------|
| 0   | MBALIGN  | Aligner les modules chargés sur des frontières de page (4 096 o)  |
| 1   | MEMINFO  | Remplir la structure `multiboot_info` avec la carte mémoire RAM    |

Nous activons les deux (`MBFLAGS = 0x3`), ce qui donne à notre noyau une carte
complète de la mémoire disponible dès son démarrage.

#### `CHECKSUM` : la somme de contrôle

La spec exige que :

```
MAGIC + MBFLAGS + CHECKSUM ≡ 0  (mod 2^32)
```

D'où `CHECKSUM = -(MAGIC + MBFLAGS)`. En arithmétique 32 bits non signée,
additionner un nombre à son opposé donne bien 0. Cela permet à GRUB de
**valider** l'en-tête sans ambiguïté : si la somme n'est pas nulle, l'en-tête
est corrompu ou absent.

Vérification manuelle :

```
  0x1BADB002   (MAGIC)
+ 0x00000003   (MBFLAGS)
+ 0xE4524FFB   (CHECKSUM = -(0x1BADB005) en 32 bits)
= 0x100000000  → tronqué à 0x00000000 ✓
```

### 3.2 La section `.multiboot_header` (lignes 23–27)

```nasm
section .multiboot_header
align 4
    dd MAGIC
    dd MBFLAGS
    dd CHECKSUM
```

Trois `dd` (double-word = 32 bits chacun) — 12 octets en tout, alignés sur 4
octets (`align 4`).

**Pourquoi `align 4` ?** La spec Multiboot v1 impose que la signature soit alignée
sur une frontière de 32 bits. GRUB cherche les mots de 32 bits : si l'en-tête
commence à une adresse impaire, il ne le trouvera jamais.

**Pourquoi dans les 8 premiers Kio ?** GRUB ne scanne que les 8 192 premiers
octets du fichier image pour des raisons de performance. Si l'en-tête se
retrouvait plus loin (par exemple après un gros segment de données), GRUB
ignorerait le noyau.

Le script linker (étape 06) s'assure que `.multiboot_header` est placé en
**tout premier** dans le binaire final, à l'adresse physique `0x100000` (1 Mio).
→ Voir [étape 06 — le linker script](../06-linker-script/README.md).

---

## 4. Le mode protégé 32 bits

### 4.1 Mode réel vs mode protégé

| Caractéristique      | Mode réel (16 bits)         | Mode protégé (32 bits)            |
|----------------------|-----------------------------|-----------------------------------|
| Espace d'adressage   | 1 Mio (20 bits)             | 4 Gio (32 bits)                   |
| Protection mémoire   | Aucune                      | Segments + pagination possible    |
| Registres            | 16 bits (AX, BX…)           | 32 bits (EAX, EBX…)               |
| Appels système OS    | Interruptions BIOS          | Mécanisme propre au noyau         |

Le mode protégé est activé en positionnant le bit PE du registre `CR0`.
GRUB effectue cette transition **avant** de sauter à `_start` — nous recevons
notre noyau déjà en mode protégé 32 bits, sans avoir eu à écrire une seule ligne
de code de transition.

### 4.2 Ce que GRUB garantit à l'entrée de `_start`

Selon la spec Multiboot v1, au moment où GRUB saute au point d'entrée du noyau :

| Registre | Valeur                    | Signification                                         |
|----------|---------------------------|-------------------------------------------------------|
| `EAX`    | `0x2BADB002`              | Preuve qu'un bootloader Multiboot conforme a tourné   |
| `EBX`    | adresse physique          | Pointeur vers la structure `multiboot_info`           |
| `CS`     | segment code 32 bits      | Exécution en mode protégé                             |
| `EFLAGS` | bit IF = 0                | Interruptions désactivées                             |
| Pile     | **non définie**           | Nous devons configurer `ESP` nous-mêmes               |

Le `0x2BADB002` dans EAX se lit « 2 bad boot 2 » — symétrique du `0x1BADB002`
du noyau. C'est une **poignée de main** : le bootloader dit « j'ai bien trouvé
ton en-tête Multiboot et je l'ai respecté ».

Notre `_start` (ligne 57 de `boot.s`) préserve immédiatement EAX dans EDX pour
que la valeur survive à la boucle de zéro-initialisation de `.bss` qui suit,
avant de la passer à `kmain`.

→ La suite de `_start` (pile, zéro de `.bss`, appel à `kmain`) est détaillée
dans [l'étape 05 — point d'entrée ASM](../05-boot-asm/README.md).

---

## 5. `grub.cfg` : le menu de démarrage

```
# grub/grub.cfg
set timeout=0
set default=0

menuentry "KFS_1" {
    multiboot /boot/kfs1.bin
    boot
}
```

Ligne par ligne :

- `set timeout=0` — GRUB ne montre pas de compte à rebours, il démarre
  immédiatement.
- `set default=0` — sélectionne la première (et seule) entrée par défaut.
- `menuentry "KFS_1" { … }` — définit une entrée de menu intitulée « KFS_1 ».
- `multiboot /boot/kfs1.bin` — charge `kfs1.bin` en utilisant le protocole
  Multiboot v1 (GRUB vérifie l'en-tête, charge les segments ELF, prépare
  `multiboot_info`).
- `boot` — transfère le contrôle au noyau chargé.

Le chemin `/boot/kfs1.bin` est **absolu à l'intérieur de l'ISO**. Le script
`mkiso.sh` copie le binaire compilé à cet endroit précis :

```bash
cp build/kfs1.bin "$ISODIR/boot/kfs1.bin"
```

---

## 6. Fabrication de l'ISO avec `mkiso.sh`

```bash
# scripts/mkiso.sh (simplifié)
ISODIR=build/isodir
mkdir -p "$ISODIR/boot/grub"
cp build/kfs1.bin  "$ISODIR/boot/kfs1.bin"
cp grub/grub.cfg   "$ISODIR/boot/grub/grub.cfg"

grub-mkrescue -o build/kfs1.iso "$ISODIR"
```

`grub-mkrescue` produit une image ISO 9660 amorçable qui contient :

- Un GRUB complet (stage 2, modules filesystem, etc.) dans la zone de boot.
- Le répertoire `boot/grub/grub.cfg` que GRUB lira au démarrage.
- Notre noyau `boot/kfs1.bin`.

La contrainte du sujet impose que l'ISO ne dépasse pas **10 Mio** — le script
vérifie cela (`if [ "$size" -le 10485760 ]`).

### Vérifier la conformité Multiboot

Avant de construire l'ISO, on peut valider que le binaire est bien reconnu comme
Multiboot :

```bash
grub-file --is-x86-multiboot build/kfs1.bin && echo "OK" || echo "INVALIDE"
```

Cette commande renvoie 0 (succès) si et seulement si GRUB trouve un en-tête
Multiboot v1 valide dans les 8 premiers Kio du fichier. C'est le même test que
fait GRUB au démarrage, sans avoir à booter une VM.

→ Cette vérification est intégrée dans la chaîne de build — voir
[étape 08 — tests & CI](../08-compilation-link/README.md).

---

## En résumé

| Élément            | Rôle                                                                  |
|--------------------|-----------------------------------------------------------------------|
| GRUB               | Bootloader : passe du BIOS au mode protégé 32 bits, charge le noyau  |
| `MAGIC 0x1BADB002` | Signature que GRUB cherche dans les 8 premiers Kio du noyau           |
| `MBFLAGS`          | Demandes au bootloader : alignement modules (bit 0) + carte RAM (bit 1) |
| `CHECKSUM`         | Garantit l'intégrité : `MAGIC + MBFLAGS + CHECKSUM == 0 mod 2^32`    |
| `EAX = 0x2BADB002` | Réponse du bootloader : « j'ai bien suivi le protocole Multiboot »   |
| `EBX`              | Pointeur vers `multiboot_info` (carte mémoire, modules…)             |
| `grub.cfg`         | Indique à GRUB quel fichier charger et avec quel protocole            |
| `mkiso.sh`         | Assemble l'ISO amorçable avec `grub-mkrescue`                        |

Le flux est simple : nous mettons 12 octets magiques au début de notre noyau ;
GRUB les lit, charge le fichier, et nous remet les clés en mode protégé 32 bits
avec une carte de la mémoire dans EBX.

---

## Pour aller plus loin

- [OSDev Wiki — Multiboot](https://wiki.osdev.org/Multiboot) : référence
  complète de la spec v1, structure `multiboot_info` champ par champ.
- [OSDev Wiki — Bare Bones](https://wiki.osdev.org/Bare_Bones) : tutoriel
  pas-à-pas qui construit un noyau minimal avec GRUB + Multiboot (en C, mais
  la logique ASM est identique).
- [GNU GRUB — Manual](https://www.gnu.org/software/grub/manual/grub/) : commandes
  `multiboot`, `boot`, et la syntaxe complète de `grub.cfg`.
- [Multiboot Specification v0.6.96](https://www.gnu.org/software/grub/manual/multiboot/multiboot.html) :
  texte officiel de la spec (FSF).
- **Étape suivante** → [05 — Point d'entrée ASM (`_start`, pile, zéro `.bss`)](../05-boot-asm/README.md)
- **Étape suivante** → [06 — Le linker script (placement des sections)](../06-linker-script/README.md)
