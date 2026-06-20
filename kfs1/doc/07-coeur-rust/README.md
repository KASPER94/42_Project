# Étape 07 — Le cœur Rust : `kmain` & panic

## Objectif

Comprendre le point d'entrée Rust du noyau : comment `kmain` est appelé depuis
l'assembleur, pourquoi sa signature est exactement ce qu'elle est, pourquoi un
`#[panic_handler]` est obligatoire en `no_std`, et comment on dialogue avec le
matériel via les ports d'E/S x86.

---

## Fichiers concernés

- [`../../src/lib.rs`](../../src/lib.rs) — racine du crate : `kmain`, panic handler, `outb`/`inb`, `halt`, `serial_print`
- [`../../src/boot.s`](../../src/boot.s) — l'appelant assembleur (`call kmain`, lignes 80–82, cf. [étape 05](../05-boot-asm/README.md))
- [`../../CONTRACTS.md`](../../CONTRACTS.md) — le contrat ABI entre l'assembleur et Rust (section "Entry contract")

---

## Contexte : où en sommes-nous dans le démarrage ?

Quand GRUB charge notre noyau, il saute à `_start` (dans `boot.s`).
Ce code assembleur :

1. pose un pointeur de pile (`mov esp, stack_top`) ;
2. met `.bss` à zéro (`rep stosd`) ;
3. pousse deux arguments sur la pile (`push ebx` / `push edx`) ;
4. appelle `kmain` via l'instruction `call kmain`.

À partir de là, **c'est Rust qui prend la main**. Ce fichier explique tout ce
qui se passe côté Rust, depuis l'attribut `#![no_std]` jusqu'à la boucle
clavier finale.

---

## `#![no_std]` — se passer de la bibliothèque standard

La première ligne du fichier [`../../src/lib.rs`](../../src/lib.rs) est :

```rust
#![no_std]
```

### Pourquoi pas `std` ?

La bibliothèque standard Rust (`std`) suppose qu'un système d'exploitation
existe en dessous d'elle : elle utilise des appels système pour allouer de la
mémoire (`malloc`), gérer les threads, ouvrir des fichiers, etc. Dans un
noyau, **nous sommes** le système d'exploitation — il n'y a rien en dessous.
On ne peut donc pas utiliser `std`.

### Ce que `#![no_std]` apporte (et supprime)

| Disponible via `core` | Absent (c'est dans `std` ou `alloc`) |
|---|---|
| Types de base : `u8`, `u32`, `bool`… | `String`, `Vec`, `HashMap` |
| `Option`, `Result`, itérateurs | Allocation dynamique (`Box`, `Rc`…) |
| Formatage via `core::fmt` | Threads, fichiers, réseau |
| `core::arch::asm!` pour l'assembleur en ligne | Déroulement de pile (*unwinding*) |

`#![no_std]` s'applique à l'ensemble du **crate** : toutes les dépendances
déclarées dans les `mod` qui suivent héritent de cette contrainte.

---

## La signature de `kmain` décortiquée

```rust
// src/lib.rs, ligne 99–100
#[no_mangle]
pub extern "C" fn kmain(_multiboot_magic: u32, _multiboot_info: u32) -> ! {
```

Chaque mot ici a une raison d'être précise.

### `#[no_mangle]` — garder le nom tel quel

Par défaut, Rust **mange** (*mangles*) les noms de fonctions : il ajoute des
suffixes d'encodage pour gérer les espaces de noms, la généricité, etc.
`kmain` deviendrait quelque chose comme `_ZN4kfs15kmainE` dans le binaire.

L'instruction NASM `extern kmain` (ligne 41 de `boot.s`) cherche **exactement**
le symbole `kmain` dans la table des symboles ELF. Avec le mangling activé,
le linker ne trouverait pas `kmain` et échouerait.

`#[no_mangle]` désactive le mangling : le symbole exporté s'appellera
littéralement `kmain`.

### `extern "C"` — l'ABI cdecl

L'ABI (*Application Binary Interface*) définit **comment** les arguments sont
passés entre l'appelant et l'appelé au niveau machine : dans quels registres,
dans quel ordre sur la pile, qui nettoie la pile après l'appel.

Rust utilise par défaut sa propre ABI interne qui peut changer d'une version
du compilateur à l'autre. Le code assembleur, lui, utilise l'ABI **cdecl**
(l'ABI C standard sur i386) :

- les arguments sont poussés sur la pile **de droite à gauche** ;
- l'appelant nettoie la pile après le retour.

Regardons les lignes 80–81 de `boot.s` :

```nasm
push ebx    ; arg2 : multiboot_info  (u32) → placé en [esp+8] depuis kmain
push edx    ; arg1 : multiboot_magic (u32) → placé en [esp+4] depuis kmain
call kmain
```

`extern "C"` dit au compilateur Rust : « génère du code qui reçoit les
arguments selon la convention cdecl ». Sans cela, Rust chercherait les
arguments dans des registres ou des offsets différents, et lirait n'importe
quoi.

> **Résumé** : `boot.s` pousse les arguments avec cdecl → `extern "C"` fait
> que Rust les lit avec cdecl → les deux se parlent correctement.

### `(multiboot_magic: u32, multiboot_info: u32)` — ce que GRUB passe

GRUB remplit deux registres avant de sauter à `_start` (cf. `CONTRACTS.md`,
section "Entry contract") :

- `EAX` = `0x2BADB002` — le "magic number" Multiboot v1, preuve qu'un
  chargeur Multiboot conforme a démarré le noyau.
- `EBX` = adresse physique de la structure `multiboot_info`, qui contient
  la carte mémoire, les modules chargés, etc.

`boot.s` déplace ces valeurs vers la pile avant l'appel. `kmain` les reçoit
en tant que deux `u32`. Les noms sont préfixés `_` car nous ne les utilisons
pas encore dans cette étape (Rust émet un avertissement pour les variables
inutilisées).

### `-> !` — la divergence, ou « cette fonction ne retourne jamais »

Le type `!` s'appelle le **type jamais** (*never type*). Il indique au
compilateur que la fonction **ne reviendra jamais** à son appelant. C'est une
promesse forte : le compilateur peut s'en servir pour des optimisations et
pour détecter du code mort.

Pourquoi `kmain` ne peut-elle pas retourner ?

Regardons la suite de `boot.s` après le `call kmain` (lignes 84–88) :

```nasm
.hang:
    cli
    hlt
    jmp .hang
```

Ce code est là « au cas où » — défense en profondeur — mais il ne constitue
pas un environnement d'exécution valide. GRUB n'a laissé aucun cadre de pile
de retour, aucun mécanisme de retour propre. Si `kmain` revenait, l'adresse
de retour sur la pile serait indéfinie, et le processeur exécuterait du code
aléatoire. Un noyau qui revient de son point d'entrée principal est un noyau
qui plante de façon incontrôlée.

`-> !` transforme cette contrainte en **erreur de compilation** : si vous
écrivez du code dans `kmain` qui pourrait laisser la fonction se terminer
naturellement, Rust refuse de compiler.

---

## La fonction `halt()` — arrêter le CPU proprement

```rust
// src/lib.rs, lignes 87–92
fn halt() -> ! {
    loop {
        unsafe { core::arch::asm!("hlt", options(nomem, nostack)) };
    }
}
```

L'instruction `hlt` suspend le processeur jusqu'à la prochaine interruption
matérielle. Sur un PC sans gestion des interruptions configurée (ce qu'on n'a
pas encore), le CPU se remet en veille indéfiniment.

La boucle `loop { hlt }` est nécessaire parce qu'en théorie une interruption
pourrait réveiller le CPU. Sans la boucle, après une telle interruption, le
CPU continuerait l'exécution après `halt()`, ce qui violerait le `-> !`.

`halt()` est appelée dans le panic handler (voir ci-dessous) pour immobiliser
le système dès qu'une erreur fatale est détectée.

---

## L'assembleur en ligne : `core::arch::asm!`

Certaines opérations n'ont pas d'équivalent en Rust pur : écrire sur un port
d'E/S, lire le registre d'état du CPU, exécuter `hlt`. Pour cela, Rust offre
la macro `core::arch::asm!` qui permet d'insérer des instructions x86
directement dans le code généré.

### La notion de port d'E/S

Sur l'architecture x86, il existe **deux espaces d'adressage distincts** :

| Espace | Taille | Accès |
|---|---|---|
| Mémoire | 4 Go (32 bits) | `mov`, pointeurs ordinaires |
| Ports d'E/S | 65 536 ports (16 bits) | Instructions `in`/`out` uniquement |

Les ports d'E/S permettent de communiquer avec les périphériques (clavier,
port série, contrôleur de disque, VGA…) sans passer par la mémoire. Chaque
périphérique se voit attribuer une plage de numéros de ports fixée par
convention (depuis les débuts du PC).

> Les instructions `in`/`out` sont **privilégiées** : elles ne peuvent
> s'exécuter qu'en ring 0 (mode noyau). Un programme utilisateur qui tenterait
> de les exécuter déclencherait une faute de protection générale (#GP).

### `outb` — écrire un octet sur un port

```rust
// src/lib.rs, lignes 47–57
pub unsafe fn outb(port: u16, value: u8) {
    unsafe {
        core::arch::asm!(
            "out dx, al",
            in("dx") port,
            in("al") value,
            options(nomem, nostack, preserves_flags),
        );
    }
}
```

**Décryptage ligne par ligne :**

- `"out dx, al"` — l'instruction assembleur x86 : envoie l'octet contenu dans
  le registre `AL` vers le port dont le numéro est dans `DX`.
- `in("dx") port` — **contrainte d'entrée** : place la valeur Rust `port`
  dans le registre `DX` avant l'instruction. Le compilateur sait qu'il ne peut
  pas mettre `port` ailleurs.
- `in("al") value` — idem pour `value` dans `AL`.
- `options(nomem, nostack, preserves_flags)` :
  - `nomem` : l'instruction ne lit ni n'écrit en mémoire (le compilateur peut
    réordonner des accès mémoire autour d'elle en toute sécurité) ;
  - `nostack` : l'instruction ne touche pas la pile ;
  - `preserves_flags` : les drapeaux du registre `EFLAGS` ne sont pas
    modifiés (le compilateur n'a pas besoin de les sauvegarder).

La fonction est marquée `unsafe` parce qu'écrire sur un port arbitraire peut
avoir des effets irréversibles (réinitialiser un périphérique, écrire dans un
contrôleur DMA, etc.).

### `inb` — lire un octet depuis un port

```rust
// src/lib.rs, lignes 64–76
pub unsafe fn inb(port: u16) -> u8 {
    let value: u8;
    unsafe {
        core::arch::asm!(
            "in al, dx",
            out("al") value,
            in("dx") port,
            options(nomem, nostack, preserves_flags),
        );
    }
    value
}
```

La différence par rapport à `outb` : la contrainte est `out("al") value`
(écriture vers la variable Rust `value` depuis `AL`). L'instruction `in al, dx`
lit un octet depuis le port `DX` et le place dans `AL`, que la contrainte
`out` récupère ensuite dans la variable Rust.

`inb` est utilisée dans le driver clavier ([étape 12](../12-bonus-clavier-ecrans/README.md))
pour lire les scancodes depuis le port `0x60` du contrôleur PS/2.

---

## Le port série COM1 (`0x3F8`) comme canal de débogage

```rust
// src/lib.rs, lignes 79–84
pub fn serial_print(s: &str) {
    for &b in s.as_bytes() {
        unsafe { outb(0x3F8, b) };
    }
}
```

Le port série COM1 est câblé aux adresses `0x3F8`–`0x3FF`. Écrire un octet
sur `0x3F8` (le registre de données) l'envoie sur la ligne série.

### Pourquoi le port série et pas directement VGA ?

Quand on développe un noyau, on a souvent besoin de voir ce qui se passe
**avant** que le driver VGA soit initialisé, ou dans des contextes où l'écran
n'est pas accessible (CI headless, crash très tôt, panic handler). Le port
série est :

- **simple** : un seul `outb` par octet, pas de curseur, pas de scroll ;
- **visible depuis l'hôte** : QEMU redirige COM1 vers la sortie standard
  (`make run`) ou un fichier log ;
- **disponible immédiatement** : sans aucune initialisation préalable pour un
  usage basique en mode polling.

Dans `kmain`, on trouve :

```rust
// src/lib.rs, ligne 105
serial_print("42\nKFS1_BOOT_OK\n");
```

Cette ligne est la **preuve de vie** du noyau : `make smoke` lance QEMU sans
affichage graphique et vérifie que la chaîne `KFS1_BOOT_OK` apparaît sur la
sortie série. C'est le test de non-régression minimal du pipeline CI.

---

## Le `#[panic_handler]` obligatoire

```rust
// src/lib.rs, lignes 121–125
#[panic_handler]
fn panic(_info: &PanicInfo) -> ! {
    serial_print("KERNEL PANIC\n");
    halt();
}
```

### Pourquoi est-il obligatoire ?

En Rust standard, quand une panique se produit (ex. : accès hors bornes,
`unwrap()` sur `None`), le runtime appelle un panic handler **défini dans
`std`**, qui peut dérouler la pile, afficher un message, etc.

En `#![no_std]`, il n'y a pas de runtime. Rust exige donc que **vous**
fournissiez ce handler. Si vous ne le faites pas, le compilateur refuse de
produire un binaire final : erreur de link « undefined reference to
`rust_begin_unwind` ».

L'attribut `#[panic_handler]` marque votre fonction comme le gestionnaire de
panique du crate. Il ne peut y en avoir qu'un seul.

### Pourquoi le panic handler ne peut-il faire que ça ?

Dans un noyau `no_std` sans allocateur, le panic handler est dans une
situation extrêmement contrainte :

- **Pas d'allocation** : impossible d'utiliser `format!`, `String::from`, etc.
  pour construire un message d'erreur élaboré.
- **Pas de déroulement de pile** (*unwinding*) : notre target `i386-kfs`
  est configurée avec `panic=abort` (cf. `CONTRACTS.md`). La stratégie
  `abort` ne déroule pas la pile — elle s'arrête immédiatement. On ne peut
  donc pas non plus compter sur les destructeurs (`Drop`) pour nettoyer.
- **État du système inconnu** : la panique peut survenir dans n'importe quel
  contexte, potentiellement en plein milieu d'une écriture VGA ou d'une
  opération clavier. On ne peut pas faire confiance à ces sous-systèmes.

La seule action sûre et universellement disponible : envoyer un signal sur le
port série (qui ne nécessite qu'un `outb`), puis immobiliser le CPU avec
`halt()`. C'est exactement ce que fait notre handler.

> `_info: &PanicInfo` contient le message et l'emplacement du panic, mais on
> ne les exploite pas ici. Une amélioration future pourrait utiliser
> `serial_print` avec du formatage `core::fmt` pour afficher le fichier et la
> ligne.

---

## Ce que fait `kmain` pas à pas

```rust
// src/lib.rs, lignes 100–117
pub extern "C" fn kmain(_multiboot_magic: u32, _multiboot_info: u32) -> ! {
    screens::init();          // (1) initialisation de l'écran

    println!("42");           // (2) affichage obligatoire du sujet
    serial_print("42\nKFS1_BOOT_OK\n");  // (3) signal de vie sur COM1

    keyboard::init();         // (4) initialisation du clavier

    loop {                    // (5) boucle principale
        if let Some(event) = keyboard::poll() {
            screens::handle_key(event);
        }
        core::hint::spin_loop();
    }
}
```

### (1) `screens::init()` — préparer l'affichage

Initialise le sous-système des écrans virtuels et efface l'écran 0. C'est le
premier appel car tout ce qui suit (notamment `println!`) a besoin que le
driver d'affichage soit prêt. Les détails VGA sont dans l'[étape 09](../09-ecran-vga/README.md).

### (2) `println!("42")` — preuve à l'écran

Le sujet du projet exige que le noyau affiche `42`. `println!` est une macro
définie dans ce même fichier (lignes 35–38) ; elle délègue à
`console::_print` qui passe par le driver VGA. Les macros `print!`/`println!`
sont expliquées dans l'[étape 11](../11-bonus-console-printf/README.md).

### (3) `serial_print(...)` — preuve sur COM1

Envoie la même information sur le port série pour le pipeline CI (`make smoke`).

### (4) `keyboard::init()` — préparer la saisie

Initialise le driver clavier PS/2. Les détails du driver clavier sont dans
l'[étape 12](../12-bonus-clavier-ecrans/README.md).

### (5) La boucle principale — le cœur battant du noyau

```rust
loop {
    if let Some(event) = keyboard::poll() {
        screens::handle_key(event);
    }
    core::hint::spin_loop();
}
```

C'est un **polling actif** : le noyau interroge en permanence le registre du
contrôleur PS/2 pour savoir si une touche a été pressée. Si un événement est
disponible, il est transmis au gestionnaire d'écrans qui l'affiche ou
effectue un changement d'écran virtuel (touches Fn).

`core::hint::spin_loop()` est un indice au processeur qu'on est dans une
attente active : sur les CPU modernes, cela correspond à l'instruction `PAUSE`
qui réduit la consommation d'énergie et améliore les performances des cœurs
voisins dans un contexte hyperthreadé.

La boucle ne peut jamais se terminer (c'est un `loop` sans `break`), ce qui
satisfait le `-> !` de la signature.

---

## Liens entre étapes

| Étape | Rôle par rapport à ce fichier |
|---|---|
| [05 — Boot ASM](../05-boot-asm/README.md) | Appelant : prépare la pile et appelle `kmain` |
| [09 — VGA](../09-ecran-vga/README.md) | `screens::init()` et `println!` dans `kmain` |
| [11 — Macros print!](../11-bonus-console-printf/README.md) | `print!`/`println!` définis dans `lib.rs` |
| [12 — Clavier](../12-bonus-clavier-ecrans/README.md) | `keyboard::init()` et `keyboard::poll()` dans la boucle |

---

## En résumé

- `#![no_std]` coupe l'accès à la bibliothèque standard ; seul `core` reste
  disponible. Cela est inévitable dans un noyau puisqu'il n'y a pas d'OS en
  dessous.
- La signature `#[no_mangle] pub extern "C" fn kmain(...) -> !` est un
  contrat ABI tripartite : `#[no_mangle]` garantit que l'assembleur trouve le
  bon symbole, `extern "C"` aligne la convention d'appel avec les `push` de
  `boot.s`, et `-> !` interdit tout retour accidentel.
- Le `#[panic_handler]` est imposé par le compilateur en `no_std` ; contraint
  par l'absence d'alloc et la stratégie `panic=abort`, il ne peut qu'émettre
  un signal sur COM1 puis bloquer le CPU avec `halt()`.
- `outb`/`inb` wrappent les instructions `out dx,al` / `in al,dx` via
  `core::arch::asm!` ; les contraintes de registres et les options (`nomem`,
  `nostack`, `preserves_flags`) informent le compilateur des effets de
  l'instruction pour qu'il optimise correctement.
- `serial_print` sur le port `0x3F8` est le canal de débogage *headless* :
  un seul `outb` par octet, visible immédiatement depuis QEMU sans aucun
  sous-système graphique.
- `kmain` orchestre le démarrage (écrans, clavier) puis entre dans une boucle
  de polling infinie qui constitue le cœur du noyau.

---

## Pour aller plus loin

- **Interruptions clavier** : le polling actif fonctionne, mais consomme 100 %
  du CPU. La prochaine étape logique serait de configurer le contrôleur
  d'interruptions (PIC 8259) pour recevoir des IRQ clavier.
- **Exploiter `PanicInfo`** : `_info.message()` et `_info.location()` donnent
  le message et l'emplacement du panic. Avec un peu de `core::fmt`, on
  pourrait les afficher sur COM1.
- **Initialiser COM1 correctement** : notre `serial_print` écrit directement
  sans initialiser le UART 16550. Pour un usage fiable (débit, parité,
  handshake), il faudrait écrire dans les registres de configuration
  (`0x3F8+1` à `0x3F8+7`).
- **Vérifier le magic Multiboot** : `_multiboot_magic` devrait valoir
  `0x2BADB002`. Un assert précoce (`if magic != 0x2BADB002 { halt(); }`)
  permettrait de détecter un démarrage sans chargeur Multiboot valide.
- **Références** :
  - [Multiboot v1 Specification](https://www.gnu.org/software/grub/manual/multiboot/multiboot.html)
  - [OSDev Wiki — I/O Ports](https://wiki.osdev.org/I/O_Ports)
  - [OSDev Wiki — Serial Ports](https://wiki.osdev.org/Serial_Ports)
  - [Rust Reference — Inline assembly](https://doc.rust-lang.org/reference/inline-assembly.html)
  - [Rust Reference — `#[panic_handler]`](https://doc.rust-lang.org/reference/runtime.html#the-panic_handler-attribute)
