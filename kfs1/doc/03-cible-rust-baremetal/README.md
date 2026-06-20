# Étape 03 — La cible Rust bare-metal & `no_std`

## Objectif de l'étape

Comprendre comment on fait tourner du Rust sans système d'exploitation :
qu'est-ce que `#![no_std]`, pourquoi il faut une **cible personnalisée**
(`i386-kfs.json`), pourquoi on doit recompiler `core` (`build-std`), et le sens
de chaque option (soft-float, `panic=abort`, staticlib).

## Fichiers concernés

- [`../../i386-kfs.json`](../../i386-kfs.json) — la spécification de cible bare-metal i386
- [`../../.cargo/config.toml`](../../.cargo/config.toml) — `build-std`, la cible par défaut, `json-target-spec`
- [`../../rust-toolchain.toml`](../../rust-toolchain.toml) — épinglage de nightly + composants
- [`../../Cargo.toml`](../../Cargo.toml) — crate `staticlib`, profils `panic = "abort"`

---

## 1. `#![no_std]` : programmer sans système d'exploitation

Quand on écrit un programme Rust normal, le compilateur lie automatiquement la
bibliothèque standard **`std`**. Cette bibliothèque suppose qu'un OS est présent :
elle s'appuie sur lui pour allouer de la mémoire (`malloc`/`free`), ouvrir des
fichiers, créer des threads, gérer les paniques avec déroulement de pile, etc.

Un noyau *est* le système d'exploitation — il n'y a rien en-dessous sur quoi
s'appuyer. On doit donc dire à Rust d'abandonner `std` :

```rust
#![no_std]
```

### Ce qu'on perd

| Fonctionnalité perdue | Raison |
|---|---|
| `std::collections`, `String`, `Vec` | nécessitent un allocateur (heap) |
| `std::io`, fichiers, réseau | nécessitent des appels système OS |
| `std::thread` | nécessite le scheduler de l'OS |
| `println!`, `format!` | s'appuient sur `std::io` |
| `std::panic` avec unwinding | nécessite la libunwind ou équivalent |

### Ce qu'on garde : `core`

La crate `core` est le sous-ensemble de la bibliothèque standard qui ne dépend
d'aucun OS. Elle contient :

- les types primitifs (`u8`, `i32`, `bool`, les tableaux…)
- les traits fondamentaux (`Copy`, `Clone`, `Iterator`, `Option`, `Result`…)
- l'arithmétique, les opérations bit à bit, `mem::size_of`, etc.
- les macros `assert!`, `unreachable!`, `panic!` (version minimale)

`core` ne fait aucune hypothèse sur l'environnement d'exécution : c'est tout ce
dont un noyau a besoin au départ.

---

## 2. Le *target triple* : pourquoi aucune cible standard ne convient

Rust identifie chaque environnement cible par un **target triple** de la forme
`<arch>-<vendor>-<os>[-<abi>]`. Exemples courants :

- `x86_64-unknown-linux-gnu` — PC Linux 64 bits
- `aarch64-apple-darwin` — Mac Apple Silicon
- `thumbv7em-none-eabihf` — microcontrôleur ARM Cortex-M (bare-metal)

Pour écrire un noyau i386, on voudrait quelque chose comme
`i686-unknown-none` — une cible 32 bits sans OS. Le problème : **Rust ne fournit
pas cette cible en tier stable**. Les cibles `*-none` 32 bits ne font pas partie
de la distribution officielle de rustc ; elles n'ont pas de binaires précompilés
de `core`.

La solution est de **définir notre propre cible** dans un fichier JSON que rustc
peut consommer. C'est ce que fait [`../../i386-kfs.json`](../../i386-kfs.json).

---

## 3. Décortiquer `i386-kfs.json`

```json
{
  "llvm-target": "i686-unknown-none-gnu",
  "data-layout": "e-m:e-p:32:32-p270:32:32-p271:32:32-p272:64:64-i128:128-f64:32:64-f80:32-n8:16:32-S128",
  "arch": "x86",
  "target-endian": "little",
  "target-pointer-width": 32,
  "os": "none",
  "vendor": "unknown",
  "executables": true,
  "linker-flavor": "ld.lld",
  "linker": "rust-lld",
  "panic-strategy": "abort",
  "disable-redzone": true,
  "features": "-mmx,-sse,-sse2,+soft-float",
  "rustc-abi": "x86-softfloat",
  "max-atomic-width": 64
}
```

### `llvm-target` : la chaîne que LLVM comprend

```json
"llvm-target": "i686-unknown-none-gnu"
```

LLVM (le backend de rustc) a sa propre nomenclature de cibles. On lui dit
`i686` (processeur x86 compatible Pentium Pro, 32 bits), vendeur `unknown`, OS
`none` (bare-metal), ABI `gnu`. C'est différent du nom de notre fichier
(`i386-kfs`) : le nom du fichier est juste un identifiant interne pour Cargo.

### `data-layout` : la géométrie de la mémoire

```json
"data-layout": "e-m:e-p:32:32-p270:32:32-..."
```

Cette chaîne (format LLVM DataLayout) décrit l'agencement des données en
mémoire : endianness (`e` = little-endian), taille des pointeurs (`p:32:32` =
pointeur 32 bits, aligné sur 32 bits), taille des entiers, alignement des
flottants, etc. Elle doit correspondre exactement au CPU cible pour que le
compilateur génère du code correct.

### `arch` et `target-pointer-width`

```json
"arch": "x86",
"target-pointer-width": 32,
```

`arch` informe rustc de l'architecture (utilisé par les `#[cfg(target_arch)]`).
`target-pointer-width: 32` indique qu'un `usize`/`isize` fait 32 bits — crucial
pour les calculs d'adresses mémoire dans le noyau.

### `os: "none"` — pas de système d'exploitation

```json
"os": "none",
```

Aucun OS hôte. Rust ne générera aucun appel système, aucun runtime OS. Ce champ
est aussi visible via `#[cfg(target_os = "none")]` dans le code source.

### `panic-strategy: "abort"` — pas de déroulement de pile

```json
"panic-strategy": "abort",
```

Quand une panique se produit, deux stratégies sont possibles :

- **unwind** (déroulement) : remonte la pile d'appels, appelle les destructeurs
  (`Drop`), permet de la rattraper avec `std::panic::catch_unwind`. Nécessite
  la bibliothèque `libunwind` ou équivalent — indisponible en bare-metal.
- **abort** : arrête immédiatement le programme (ou ici, plante le noyau).
  Simple, sans dépendance externe.

On choisit `abort` ici. Cela est redondant avec le `Cargo.toml` (voir
section 5), mais le préciser dans la spec JSON garantit la cohérence quel que
soit le contexte de compilation.

### `linker` et `linker-flavor` — l'éditeur de liens

```json
"linker-flavor": "ld.lld",
"linker": "rust-lld",
```

`rust-lld` est le linker LLD (LLVM Linker) fourni avec la toolchain Rust.
`ld.lld` est la syntaxe de commande compatible `ld` (GNU linker). On n'utilise
pas le `cc` du système pour lier (ce serait le défaut sur Linux), car sur une
cible bare-metal il faut piloter le linker directement. L'étape 06 explique le
script de linker et l'étape 08 détaille la commande de link finale.

### `disable-redzone: true` — pas de zone rouge sur la pile

```json
"disable-redzone": true,
```

Sur x86-64 (et certaines ABI 32 bits), les compilateurs peuvent utiliser les
128 octets *sous* le pointeur de pile (la "red zone") sans décrémenter `esp`.
Dans un noyau, les interruptions peuvent survenir à tout moment et écraser
cette zone. On la désactive pour la sécurité.

### `features` et `rustc-abi` — soft-float et désactivation SSE/MMX

```json
"features": "-mmx,-sse,-sse2,+soft-float",
"rustc-abi": "x86-softfloat",
```

C'est l'une des décisions les plus importantes de la spec. Voici pourquoi.

#### Pourquoi désactiver SSE et MMX dans un noyau ?

SSE (Streaming SIMD Extensions) et MMX sont des extensions vectorielles du
processeur x86. Elles utilisent des registres dédiés : `xmm0`–`xmm7` (SSE),
`mm0`–`mm7` (MMX).

Le problème : **les interruptions**. Quand un processeur répond à une
interruption ou une exception, il sauvegarde l'état des registres généraux sur
la pile pour pouvoir reprendre l'exécution. Mais il **ne sauvegarde pas
automatiquement** les registres SSE/MMX — cela demanderait les instructions
`fxsave`/`fxrstor` (512 octets), coûteuses à chaque interruption.

Si le noyau utilisait SSE, il faudrait :
1. Activer les registres SSE au démarrage (bit `CR4.OSFXSR`).
2. Sauvegarder/restaurer manuellement les registres SSE à chaque entrée/sortie
   d'interruption.

C'est un travail considérable et une source de bugs critiques (corruption
silencieuse des registres SSE d'une tâche par une interruption). La solution
simple : **interdire SSE et MMX dans le noyau**.

#### Soft-float : émulation des flottants

```
"-mmx,-sse,-sse2,+soft-float"
```

Le préfixe `-` désactive une feature CPU, `+` l'active. On désactive donc MMX,
SSE et SSE2. Mais si on désactive SSE, comment faire des calculs en virgule
flottante ? Sur x86 32 bits, le FPU x87 classique reste disponible, mais Rust
l'évite aussi par défaut pour des raisons de cohérence ABI.

`+soft-float` indique à LLVM d'**émuler les flottants en logiciel** via des
fonctions auxiliaires (bibliothèque `compiler-rt`/`compiler_builtins`). En
pratique, un noyau n'a pas besoin de calculs flottants — mais si le compilateur
en génère (ex. pour des conversions implicites), ils seront traités proprement
sans toucher les registres vectoriels.

`"rustc-abi": "x86-softfloat"` enfonce le clou au niveau de l'ABI Rust :
les arguments et valeurs de retour de type flottant passent par des entiers ou
la pile, jamais par des registres SSE.

### `max-atomic-width: 64`

```json
"max-atomic-width": 64
```

Indique que la cible supporte les opérations atomiques jusqu'à 64 bits (via
`cmpxchg8b` sur i686+). Nécessaire pour que `core::sync::atomic::AtomicU64`
soit disponible.

---

## 4. `build-std` : recompiler `core` pour notre cible

Ouvrir [`../../.cargo/config.toml`](../../.cargo/config.toml) :

```toml
[build]
target = "i386-kfs.json"

[unstable]
build-std = ["core", "compiler_builtins"]
build-std-features = ["compiler-builtins-mem"]
json-target-spec = true
```

### Pourquoi recompiler `core` ?

Les cibles officielles Rust sont livrées avec des binaires précompilés de
`core` (via `rustup component add rust-std`). Notre cible personnalisée n'en a
pas : il n'existe pas de `core` précompilé pour `i386-kfs.json`. Il faut donc
**recompiler `core` depuis les sources** à chaque `cargo build`.

C'est le rôle de `build-std = ["core", "compiler_builtins"]` : Cargo va
télécharger les sources de la bibliothèque standard (composant `rust-src`) et
les recompiler avec les mêmes options que notre crate (notamment `soft-float`).

### `compiler_builtins` : les fonctions de bas niveau

`compiler_builtins` est une crate qui fournit les fonctions d'aide que le
compilateur peut générer implicitement : opérations 64 bits sur CPU 32 bits,
comparaisons, conversions flottantes, etc. Sans elle, le link échouerait avec
des symboles manquants.

### `compiler-builtins-mem` : `memcpy`, `memset`, `memmove`, `memcmp`

```toml
build-std-features = ["compiler-builtins-mem"]
```

Le compilateur peut générer des appels à `memcpy`, `memset`, `memmove` et
`memcmp` (ex. pour copier des structures). Ces fonctions doivent exister au
link. L'option `compiler-builtins-mem` active leur implémentation dans
`compiler_builtins`.

> **Important** : ne jamais réécrire ces fonctions dans le code du noyau.
> Si elles sont définies deux fois (une fois par `compiler_builtins`, une fois
> dans votre code), le linker refusera de lier avec une erreur de symbole
> dupliqué. L'étape 10 reviendra sur ce point dans le contexte de `libk`.

### `json-target-spec = true`

```toml
json-target-spec = true
```

Les versions récentes de nightly exigent cette option dans `[unstable]` pour
accepter des fichiers `.json` comme spec de cible. C'est une mesure de sécurité
(les specs JSON peuvent faire des choses puissantes) qui doit être explicitement
accordée.

---

## 5. `Cargo.toml` : `staticlib` et `panic = "abort"`

```toml
[lib]
crate-type = ["staticlib"]
path = "src/lib.rs"

[profile.dev]
panic = "abort"

[profile.release]
panic = "abort"
opt-level = 2
lto = true
```

### `crate-type = ["staticlib"]`

On compile notre crate Rust en **bibliothèque statique** (`.a`). Ce n'est pas
un exécutable autonome : le point d'entrée (`_start`) est fourni par
`src/boot.s` (assembleur NASM), et le linker assemblera les deux. L'étape 08
détaille comment `libkfs1.a` est intégrée à la commande `ld`.

### `panic = "abort"` dans les profils

```toml
[profile.dev]
panic = "abort"

[profile.release]
panic = "abort"
```

En cohérence avec `panic-strategy: "abort"` dans la spec JSON, on le précise
aussi dans `Cargo.toml` pour chaque profil. Cela garantit que même si une
dépendance essaie d'utiliser le déroulement de pile, le comportement global
reste `abort`. Pas de `libunwind`, pas de tables d'exception DWARF.

### `lto = true` en release

`lto` (Link-Time Optimization) permet à LLVM d'optimiser à travers les
frontières de crates. Sur un noyau, c'est particulièrement utile : le code
sera plus compact et les appels inlinés agressivement.

---

## 6. `rust-toolchain.toml` : nightly + `rust-src`

```toml
[toolchain]
channel = "nightly"
components = ["rust-src", "llvm-tools-preview"]
```

### Pourquoi nightly ?

Plusieurs fonctionnalités utilisées ici sont **instables** (préfixées par `Z`
dans les options Cargo) :

- `build-std` est une feature instable de Cargo (`[unstable]`).
- `json-target-spec` est une feature instable.
- Certaines annotations de la spec de cible (`rustc-abi`, etc.) sont
  spécifiques à nightly.

Le canal stable ne permet pas ces features. On est obligés d'utiliser nightly.

### `rust-src` : les sources de la bibliothèque standard

Pour que `build-std` fonctionne, il faut les sources de `core` et
`compiler_builtins`. Le composant `rust-src` les installe sous
`$(rustup toolchain dir)/lib/rustlib/src/`. Sans lui, la compilation
échouerait avec une erreur indiquant que les sources sont introuvables.

### `llvm-tools-preview`

Fournit des outils LLVM (`llvm-objdump`, `llvm-nm`, `rust-lld`, etc.) au sein
de la toolchain Rust. `rust-lld` (référencé dans `i386-kfs.json`) en fait
partie.

---

## 7. Comment tout s'articule

Voici le chemin complet, de la commande à l'objet compilé :

```
cargo build --release
    │
    ├── lit rust-toolchain.toml → utilise nightly + rust-src
    ├── lit .cargo/config.toml  → cible i386-kfs.json, build-std activé
    ├── lit i386-kfs.json       → configure LLVM (arch, ABI, features…)
    │
    ├── recompile core + compiler_builtins pour i386-kfs
    │        (avec soft-float, os=none, panic=abort…)
    │
    ├── compile src/lib.rs (#![no_std])
    │
    └── produit target/i386-kfs/release/libkfs1.a
```

L'étape 06 montre comment le script linker (`linker.ld`) décrit la disposition
mémoire. L'étape 08 montre comment `ld` assemble `boot.o` et `libkfs1.a` en un
binaire ELF final.

---

## En résumé

| Décision | Fichier | Raison |
|---|---|---|
| `#![no_std]` | `src/lib.rs` | Pas d'OS hôte — on supprime la dépendance à `std` |
| Cible JSON personnalisée | `i386-kfs.json` | Pas de cible `i686-none` stable dans rustc |
| `os: "none"` | `i386-kfs.json` | Bare-metal, aucun appel système |
| `-mmx,-sse,-sse2,+soft-float` | `i386-kfs.json` | Pas de registres SSE à sauvegarder dans les interruptions |
| `panic-strategy: "abort"` | `i386-kfs.json` + `Cargo.toml` | Pas de `libunwind` en bare-metal |
| `build-std = ["core","compiler_builtins"]` | `.cargo/config.toml` | Recompiler `core` pour notre cible non-standard |
| `compiler-builtins-mem` | `.cargo/config.toml` | Fournit `memcpy`/`memset`/`memmove`/`memcmp` |
| `json-target-spec = true` | `.cargo/config.toml` | Activer explicitement les specs JSON (feature nightly) |
| `crate-type = ["staticlib"]` | `Cargo.toml` | Le point d'entrée est en ASM, on livre une `.a` |
| `channel = "nightly"` | `rust-toolchain.toml` | `build-std` et `json-target-spec` sont des features instables |
| `rust-src` | `rust-toolchain.toml` | Sources de `core` nécessaires pour `build-std` |

---

## Pour aller plus loin

- **Étape 06** — Le script linker (`linker.ld`) : comment la mémoire du noyau
  est organisée (sections `.text`, `.rodata`, `.data`, `.bss`, point de
  chargement à 1 MiB).
- **Étape 08** — La commande de link finale : comment `boot.o` et `libkfs1.a`
  sont assemblés en un binaire ELF i386.
- **Étape 10** — `libk` et les fonctions mémoire : pourquoi on ne réécrit pas
  `memcpy`/`memset` et ce que `compiler-builtins-mem` fournit exactement.
- [The Embedonomicon (Rust)](https://docs.rust-embedded.org/embedonomicon/) —
  référence sur le développement bare-metal en Rust.
- [OSDev Wiki — Setting Up Long Mode](https://wiki.osdev.org/Setting_Up_Long_Mode)
  et plus généralement [OSDev Wiki](https://wiki.osdev.org/) — encyclopédie de
  référence pour l'OS-dev.
- [LLVM Language Reference — Data Layout](https://llvm.org/docs/LangRef.html#data-layout)
  — documentation complète sur la chaîne `data-layout`.
- [Rustc Dev Guide — Custom Targets](https://rustc-dev-guide.rust-lang.org/building/build-install-distribution-artifacts.html)
  — comment rustc consomme les specs de cible JSON.
