# Étape 12 — Bonus : Clavier PS/2 & écrans virtuels

## Objectif de l'étape

Comprendre comment lire le clavier sans interruptions (en *polling*) et décoder
les scancodes, puis comment gérer plusieurs écrans texte indépendants que l'on
bascule avec F1–F4. C'est l'aboutissement interactif du noyau.

## Fichiers concernés

- [`../../src/keyboard.rs`](../../src/keyboard.rs) — driver clavier PS/2 (polling, scancode set 1)
- [`../../src/screens.rs`](../../src/screens.rs) — écrans virtuels, bascule F1–F4
- [`../../src/lib.rs`](../../src/lib.rs) — la boucle principale (`keyboard::poll` → `screens::handle_key`)
- [`../../src/vga.rs`](../../src/vga.rs) — `save_buffer`/`load_buffer`/`cursor`/`set_cursor` utilisés par les écrans

---

## Partie 1 — Le clavier PS/2 (`keyboard.rs`)

### 1.1 Le matériel : le contrôleur PS/2

Avant d'écrire une seule ligne de code, il faut comprendre à quoi on parle. Un
clavier PS/2 est connecté à un contrôleur dédié (le *8042* ou son équivalent)
intégré à la carte mère. Ce contrôleur expose deux **ports d'entrée/sortie
x86** (accessibles via les instructions `in`/`out`, privilège ring 0) :

| Port  | Nom          | Rôle                                          |
|-------|--------------|-----------------------------------------------|
| `0x60`| `PS2_DATA`   | Lire un scancode (ou écrire une commande)     |
| `0x64`| `PS2_STATUS` | Lire le registre de statut du contrôleur      |

Dans [`../../src/keyboard.rs`](../../src/keyboard.rs) (lignes 49–52) :

```rust
const PS2_DATA:   u16 = 0x60;
const PS2_STATUS: u16 = 0x64;
const STATUS_OBF: u8  = 0x01;
```

Le registre de statut contient plusieurs bits. Le plus important pour nous est
le **bit 0**, appelé **OBF** (*Output Buffer Full*). Il vaut `1` quand un
scancode est prêt à être lu dans `PS2_DATA`, et `0` sinon.

> **Analogie :** imaginez une boîte aux lettres. Le bit OBF est le petit
> drapeau rouge qui se lève quand il y a du courrier. On ne doit ouvrir la
> boîte que si le drapeau est levé.

### 1.2 Polling versus interruptions — pourquoi le polling ici ?

Sur un PC, quand on appuie sur une touche, le contrôleur PS/2 envoie
normalement une **IRQ 1** (interruption matérielle ligne 1). Le processeur
interrompt alors ce qu'il fait et saute dans un gestionnaire d'interruption
(ISR). C'est le mécanisme *propre* pour les noyaux matures.

**Mais cela nécessite :**
1. Une **IDT** (Interrupt Descriptor Table) — la table qui associe chaque
   numéro d'IRQ à une fonction gestionnaire.
2. Un **PIC** (Programmable Interrupt Controller) correctement initialisé et
   démasqué.

Ces deux éléments font partie de **KFS_2**. Ici, dans KFS_1, on n'a ni IDT ni
PIC configuré. On utilise donc le **polling** : la boucle principale du noyau
*interroge activement* le port statut à chaque tour pour savoir si une touche
a été pressée. C'est moins efficace (le CPU tourne en permanence), mais c'est
suffisant pour un noyau de démonstration et ne requiert aucune infrastructure
d'interruptions.

Le commentaire du module (ligne 6 de `keyboard.rs`) le dit explicitement :
```
Polling-based — no IRQ/IDT required (that is KFS_2 territory).
```

### 1.3 Le scancode set 1

Quand on appuie sur une touche, le contrôleur place dans `PS2_DATA` un
**scancode** — un nombre qui identifie la *position physique* de la touche sur
le clavier, pas le caractère qu'elle représente. Il existe plusieurs
"ensembles" (sets) de scancodes selon les générations de matériel. QEMU et la
plupart des PC compatibles utilisent le **scancode set 1** par défaut.

Le scancode set 1 distingue deux types d'événements :

- **Make code** (appui) : scancode brut, de 0x01 à 0x58 pour les touches
  ordinaires.
- **Break code** (relâche) : `make | 0x80` — exactement le même code avec le
  bit 7 mis à 1.

Exemple : la touche `A` a le make code `0x1E`. Appuyer dessus envoie `0x1E`,
relâcher envoie `0x9E` (`0x1E | 0x80`).

Dans `poll()` (lignes 152–153) :

```rust
let is_break = sc & 0x80 != 0;
let make = sc & 0x7F; // strip the break bit to get the make code
```

### 1.4 Les modificateurs : Shift et Ctrl

Certaines touches ne produisent pas un caractère mais changent l'état du
clavier : c'est le cas de Shift et Ctrl. Le driver les trace via deux
variables globales :

```rust
static mut SHIFT: bool = false;  // ligne 62
static mut CTRL:  bool = false;  // ligne 65
```

> **Pourquoi `addr_of_mut!` ?** En Rust, créer une référence `&mut` vers un
> `static mut` est une erreur (lint `static_mut_refs`). La macro
> `core::ptr::addr_of_mut!` renvoie un pointeur brut sans créer de référence,
> ce qui évite le problème tout en restant sûr dans un contexte
> single-threaded.

La logique dans `poll()` :
- Si `is_break` et make == `0x2A` ou `0x36` (Left/Right Shift) → `SHIFT = false`.
- Si `is_break` et make == `0x1D` (Left Ctrl) → `CTRL = false`.
- Si make code et `0x2A`/`0x36` → `SHIFT = true`, retour `None` (pas d'événement).
- Si make code et `0x1D` → `CTRL = true`, retour `None`.

Les break codes ne produisent **jamais** de `KeyEvent` (ligne 168) :
```rust
return None; // Break codes never produce a KeyEvent.
```

### 1.5 Les tables de traduction US QWERTY

Le scancode identifie une *position* physique. Pour obtenir le caractère ASCII
correspondant, on utilise deux tableaux de 89 entrées (indexés par make code) :

- `UNSHIFTED` (ligne 82) : la touche seule (`a`, `1`, `-`…)
- `SHIFTED` (ligne 98) : la touche avec Shift (`A`, `!`, `_`…)

```rust
static UNSHIFTED: [u8; 89] = [ … ]; // ex: index 0x1E → b'a'
static SHIFTED:   [u8; 89] = [ … ]; // ex: index 0x1E → b'A'
```

Une valeur `0` dans le tableau signifie "pas de caractère ASCII pour ce
scancode" (touches de contrôle, non mappées, etc.).

La sélection (lignes 215–225) :
```rust
let ascii = if shift { SHIFTED[sc as usize] } else { UNSHIFTED[sc as usize] };
if ascii != 0 { Key::Char(ascii) } else { Key::Other }
```

### 1.6 Les types `Key` et `KeyEvent`

Le résultat final de la décodification est emballé dans deux types :

```rust
pub enum Key {
    Char(u8),       // un caractère ASCII déjà shifté
    Enter,
    Backspace,
    Tab,
    Esc,
    Function(u8),   // F1..F12
    Other,
}

pub struct KeyEvent {
    pub key:   Key,
    pub shift: bool,
    pub ctrl:  bool,
}
```

`KeyEvent::as_char()` (ligne 37) est un raccourci pratique : il renvoie
`Some(b'\n')` pour `Enter` et `Some(c)` pour `Char(c)`, sinon `None`.

### 1.7 `init()` : drainer le buffer au démarrage

La fonction `init()` (ligne 119) fait une chose simple mais indispensable :
elle vérifie si un byte traîne dans le buffer PS/2 (laissé là par GRUB) et le
lit pour l'éliminer. Sans ça, le premier `poll()` pourrait renvoyer une
frappe parasite.

```rust
pub fn init() {
    unsafe {
        if crate::inb(PS2_STATUS) & STATUS_OBF != 0 {
            let _ = crate::inb(PS2_DATA);
        }
    }
}
```

### 1.8 `poll()` : la fonction centrale

`poll()` (ligne 140) réunit tout ce qu'on vient de voir :

1. Lire `PS2_STATUS` ; si OBF == 0, retourner `None` (rien à lire).
2. Lire `PS2_DATA` : le scancode brut.
3. Extraire `is_break` et `make`.
4. Si break : mettre à jour SHIFT/CTRL si nécessaire, retourner `None`.
5. Si make modificateur : mettre à jour SHIFT/CTRL, retourner `None`.
6. Capturer l'état courant de `shift` et `ctrl` pour l'événement.
7. Décoder `make` en `Key` (touches spéciales hardcodées, puis lookup tables).
8. Retourner `Some(KeyEvent { key, shift, ctrl })`.

---

## Partie 2 — Les écrans virtuels (`screens.rs`)

### 2.1 L'idée : plusieurs écrans, un seul visible

Sur un terminal Linux, on bascule entre des "TTY" avec Alt+F1, Alt+F2, etc.
Chaque TTY a son propre contenu affiché. Notre noyau reproduit ce concept à
l'échelle.

Il y a `NUM_SCREENS = 4` écrans virtuels (ligne 16 de `screens.rs`).
À tout moment :
- **Un seul** écran est "actif" : son contenu est dans le framebuffer VGA réel
  (`0xB8000`), visible à l'écran.
- **Les trois autres** sont "endormis" : leur contenu est conservé dans des
  tableaux de bytes en mémoire, dans la section `.bss`.

### 2.2 La structure `Screen` et `Manager`

```rust
struct Screen {
    buffer: [u8; BUFFER_BYTES],  // copie du framebuffer VGA (4000 bytes)
    col: usize,                  // position curseur sauvegardée
    row: usize,
}

struct Manager {
    screens: [Screen; NUM_SCREENS],  // les 4 écrans
    active:  usize,                  // index de l'écran actif (0..3)
}
```

`BUFFER_BYTES` vaut `80 * 25 * 2 = 4000` octets (80 colonnes × 25 lignes × 2
octets par cellule — voir étape [09 — VGA](../09-ecran-vga/README.md)).

Le `Manager` global est déclaré ligne 40 :
```rust
static mut MANAGER: Manager = Manager {
    screens: [Screen::new(); NUM_SCREENS],
    active: 0,
};
```

Comme pour `WRITER` dans `vga.rs` et `SHIFT`/`CTRL` dans `keyboard.rs`, on y
accède via `addr_of_mut!` pour éviter le lint `static_mut_refs` (ligne 48) :
```rust
fn manager() -> &'static mut Manager {
    unsafe { &mut *core::ptr::addr_of_mut!(MANAGER) }
}
```

### 2.3 `save_buffer` et `load_buffer` : la mécanique du swap

La magie des écrans virtuels repose entièrement sur deux fonctions de
[`../../src/vga.rs`](../../src/vga.rs) :

- **`save_buffer(dst)`** (ligne 299 de `vga.rs`) : lit le framebuffer matériel
  `0xB8000` octet par octet (via `read_volatile`) et le copie dans `dst`.
- **`load_buffer(src)`** (ligne 308 de `vga.rs`) : l'inverse — écrit `src`
  dans le framebuffer matériel (via `write_volatile`).

> Le `volatile` est indispensable : sans lui, le compilateur pourrait décider
> que la mémoire à `0xB8000` n'est pas "vraiment" utile et optimiser les
> lectures/écritures. `volatile` lui dit : "non, ces accès ont des effets
> matériels, ne les touche pas."

On sauvegarde aussi le **curseur** : sa position `(col, row)` est stockée dans
`Screen.col` et `Screen.row`, et restaurée avec `vga::set_cursor()` (voir
étape [09 — VGA](../09-ecran-vga/README.md) pour la mécanique CRTC).

### 2.4 `switch_to` : la bascule entre écrans

`switch_to(target)` (ligne 64 de `screens.rs`) fait la bascule complète :

```rust
pub fn switch_to(target: usize) {
    if target >= NUM_SCREENS { return; }
    let m = manager();
    if target == m.active { return; }   // déjà actif, rien à faire

    // 1. Sauvegarder l'écran sortant
    let cur = m.active;
    let (col, row) = vga::cursor();
    m.screens[cur].col = col;
    m.screens[cur].row = row;
    vga::save_buffer(&mut m.screens[cur].buffer);

    // 2. Restaurer l'écran entrant
    m.active = target;
    vga::load_buffer(&m.screens[target].buffer);
    vga::set_cursor(m.screens[target].col, m.screens[target].row);
}
```

En pratique : appuyer sur F2 appelle `switch_to(1)`. Le contenu visible
disparaît dans le buffer de l'écran 0, et le contenu de l'écran 1 apparaît
instantanément — y compris le curseur là où il était quand on avait quitté
l'écran 1.

### 2.5 L'isolation entre écrans

Chaque écran a son propre `[u8; BUFFER_BYTES]` en `.bss`. Les contenus ne se
mélangent jamais : ce qu'on tape sur l'écran 2 ne peut pas apparaître sur
l'écran 3. C'est l'équivalent "bare metal" des sessions TTY Linux.

Au démarrage (fonction `init()`, ligne 52), les buffers sont tous à zéro
(`.bss` est initialisée à zéro par le boot). L'écran 0 est rendu actif et
`vga::init()` l'efface avec le fond noir par défaut.

### 2.6 `handle_key` : router les touches

`handle_key(event)` (ligne 93) est le point d'entrée qui décide quoi faire
d'un `KeyEvent` :

```rust
pub fn handle_key(event: KeyEvent) {
    match event.key {
        // F1..F4 → bascule d'écran
        Key::Function(n) if (1..=NUM_SCREENS as u8).contains(&n) => {
            switch_to((n - 1) as usize);
        }
        // F5..F12 → ignorées (aucun écran assigné)
        Key::Function(_) => {}
        // Retour arrière → effacer la cellule précédente
        Key::Backspace => vga::backspace(),
        // Tout le reste : si c'est imprimable, l'afficher
        _ => {
            if let Some(c) = event.as_char() {
                vga::print_char(c);
                // Miroir série pour les tests headless
                unsafe { crate::outb(0x3F8, c) };
            }
        }
    }
}
```

Points notables :
- **F1 → écran 0, F2 → écran 1, …** : `switch_to((n - 1) as usize)` car les
  touches de fonction sont numérotées à partir de 1 mais les écrans à partir
  de 0.
- **Miroir série** : chaque caractère tapé est aussi envoyé sur le port COM1
  (`0x3F8`). Cela permet aux tests automatisés (qui ne peuvent pas "voir"
  l'écran) de vérifier que la saisie fonctionne.
- **`as_char()`** : rappel — cette méthode de `KeyEvent` retourne
  `Some(b'\n')` pour `Enter`, `Some(c)` pour `Char(c)`, `None` sinon.

### 2.7 La boucle principale dans `kmain`

Tout s'assemble dans [`../../src/lib.rs`](../../src/lib.rs) (lignes 101–116) :

```rust
pub extern "C" fn kmain(_multiboot_magic: u32, _multiboot_info: u32) -> ! {
    screens::init();      // initialise les 4 écrans, efface l'écran 0
    println!("42");
    serial_print("42\nKFS1_BOOT_OK\n");
    keyboard::init();     // drainer le buffer PS/2 résiduel

    loop {
        if let Some(event) = keyboard::poll() {
            screens::handle_key(event);
        }
        core::hint::spin_loop();   // hint CPU : on est dans une boucle active
    }
}
```

`core::hint::spin_loop()` est une instruction `pause` sur x86. Elle indique au
processeur qu'on est dans une boucle d'attente active (*spin loop*), ce qui
améliore les performances dans les architectures avec hyperthreading et réduit
la consommation d'énergie — sans pour autant dormir.

Pour comprendre cette boucle dans son contexte d'amorçage, voir l'étape
[07 — Boucle principale](../07-coeur-rust/README.md).

---

## En résumé

**Clavier :** `keyboard::poll()` interroge le port statut `0x64` à chaque tour
de boucle. Si le bit OBF est levé, elle lit le scancode sur `0x60`, détermine
si c'est un appui ou un relâchement, met à jour SHIFT/CTRL si besoin, puis
traduit le scancode en `KeyEvent` grâce aux tables `UNSHIFTED`/`SHIFTED`. La
décision de faire du polling (plutôt que des IRQ) est délibérée : l'IDT et le
PIC ne seront configurés qu'en KFS_2.

**Écrans virtuels :** `screens::switch_to(n)` sauvegarde le framebuffer et le
curseur de l'écran courant dans un tableau en mémoire (`Screen.buffer`), puis
restaure ceux de l'écran cible. L'écran actif est le seul qui vit dans le
vrai framebuffer VGA. `handle_key` fait le dispatch : caractères imprimables
vers `vga::print_char`, backspace vers `vga::backspace`, F1–F4 vers
`switch_to`.

---

## Pour aller plus loin

- **OSDev Wiki — PS/2 Keyboard** :
  <https://wiki.osdev.org/PS/2_Keyboard> — référence complète sur les ports,
  les commandes, les scancodes set 1/2/3 et les touches étendues (préfixe
  `0xE0`).
- **OSDev Wiki — PS/2 Controller** :
  <https://wiki.osdev.org/8042_PS/2_Controller> — le contrôleur 8042, ses
  registres de commande, d'initialisation et de test.
- **Scancode Set 1 (table complète)** :
  <https://wiki.osdev.org/Keyboard#Scan_Code_Set_1> — tous les make/break
  codes, y compris les touches étendues.
- **IRQ et PIC** : la prochaine étape logique est d'activer les interruptions
  (IRQ 1 pour le clavier) en configurant le 8259 PIC — sujet de KFS_2.
- Renvoi étape [09 — Driver VGA](../09-ecran-vga/README.md) pour `save_buffer`,
  `load_buffer`, `cursor`, `set_cursor` et la mécanique CRTC.
- Renvoi étape [07 — Boucle principale](../07-coeur-rust/README.md) pour le
  contexte de `kmain`.
