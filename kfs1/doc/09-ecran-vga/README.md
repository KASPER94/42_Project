# Étape 09 — Le driver écran VGA

## Objectif de l'étape

Comprendre comment on affiche du texte sans aucune bibliothèque graphique : le
mode texte VGA, le framebuffer à l'adresse physique `0xB8000`, le format des
cellules (caractère + couleur), et toutes les opérations du driver (écrire,
effacer, défiler, curseur matériel) — jusqu'à l'affichage de `42`.

## Fichiers concernés

- [`../../src/vga.rs`](../../src/vga.rs) — le driver écran (fichier entier)
- [`../../src/lib.rs`](../../src/lib.rs) — `kmain` appelle `vga::init` puis affiche `42`
- [`../../src/console.rs`](../../src/console.rs) — branche `print!` sur le driver (détaillé à l'[étape 11](../11-bonus-console-printf/README.md))

---

## 1. Le mode texte VGA : pourquoi, comment

### Pas de pixels à gérer

En mode graphique, afficher un caractère exige de dessiner chaque pixel de la
police — impossible sans bibliothèque et sans mémoire suffisante pour les
polices. Le mode texte VGA règle le problème différemment : la carte vidéo
gère elle-même le rendu de chaque caractère à partir d'une police câblée en
ROM. Le noyau n'a qu'à écrire *quel caractère* et *de quelle couleur* — le
matériel s'occupe du reste.

### La grille 80×25

L'écran est une grille fixe de **80 colonnes × 25 lignes** = 2 000 cellules.
Chaque cellule occupe **2 octets** consécutifs en mémoire :

```
Offset n     Offset n+1
┌──────────┬──────────────┐
│ ASCII    │  Attribut    │
│ (octet 0)│  (octet 1)   │
└──────────┴──────────────┘
  code du    (fond << 4) | texte
  caractère
```

Soit, pour la totalité de l'écran :

```
80 colonnes × 25 lignes × 2 octets = 4 000 octets
```

La constante `BUFFER_BYTES` (ligne 22 de `vga.rs`) en est la preuve :

```rust
pub const BUFFER_BYTES: usize = COLS * ROWS * 2; // 80 × 25 × 2 = 4 000
```

---

## 2. Le framebuffer mémoire-mappé à `0xB8000`

### Qu'est-ce qu'une adresse mémoire-mappée ?

Sur x86, le bus d'adresses est partagé entre la RAM et les périphériques. Une
plage de l'espace d'adressage physique peut être "câblée" directement vers un
registre ou une mémoire interne à un périphérique — ici la carte vidéo. Lire
ou écrire à l'adresse `0xB8000` ne touche donc **pas la RAM** : cela écrit
directement dans la mémoire vidéo, et la carte affiche en temps réel ce
qu'elle y lit.

C'est le principe du **memory-mapped I/O** (MMIO) : aucun appel système, aucun
pilote intermédiaire — un simple pointeur suffit.

### La constante `VGA_BUFFER`

```rust
// src/vga.rs, ligne 16
const VGA_BUFFER: usize = 0xB8000;
```

C'est l'adresse physique universelle du framebuffer texte VGA en mode couleur
(MDA/Hercules utilise `0xB0000`). Elle est garantie disponible après le
passage en mode protégé 32 bits par GRUB (voir [étape 04](../04-grub-multiboot/README.md)).

---

## 3. L'attribut couleur : `Color` et `make_attr`

### La palette 4 bits (16 couleurs)

VGA standard offre une palette de 16 couleurs numérotées de 0 à 15. L'enum
`Color` (lignes 38–55) les nomme :

```rust
#[repr(u8)]
pub enum Color {
    Black = 0, Blue = 1, Green = 2, Cyan = 3,
    Red = 4,   Magenta = 5, Brown = 6, LightGray = 7,
    DarkGray = 8, LightBlue = 9, LightGreen = 10, LightCyan = 11,
    LightRed = 12, Pink = 13, Yellow = 14, White = 15,
}
```

`#[repr(u8)]` garantit que chaque variante est stockée comme un octet — on
peut donc la caster directement en `u8` sans conversion supplémentaire.

### L'octet attribut

L'octet attribut empaquette fond et texte en un seul octet 8 bits :

```
Bits  7  6  5  4  |  3  2  1  0
      ───────────    ───────────
      fond (4 bits)  texte (4 bits)
```

La fonction `make_attr` (lignes 59–61) réalise cet emballage :

```rust
pub const fn make_attr(fg: Color, bg: Color) -> u8 {
    ((bg as u8) << 4) | (fg as u8)
}
```

Exemple : texte blanc sur fond noir → `make_attr(Color::White, Color::Black)`
= `(0 << 4) | 15` = `0x0F`.

---

## 4. Pourquoi les accès doivent être volatiles

### Le problème de l'optimisation compilateur

En Rust (comme en C), le compilateur est autorisé à supprimer des écritures
qui lui semblent "inutiles" — par exemple s'il détecte que la valeur écrite
n'est jamais relue *dans le code*. C'est catastrophique pour un driver :
écrire dans `0xB8000` n'est **jamais relu par le CPU**, seulement par la carte
vidéo. Sans précaution, le compilateur pourrait éluder toutes les écritures
et l'écran resterait noir.

### `write_volatile` / `read_volatile`

La solution est d'utiliser les primitives `core::ptr::write_volatile` et
`core::ptr::read_volatile`. Ces fonctions informent le compilateur que l'accès
a des **effets de bord observables** : il est interdit de le réordonner, de le
fusionner ou de l'élider.

Dans `write_cell` (lignes 106–115) :

```rust
unsafe fn write_cell(&self, col: usize, row: usize, byte: u8) {
    let offset = (row * COLS + col) * 2;
    let ptr = (VGA_BUFFER + offset) as *mut u8;
    unsafe {
        write_volatile(ptr, byte);       // octet ASCII
        write_volatile(ptr.add(1), self.attr); // octet attribut
    }
}
```

Et dans `scroll_up` (lignes 185–188), les *lectures* aussi sont volatiles :

```rust
let ch = core::ptr::read_volatile(src);
let at = core::ptr::read_volatile(src.add(1));
```

Sans `read_volatile`, le compilateur pourrait supposer que la mémoire vidéo
n'a pas changé depuis la dernière lecture et utiliser une valeur en cache.

---

## 5. La structure `Writer` et son singleton global

### `Writer` : la structure d'état

```rust
// src/vga.rs, lignes 76–80
pub struct Writer {
    col: usize,   // colonne courante (0..79)
    row: usize,   // ligne courante   (0..24)
    attr: u8,     // attribut couleur courant
}
```

`Writer` mémorise la **position du curseur** et la **couleur courante**. Il
n'y a aucune référence au framebuffer dans la struct : l'adresse `VGA_BUFFER`
est une constante globale, et les accès se font toujours via des pointeurs
bruts calculés à la volée.

### Le singleton `WRITER`

```rust
// src/vga.rs, lignes 69–73
static mut WRITER: Writer = Writer {
    col: 0,
    row: 0,
    attr: make_attr(Color::White, Color::Black),
};
```

Un `static mut` est une variable globale mutable. Rust refuse normalement
d'y accéder directement car cela peut induire des courses de données
(data races) en contexte multi-threadé. Dans notre noyau mono-thread, c'est
sûr — mais le compilateur ne le sait pas et émet un lint `static_mut_refs`.

### Le motif `addr_of_mut!`

La fonction privée `writer()` (lignes 240–244) contourne ce lint :

```rust
unsafe fn writer() -> &'static mut Writer {
    unsafe { &mut *core::ptr::addr_of_mut!(WRITER) }
}
```

`addr_of_mut!(WRITER)` obtient un pointeur brut vers `WRITER` *sans* créer de
référence intermédiaire — ce qui est précisément ce que le lint reprochait.
On convertit ensuite ce pointeur en `&mut Writer`. L'annotation
`# Safety` de chaque appelant garantit qu'on ne crée jamais deux `&mut`
simultanément (le noyau est mono-thread à ce stade).

---

## 6. Les opérations du driver

### `clear` — effacer l'écran (lignes 84–94)

Parcourt toutes les cellules de la grille et y écrit un espace `b' '` avec
l'attribut courant, puis repositionne le curseur en `(0, 0)` et synchronise
le curseur matériel.

```rust
pub fn clear(&mut self) {
    for row in 0..ROWS {
        for col in 0..COLS {
            unsafe { self.write_cell(col, row, b' ') };
        }
    }
    self.col = 0;
    self.row = 0;
    self.update_cursor();
}
```

### `write_cell` — écrire une cellule (lignes 106–115)

Calcule l'offset dans le framebuffer :

```
offset = (row × 80 + col) × 2
```

Le `× 2` vient du fait que chaque cellule fait 2 octets. Puis deux
`write_volatile` : un pour le caractère, un pour l'attribut.

### `write_byte` — écrire un octet avec gestion du curseur (lignes 121–138)

Deux cas :

1. `b'\n'` → remet `col` à 0, appelle `advance_row` (qui scrolle si besoin).
2. Tout autre octet → si on est en bout de ligne (`col >= COLS`), wrap
   automatique, puis `write_cell`, puis `col += 1`.

Dans les deux cas, `update_cursor()` synchronise le curseur matériel.

### `write_str` — écrire une chaîne (lignes 141–145)

Simple itération sur les octets de la `&str`, chacun passé à `write_byte`.

### `advance_row` et `scroll_up` — le défilement (lignes 166–197)

`advance_row` passe à la ligne suivante. Si on est déjà à la dernière ligne
(`row + 1 == ROWS`), il appelle `scroll_up` au lieu d'incrémenter.

`scroll_up` copie chaque ligne `n` vers la ligne `n-1`, en utilisant
`read_volatile`/`write_volatile` pour que les accès au framebuffer ne soient
pas optimisés. La dernière ligne est ensuite effacée avec des espaces.

```
Avant scroll :    Après scroll :
┌─ ligne 0 ──┐   ┌─ ligne 0 ──┐  ← ancienne ligne 1
├─ ligne 1 ──┤   ├─ ligne 1 ──┤  ← ancienne ligne 2
├─ ligne 2 ──┤   ├─ ligne 2 ──┤  ← ...
│    ...     │   │    ...     │
└─ ligne 24 ─┘   └─ ligne 24 ─┘  ← blancs
```

### `backspace` — retour arrière (lignes 152–163)

Recule d'une cellule (en remontant à la fin de la ligne précédente si
nécessaire, mais jamais au-dessus de la ligne 0), écrit un espace, et
repositionne le curseur.

---

## 7. Le curseur matériel : ports CRTC

### Pourquoi deux curseurs ?

Il existe deux "curseurs" distincts :

- Le curseur **logique** : `Writer.col` / `Writer.row` — position en mémoire.
- Le curseur **matériel** : le clignotant visible à l'écran, géré par la puce
  CRTC de la carte VGA.

Ils sont indépendants. Si on n'appelle pas `update_cursor`, le clignotant
reste en place même si on a écrit des caractères ailleurs.

### Les ports CRTC

Le CRTC (CRT Controller) de VGA expose ses registres via deux ports I/O :

| Port | Rôle |
|------|------|
| `0x3D4` (`CRTC_INDEX`) | Sélectionne le registre à lire/écrire |
| `0x3D5` (`CRTC_DATA`)  | Lit ou écrit la valeur du registre sélectionné |

Pour mettre à jour le curseur, on programme deux registres :

| Registre | Nom            | Contenu                        |
|----------|----------------|--------------------------------|
| `0x0E`   | `CRTC_CURSOR_HI` | Octet de poids fort de la position |
| `0x0F`   | `CRTC_CURSOR_LO` | Octet de poids faible            |

La **position linéaire** se calcule ainsi :

```
pos = row × COLS + col   (résultat entre 0 et 1 999)
```

### `update_cursor` (lignes 218–229)

```rust
fn update_cursor(&self) {
    let pos: u16 = (self.row * COLS + self.col) as u16;
    unsafe {
        crate::outb(CRTC_INDEX, CRTC_CURSOR_HI);
        crate::outb(CRTC_DATA,  (pos >> 8) as u8);  // bits 15..8
        crate::outb(CRTC_INDEX, CRTC_CURSOR_LO);
        crate::outb(CRTC_DATA,  (pos & 0xFF) as u8); // bits 7..0
    }
}
```

`outb` est défini dans `lib.rs` (ligne 47) : une instruction assembleur
`out dx, al` qui envoie un octet sur un port I/O. C'est l'unique moyen de
communiquer avec les périphériques dont les registres ne sont pas
mémoire-mappés (I/O-mapped I/O, distinct du MMIO).

---

## 8. L'API publique de `vga.rs`

Toutes les fonctions publiques sont de simples délégués vers le singleton
`WRITER` via `writer()`. Elles forment la surface visible du module :

| Fonction | Rôle |
|----------|------|
| `init()` | Initialise couleur (blanc/noir) et efface l'écran — à appeler en premier |
| `clear()` | Efface l'écran et remet le curseur en (0, 0) |
| `set_color(fg, bg)` | Change la couleur pour les prochains caractères |
| `print(s)` | Écrit une `&str` |
| `print_char(c)` | Écrit un seul octet ASCII |
| `backspace()` | Retour arrière |
| `cursor()` | Retourne `(col, row)` courant |
| `set_cursor(col, row)` | Déplace le curseur (avec synchronisation matérielle) |
| `save_buffer(dst)` | Copie le framebuffer live dans `dst` (écrans virtuels — étape 12) |
| `load_buffer(src)` | Restaure un framebuffer dans l'écran live (étape 12) |

`save_buffer` et `load_buffer` lisent et écrivent tous les octets du
framebuffer via `read_volatile`/`write_volatile` pour la même raison qu'ailleurs :
éviter que le compilateur ne considère les données vidéo comme mortes.

---

## 9. Le lien avec l'exigence du sujet : afficher `42`

Dans `kmain` (`src/lib.rs`, ligne 101) :

```rust
screens::init(); // configure les écrans virtuels, appelle vga::init() en interne
println!("42");
```

`screens::init` initialise les écrans virtuels, ce qui inclut `vga::init()` :
couleur blanc/noir, effacement complet. Puis `println!("42")` déclenche la
chaîne :

```
println!("42")
  → console::_print(format_args!("42\n"))
    → VgaSink::write_str("42\n")
      → vga::print("42\n")
        → Writer::write_str("42\n")
          → write_byte(b'4'), write_byte(b'2'), write_byte(b'\n')
            → write_cell(...), update_cursor()
```

Le `42` apparaît en blanc sur fond noir en haut à gauche de l'écran — et le
curseur matériel clignotant se place juste après.

Le lien `print!` → `console.rs` → `vga.rs` est détaillé à l'[étape 11](../11-bonus-console-printf/README.md).
Les écrans virtuels (`save_buffer`/`load_buffer`) sont détaillés à l'[étape 12](../12-bonus-clavier-ecrans/README.md).

---

## En résumé

Le driver VGA repose sur trois mécanismes fondamentaux :

1. **MMIO** : écrire à `0xB8000` modifie directement la mémoire vidéo — pas
   d'appel système, pas de pilote intermédiaire.
2. **Accès volatiles** : `write_volatile`/`read_volatile` empêchent le
   compilateur d'optimiser ou d'éluder des accès qui n'ont d'effet que sur le
   matériel.
3. **I/O porté** : le curseur matériel CRTC est contrôlé via `outb` sur les
   ports `0x3D4`/`0x3D5`, un mécanisme distinct du MMIO.

La struct `Writer` encapsule l'état (position, couleur) et toutes les
opérations. Son singleton global `WRITER` est accédé via `addr_of_mut!` pour
contourner le lint Rust sur les références à des `static mut`, en restant
correct car le noyau est mono-thread.

---

## Pour aller plus loin

- [OSDev Wiki — VGA Text Mode](https://wiki.osdev.org/Printing_To_Screen) —
  référence complète sur le mode texte, les attributs et le CRTC.
- [OSDev Wiki — VGA Hardware](https://wiki.osdev.org/VGA_Hardware) —
  description des registres CRTC, des ports I/O et de la palette.
- [OSDev Wiki — Memory Map](https://wiki.osdev.org/Memory_Map) —
  carte mémoire x86 : où se trouve `0xB8000` par rapport à la RAM et aux
  autres périphériques mémoire-mappés.
- [Étape 07 — kmain](../07-coeur-rust/README.md) — comment le noyau arrive dans
  `kmain` et appelle `vga::init`.
- [Étape 11 — print!](../11-bonus-console-printf/README.md) — comment `print!` et
  `println!` sont câblés sur le driver VGA via `console.rs`.
- [Étape 12 — Écrans virtuels](../12-bonus-clavier-ecrans/README.md) — comment
  `save_buffer`/`load_buffer` permettent de basculer entre plusieurs écrans.
