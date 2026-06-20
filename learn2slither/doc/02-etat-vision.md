# 02 — L'état : la vision du serpent et l'encodage 12 bits (+ règle −42)

> Ce que le serpent « voit », comment cette vision est compressée en un entier 12 bits $s \in [0,\,4095]$, et pourquoi l'agent ne reçoit rien d'autre (règle −42).

**Prérequis :** [01 — Vue d'ensemble : le problème RL et la boucle agent–environnement](01-vue-ensemble-rl.md) · **Suite :** [03 — Les récompenses et le reward shaping](03-recompenses.md)

---

## Intuition

Imaginez-vous dans un couloir sans mémoire et les yeux bandés, sauf quatre lampes de poche fixées à votre casque — une vers l'avant, une vers l'arrière, une à gauche, une à droite. Chaque lampe éclaire jusqu'au mur suivant. Vous pouvez voir s'il y a quelque chose de dangereux juste devant, si une bonne pomme est dans l'axe et si une mauvaise pomme est en vue. C'est tout. C'est exactement ce que voit le serpent dans Learn2Slither.

La tête émet quatre **rayons** (UP, LEFT, DOWN, RIGHT). Chaque rayon parcourt le plateau dans sa direction jusqu'au premier mur. Trois questions sont posées à chaque rayon :

1. **Danger** — la case adjacente (la première de la direction) est-elle un mur ou un segment de corps ?
2. **Pomme verte en ligne** — y a-t-il un `G` quelque part dans ce rayon ?
3. **Pomme rouge en ligne** — y a-t-il un `R` quelque part dans ce rayon ?

Trois réponses booléennes × 4 directions = 12 bits, soit $2^{12} = 4096$ états possibles. L'agent reçoit cet entier 12 bits comme état $s$. Il ne sait rien d'autre : pas de coordonnées, pas de position des pommes hors ligne de vue, pas le plateau complet.

### Les symboles

| Symbole | Signification |
|---------|--------------|
| `W` | Mur (wall) |
| `H` | Tête du serpent |
| `S` | Segment de corps |
| `G` | Pomme verte |
| `R` | Pomme rouge |
| `0` | Case vide |

### La croix de vision en terminal

Avant chaque décision, `render_vision` affiche une croix ASCII centrée sur la tête. Seule la colonne de la tête est dessinée verticalement, et seule la ligne de la tête est dessinée en entier. Cela permet de vérifier d'un coup d'œil ce que le serpent perçoit, sans afficher le plateau complet.

```text
     W
     0
     G
     0
W0S0H0000W
     R
     0
     W
```

*Lecture : la tête `H` est en position (ligne 4, col 5) sur un plateau 8×8 (murs `W` non joués). Vers le haut on voit une pomme verte `G`, vers le bas une pomme rouge `R`.*

---

## En profondeur

### L'ordre canonique des directions

`contracts.py:DIRECTION_ORDER` fixe l'ordre dans lequel les directions sont traitées :

```
DIRECTION_ORDER = [UP (i=0), LEFT (i=1), DOWN (i=2), RIGHT (i=3)]
```

Cet ordre correspond exactement aux valeurs entières de l'énumération `Action` (`UP=0, LEFT=1, DOWN=2, RIGHT=3`). État et action partagent ainsi le même modèle mental.

### Les 3 bits d'une direction

Pour chaque direction d'indice $i$, la méthode `_scan_ray` retourne un entier à 3 bits :

| Bit | Constante | Signification |
|-----|-----------|--------------|
| 0 | `_BIT_DANGER` | case adjacente = mur ou corps |
| 1 | `_BIT_GREEN`  | au moins un `G` dans le rayon |
| 2 | `_BIT_RED`    | au moins un `R` dans le rayon |

La définition de **danger** est strictement locale : seule la case *adjacente* à la tête (la première du rayon) déclenche le bit danger. Un corps loin dans le rayon ne le déclenche pas — seul `SYM_WALL` et `SYM_BODY` à distance 1 comptent.

### La formule d'encodage

Les bits de chaque direction sont décalés à l'offset $3i$ et accumulés par OR :

$$s = \sum_{i=0}^{3} b_i \cdot 2^{3i}$$

où $b_i \in [0,7]$ est l'entier 3 bits de la $i$-ème direction. En Python :

```python
state = 0
for i, action in enumerate(DIRECTION_ORDER):
    bits = self._scan_ray(env, head_row, head_col, action.delta)
    state |= bits << (3 * i)
```

Le résultat $s$ est toujours dans $[0, 4095]$ ($2^{12} - 1$), soit `N_STATES = 4096` états discrets.

**Extraction d'un bit** : le bit de rang $k$ vaut $(s \gg k)\ \&\ 1$.

### Exemple concret d'encodage

Considérons la situation suivante sur un plateau 8×8 (la tête est en (4, 3)) :

```text
     W
     0
     G
     0
W0S0H0000W
     R
     0
     W
```

Balayage rayon par rayon :

| Direction | $i$ | Case adjacente | Reste du rayon | danger | green | red | $b_i$ | $b_i \cdot 2^{3i}$ |
|-----------|-----|----------------|----------------|--------|-------|-----|-------|---------------------|
| UP        | 0   | `0` (vide)     | `G` en ligne   | 0      | 1     | 0   | `010` = **2** | $2 \times 2^0 = 2$  |
| LEFT      | 1   | `S` (corps)    | —              | 1      | 0     | 0   | `001` = **1** | $1 \times 2^3 = 8$  |
| DOWN      | 2   | `0` (vide)     | `R` en ligne   | 0      | 0     | 1   | `100` = **4** | $4 \times 2^6 = 256$ |
| RIGHT     | 3   | `0` (vide)     | rien           | 0      | 0     | 0   | `000` = **0** | $0 \times 2^9 = 0$   |

$$s = 2 + 8 + 256 + 0 = \mathbf{266}$$

L'agent reçoit l'entier `266`. Il ne sait pas où se trouvent les pommes sur le plateau, ni la taille du plateau, ni les coordonnées de la tête : seulement ce que les quatre rayons révèlent.

### Indépendance vis-à-vis de la taille du plateau

L'encodage ne contient aucune coordonnée absolue. Seule la présence/absence de symboles dans les rayons est codée. Un même état $s = 266$ représente la même situation (corps à gauche, pomme verte au-dessus, pomme rouge en dessous) quel que soit le plateau : 10×10, 15×15 ou 20×20. C'est précisément ce qui rend possible le bonus « taille de plateau variable » : un modèle entraîné sur 10×10 peut être évalué sur un plateau plus grand sans recompiler ni ré-entraîner. La démonstration chiffrée de cette propriété est en [étape 08](08-entrainement-evaluation-bonus.md).

### La règle −42 : information visible uniquement

Le sujet impose une contrainte forte : **l'agent ne peut recevoir que l'information visible par le serpent**. Violer cette règle entraîne une pénalité de −42 points. Concrètement, cela interdit de passer à l'agent :

- les coordonnées de la tête ;
- la position des pommes hors ligne de vue ;
- le plateau complet ou une représentation matricielle de celui-ci ;
- toute information qui ne soit pas dérivable des 4 rayons.

Dans le code, cette contrainte est architecturale : l'`Interpreter` est le **seul** composant qui lit le plateau, et il ne transmet à l'agent que l'entier $s$ (via `get_state`) et le scalaire $r$ (via `get_reward`). Ni l'`Environment`, ni le plateau brut n'atteignent jamais directement l'agent. La conception `Environment → Interpreter → Agent` documentée dans `contracts.py` est la garantie structurelle de cette règle.

---

## Dans le code

### `interpreter.py:Interpreter.get_state`

Point d'entrée principal. Récupère `env.head` (row, col), itère sur `DIRECTION_ORDER`, appelle `_scan_ray` pour chaque direction et accumule les bits à l'offset `3 * i`.

### `interpreter.py:Interpreter._scan_ray`

- Lit `env.cell_symbol(row, col)` à la case adjacente (`head + delta`).
- Si cette première case est `SYM_WALL` ou `SYM_BODY` : pose `_BIT_DANGER`.
- Parcourt ensuite le rayon case par case jusqu'au mur (`SYM_WALL`) : pose `_BIT_GREEN` ou `_BIT_RED` à chaque pomme rencontrée.
- Retourne les 3 bits combinés.

```python
_BIT_DANGER = 0
_BIT_GREEN  = 1
_BIT_RED    = 2
```

### `interpreter.py:Interpreter.render_vision`

Construit la croix ASCII pour le terminal. Dessine toute la colonne de la tête (appels à `_column_symbol`) et toute la ligne de la tête (appel à `_row_line`). Sert uniquement au débogage et à la transparence ; n'est pas utilisé pour produire $s$.

### `config.py`

| Constante | Valeur | Rôle |
|-----------|--------|------|
| `STATE_ENCODING_VERSION` | `"v1"` | Version de l'encodage, stockée dans les fichiers modèles |
| `N_STATES` | `1 << 12` = **4096** | Taille de la Q-table (axe états) |
| `SYM_WALL`, `SYM_HEAD`, `SYM_BODY`, `SYM_GREEN`, `SYM_RED`, `SYM_EMPTY` | `"W" "H" "S" "G" "R" "0"` | Symboles canoniques utilisés par `cell_symbol` et `_scan_ray` |

### `contracts.py:DIRECTION_ORDER` et `Action.delta`

`DIRECTION_ORDER` est la liste `[UP, LEFT, DOWN, RIGHT]` qui donne l'ordre de packing. `Action.delta` retourne le `(d_row, d_col)` correspondant, utilisé par `_scan_ray` pour progresser dans le rayon.

### `environment.py:Environment.cell_symbol`

Fournit le symbole de n'importe quelle case (y compris hors-plateau, qui retourne `SYM_WALL`). C'est la seule interface par laquelle `Interpreter` lit le plateau.

---

## À retenir

- Le serpent ne « voit » que 4 rayons depuis sa tête : 3 questions booléennes × 4 directions = **12 bits**, soit 4096 états discrets.
- **Danger** = case *adjacente* est un mur ou un corps (pas l'ensemble du rayon).
- L'encodage v1 est **board-size-independent** : aucune coordonnée absolue n'entre dans $s$, ce qui rend les modèles transférables entre tailles de plateau.
- L'`Interpreter` est le **seul** composant autorisé à lire le plateau et à produire $s$ — c'est la garantie architecturale de la règle −42.
- La **récompense** $r$ est aussi calculée par l'`Interpreter` (via `get_reward`) mais son usage par l'agent est traité en [étape 03](03-recompenses.md) et [étape 04](04-q-learning-tabulaire.md).
- Comment $s$ alimente la sélection d'action et la mise à jour de $Q$ → [étapes 04–05](04-q-learning-tabulaire.md) ; son expansion en vecteur de features pour le réseau → [étape 06](06-reseau-neurones.md).

---

## Liens

- Prérequis : [01 — Vue d'ensemble : le problème RL et la boucle agent–environnement](01-vue-ensemble-rl.md)
- Suite : [03 — Les récompenses et le reward shaping](03-recompenses.md)
- Voir aussi :
  - [04 — Q-learning tabulaire : Bellman, mise à jour, α et γ](04-q-learning-tabulaire.md) — comment $s$ est utilisé pour choisir et mettre à jour une action
  - [05 — Exploration vs exploitation : ε-greedy et décroissance](05-exploration-exploitation.md) — la politique qui exploite $s$
  - [06 — Le réseau de neurones : MLP, features, TD semi-gradient](06-reseau-neurones.md) — expansion $s \to \phi(s) \in \{0,1\}^{12}$
  - [08 — Entraînement, modèles, évaluation et bonus](08-entrainement-evaluation-bonus.md) — démonstration du bonus taille variable
