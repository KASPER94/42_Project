# Documentation pas à pas — KFS_1

Cette documentation explique le kernel **KFS_1** (un noyau i386 écrit en Rust,
démarré par GRUB, qui affiche `42` à l'écran) **étape par étape, depuis zéro**.
Aucune connaissance préalable en développement de noyau n'est supposée : on
explique au fur et à mesure ce qu'est le mode protégé, Multiboot, le mode texte
VGA, l'édition de liens, etc.

> Le sujet officiel et son découpage sémantique se trouvent dans
> [`../.specs/`](../.specs/README.md). Le « contrat » technique interne (ABI
> d'entrée, disposition mémoire, surface des modules) est dans
> [`../CONTRACTS.md`](../CONTRACTS.md). Le README projet est
> [`../README.md`](../README.md).

## Comment lire cette doc

Les étapes suivent **l'ordre réel des événements** : d'abord comment la machine
démarre et comment on fabrique le kernel, puis le code qui s'exécute, puis
l'écran, puis les bonus. Lis-les dans l'ordre : chaque étape s'appuie sur la
précédente. Chaque page contient :

- **Objectif de l'étape** — ce que tu vas comprendre.
- **Fichiers concernés** — liens directs vers le code expliqué.
- L'explication détaillée, avec des renvois précis (`fichier`, symbole, ligne).

## Le flux global, en un schéma

```
        Mise sous tension
              │
              ▼
          ┌────────┐
          │  BIOS  │  teste le matériel, cherche un média amorçable
          └────────┘
              │
              ▼
          ┌────────┐
          │  GRUB  │  lit l'ISO, trouve notre kernel, lit l'en-tête Multiboot,
          └────────┘  passe le CPU en mode protégé 32 bits
              │   EAX = 0x2BADB002 (preuve), EBX = infos Multiboot
              ▼
     ┌──────────────────┐
     │ _start  (boot.s) │  installe la pile, met .bss à zéro, push EAX/EBX
     └──────────────────┘
              │  call kmain  (convention cdecl)
              ▼
     ┌──────────────────┐
     │ kmain   (lib.rs) │  point d'entrée Rust, #![no_std]
     └──────────────────┘
         │            │
         │            └────────────► boucle principale :
         ▼                           keyboard::poll → screens::handle_key
   ┌───────────────┐                       (bonus)
   │ vga (0xB8000) │  écrit dans le framebuffer texte → "42" à l'écran
   └───────────────┘
```

## Les étapes

### Partie obligatoire

1. [Étape 01 — Vue d'ensemble & cycle de vie du boot](01-vue-densemble/README.md)
   Ce qu'est un noyau « freestanding », l'arborescence du projet, et le voyage
   complet de la mise sous tension jusqu'à l'affichage de `42`.
2. [Étape 02 — L'environnement de build (Docker amd64)](02-environnement-build/README.md)
   Pourquoi tout se compile dans un conteneur Linux amd64, et comment le
   `Makefile` pilote la chaîne d'outils (nasm, GRUB, QEMU, Rust nightly).
3. [Étape 03 — La cible Rust bare-metal & `no_std`](03-cible-rust-baremetal/README.md)
   Programmer sans système d'exploitation : `no_std`, la cible personnalisée
   `i386-kfs.json`, `build-std`, soft-float, `panic=abort`.
4. [Étape 04 — GRUB & le standard Multiboot](04-grub-multiboot/README.md)
   Comment un bootloader charge un noyau, l'en-tête Multiboot v1 (magic, flags,
   checksum) et la configuration GRUB.
5. [Étape 05 — Le code de boot en assembleur](05-boot-asm/README.md)
   `boot.s` : la pile, la mise à zéro de `.bss`, le passage des arguments en
   cdecl et l'appel de `kmain`.
6. [Étape 06 — Le script d'édition de liens](06-linker-script/README.md)
   `linker.ld` : pourquoi on charge à 1 Mio, l'ordre des sections et les
   symboles exportés.
7. [Étape 07 — Le cœur Rust : `kmain` & panic](07-coeur-rust/README.md)
   `lib.rs` : le point d'entrée Rust, le gestionnaire de panique obligatoire et
   les accès aux ports d'E/S.
8. [Étape 08 — Compilation & édition de liens](08-compilation-link/README.md)
   La chaîne complète : `nasm` → `cargo` → `ld`, la fabrication de l'ISO et la
   contrainte des 10 Mo.
9. [Étape 09 — Le driver écran VGA](09-ecran-vga/README.md)
   `vga.rs` : le framebuffer texte à `0xB8000`, les cellules, les couleurs, le
   défilement, le curseur matériel — et enfin afficher `42`.
10. [Étape 10 — La bibliothèque kernel `libk`](10-bibliotheque-libk/README.md)
    `libk/` : nos propres types et fonctions de chaînes (`strlen`, `strcmp`),
    puisqu'il n'y a pas de libc.

### Partie bonus

11. [Étape 11 — Console & macros `print!`](11-bonus-console-printf/README.md)
    `console.rs` : brancher `core::fmt::Write` pour offrir `print!` / `println!`.
12. [Étape 12 — Clavier PS/2 & écrans virtuels](12-bonus-clavier-ecrans/README.md)
    `keyboard.rs` et `screens.rs` : lire le clavier en *polling* et basculer
    entre plusieurs écrans avec F1–F4.
