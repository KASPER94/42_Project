# 07 — Architecture du code et cycle de vie (Environment → Interpreter → Agent, CLI, boucle, save/load)

> Vue d'ensemble des modules, de leurs contrats d'interface, de la boucle de jeu pas à pas, du wiring CLI et du format de sauvegarde/chargement des modèles.

**Prérequis :** [01 — Vue d'ensemble : le problème RL et la boucle agent–environnement](01-vue-ensemble-rl.md) à [06 — Le réseau de neurones : MLP, features, TD semi-gradient](06-reseau-neurones.md) · **Suite :** [08 — Entraînement, modèles, évaluation et bonus](08-entrainement-evaluation-bonus.md)

---

## Intuition

Imaginez une cuisine organisée en trois postes indépendants : un cuisinier qui gère le fourneau (l'Environnement), un interprète qui goûte les plats et les note (l'Interpréteur), et un chef qui décide des prochaines actions (l'Agent). Les trois n'ont pas besoin de se connaître personnellement — ils communiquent uniquement via un menu standardisé : le contrat défini dans `contracts.py`.

Cette séparation n'est pas cosmétique. Le sujet **impose** que l'agent ne voie jamais le plateau brut, seulement la vision que l'interpréteur lui transmet (règle −42, détaillée en [étape 02](02-etat-vision.md)). En rendant cette frontière explicite dans le code via des `Protocol` Python, chaque composant peut être testé, remplacé ou réimplémenté sans toucher aux autres.

La boucle de jeu (`game.py`) est l'orchestrateur léger : elle ne contient ni règles de jeu ni maths d'apprentissage — elle câble juste les trois composants en suivant le contrat.

---

## En profondeur

### La carte des modules

```
┌─────────────────────────────────────────────────────────────────┐
│                         cli.py                                  │
│  build_parser ─► make_agent ─► _run_from_args ─► run_sessions  │
└───────────────────────────┬─────────────────────────────────────┘
                            │ instancie et passe
         ┌──────────────────┼──────────────────────┐
         ▼                  ▼                       ▼
  environment.py      interpreter.py         agent.py / nn_agent.py
  Environment         Interpreter            QTableAgent / NNAgent
  (EnvironmentP)      (InterpreterP)         (AgentP)
         │                  │                       │
         └──────────────────┴───────────────────────┘
                            │
                     contracts.py
                  Action · Event · StepResult
                  EnvironmentP · InterpreterP · AgentP

  [optionnel]  visualizer.py   menu.py
               Visualizer      Lobby / LobbyConfig
               (I/O pur)       (lobby de configuration)
```

**Règle d'or :** aucun module concret ne dépend d'un autre module concret. L'Environnement n'importe jamais l'Agent ; l'Agent n'importe jamais l'Environnement. Seul `contracts.py` est importé par tous.

### `contracts.py` — l'unique point de couplage

`contracts.py` exporte trois types de données et trois `Protocol` :

| Symbole | Nature | Rôle |
| --- | --- | --- |
| `Action` | `IntEnum` (UP=0, LEFT=1, DOWN=2, RIGHT=3) | les 4 mouvements possibles ; valeur = index dans le vecteur Q |
| `Event` | `Enum` (MOVE, EAT_GREEN, EAT_RED, DEATH) | ce qui s'est passé lors d'un pas |
| `StepResult` | `dataclass` frozen (`event`, `done`, `length`) | résultat renvoyé par `Environment.step` |
| `EnvironmentP` | `Protocol` runtime-checkable | interface du monde (`reset`, `step`, `head`, `length`, `cell_symbol`) |
| `InterpreterP` | `Protocol` runtime-checkable | interface de traduction (`get_state`, `get_reward`, `render_vision`) |
| `AgentP` | `Protocol` runtime-checkable | interface du cerveau (`choose_action`, `learn`, `end_session`, `save`, `load`, `learning`) |

La signature d'`AgentP.learn` résume à elle seule tout le MDP :

```python
def learn(self, state: int, action: Action, reward: float,
          next_state: int, done: bool) -> None: ...
```

Cinq scalaires — $(s, a, r, s', \text{done})$ — constituent la transition minimale dont un agent a besoin pour mettre à jour sa fonction $Q$. Comment il l'exploite (table ou réseau) est son affaire interne, décrite aux [étapes 04](04-q-learning-tabulaire.md) et [06](06-reseau-neurones.md).

### Le cycle de vie d'un pas dans `game._run_one_game`

Voici la séquence exacte exécutée à chaque pas $t$ à l'intérieur de `game.py:_run_one_game` :

```
1. env.reset()                         ← début de session (une seule fois)
2. state = interpreter.get_state(env)  ← encoder la vision initiale → s₀

   ┌── boucle while True ──────────────────────────────────────────┐
   │                                                               │
   │  3. action = agent.choose_action(state)   ε-greedy → aₜ      │
   │  4. result = env.step(action)             transition → Sₜ     │
   │     └── result.event, result.done, result.length             │
   │  5. reward = interpreter.get_reward(result)   → rₜ           │
   │  6. next_state = interpreter.get_state(env)   → sₜ₊₁         │
   │     (si result.done : next_state = state, pas de scan)       │
   │  7. agent.learn(state, action, reward,                        │
   │                 next_state, result.done)   mise à jour Q      │
   │  8. state = next_state                    avancer d'un pas    │
   │  9. _present_step(...)  affichage / cadence / gate step       │
   │     └── retourne False si l'utilisateur demande à quitter     │
   │ 10. if result.done or duration >= max_steps : sortie          │
   └───────────────────────────────────────────────────────────────┘

11. agent.end_session()                ← décroître ε, fin de partie
```

Quelques détails importants :

- **`next_state` sur terminal** : si `result.done` vaut `True`, le serpent est mort et il n'y a pas d'état suivant significatif. `_run_one_game` réutilise `state` comme `next_state` et passe `done=True` à `learn`, ce qui fait que la cible TD se réduit à $r$ (pas de terme bootstrap). Voir [étape 04](04-q-learning-tabulaire.md).
- **`MAX_STEPS_PER_SESSION`** (`config.py`, valeur `1000`) : cap dur par session pour éviter qu'un serpent qui tourne en rond bloque l'entraînement. Quand `duration >= max_steps`, la partie se termine proprement sans pénalité de mort.
- **`agent.end_session()`** est appelé dans `run_sessions` **après** chaque partie, même si `quit_requested` est `True` — la décroissance d'$\epsilon$ est ainsi toujours cohérente. Voir [étape 05](05-exploration-exploitation.md).
- **Mode gelé** (`agent.learning = False`) : `learn` devient un no-op et `choose_action` est purement glouton. La boucle s'exécute de façon identique — la différence est entièrement encapsulée dans l'agent.

### La CLI — `cli.py`

#### Flags disponibles

| Flag | Type | Défaut | Effet |
| --- | --- | --- | --- |
| `-sessions N` | `int` | `1` | nombre de parties à jouer |
| `-save PATH` | `str` | `None` | sauvegarder le modèle à la fin (même après `KeyboardInterrupt`) |
| `-load PATH` | `str` | `None` | charger un modèle existant avant de jouer |
| `-visual on\|off` | choix | `on` | activer/désactiver l'affichage pygame |
| `-dontlearn` | flag | `False` | geler l'agent (exploitation pure, aucune mise à jour) |
| `-step-by-step` | flag | `False` | avancer d'un pas par saisie utilisateur |
| `-speed FPS` | `int` | `DEFAULT_FPS` (10) | vitesse d'affichage en frames/s |
| `-board-size N` | `int` | `BOARD_SIZE` (10) | taille du plateau (bonus taille variable) |
| `-model qtable\|nn` | choix | `qtable` | type d'agent pour un run sans `-load` |
| `-menu` | flag | `False` | ouvrir le lobby graphique de configuration (bonus) |

#### Wiring dans `_run_from_args`

`cli.py:_run_from_args` assemble les trois composants et lance la boucle :

```python
env         = Environment(size=args.board_size, seed=DEFAULT_SEED)
interpreter = Interpreter()
agent       = make_agent(args)            # QTableAgent ou NNAgent
if args.dontlearn:
    agent.learning = False
visualizer  = _build_visualizer(args)     # None si -visual off
run_sessions(env, interpreter, agent, sessions=..., visualizer=..., ...)
```

La gestion d'erreur est volontairement simple : un `KeyboardInterrupt` est intercepté et la clause `finally` garantit que `-save` est toujours honoré.

#### Détection automatique du type avec `make_agent`

`cli.py:make_agent` lit le champ `"type"` du fichier JSON pour déterminer quelle classe instancier, **indépendamment de `-model`** :

```python
def make_agent(args):
    if args.load:
        agent = _agent_for_type(_model_type(args.load))  # lit "type" dans le JSON
        agent.load(args.load)
        return agent
    return _agent_for_type(args.model)                   # qtable ou nn
```

`cli.py:_model_type` fait un `json.load` minimal sur le fichier et extrait `payload["type"]`. Cela évite de devoir préciser `-model nn` quand on recharge un modèle réseau.

#### Import paresseux de pygame

`cli.py:_build_visualizer` n'importe `Visualizer` (et donc pygame) que si `-visual on` est demandé. Un entraînement headless (`-visual off`) ne touche jamais à pygame, même si la bibliothèque n'est pas installée.

---

## Dans le code

### Sauvegarde et chargement — le format JSON-dans-`.txt`

Les deux agents sérialisent leur état dans un fichier JSON renommé en `.txt` par convention. Le champ `"type"` en tête est la clé qui permet le round-trip automatique via `make_agent`.

#### `QTableAgent` (`agent.py:QTableAgent.save` / `load`)

Seules les **lignes non nulles** de la Q-table sont stockées (la table fait 4 096 × 4 `float32` ; la majorité des états reste à zéro en début d'entraînement). Le schéma :

```json
{
  "type": "qtable",
  "encoding": "v1",
  "alpha": 0.1,
  "gamma": 0.9,
  "epsilon": 0.42,
  "q": {
    "17":  [1.2, -0.5, 0.0, 3.1],
    "305": [0.0,  2.8, 0.0, 0.0]
  }
}
```

- Clés de `"q"` : index d'état (entier sérialisé en chaîne).
- Valeurs : liste de 4 `float` dans l'ordre `Action` (UP, LEFT, DOWN, RIGHT).
- Hyperparamètres (`alpha`, `gamma`, `epsilon`) restaurés à l'identique.
- Au chargement : table remise à zéro, puis les lignes présentes sont remplies — le round-trip est exact à la précision `float32` près.

#### `NNAgent` (`nn_agent.py:NNAgent.save` / `load`)

Les quatre tenseurs de poids sont stockés en listes Python imbriquées (`.tolist()`). Le schéma :

```json
{
  "type": "nn",
  "encoding": "v1",
  "hidden": 32,
  "epsilon": 0.42,
  "weights": {
    "w1": [[...], ...],
    "b1": [...],
    "w2": [[...], ...],
    "b2": [...]
  }
}
```

- `"hidden"` : taille de la couche cachée (permet de recharger un modèle entraîné avec une valeur différente de `NN_HIDDEN_SIZE`).
- `"weights"` : `w1` de forme `(12, hidden)`, `b1` de forme `(hidden,)`, `w2` de forme `(hidden, 4)`, `b2` de forme `(4,)`.
- `gamma` et `lr` ne sont pas persistés : ils sont réinitialisés depuis `config.py` au chargement (seuls l'état appris — les poids — et `epsilon` sont restaurés).
- Le round-trip est exact à la précision `float32` près via `np.asarray(..., dtype=np.float32)`.

### L'affichage — `visualizer.py` et `menu.py` (couche optionnelle)

`visualizer.py:Visualizer` est une couche d'I/O pure : elle ne lit que les accesseurs de `EnvironmentP` (jamais l'Agent ni l'Interpréteur) et affiche le plateau pygame plus un panneau de statistiques en direct. `menu.py` fournit le lobby de configuration graphique (`Lobby`, `LobbyConfig`, widgets `Button`/`Stepper`/`Cycler`/`Toggle`) qui se substitue à la CLI quand l'application est lancée sans arguments. Ces deux composants sont décrits en détail à l'[étape 08](08-entrainement-evaluation-bonus.md).

---

## À retenir

- **`contracts.py` est l'unique liant** : Environnement, Interpréteur et Agent ne se connaissent qu'à travers les `Protocol` et `dataclass` de ce fichier. Aucune dépendance croisée entre classes concrètes.
- **La boucle `_run_one_game`** suit toujours la même séquence : `reset` → `get_state` → (`choose_action` → `step` → `get_reward` → `get_state` → `learn`) × $t$ → `end_session`.
- **`agent.learning`** est l'unique interrupteur entre mode entraînement et mode évaluation ; la boucle est identique dans les deux cas.
- **Le champ `"type"` dans le JSON** permet à `make_agent` de reconstruire le bon agent sans ambiguïté, qu'il s'agisse d'une Q-table (`"qtable"`) ou d'un réseau (`"nn"`).
- **L'import de pygame est paresseux** : un entraînement headless (`-visual off`) ne dépend jamais de pygame, même pour l'import.
- **`MAX_STEPS_PER_SESSION = 1000`** protège l'entraînement contre les boucles infinies ; `-save` est toujours honoré, même en cas de `KeyboardInterrupt`.

---

## Liens

- Prérequis : [01 — Vue d'ensemble : le problème RL et la boucle agent–environnement](01-vue-ensemble-rl.md)
- Prérequis : [02 — L'état : la vision du serpent et l'encodage 12 bits](02-etat-vision.md)
- Prérequis : [03 — Les récompenses et le reward shaping](03-recompenses.md)
- Prérequis : [04 — Q-learning tabulaire : équation de Bellman, mise à jour, α et γ](04-q-learning-tabulaire.md)
- Prérequis : [05 — Exploration vs exploitation : ε-greedy et la décroissance](05-exploration-exploitation.md)
- Prérequis : [06 — Le réseau de neurones : MLP, features, TD semi-gradient](06-reseau-neurones.md)
- Suite : [08 — Entraînement, modèles, évaluation et bonus](08-entrainement-evaluation-bonus.md)
- Voir aussi : [02 — L'état : la vision du serpent](02-etat-vision.md) (encodage 12 bits utilisé par `get_state`)
- Voir aussi : [04 — Q-learning tabulaire](04-q-learning-tabulaire.md) (mécanique de `learn` pour `QTableAgent`)
- Voir aussi : [06 — Le réseau de neurones](06-reseau-neurones.md) (mécanique de `learn` pour `NNAgent`)
- Voir aussi : [08 — Entraînement, modèles, évaluation et bonus](08-entrainement-evaluation-bonus.md) (détail fonctionnel du visualiseur et du lobby)
