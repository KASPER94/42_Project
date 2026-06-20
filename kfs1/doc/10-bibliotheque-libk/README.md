# Étape 10 — La bibliothèque kernel `libk`

## Objectif de l'étape

Comprendre pourquoi un noyau doit réimplémenter ses propres outils de base (il
n'y a pas de libc) et lire la petite bibliothèque maison : les alias de types et
les fonctions de chaînes (`strlen`, `strcmp`, `strncmp`, `str_from_cstr`).

## Fichiers concernés

- [`../../src/lib.rs`](../../src/lib.rs) — déclare `pub mod libk;` (ligne 19)
- [`../../src/libk/mod.rs`](../../src/libk/mod.rs) — déclare les sous-modules `string` et `types`
- [`../../src/libk/types.rs`](../../src/libk/types.rs) — alias de types kernel (`paddr`, `vaddr`, `byte`…)
- [`../../src/libk/string.rs`](../../src/libk/string.rs) — `strlen`, `strcmp`, `strncmp`, `str_from_cstr`
- [`../../.cargo/config.toml`](../../.cargo/config.toml) — active `compiler-builtins-mem` (cf. étape 03)

---

## Pourquoi un noyau n'a pas accès à la libc

Quand vous écrivez un programme ordinaire en C ou en Rust, vous utilisez sans y
penser des fonctions comme `strlen`, `memcpy`, `printf`. Ces fonctions viennent
de la **bibliothèque C standard** (libc), qui est elle-même compilée pour un OS
précis : elle suppose que le noyau tourne sous elle, qu'il gère la mémoire, les
fichiers, les threads, etc.

Un noyau, c'est exactement l'inverse : **il n'y a rien en dessous**. Aucun OS,
aucun runtime, aucune libc. Le fichier `src/lib.rs` l'annonce dès la première
ligne active :

```rust
// src/lib.rs, ligne 15
#![no_std]
```

`no_std` dit au compilateur Rust : « n'inclus pas la bibliothèque standard
(`std`), ni la libc. » Seule la crate `core` reste disponible — elle contient
les abstractions fondamentales (traits, itérateurs, types primitifs) mais
**aucune fonction système** et **aucune allocation dynamique**.

Conséquence directe : si le noyau a besoin de `strlen`, il doit l'écrire
lui-même.

---

## L'idée de `libk` : une bibliothèque kernel maison

Plutôt que d'éparpiller ces fonctions utilitaires partout dans le code, le
projet les regroupe dans un module dédié : `libk` (« library kernel »).

L'entrée du module est déclarée dans `src/lib.rs` :

```rust
// src/lib.rs, ligne 19
pub mod libk;
```

Le fichier `src/libk/mod.rs` décrit ce que contient ce module :

```rust
// src/libk/mod.rs, lignes 12-13
pub mod string;
pub mod types;
```

Deux sous-modules pour l'instant :

| Sous-module | Rôle |
|-------------|------|
| `types`     | Alias de types entiers/pointeurs utilisés partout dans le noyau |
| `string`    | Fonctions de manipulation de chaînes C null-terminées |

Le commentaire introductif du `mod.rs` (lignes 8-10) précise déjà une règle
importante que l'on détaille plus loin :

> `memcpy`, `memset`, `memmove`, and `memcmp` are intentionally **not** defined
> here; they are provided by `compiler-builtins-mem` and duplicate symbols would
> break the link.

`libk` est volontairement minimaliste pour l'instant. Les KFS suivants
(gestion de la mémoire, système de fichiers…) viendront l'enrichir : allocateur,
utilitaires numériques, etc. C'est un point d'extension naturel du projet.

---

## Les alias de types : `src/libk/types.rs`

### Pourquoi des alias ?

En programmation bas niveau, on manipule constamment des adresses mémoire, des
tailles, des octets bruts. Les types primitifs de Rust (`u32`, `usize`, `u8`)
sont corrects, mais peu expressifs : `u32` ne dit pas si c'est une adresse
physique, virtuelle, ou juste un entier quelconque.

Les alias de types permettent d'écrire du code **lisible** sans aucun coût à
l'exécution — ce sont de simples synonymes, le compilateur les efface.

### Le contenu de `types.rs`

```rust
// src/libk/types.rs, lignes 8-23
#![allow(non_camel_case_types)]

pub type uptr  = usize;   // entier non signé de la taille d'un pointeur (32 bits sur i386)
pub type iptr  = isize;   // entier signé de la taille d'un pointeur
pub type byte  = u8;      // octet
pub type paddr = u32;     // adresse physique (32 bits sur i386)
pub type vaddr = u32;     // adresse virtuelle (32 bits sur i386)
```

### `#![allow(non_camel_case_types)]`

Rust exige normalement que les types s'écrivent en `CamelCase` (`MonType`).
`paddr`, `vaddr`, `byte`… sont écrits en minuscules — convention héritée du C
et universelle dans les noyaux. Sans cette directive, le compilateur émettrait
un avertissement pour chaque alias. Le `#![allow(non_camel_case_types)]` en
tête de fichier (ligne 8) supprime ces avertissements pour ce fichier
uniquement, sans les ignorer globalement.

### Utilité concrète

Comparer ces deux signatures :

```rust
// Sans alias — que fait `u32` ici ? adresse physique ? virtuelle ? valeur ?
fn map_page(phys: u32, virt: u32, flags: u32);

// Avec alias — l'intention est explicite
fn map_page(phys: paddr, virt: vaddr, flags: u32);
```

Sur i386 (32 bits), `paddr` et `vaddr` valent tous les deux `u32` aujourd'hui —
le commentaire le précise (ligne 22 : *"same as physical for now"*). Quand on
ajoutera la pagination dans KFS suivants, la distinction sera déjà là dans le
code.

---

## Les fonctions de chaînes : `src/libk/string.rs`

### Les chaînes C : rappel

En C, une chaîne de caractères est un tableau d'octets (`char*`) terminé par un
octet nul (`'\0'`, valeur `0`). En Rust bas niveau, on les représente comme
`*const u8` : un pointeur brut vers des octets, terminé par un `0`.

Il n'y a **aucune information de longueur** : pour savoir où s'arrête la chaîne,
il faut la parcourir octet par octet jusqu'au `0`. C'est précisément ce que
font les fonctions ci-dessous.

### Pourquoi `unsafe` ?

Rust garantit normalement qu'un pointeur est valide avant d'y accéder. Avec un
`*const u8` brut reçu d'un appel système ou d'une structure multiboot, cette
garantie n'existe pas : le compilateur ne peut pas vérifier que le pointeur est
non nul, correctement aligné, qu'il pointe vers de la mémoire lisible, et
surtout qu'il y a bien un octet `0` quelque part. Le contrat de sécurité est
donc déplacé vers l'**appelant**, et Rust exige que tout code qui déréférence un
pointeur brut soit dans un bloc ou une fonction `unsafe`.

### `strlen` (lignes 18–25)

```rust
pub unsafe fn strlen(s: *const u8) -> usize {
    let mut len = 0usize;
    while unsafe { *s.add(len) } != 0 {
        len += 1;
    }
    len
}
```

Parcourt les octets à partir de `s` jusqu'au premier `0` et renvoie le nombre
d'octets **avant** ce `0` (le `0` terminal n'est pas compté, comme en C).

`s.add(len)` est l'arithmétique de pointeur Rust : équivalent de `s + len` en C.

### `strcmp` (lignes 33–47)

```rust
pub unsafe fn strcmp(a: *const u8, b: *const u8) -> c_int {
    let mut i = 0usize;
    loop {
        let ca = unsafe { *a.add(i) };
        let cb = unsafe { *b.add(i) };
        if ca != cb {
            return (ca as c_int) - (cb as c_int);
        }
        if ca == 0 {
            return 0;
        }
        i += 1;
    }
}
```

Compare deux chaînes octet par octet :

- Si les octets diffèrent, renvoie la **différence** (négatif si `a < b`,
  positif si `a > b`) — convention POSIX.
- Si les deux octets courants sont `0` simultanément, les chaînes sont égales :
  renvoie `0`.

Le type de retour est `c_int` (alias `i32` sur i386), importé depuis
`core::ffi::c_int` (ligne 12), ce qui garantit la compatibilité avec l'ABI C si
on devait appeler cette fonction depuis du code assembleur.

### `strncmp` (lignes 54–67)

```rust
pub unsafe fn strncmp(a: *const u8, b: *const u8, n: usize) -> c_int {
    for i in 0..n {
        let ca = unsafe { *a.add(i) };
        let cb = unsafe { *b.add(i) };
        if ca != cb {
            return (ca as c_int) - (cb as c_int);
        }
        if ca == 0 {
            return 0;
        }
    }
    0
}
```

Identique à `strcmp` mais s'arrête après au plus `n` octets. Utile quand on
veut comparer uniquement un préfixe (par exemple, vérifier qu'une commande
commence par `"help"` sans imposer l'égalité totale).

### `str_from_cstr` (lignes 75–80)

```rust
pub unsafe fn str_from_cstr<'a>(s: *const u8) -> Option<&'a str> {
    let len = unsafe { strlen(s) };
    let bytes = unsafe { core::slice::from_raw_parts(s, len) };
    core::str::from_utf8(bytes).ok()
}
```

Convertit un `*const u8` C en `&str` Rust **sans copie** :

1. Calcule la longueur avec `strlen`.
2. Construit un slice `&[u8]` depuis le pointeur brut avec `from_raw_parts`.
3. Tente une interprétation UTF-8 avec `from_utf8` — renvoie `None` si les
   octets ne sont pas du texte UTF-8 valide.

C'est la passerelle entre le monde C (multiboot, BIOS) et le monde Rust du
noyau : une fois qu'on a un `&str`, on peut utiliser toutes les capacités de
`core` sans `unsafe`.

---

## Pourquoi on ne réimplémente PAS `memcpy`, `memset`, `memmove`, `memcmp`

C'est un piège classique — et `mod.rs` le documente explicitement (lignes 8-10).

### Ce que `compiler-builtins-mem` fournit

Comme vu à l'**étape 03**, le fichier `.cargo/config.toml` active :

```toml
# .cargo/config.toml, lignes 7-8
build-std = ["core", "compiler_builtins"]
build-std-features = ["compiler-builtins-mem"]
```

L'option `compiler-builtins-mem` demande à la crate `compiler_builtins` de
fournir des implémentations de `memcpy`, `memset`, `memmove` et `memcmp`
adaptées aux cibles bare-metal. Ces symboles sont **déjà présents** dans le
binaire final.

### Le problème des symboles dupliqués

L'éditeur de liens (`ld`) exige que chaque symbole soit défini **exactement une
fois**. Si `libk/string.rs` définissait aussi `memcpy`, il existerait deux
définitions du même symbole — une dans `compiler_builtins`, une dans notre code.
L'édition de liens échouerait avec une erreur du type :

```
error: multiple definition of `memcpy`
```

### La distinction conceptuelle

Il y a aussi une raison conceptuelle : `memcpy`/`memset`/`memmove`/`memcmp` sont
des opérations sur des **blocs mémoire bruts** (octets quelconques, pas
forcément des chaînes). Les fonctions de `string.rs` ont une **sémantique de
chaîne** : elles s'arrêtent au `\0`. Ce sont deux niveaux d'abstraction
différents.

---

## Lien avec l'exigence du sujet 42

Le sujet KFS-1 exige que le noyau fournisse des helpers C-string utilisables
dans les composants bas niveau. `strlen`, `strcmp` et `strncmp` sont
explicitement cités. La `libk` y répond directement, tout en anticipant les
besoins des KFS suivants (gestion de la mémoire, parseurs de commandes, etc.).

---

## En résumé

- Un noyau `#![no_std]` n'a pas accès à la libc : il doit réécrire les outils
  dont il a besoin.
- `libk` est le module-maison qui regroupe ces outils : pour l'instant des alias
  de types (`paddr`, `vaddr`, `byte`…) et des fonctions de chaînes C-compatibles.
- Les alias de types n'ont aucun coût à l'exécution mais rendent le code bas
  niveau lisible et auto-documenté.
- Les fonctions de `string.rs` manipulent des `*const u8` null-terminés — elles
  sont `unsafe` car le contrat de validité du pointeur repose sur l'appelant.
- `memcpy`/`memset`/`memmove`/`memcmp` ne sont **pas** redéfinis ici : ils sont
  déjà fournis par `compiler-builtins-mem` et les redéfinir provoquerait des
  erreurs de lien.

---

## Pour aller plus loin

- **Étape 03** — `compiler-builtins-mem` et la configuration du target bare-metal
  dans `.cargo/config.toml`
- **Étape 07** — Le driver VGA et la console qui utilisent ces types (`vaddr`,
  `byte`) pour adresser le framebuffer `0xB8000`
- `core::ffi` — le module de `core` qui fournit `c_int`, `c_char`, etc., pour
  l'interopérabilité avec l'ABI C sans libc
- Les KFS suivants enrichiront `libk` : allocateur slab, utilitaires numériques,
  gestionnaire d'erreurs kernel…
