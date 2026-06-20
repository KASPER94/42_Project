# 08 — Entraînement, modèles, évaluation et bonus

> Comment entraîner des modèles en avance, lire leur progression, évaluer un
> modèle gelé sans l'altérer, et les trois bonus : longueur élevée, affichage
> riche et taille de plateau variable.

**Prérequis :**
[04 — Q-learning tabulaire](04-q-learning-tabulaire.md) ·
[05 — Exploration vs exploitation](05-exploration-exploitation.md) ·
[06 — Le réseau de neurones](06-reseau-neurones.md) ·
[07 — Architecture du code et cycle de vie](07-architecture-code.md)
**Suite :** *(fin de la documentation)*

---

## Intuition

Entraîner un agent de renforcement, c'est le laisser jouer des milliers de
parties pour qu'il accumule de l'expérience. Plus il joue, mieux il connaît
les situations et plus ses décisions s'améliorent. Mais pendant l'entraînement
l'agent explore encore (il tente parfois des actions aléatoires), ce qui peut
masquer sa vraie valeur.

Pour mesurer honnêtement ce qu'un modèle a *appris*, on le **gèle** : on coupe
toute exploration et toute mise à jour, et on le laisse jouer en mode purement
glouton. C'est la combinaison `-load … -dontlearn` : charger un fichier de
modèle, puis interdire tout apprentissage supplémentaire.

La progression est frappante. Avec seulement 10 sessions d'entraînement, le
serpent tourne en rond (longueur 4). À 1000 sessions il dépasse largement
l'objectif de longueur ≥ 10 — il atteint 31. À 5000 sessions il atteint 46,
et survit la session entière (durée = 1000 = le plafond par session).

---

## En profondeur

### Entraîner un modèle en avance

Le sujet impose que l'entraînement soit fait **à l'avance** (cela peut prendre
du temps). La commande type pour entraîner un `QTableAgent` sur `N` sessions
en mode sans affichage puis sauvegarder le résultat :

```bash
./snake -sessions N -save models/Nsess.txt -visual off
```

Le flag `-visual off` désactive le rendu pygame : pas de fenêtre, pas
d'import de pygame, la boucle tourne aussi vite que le CPU le permet.
L'entraînement headless est significativement plus rapide qu'en mode visuel.

Pour entraîner un `NNAgent` à la place :

```bash
./snake -sessions N -save models/nn_Nsess.txt -visual off -model nn
```

Quand `-load` est fourni, le champ `"type"` du fichier JSON détermine
automatiquement la classe à instancier (`make_agent` dans `cli.py`) ; `-model`
est ignoré dans ce cas.

**Déterminisme.** Toutes les exécutions utilisent la graine `DEFAULT_SEED = 42`
(fixée dans `config.py` et passée à `Environment` et aux agents). La même
commande produit exactement le même résultat à chaque fois.

### Le cap `MAX_STEPS_PER_SESSION`

Chaque partie est limitée à `MAX_STEPS_PER_SESSION = 1000` pas (constante dans
`config.py`, paramètre `max_steps` de `run_sessions`). Quand la sortie affiche
`max duration = 1000`, cela signifie que le serpent a **survécu toute la
session** sans mourir : il a appris à rester en vie indéfiniment sur le plateau.
La valeur `1000` n'est donc pas un score arbitraire mais une borne de survie.

### Évaluer un modèle sans l'altérer

Pour mesurer la vraie performance d'un modèle sans risquer de dégrader ses
poids/sa table, on le charge **gelé** :

```bash
./snake -load models/<fichier> -dontlearn -visual off -sessions 100
```

Le flag `-dontlearn` positionne `agent.learning = False` (voir
[05 — Exploration vs exploitation](05-exploration-exploitation.md)) :

- aucune action aléatoire ($\epsilon$ ignoré) — la politique est purement
  gloutonne $\pi(s) = \arg\max_a Q(s,a)$ ;
- aucune mise à jour de $Q$ (ni table, ni poids réseau) ;
- le fichier source n'est pas touché (aucun `-save` implicite).

À la fin d'un lot de 100 parties, le programme imprime :

```text
Game over, max length = X, max duration = Y
```

`X` est la longueur maximale atteinte sur toutes les parties ; `Y` est la
durée maximale (en pas). Ces deux valeurs sont les métriques de performance
de référence du projet.

**Objectif de succès.** Le sujet fixe un serpent de longueur ≥ 10 avec une
durée de vie importante. Les modèles à 1000 et 5000 sessions pulvérisent cet
objectif (31 et 46 respectivement).

### Progression des modèles

Le dossier `models/` contient des modèles pré-entraînés. Chaque fichier est
un run frais depuis zéro avec `N` sessions (pas une reprise du précédent),
ce qui permet de lire la courbe d'apprentissage réelle. Les colonnes
`Eval max length` / `Eval max duration` ci-dessous sont mesurées en chargeant
chaque modèle gelé (`-dontlearn`) sur un lot de 100 parties en 10×10 :

| Fichier | Type | Sessions | Eval max length | Eval max duration |
| --- | --- | --- | --- | --- |
| `models/1sess.txt` | qtable | 1 | 4 | 12 |
| `models/10sess.txt` | qtable | 10 | 4 | 16 |
| `models/100sess.txt` | qtable | 100 | 5 | 28 |
| `models/1000sess.txt` | qtable | 1000 | **31** | 1000 |
| `models/5000sess.txt` | qtable | 5000 | **46** | 1000 |
| `models/nn_100sess.txt` | nn | 100 | 5 | 1000 |
| `models/nn_1000sess.txt` | nn | 1000 | **38** | 1000 |
| `models/nn_5000sess.txt` | nn | 5000 | **40** | 378 |

### Comparaison qtable vs nn

Les deux agents partagent la même politique ε-greedy et les mêmes
hyperparamètres $\alpha = 0.1$, $\gamma = 0.9$, $\epsilon_{\text{start}} = 1.0
\to \epsilon_{\min} = 0.01$ (voir [04](04-q-learning-tabulaire.md) et
[05](05-exploration-exploitation.md)). Ce qui diffère, c'est la représentation
de $Q$ :

- le `QTableAgent` stocke $Q$ dans un tableau dense `(4096, 4)` — une valeur
  exacte par paire état/action, apprise d'un coup dès la première visite ;
- le `NNAgent` paramétrise $Q$ avec un MLP `12→32→4` — chaque mise à jour
  est plus coûteuse et moins précise car elle modifie des paramètres partagés
  (voir [06 — Le réseau de neurones](06-reseau-neurones.md)).

Résultat : le réseau apprend **plus lentement par session** (à 100 sessions il
plafonne à longueur 5, comme la table), mais avec suffisamment d'entraînement
il devient pleinement compétitif : **38 à 1000 sessions, 40 à 5000**. Le
réseau n'est pas inférieur par nature — il converge plus lentement.

---

## Dans le code

### Flags et orchestration

Tous les flags pertinents sont dans `cli.py:build_parser` :

| Flag | Rôle |
| --- | --- |
| `-sessions N` | Nombre de parties à jouer (entraînement ou évaluation). |
| `-save PATH` | Sauvegarder l'état après le run. |
| `-load PATH` | Charger un modèle avant le run (le champ `"type"` du JSON sélectionne l'agent). |
| `-visual on\|off` | Activer/désactiver l'affichage pygame. `off` = headless. |
| `-dontlearn` | Geler l'agent : aucune exploration, aucune mise à jour. |
| `-model qtable\|nn` | Type d'agent pour un run sans `-load`. |
| `-board-size N` | Taille du plateau en cellules (bonus). |
| `-menu` | Ouvrir le lobby graphique (bonus) ; aussi ouvert si aucun argument. |

La fonction `cli.py:_run_from_args` assemble `Environment`, `Interpreter` et
l'agent, positionne `agent.learning = False` si `-dontlearn`, puis appelle
`game.py:run_sessions`. La graine `DEFAULT_SEED = 42` est passée à la
construction de `Environment` et des agents.

### Impression des résultats

`game.py:run_sessions` maintient `max_length` et `max_duration` sur l'ensemble
des sessions et imprime à la fin :

```python
print("Game over, max length = {0}, max duration = {1}".format(max_length, max_duration))
```

La constante `MAX_STEPS_PER_SESSION` (importée de `config.py`) est passée comme
`max_steps` à `run_sessions` et testée dans `_run_one_game` :

```python
if result.done or duration >= max_steps:
    return best_length, duration, False
```

### Bonus 1 — Longueur élevée

Aucun code spécifique : la longueur mesurée est celle du serpent à l'issue de
chaque partie, calculée dans `_run_one_game` via `result.length`. Le `QTableAgent`
entraîné sur 5000 sessions atteint la longueur **46** en évaluation gelée,
dépassant largement le palier 35 du sujet.

### Bonus 2 — Affichage riche : lobby + panneau de stats + contrôles

Lancer sans arguments (ou avec `-menu`) ouvre le lobby graphique de
configuration :

```bash
./snake          # ouvre le lobby
./snake -menu    # idem
```

Le lobby (`menu.py:Lobby`, `menu.py:run_lobby`) permet de régler sessions,
vitesse, taille de plateau, modèle à charger, type d'agent et mode gelé avec
la souris. Les widgets (`Button`, `Stepper`, `Cycler`, `Toggle` dans `menu.py`)
produisent un objet `LobbyConfig` transmis à `_run_from_lobby` dans `cli.py`,
qui le mappe sur le même chemin d'exécution que les flags CLI.

Pendant la partie, le panneau latéral droit (implémenté dans
`visualizer.py:Visualizer._draw_panel` / `_panel_lines`) affiche en direct :
session `i/N`, longueur courante, longueur max, durée, récompense totale,
valeur d'$\epsilon$ (ou `frozen` si gelé) et vitesse. Les contrôles clavier
sont gérés dans `visualizer.py:Visualizer.process_events` et
`_handle_control_key` : **Espace** pause/reprise, **↑/↓** vitesse, **→**
avance d'un pas, **Esc** quitte.

### Bonus 3 — Taille de plateau variable, même modèle

```bash
./snake -load models/5000sess.txt -visual on -board-size 15
./snake -load models/5000sess.txt -dontlearn -visual off -sessions 100 -board-size 20
```

La propriété cross-size repose sur l'encodage de l'état : les 12 bits décrivent
la vision en ligne de mire dans les quatre directions (danger adjacent, pomme
verte en ligne, pomme rouge en ligne), sans aucune coordonnée absolue ni
dimension de plateau. Un modèle entraîné sur 10×10 joue donc **sans
modification** sur n'importe quelle taille (voir
[02 — L'état : la vision du serpent](02-etat-vision.md) pour la dérivation de
l'encodage).

Performance mesurée avec le même `models/5000sess.txt` gelé, 100 parties :

| Plateau | Eval max length | Eval max duration |
| --- | --- | --- |
| 10×10 | 46 | 1000 |
| 15×15 | 51 | 1000 |
| 20×20 | 52 | 1000 |

La longueur *augmente* sur les grands plateaux car il y a davantage d'espace
pour croître avant d'atteindre le plafond de survie. Cette propriété est
verrouillée par des tests automatisés dans `tests/test_bonus.py`.

---

## À retenir

- L'entraînement se fait **en avance**, en headless (`-visual off`) pour aller
  vite ; la graine `42` garantit la reproductibilité.
- Pour évaluer sans altérer : `-load <modèle> -dontlearn` — la politique devient
  purement gloutonne, aucune mise à jour de $Q$ n'est effectuée.
- `max duration = 1000` signifie que le serpent a survécu tout le plafond
  `MAX_STEPS_PER_SESSION` : il a appris à rester en vie indéfiniment.
- La progression qtable 1 → 10 → 100 → 1000 → 5000 sessions montre des
  longueurs 4 → 4 → 5 → **31** → **46** : le saut se produit entre 100 et 1000
  sessions, quand $\epsilon$ a suffisamment décru pour que la politique
  gloutonne domine.
- Le `NNAgent` converge plus lentement (longueur 5 à 100 sessions) mais devient
  compétitif avec assez d'entraînement (**38** à 1000, **40** à 5000).
- Les trois bonus sont implémentés : longueur élevée (46, bien au-delà du palier
  35), lobby + panneau de stats en direct, et taille de plateau variable avec le
  même modèle (propriété garantie par l'encodage 12 bits sans coordonnées).

---

## Liens

- Prérequis :
  [04 — Q-learning tabulaire : équation de Bellman, mise à jour, α et γ](04-q-learning-tabulaire.md)
- Prérequis :
  [05 — Exploration vs exploitation : ε-greedy et la décroissance](05-exploration-exploitation.md)
- Prérequis :
  [06 — Le réseau de neurones : MLP, features, TD semi-gradient, rétropropagation](06-reseau-neurones.md)
- Prérequis :
  [07 — Architecture du code et cycle de vie](07-architecture-code.md)
- Voir aussi :
  [02 — L'état : la vision du serpent et l'encodage 12 bits](02-etat-vision.md)
  (encodage qui rend possible le cross-size)
- Référence projet : [README du dépôt](../README.md) (sections Models, Bonus,
  Defense checklist)
