# Étape 11 — Bonus : Console & macros `print!`

## Objectif de l'étape

Comprendre comment on obtient un `printf`-comme en Rust bare-metal : brancher le
trait `core::fmt::Write` sur le driver VGA pour offrir les macros `print!` et
`println!` avec formatage (`{}`), exactement comme en Rust « normal ».

C'est l'équivalent du `printk` du noyau Linux ou du `printf` de la libc — mais
sans aucune allocation dynamique, sans la bibliothèque standard, et en quelques
dizaines de lignes.

## Fichiers concernés

- [`../../src/console.rs`](../../src/console.rs) — le pont `core::fmt::Write` → VGA, et `backspace`
- [`../../src/lib.rs`](../../src/lib.rs) — les macros `print!` / `println!` et la fonction `_print`
- [`../../src/vga.rs`](../../src/vga.rs) — la cible finale de l'écriture (cf. [étape 09](../09-ecran-vga/README.md))

---

## Pourquoi ce bonus existe

### Le problème : afficher des valeurs formatées sans `std`

En Rust « normal », on écrit `println!("{}", valeur)` et ça fonctionne. Mais
cette macro repose sur `std::io`, qui s'appuie elle-même sur le système
d'exploitation (appel système `write`, descripteur de fichier, etc.). Dans un
noyau `#![no_std]`, rien de tout cela n'existe.

La question du bonus est donc : **comment recréer `printf`/`printk` from
scratch ?**

Le projet 42 vous demande explicitement d'implémenter un mécanisme d'affichage
formaté — pas seulement `print("bonjour")`, mais `print("{} + {} = {}", a, b,
a+b)`. C'est ce que cette étape construit.

### Ce que `core::fmt` apporte

La crate `core` (le sous-ensemble de `std` qui ne dépend pas de l'OS) contient
le module `core::fmt`, qui fournit toute la mécanique de formatage : les
spécificateurs `{}`, `{:?}`, `{:x}`, les tampons intermédiaires, etc. **Ce
module ne fait aucune allocation** — il travaille avec des callbacks vers un
puits d'écriture.

Pour brancher votre propre sortie sur ce système, il suffit d'implémenter un
seul trait : `core::fmt::Write`.

---

## Le trait `core::fmt::Write`

### Définition (dans `core`)

```rust
pub trait Write {
    fn write_str(&mut self, s: &str) -> fmt::Result;

    // Méthodes fournies par défaut (vous n'avez pas à les réécrire) :
    fn write_char(&mut self, c: char) -> fmt::Result { ... }
    fn write_fmt(&mut self, args: fmt::Arguments<'_>) -> fmt::Result { ... }
}
```

Un trait en Rust est une interface : il décrit un comportement qu'un type doit
implémenter. Ici, le contrat est simple : **"je suis un endroit où on peut
écrire des chaînes de caractères"**.

La méthode obligatoire est `write_str`. Vous fournissez cette méthode, et vous
obtenez gratuitement `write_fmt` — c'est elle qui orchestre tout le formatage.

### L'implémentation sur `VgaSink`

Le fichier [`../../src/console.rs`](../../src/console.rs) définit un type
fantôme `VgaSink` (lignes 9–16) :

```rust
// src/console.rs, lignes 9–16
struct VgaSink;

impl Write for VgaSink {
    fn write_str(&mut self, s: &str) -> fmt::Result {
        crate::vga::print(s);
        Ok(())
    }
}
```

**`VgaSink` est une structure vide** — elle ne contient aucun champ. On appelle
ça un *type fantôme* ou *zero-sized type* (ZST). Elle n'existe que pour porter
l'implémentation du trait.

Quand `write_str` est appelée avec une chaîne `s`, elle délègue immédiatement à
`vga::print(s)` ([`../../src/vga.rs`](../../src/vga.rs), ligne 269), qui écrit
chaque octet dans le framebuffer VGA à l'adresse `0xB8000`. C'est tout. Mais ce
petit pont suffit à connecter l'ensemble de `core::fmt` à l'écran.

---

## `format_args!` et `write_fmt` : le formatage sans allocation

### Le problème de la mémoire

Quand on écrit `println!("{} + {} = {}", a, b, a+b)`, le résultat doit bien
être assemblé quelque part. En userspace, on utiliserait une `String` (allocation
sur le tas). En no_std, il n'y a pas de tas.

La solution de `core::fmt` est élégante : **on ne construit jamais la chaîne
finale en mémoire**. À la place, `write_fmt` appelle `write_str` en plusieurs
fois — une fois pour chaque morceau de texte littéral, une fois pour chaque
valeur formatée. Le puits d'écriture (`VgaSink` ici) reçoit les morceaux au fur
et à mesure et les envoie directement à l'écran.

### `format_args!`

La macro `format_args!` est une macro du compilateur (`builtin`). Elle prend un
format littéral et des arguments, et produit une valeur de type
`core::fmt::Arguments<'_>`. Ce type est une description opaque du formatage à
effectuer — essentiellement une liste de callbacks. **Il ne contient pas de
chaîne allouée.**

```rust
let args: core::fmt::Arguments = format_args!("{} + {} = {}", a, b, a + b);
// args est une petite structure sur la pile, pas d'allocation.
```

C'est cette valeur `Arguments` que l'on passe ensuite à `write_fmt`, qui se
charge d'appeler `write_str` autant de fois que nécessaire.

---

## La fonction `_print` dans `console.rs`

```rust
// src/console.rs, lignes 19–22
pub fn _print(args: fmt::Arguments) {
    let _ = VgaSink.write_fmt(args);
}
```

Cette fonction est le **point d'entrée unique** du système d'affichage formaté.
Elle :

1. Instancie `VgaSink` (coût zéro — ZST).
2. Appelle `write_fmt(args)`, héritée du trait `Write`. Cette méthode par défaut
   parcourt les `Arguments` et appelle notre `write_str` pour chaque fragment.
3. Ignore le `Result` (l'écriture VGA ne peut pas échouer dans ce noyau).

Le préfixe `_` dans `_print` est une convention pour indiquer que cette fonction
est une aide interne, pas destinée à être appelée directement par l'utilisateur
— même si elle est `pub` (nécessaire car les macros y accèdent depuis n'importe
quel module).

---

## Les macros `print!` et `println!` dans `lib.rs`

### Qu'est-ce que `macro_rules!` ?

`macro_rules!` est le système de macros par correspondance de motifs de Rust.
Une macro décrite avec `macro_rules!` transforme du code source au moment de la
compilation — c'est une expansion textuelle typée.

Syntaxe générale :

```rust
macro_rules! nom_macro {
    (motif) => { code_généré };
}
```

Le `$($arg:tt)*` capture zéro ou plusieurs *token trees* (`tt`) — autrement dit,
n'importe quelle séquence de tokens Rust valide.

### La macro `print!`

```rust
// src/lib.rs, lignes 28–31
#[macro_export]
macro_rules! print {
    ($($arg:tt)*) => ($crate::console::_print(format_args!($($arg)*)));
}
```

Quand vous écrivez `print!("{}", x)`, le compilateur remplace cela par :

```rust
kfs1::console::_print(format_args!("{}", x))
```

Deux éléments importants :

**`$crate`** : dans une macro exportée, `$crate` se résout toujours vers la
crate qui *définit* la macro (ici `kfs1`), quel que soit le contexte
d'utilisation. Sans `$crate`, si on utilisait `console::_print` directement, le
chemin serait résolu dans la crate *appelante*, provoquant une erreur de
compilation. C'est la façon idiomatique d'écrire des macros réutilisables.

**`#[macro_export]`** : cet attribut rend la macro accessible à l'extérieur du
module où elle est définie. Sans lui, la macro serait invisible en dehors de
`lib.rs`. Avec lui, elle est disponible à la racine de la crate (comme si elle
était définie dans `lib.rs` à la racine).

### La macro `println!`

```rust
// src/lib.rs, lignes 34–38
#[macro_export]
macro_rules! println {
    ()              => ($crate::print!("\n"));
    ($($arg:tt)*)   => ($crate::print!("{}\n", format_args!($($arg)*)));
}
```

`println!` possède deux branches :

- **Cas vide** `println!()` : équivaut à `print!("\n")` — juste un saut de
  ligne.
- **Cas général** `println!("{}", x)` : délègue à `print!` en ajoutant `"\n"`
  à la fin via le format `"{}\n"`.

Pourquoi déléguer à `print!` plutôt que d'appeler `_print` directement ?
**Pour éviter la duplication de logique.** Toute la chaîne de formatage est
centralisée dans `print!`. `println!` ne fait qu'ajouter le `\n`.

---

## Le chemin complet d'un `println!("{}", x)`

Voici le trajet complet, du code utilisateur jusqu'aux pixels sur l'écran :

```
println!("val = {}", x)          [lib.rs, ligne 37]
  │
  │  expansion macro : println! → print!("{}\n", format_args!("val = {}", x))
  ▼
print!("{}\n", <Arguments>)       [lib.rs, ligne 30]
  │
  │  expansion macro : print! → kfs1::console::_print(format_args!(...))
  ▼
console::_print(args)             [console.rs, ligne 19]
  │
  │  VgaSink.write_fmt(args)
  │  (méthode par défaut de core::fmt::Write)
  ▼
VgaSink::write_str(&mut self, s)  [console.rs, ligne 12]
  │
  │  crate::vga::print(s)
  ▼
vga::print(s)                     [vga.rs, ligne 269]
  │
  │  writer().write_str(s)
  │  → write_byte() pour chaque octet
  ▼
write_volatile(ptr, byte)         [vga.rs, ligne 112]
  │
  ▼
Framebuffer VGA @ 0xB8000         [physique]
```

**Aucune allocation** n'a lieu dans ce chemin. `format_args!` produit une
structure sur la pile ; `write_fmt` appelle `write_str` plusieurs fois ;
`write_str` envoie directement au driver VGA.

---

## La fonction `backspace()` dans `console.rs`

```rust
// src/console.rs, lignes 28–30
pub fn backspace() {
    crate::vga::backspace();
}
```

`console.rs` expose aussi `backspace()`, qui délègue à `vga::backspace()`
([`../../src/vga.rs`](../../src/vga.rs), ligne 281). Cette indirection a une
raison d'être architecturale : les modules de haut niveau (comme `screens`) n'ont
pas besoin d'importer `vga` directement — ils passent par `console`. Cela
concentre les dépendances vers le driver VGA en un seul endroit.

L'implémentation dans `vga.rs` (méthode `Writer::backspace`, lignes 152–163)
recule le curseur d'une cellule (avec gestion du retour à la ligne précédente si
on est en colonne 0), écrase la cellule avec un espace, et met à jour le curseur
matériel via les ports CRTC.

Cette fonction est utilisée dans l'étape 12 pour gérer la touche Backspace dans
la boucle clavier.

---

## Équivalence avec `printf`/`printk`

| C (userspace)        | Linux kernel       | Ce noyau (Rust no_std)              |
|----------------------|--------------------|-------------------------------------|
| `printf("%d\n", x)`  | `printk("%d\n", x)`| `println!("{}", x)`                 |
| `putchar(c)`         | —                  | `vga::print_char(c)`                |
| `fputs(s, stdout)`   | —                  | `vga::print(s)`                     |

Le mécanisme est différent (traits vs fonctions variadiques), mais le résultat
est identique : un formatage générique, extensible, sans allocation.

---

## En résumé

- **`VgaSink`** est un type fantôme (zéro octet) qui implémente
  `core::fmt::Write` en déléguant `write_str` à `vga::print`. Ce pont d'une
  ligne suffit à connecter tout le système de formatage de `core` au framebuffer.
- **`format_args!`** produit une description du formatage sur la pile (pas
  d'allocation) ; **`write_fmt`** l'exécute en appelant `write_str` fragment
  par fragment.
- **`print!`** et **`println!`** dans `lib.rs` sont des macros `macro_rules!`
  exportées avec `#[macro_export]`. Elles utilisent `$crate` pour résoudre le
  chemin vers `console::_print` de façon robuste.
- **`println!`** délègue à `print!` en ajoutant `"\n"` — évite la duplication
  et centralise la logique.
- **`backspace()`** dans `console.rs` est une façade vers `vga::backspace()`,
  utilisée à l'étape 12 pour gérer la saisie clavier.

---

## Pour aller plus loin

- **Étape 09** — [Driver VGA](../09-ecran-vga/README.md) : les détails de
  `vga::print`, `write_byte`, le scroll, et le curseur matériel CRTC.
- **Étape 07** — [Structure de `lib.rs` et `kmain`](../07-coeur-rust/README.md) :
  comment `println!("42")` est le premier appel depuis `kmain`.
- **Étape 12** — Clavier et saisie : `console::backspace()` est appelée depuis
  le gestionnaire de touches pour effacer le dernier caractère tapé.
- **`core::fmt::Display` vs `core::fmt::Debug`** : pour formater vos propres
  types avec `{}` ou `{:?}`, implémentez ces traits. La mécanique est exactement
  la même que `Write` — `core::fmt` appelle votre méthode `fmt`.
- **Sécurité future** : dans un noyau multicoeur, l'accès concurrent à
  `VgaSink`/`WRITER` nécessiterait un mutex (spinlock). Pour l'instant, le
  noyau est mono-thread, donc l'absence de synchronisation est correcte.
