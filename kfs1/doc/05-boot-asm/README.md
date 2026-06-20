# Étape 05 — Le code de boot en assembleur

## Objectif de l'étape

Lire et comprendre ligne par ligne `boot.s`, le tout premier code **à nous** qui
s'exécute. Il prépare le terrain pour le Rust : il installe une pile, met la
section `.bss` à zéro, puis appelle `kmain` en lui passant les bons arguments.

## Fichiers concernés

- [`../../src/boot.s`](../../src/boot.s) — le stub de boot NASM (fichier entier)
- [`../../linker.ld`](../../linker.ld) — fournit les symboles `_bss_start` / `_bss_end` (détaillé à l'[étape 06](../06-linker-script/README.md))
- [`../../src/lib.rs`](../../src/lib.rs) — la cible de l'appel : `kmain` (détaillé à l'[étape 07](../07-coeur-rust/README.md))

---

## 1. Pourquoi un fichier assembleur ?

Rust est un langage de haut niveau : même sans bibliothèque standard (`#![no_std]`),
le compilateur émet du code qui **suppose** qu'un environnement minimal est déjà
en place : une pile valide, une section `.bss` à zéro, etc.

Or, quand GRUB nous passe la main, **rien de tout cela n'est garanti**. Il faut
donc quelques dizaines d'instructions assembleur pour construire ce socle avant
de sauter dans le monde Rust.

C'est le rôle unique de `boot.s`.

---

## 2. NASM et `[bits 32]`

```nasm
[bits 32]
```
*(ligne 11)*

GRUB entre dans le noyau en **mode protégé 32 bits**. La directive `[bits 32]`
indique à NASM (le compilateur assembleur que nous utilisons) qu'il doit émettre
des instructions 32 bits. Sans elle, NASM supposerait par défaut du code 16 bits,
ce qui produirait un binaire incompatible.

> **NASM vs GAS** : NASM (Netwide Assembler) utilise une syntaxe Intel
> (`mov dst, src`). C'est le choix classique pour les projets bare-metal x86.
> L'autre assembleur courant, GAS (GNU Assembler), utilise la syntaxe AT&T
> (`mov src, dst`) — c'est l'inverse. Ici on reste en NASM.

---

## 3. La section `.multiboot_header`

```nasm
section .multiboot_header
align 4
    dd MAGIC
    dd MBFLAGS
    dd CHECKSUM
```
*(lignes 23–27)*

Ce bloc est déjà expliqué en détail dans l'**[étape 04](../04-grub-multiboot/README.md)**.
En résumé : GRUB cherche ces trois dwords dans les 8 premiers Kio du fichier kernel
pour confirmer qu'il s'agit d'un noyau Multiboot v1 valide.

---

## 4. La pile — section `.bss`

### 4.1 Pourquoi une pile est indispensable

Une pile (*stack*) est une zone mémoire utilisée pour :
- stocker les **adresses de retour** lors d'un `call` (instruction d'appel de fonction),
- passer les **arguments** aux fonctions (convention cdecl, voir §7),
- sauvegarder temporairement des **registres**.

Sans pile initialisée, la première instruction `call kmain` provoque un comportement
indéfini — voire un triple fault (l'équivalent d'un crash matériel).

### 4.2 Déclaration de la pile en `.bss`

```nasm
section .bss
align 16
stack_bottom:
    resb 16384          ; 16 KiB
stack_top:
```
*(lignes 32–36)*

- **`.bss`** : section des données non initialisées. Elle ne prend pas de place dans
  le fichier ELF — le fichier contient juste la taille, et le chargeur réserve la
  mémoire. C'est économique pour une grande pile.
- **`align 16`** : force l'alignement à 16 octets. C'est requis par l'ABI System V
  (et recommandé pour les instructions SSE).
- **`resb 16384`** : réserve 16 384 octets = 16 Kio. `resb N` signifie « réserve
  N bytes » (sans valeur initiale — d'où le nom `.bss`).
- **`stack_bottom`** / **`stack_top`** : deux labels qui encadrent le bloc. Ce sont
  juste des noms symboliques pointant vers les adresses basse et haute du bloc.

### 4.3 La pile croît vers le bas

Sur x86, la pile **croît vers les adresses décroissantes** :
- On initialise `esp` (le registre pointeur de pile, *stack pointer*) à l'adresse
  **haute** : `stack_top`.
- Chaque `push` **décrémente** `esp` puis écrit la valeur.
- `stack_bottom` est donc la limite basse à ne pas dépasser (sinon : stack overflow).

```
Adresses mémoire croissantes →
┌─────────────┐  ← stack_bottom  (adresse basse)
│  16 Kio     │
│  réservés   │
│  en .bss    │
└─────────────┘  ← stack_top     (adresse haute) ← esp au démarrage
                                   ↓ les push descendent ici
```

---

## 5. Le point d'entrée `_start`

```nasm
section .text
global _start
extern kmain
extern _bss_start
extern _bss_end
```
*(lignes 39–45)*

- **`section .text`** : la section contenant le code exécutable.
- **`global _start`** : déclare `_start` comme symbole public, visible par le
  linker. C'est indispensable car `linker.ld` contient `ENTRY(_start)` (ligne 12
  de `linker.ld`) — cela indique au linker où l'exécution doit commencer.
  Voir l'**[étape 06](../06-linker-script/README.md)**.
- **`extern kmain`** : indique à NASM que `kmain` est défini dans un autre fichier
  objet (ici, le code Rust compilé). NASM génère une référence symbolique que le
  linker résoudra.
- **`extern _bss_start` / `extern _bss_end`** : pareil — ces symboles sont définis
  dans `linker.ld` (lignes 55 et 59) et exportés vers l'assembleur.

---

## 6. Bloc 1 — Installer la pile (ligne 52)

```nasm
_start:
    mov esp, stack_top
```
*(ligne 52)*

`mov esp, stack_top` charge l'adresse du label `stack_top` dans le registre `esp`.
À partir de ce moment, les instructions `push`/`pop`/`call`/`ret` fonctionnent
correctement.

> C'est **la première chose à faire** : même un simple `call` utilise la pile pour
> sauvegarder l'adresse de retour. Sans cette ligne, tout ce qui suit planterait.

---

## 7. Bloc 2 — Préserver les registres Multiboot (ligne 57)

GRUB a passé deux informations importantes dans des registres avant de sauter à
`_start` :

| Registre | Valeur | Signification |
|----------|--------|---------------|
| `eax`    | `0x2BADB002` | Magic Multiboot v1 — prouve qu'un chargeur conforme a démarré |
| `ebx`    | adresse physique | Pointeur vers la structure `multiboot_info` |

Le problème : la boucle de mise à zéro de `.bss` qui suit (§8) va écraser `eax`,
`ecx` et `edi`. Mais elle ne touche **pas** `ebx` ni `edx`.

La solution :

```nasm
    mov edx, eax            ; EDX = multiboot magic (0x2BADB002)
```
*(ligne 57)*

On copie `eax` dans `edx` avant la boucle. Après la boucle, `edx` contient encore
le magic, et `ebx` contient encore le pointeur info. On pourra les passer à `kmain`.

---

## 8. Bloc 3 — Mettre `.bss` à zéro (lignes 65–70)

### 8.1 Pourquoi `.bss` n'est pas garantie à zéro

La spécification Multiboot v1 **ne garantit pas** que la section `.bss` est mise à
zéro avant de sauter au noyau. En C et en Rust, les variables globales et statiques
non initialisées sont supposées valoir `0` au démarrage — c'est une garantie du
langage. Si on ne zèle pas `.bss` nous-mêmes, ces variables pourraient contenir
des valeurs résiduelles de la RAM, ce qui provoquerait des bugs imprévisibles et
très difficiles à diagnostiquer.

### 8.2 Le code de mise à zéro

```nasm
    mov edi, _bss_start     ; destination
    mov ecx, _bss_end
    sub ecx, edi            ; byte count
    shr ecx, 2              ; -> dword count
    xor eax, eax            ; fill value = 0
    rep stosd               ; zero .bss
```
*(lignes 65–70)*

Décortiquons chaque instruction :

**`mov edi, _bss_start`**
: Charge l'adresse de début de `.bss` dans `edi` (registre *destination index*).
  `stosd` écrit toujours à l'adresse pointée par `edi`, puis avance `edi` de 4.

**`mov ecx, _bss_end` puis `sub ecx, edi`**
: Calcule la taille en octets de `.bss` : `_bss_end - _bss_start`.
  `ecx` est le registre *compteur* (*counter*) utilisé par les instructions répétées.

**`shr ecx, 2`**
: Divise `ecx` par 4 (décalage à droite de 2 bits = division par 2² = 4).
  Pourquoi ? Parce que `stosd` écrit **4 octets** (un *dword*) à la fois.
  On convertit le nombre d'octets en nombre de dwords.
  `_bss_start` et `_bss_end` sont tous deux alignés à 4 octets (garanti par
  `linker.ld`, lignes 53–59), donc la division est exacte, sans reste.

**`xor eax, eax`**
: Met `eax` à zéro. `xor reg, reg` est l'idiome classique x86 pour zéroïser un
  registre (plus court qu'un `mov eax, 0`). C'est la valeur que `stosd` va écrire.

**`rep stosd`**
: Répète l'instruction `stosd` exactement `ecx` fois.
  À chaque itération : écrit le dword `eax` (= 0) à l'adresse `[edi]`, puis
  incrémente `edi` de 4 et décrémente `ecx` de 1.
  Résultat : toute la plage `[_bss_start, _bss_end)` est mise à zéro.

Schéma de la boucle :

```
edi →  [_bss_start]  ← on écrit 0x00000000
       [+4]          ← on écrit 0x00000000
       [+8]          ← on écrit 0x00000000
       ...
       [_bss_end-4]  ← on écrit 0x00000000
              ecx décrémente à chaque pas ; s'arrête quand ecx == 0
```

---

## 9. Bloc 4 — Appeler `kmain` en cdecl (lignes 80–82)

### 9.1 La convention cdecl

La convention d'appel **cdecl** (*C declaration*) est la convention standard sur
x86 Linux/Unix. Elle définit comment passer des arguments à une fonction :

> Les arguments sont empilés **de droite à gauche** (dernier argument en premier),
> et c'est l'**appelant** qui nettoie la pile après le retour.

La signature Rust de `kmain` est (ligne 100 de `lib.rs`) :

```rust
pub extern "C" fn kmain(_multiboot_magic: u32, _multiboot_info: u32) -> !
```

- 1er argument : `_multiboot_magic` (le magic `0x2BADB002`, dans `edx`)
- 2e argument  : `_multiboot_info` (le pointeur info, dans `ebx`)

En cdecl, on empile de droite à gauche, donc d'abord le 2e, puis le 1er :

```
Pile avant call kmain :
                          ┌──────────────┐
esp+8 → (après push ebx)  │  ebx (info)  │  ← 2e argument
esp+4 → (après push edx)  │  edx (magic) │  ← 1er argument
esp   → (après call)      │  addr retour │  ← poussée par call
                          └──────────────┘
```

### 9.2 Le code

```nasm
    push ebx                ; arg2: multiboot_info  pointer (u32)
    push edx                ; arg1: multiboot_magic (u32)   = 0x2BADB002
    call kmain              ; never returns (-> !)
```
*(lignes 80–82)*

- **`push ebx`** : empile le pointeur `multiboot_info` (2e argument, empilé en
  premier selon cdecl). La pile grandit vers le bas : `esp` est décrémenté de 4,
  puis `ebx` est écrit à la nouvelle adresse `[esp]`.
- **`push edx`** : empile le magic (1er argument). `esp` descend encore de 4.
- **`call kmain`** : saute à l'adresse du symbole `kmain` en empilant l'adresse de
  retour (ici l'adresse de l'instruction suivante, `.hang`). Côté Rust, `kmain`
  déclare `-> !` (jamais de retour), donc on ne reviendra jamais ici.

> `extern "C"` dans la signature Rust (ligne 100 de `lib.rs`) garantit que
> le compilateur Rust utilise bien la convention cdecl pour cette fonction,
> et non sa propre convention interne.

---

## 10. Bloc 5 — La boucle de sécurité `cli`/`hlt` (lignes 85–88)

```nasm
.hang:
    cli
    hlt
    jmp .hang
```
*(lignes 85–88)*

`kmain` est déclarée `-> !` en Rust, ce qui signifie qu'elle ne retourne **jamais**.
Mais en assembleur, si par quelque bug elle revenait quand même, le CPU exécuterait
le code qui suit `call kmain` — ces instructions sont là pour l'en empêcher.

- **`cli`** (*clear interrupt flag*) : désactive les interruptions matérielles.
  On ne veut pas qu'une interruption réveille un CPU qui n'a plus rien à faire.
- **`hlt`** (*halt*) : suspend le CPU jusqu'à la prochaine interruption. Comme les
  interruptions sont désactivées, le CPU reste suspendu indéfiniment.
- **`jmp .hang`** : si par un miracle quelque chose sortait de `hlt` (NMI, etc.),
  on reboucle immédiatement.

Le label `.hang` (avec un point) est un **label local** NASM : il n'est visible
qu'à l'intérieur de la fonction courante.

---

## 11. La section `.note.GNU-stack` (ligne 94)

```nasm
section .note.GNU-stack noalloc noexec nowrite progbits
```
*(ligne 94)*

Sans cette ligne, l'éditeur de liens `ld` émet l'avertissement :

```
warning: missing .note.GNU-stack section implies executable stack
```

Pourquoi ? Parce que si un fichier objet ne déclare pas explicitement ses besoins
en matière de pile exécutable, `ld` suppose le pire et marque la pile du programme
comme exécutable — ce qui est une faille de sécurité potentielle.

En déclarant une section `.note.GNU-stack` avec les attributs `noexec`, on dit
explicitement : « notre pile n'a pas besoin d'être exécutable ». L'avertissement
disparaît et la pile est marquée non-exécutable.

---

## 12. Vue d'ensemble du flux d'exécution

```
GRUB charge le noyau ELF
  │  eax = 0x2BADB002
  │  ebx = &multiboot_info
  ↓
_start (boot.s, ligne 47)
  │
  ├─ mov esp, stack_top        (ligne 52) — pile opérationnelle
  │
  ├─ mov edx, eax              (ligne 57) — sauvegarde du magic
  │
  ├─ rep stosd                 (lignes 65–70) — .bss = 0
  │     edi = _bss_start
  │     ecx = (_bss_end - _bss_start) / 4
  │     eax = 0
  │
  ├─ push ebx                  (ligne 80) — arg2 sur la pile
  ├─ push edx                  (ligne 81) — arg1 sur la pile
  ├─ call kmain                (ligne 82) — saut vers le Rust
  │
  └─ .hang: cli / hlt          (lignes 85–88) — sécurité (jamais atteint)
```

---

## En résumé

`boot.s` réalise exactement quatre choses dans l'ordre, avant de rendre la main à
Rust :

1. **Pile** — `mov esp, stack_top` installe le registre de pile sur les 16 Kio
   réservés en `.bss`.
2. **Préservation** — `mov edx, eax` met le magic Multiboot à l'abri avant que la
   boucle `rep stosd` n'écrase `eax`.
3. **Mise à zéro de `.bss`** — `rep stosd` initialise toutes les variables
   globales/statiques Rust à zéro, comme le langage l'exige.
4. **Appel de `kmain`** — les arguments Multiboot sont empilés en cdecl
   (`push ebx`, `push edx`) avant `call kmain`.

Tout le reste (boucle de sécurité, `.note.GNU-stack`) est défensif ou cosmétique.

---

## Pour aller plus loin

- **[Étape 04](../04-grub-multiboot/README.md)** — structure détaillée du header Multiboot v1
- **[Étape 06](../06-linker-script/README.md)** — `linker.ld` : comment `_bss_start`, `_bss_end`
  et `ENTRY(_start)` sont définis
- **[Étape 07](../07-coeur-rust/README.md)** — ce que fait `kmain` côté Rust une fois
  appelée
- [OSDev Wiki — Setting Up A Stack](https://wiki.osdev.org/Setting_Up_A_Stack)
- [OSDev Wiki — Multiboot](https://wiki.osdev.org/Multiboot)
- [NASM Manual — Assembler Directives](https://www.nasm.us/doc/nasmdoc6.html)
- [System V ABI i386 — Calling Convention](https://www.sco.com/developers/devspecs/abi386-4.pdf)
