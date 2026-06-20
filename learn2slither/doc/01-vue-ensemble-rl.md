# 01 — Vue d'ensemble : le problème RL et la boucle agent–environnement

> Ce qu'est le RL, la boucle `Environment → Interpreter → Agent` et le cadre MDP appliqués à Learn2Slither.

**Prérequis :** aucun (point d'entrée). · **Suite :** [02 — L'état : la vision du serpent et l'encodage 12 bits](02-etat-vision.md)

---

## Intuition

Learn2Slither est un jeu Snake piloté par **apprentissage par renforcement** : un serpent se déplace sur un plateau 10×10 et son comportement est contrôlé par un **agent** qui apprend **par essai-erreur** à faire grandir le serpent jusqu'à une longueur d'au moins 10 cellules, tout en restant en vie le plus longtemps possible.

Il n'y a pas de données étiquetées, pas de réponse « correcte » fournie à l'avance. L'agent explore, tente des actions, reçoit un signal de **récompense** positif ou négatif, et ajuste progressivement son comportement pour maximiser les gains futurs. Après quelques centaines à quelques milliers de parties d'entraînement, le serpent apprend à éviter les murs, à manger les pommes vertes et à fuir les pommes rouges — uniquement grâce à ces retours.

La structure du projet est volontairement découpée en **trois rôles distincts** :

```
        +----------------------- ENVIRONMENT -----------------------+
        |                                                            |
   action A_t                                                   state S_{t+1}
        |                                                            |
        v                                                            |
      AGENT  <----- reward R_t / state S_t ----  INTERPRETER  <------+
        |  (Q-table / Q-function chooses action by Q-values)
        +----> action A_t back to the environment
```

- L'**Environnement** (`Environment`) est le monde : le plateau, le serpent, les pommes et les règles du jeu. Il ne sait rien d'apprentissage.
- L'**Interpréteur** (`Interpreter`) est l'intermédiaire : il traduit le plateau en une observation ($s$) et chaque issue en une récompense ($r$). C'est le seul composant autorisé à « lire » le plateau pour l'agent.
- L'**Agent** (`Agent`) est le cerveau Q-learning : il reçoit l'état $s$, choisit une action $a$, et met à jour sa connaissance au fil des transitions.

---

## En profondeur

### Le cadre formel : le Processus de Décision Markovien (MDP)

L'apprentissage par renforcement repose sur le formalisme du **Processus de Décision Markovien (MDP)**, défini par le tuple :

$$\mathcal{M} = (S,\ A,\ P,\ R,\ \gamma)$$

| Composante | Symbole | Dans Learn2Slither |
| --- | --- | --- |
| Espace d'états | $S$ | Les 4096 identifiants de vision ($s \in [0, 4095]$, encodage 12 bits) |
| Espace d'actions | $A$ | Les 4 mouvements : `Action` ∈ {UP=0, LEFT=1, DOWN=2, RIGHT=3} |
| Fonction de transition | $P(s' \mid s, a)$ | Les règles de déplacement et de collision de `Environment` |
| Fonction de récompense | $R(s, a)$ | Le scalaire renvoyé par `Interpreter.get_reward` |
| Facteur d'actualisation | $\gamma$ | `GAMMA = 0.9` |

La **propriété de Markov** signifie que l'état $s_t$ contient toute l'information nécessaire pour décider : la distribution de l'état suivant $s_{t+1}$ ne dépend que de $s_t$ et de $a_t$, pas de l'historique. Dans ce projet, l'état est la vision 12 bits de la tête — une observation locale qui satisfait cette propriété (le détail de l'encodage est décrit en [étape 02](02-etat-vision.md)).

### La boucle agent–environnement

À chaque **pas** $t$, la séquence est :

1. L'`Interpreter` lit le plateau et produit l'état $s_t$.
2. L'`Agent` observe $s_t$ et choisit l'action $a_t$ selon sa **politique** $\pi(s_t)$.
3. L'`Environment` exécute $a_t$ et renvoie un `StepResult` (événement + `done` + longueur).
4. L'`Interpreter` transforme le `StepResult` en récompense scalaire $r_t$.
5. L'`Interpreter` lit de nouveau le plateau pour produire $s_{t+1}$.
6. L'`Agent` appelle `learn(s_t, a_t, r_t, s_{t+1}, done)` pour mettre à jour sa fonction $Q$.

La répétition de cette boucle constitue un **épisode** (ou session). Un épisode se termine lorsque le serpent meurt (collision mur/corps ou longueur nulle) ou que le nombre de pas dépasse `MAX_STEPS_PER_SESSION`.

### Le retour actualisé

L'objectif de l'agent est de maximiser la somme des récompenses futures pondérées par $\gamma$ :

$$G_t = \sum_{k \ge 0} \gamma^k\, r_{t+k}$$

Le facteur $\gamma \in [0, 1]$ contrôle l'horizon temporel : à $\gamma = 0.9$, une récompense reçue dans 10 pas ne vaut que $0.9^{10} \approx 0{,}35$ fois une récompense immédiate. Cela pousse l'agent à préférer les gains rapides tout en valorisant quand même le futur.

### Pourquoi trois modules séparés ?

Le découpage `Environment / Interpreter / Agent` n'est pas décoratif. Il découle d'une contrainte formelle : l'agent ne doit accéder au plateau **que** via ce que l'Interpréteur lui transmet — jamais directement. Cette règle (la **règle −42** dans le sujet) garantit que l'agent apprend uniquement à partir d'observations légales, indépendantes de la taille du plateau.

Le couplage entre les trois modules passe exclusivement par `contracts.py` : les Protocols `EnvironmentP`, `InterpreterP`, `AgentP`, les types `Action`, `Event` et `StepResult`. Aucune classe concrète n'importe une autre classe concrète directement. Chaque composant peut donc être remplacé ou testé indépendamment.

---

## Dans le code

### `contracts.py` — les types partagés

Tout le couplage entre modules est défini dans `contracts.py` :

- `contracts.py:Action` — l'énumération des 4 mouvements (`UP=0`, `LEFT=1`, `DOWN=2`, `RIGHT=3`) avec leur offset `delta` en (row, col).
- `contracts.py:Event` — les 4 événements possibles d'un pas (`MOVE`, `EAT_GREEN`, `EAT_RED`, `DEATH`).
- `contracts.py:StepResult` — dataclass immuable renvoyée par `Environment.step` : `event`, `done`, `length`.
- `contracts.py:EnvironmentP` — Protocol définissant l'interface du monde : `reset()`, `step(action)`, `length`, `head`, `cell_symbol`.
- `contracts.py:InterpreterP` — Protocol définissant l'interface de traduction : `get_state(env)`, `get_reward(result)`, `render_vision(env)`.
- `contracts.py:AgentP` — Protocol définissant l'interface de l'agent : `choose_action(state)`, `learn(...)`, `end_session()`, `save/load`, et l'attribut `learning`.

### `game.py` — l'orchestrateur de la boucle

- `game.py:run_sessions` — lance `sessions` parties consécutives, appelle `agent.end_session()` à la fin de chaque partie, et imprime les maxima finaux.
- `game.py:_run_one_game` — implémente le cycle exact décrit ci-dessus : `get_state → choose_action → step → get_reward → get_state → learn`, avec gestion de `done` et du cap `MAX_STEPS_PER_SESSION`. Le détail complet de l'orchestration (CLI, sauvegarde, wiring) est décrit en [étape 07](07-architecture-code.md).

### `src/learn2slither/__init__.py` — le pitch du package

```python
"""Learn2Slither: a Q-learning snake on a 10x10 board.

Modular RL pipeline: Environment -> Interpreter -> Agent. See ``contracts`` for
the shared types and ``config`` for tunable constants.
"""
```

---

## À retenir

- Learn2Slither est un problème de **RL par essai-erreur** : l'agent apprend uniquement à partir de récompenses scalaires, sans données étiquetées.
- La boucle fondamentale est : observer $s_t$ → choisir $a_t$ → recevoir $r_t$ et $s_{t+1}$ → mettre à jour $Q$ → répéter.
- L'objectif formel est de maximiser le **retour actualisé** $G_t = \sum_{k \ge 0} \gamma^k r_{t+k}$ avec $\gamma = 0{,}9$.
- Le projet impose trois rôles distincts (`Environment`, `Interpreter`, `Agent`) couplés uniquement via `contracts.py` — jamais de dépendance directe entre classes concrètes.
- L'`Interpreter` est le seul composant autorisé à lire le plateau pour l'agent ; cette frontière garantit que l'état $s$ reste une observation locale légale (vision 12 bits).
- Un **épisode** (session) va de `reset()` jusqu'au game over ou à `MAX_STEPS_PER_SESSION` ; des centaines à milliers d'épisodes sont nécessaires pour converger.

---

## Liens

- **Prérequis :** aucun.
- **Suite :** [02 — L'état : la vision du serpent et l'encodage 12 bits](02-etat-vision.md)
- **Voir aussi :**
  - [03 — Les récompenses et le reward shaping](03-recompenses.md) — les valeurs et justifications de $r$ (renvoyé depuis cette étape)
  - [04 — Q-learning tabulaire : Bellman, mise à jour, α et γ](04-q-learning-tabulaire.md) — les maths de la mise à jour de $Q$
  - [05 — Exploration vs exploitation : ε-greedy et décroissance](05-exploration-exploitation.md) — comment $\pi$ choisit $a_t$
  - [06 — Le réseau de neurones : MLP, features, TD semi-gradient](06-reseau-neurones.md) — l'agent alternatif (`NNAgent`)
  - [07 — Architecture du code et cycle de vie](07-architecture-code.md) — le détail du wiring, de la CLI et de la boucle
