# OUTLINE — Brief pour les rédacteurs de la documentation Learn2Slither

> Document de cadrage interne. Il n'est **pas** destiné au lecteur final : c'est la
> consigne partagée que chaque agent rédacteur lit (avec le code) pour écrire **un seul**
> fichier d'étape. L'index lisible par l'utilisateur est `doc/README.md`.

## But de la documentation

Expliquer le projet Learn2Slither — un jeu Snake piloté par apprentissage par renforcement
(Q-learning, Python) — sous trois angles complémentaires :

1. les **concepts d'IA** (la boucle agent–environnement, le MDP, l'apprentissage par
   essai-erreur) ;
2. les **mathématiques** (équation de Bellman, mise à jour temporelle, ε-greedy,
   TD semi-gradient, rétropropagation) ;
3. le **code** (comment ces idées se matérialisent dans `src/learn2slither/`).

### Langue et niveau (décisions à appliquer partout)

- **Langue : français.** La prose est en français. On **ne traduit pas** les identifiants de
  code (noms de classes, de fonctions, de flags CLI, de constantes : `QTableAgent`,
  `get_state`, `-dontlearn`, `REWARD_EAT_GREEN`…) ni la **notation mathématique standard**
  ($s$, $a$, $Q$, $\gamma$…). On garde aussi les symboles d'affichage tels quels (`W H S G R 0`).
- **Niveau : les deux.** Chaque étape commence par une partie accessible (« Intuition »)
  puis approfondit (« En profondeur »). Le lecteur cible est un·e programmeur·euse
  compétent·e mais potentiellement novice en apprentissage par renforcement (RL).

## Structure imposée de CHAQUE fichier d'étape

Chaque fichier `NN-slug.md` suit exactement ce squelette (titres en français, niveau de
titre `##` pour les sections principales) :

```markdown
# NN — <Titre de l'étape>

> Résumé en une ligne de ce que couvre l'étape.

**Prérequis :** [lien vers étape(s) antérieure(s)] · **Suite :** [lien vers étape suivante]

## Intuition

Explication accessible, sans jargon non défini, avec analogies si utile.

## En profondeur

Le cœur technique : formules (LaTeX), définitions précises, raisonnement.

## Dans le code

Où et comment l'idée vit dans le dépôt. Références au format `fichier:symbole`
(ex. `agent.py:QTableAgent.learn`). Citer le code seulement quand le texte exact
est porteur de sens ; sinon décrire.

## À retenir

3 à 6 puces : les points clés à mémoriser.

## Liens

- Prérequis : [NN — Titre](NN-slug.md)
- Suite : [NN — Titre](NN-slug.md)
- Voir aussi : [NN — Titre](NN-slug.md) (pour les sujets renvoyés ailleurs)
```

Règles de rédaction :

- Le fichier doit être **autonome** : le rédacteur n'a que ce brief + le code. Ne pas
  inventer de contenu pour d'autres étapes ; renvoyer vers elles via les liens.
- Respecter strictement le **périmètre** (`scope`) et la liste **« ne pas traiter ici »** de
  l'étape pour éviter les chevauchements entre rédacteurs.
- Toute valeur numérique (récompenses, hyperparamètres, tailles) doit correspondre à
  `config.py` — ne pas réinventer de chiffres.

## Conventions partagées

### Notation mathématique

Rendu GitHub-flavored LaTeX : `$...$` en ligne, `$$...$$` en bloc. Table des symboles
canoniques (à utiliser tels quels dans toutes les étapes) :

| Symbole | Lecture | Sens dans Learn2Slither |
| --- | --- | --- |
| $s$, $s'$ | état courant / suivant | l'id de vision 12 bits dans $[0, 4095]$ |
| $a$, $a'$ | action courante / suivante | un `Action` ∈ {UP=0, LEFT=1, DOWN=2, RIGHT=3} |
| $r$ | récompense | scalaire renvoyé par `Interpreter.get_reward` |
| $Q(s,a)$ | Q-valeur | qualité estimée de l'action $a$ dans l'état $s$ |
| $\pi(s)$ | politique | l'action choisie dans l'état $s$ |
| $\alpha$ | taux d'apprentissage | `ALPHA = 0.1` |
| $\gamma$ | facteur d'actualisation | `GAMMA = 0.9` |
| $\epsilon$ | taux d'exploration | de `EPSILON_START = 1.0` vers `EPSILON_MIN = 0.01` |
| $\max_{a'} Q(s',a')$ | meilleure Q-valeur en $s'$ | terme « bootstrap » de la cible |
| $\delta$ | erreur TD (temporal-difference) | $r + \gamma \max_{a'} Q(s',a') - Q(s,a)$ |
| $t$ | pas de temps (step) | un appel à `Environment.step` |
| $\theta$ | paramètres du réseau | poids/biais $W_1, b_1, W_2, b_2$ du `NNAgent` |
| $\phi(s)$ | vecteur de features | les 12 bits de $s$ (`state_to_features`) |

Convention de signe de l'erreur TD : **attention**, le code du `NNAgent` calcule
`td_error = Q(s,a) − cible` (prédiction moins cible), tandis que la mise à jour tabulaire du
`QTableAgent` ajoute `α·(cible − Q(s,a))`. Les deux sont cohérents (descente de gradient sur
$\tfrac12 \delta^2$) ; l'étape qui décrit chaque agent doit expliciter le signe **qu'elle
utilise** et le faire correspondre au code cité.

### Markdown / LaTeX

- Titres : `#` pour le titre du fichier, `##` pour les sections du squelette ci-dessus.
- Code et identifiants en `monospace` (backticks). Blocs de code avec langage (` ```python `,
  ` ```text `).
- Formules en `$...$` / `$$...$$`. Pas d'images d'équations.
- Tableaux Markdown pour les énumérations structurées (récompenses, flags, hyperparamètres).

### Schéma de nommage des fichiers

`NN-slug.md`, `NN` sur deux chiffres avec zéro de tête, ordre = ordre de lecture.
Slugs en minuscules, mots séparés par des tirets, sans accents (ex. `04-q-learning-tabulaire.md`).

### Références croisées (liens relatifs)

Tous les fichiers d'étape **et** `README.md` sont dans `doc/`. On lie donc par nom de fichier
relatif simple : `[02 — La vision du serpent](02-etat-vision.md)`. Pour renvoyer au README du
projet (racine du dépôt) depuis `doc/` : `../README.md`. Pour pointer un fichier source :
écrire le chemin `src/learn2slither/agent.py` en `monospace` (lien optionnel `../src/...`).

## Glossaire (vocabulaire à employer de façon cohérente)

- **Agent** : l'entité qui décide (`QTableAgent` ou `NNAgent`). Choisit une action, reçoit une
  récompense, met à jour sa fonction $Q$.
- **Environnement** (`Environment`) : le monde du jeu — plateau, serpent, pommes, règles. Reçoit
  une action, renvoie un `StepResult`.
- **Interpréteur** (`Interpreter`) : intermédiaire qui transforme le plateau en **état** (vision)
  et en **récompense**. Seul composant autorisé à « lire » le plateau pour l'agent (règle −42).
- **État** (state, $s$) : ce que « voit » l'agent — ici l'id 12 bits. C'est une **observation**
  de la situation, pas le plateau complet.
- **Action** ($a$) : un des 4 mouvements (UP, LEFT, DOWN, RIGHT).
- **Récompense** (reward, $r$) : signal scalaire d'évaluation d'un pas.
- **Politique** (policy, $\pi$) : la règle qui associe un état à une action (ici ε-greedy puis,
  gelée, purement gloutonne / *greedy*).
- **Q-valeur** : estimation de la récompense cumulée attendue en prenant $a$ dans $s$ puis en
  suivant la politique. La **fonction $Q$** est l'ensemble de ces estimations (table ou réseau).
- **Exploration / exploitation** : tenter une action au hasard pour découvrir (exploration) vs
  jouer la meilleure connue (exploitation).
- **Épisode / session** : une partie, de `reset()` jusqu'au game over (ou à `MAX_STEPS_PER_SESSION`).
  Dans ce projet « session » = « game » = « épisode ».
- **Processus de décision markovien (MDP)** : cadre formel $(S, A, P, R, \gamma)$ de la boucle.
- **Pas / step** : une itération action → transition → récompense (un `Environment.step`).
- **Cible TD / bootstrap** : la valeur visée $r + \gamma \max_{a'} Q(s',a')$, qui s'appuie sur
  l'estimation courante de l'état suivant.
- **Glouton / greedy** : choisir $\arg\max_a Q(s,a)$ (ici avec départage aléatoire des ex æquo).
- **Q-table** : représentation tabulaire de $Q$ (tableau `(N_STATES, N_ACTIONS)`).
- **Approximation de fonction** : remplacer la table par un modèle paramétré (le réseau de neurones).

---

## Spécification étape par étape

8 étapes, ordonnées concepts → maths → code → pratique. Chaque section ci-dessous est la
consigne complète du rédacteur de l'étape correspondante.

---

### Étape 01

- **filename :** `01-vue-ensemble-rl.md`
- **title :** Vue d'ensemble : le problème RL et la boucle agent–environnement
- **prérequis :** aucun (point d'entrée).
- **scope :**
  - Présenter Learn2Slither en une phrase et l'objectif (faire grandir le serpent à ≥ 10
    tout en restant en vie le plus longtemps possible).
  - Introduire l'apprentissage par renforcement : apprendre **par essai-erreur** via des
    récompenses, sans données étiquetées.
  - La boucle agent–environnement : à chaque pas, l'agent observe $s_t$, choisit $a_t$,
    l'environnement renvoie $r_t$ et $s_{t+1}$ ; répétition.
  - Le découpage en **trois rôles** `Environment → Interpreter → Agent` et pourquoi cette
    modularité (chacun évaluable indépendamment ; couplage uniquement via `contracts.py`).
  - Le **MDP** comme cadre formel : tuple $(S, A, P, R, \gamma)$, propriété de Markov,
    objectif = maximiser la récompense cumulée actualisée $\sum_t \gamma^t r_t$.
  - Notion d'épisode/session et la boucle d'entraînement à haut niveau.
- **formules / notation possédées :**
  - Le tuple MDP $(S, A, P, R, \gamma)$ et la propriété de Markov.
  - Le retour actualisé $G_t = \sum_{k \ge 0} \gamma^k r_{t+k}$.
  - Le schéma ASCII de la boucle (reprendre celui de `.specs/overview.md` / `README.md`).
- **références code (`fichier:symbole`) :**
  - `contracts.py` (les Protocols `EnvironmentP`, `InterpreterP`, `AgentP` ; `Action`,
    `Event`, `StepResult`).
  - `game.py:run_sessions` et `game.py:_run_one_game` (vue très haut niveau de la boucle —
    le détail mécanique est en étape 07).
  - `src/learn2slither/__init__.py` (pitch du package).
- **ne pas traiter ici :**
  - L'encodage précis de l'état → **étape 02**.
  - Les valeurs/justifications des récompenses → **étape 03**.
  - Les maths de la mise à jour de $Q$ → **étape 04**.
  - Le détail du wiring/CLI/sauvegarde → **étape 07**.

---

### Étape 02

- **filename :** `02-etat-vision.md`
- **title :** L'état : la vision du serpent et l'encodage 12 bits (+ règle −42)
- **prérequis :** [01](01-vue-ensemble-rl.md).
- **scope :**
  - Ce que « voit » le serpent : 4 rayons depuis la tête (UP, LEFT, DOWN, RIGHT), symboles
    `W H S G R 0`.
  - La **règle −42** : l'agent ne reçoit QUE l'information visible (pas de coordonnées, pas de
    plateau complet, pas de pommes hors ligne de vue), sous peine de pénalité.
  - L'encodage « v1 » : 3 bits par direction — *danger* (bit 0), *green in line* (bit 1),
    *red in line* (bit 2) — packés à l'offset $3i$, donnant un id 12 bits ∈ $[0, 4095]$,
    soit `N_STATES = 4096` états discrets.
  - Comment un rayon est balayé jusqu'au mur, et la définition exacte de « danger » (mur ou
    corps **adjacent**).
  - Pourquoi cet encodage est **indépendant de la taille du plateau** (lien vers le bonus,
    traité en étape 08).
  - L'affichage terminal de la vision en croix (à quoi il sert : transparence/debug).
- **formules / notation possédées :**
  - La formule de packing : $s = \sum_{i=0}^{3} b_i \cdot 2^{3i}$ où $b_i$ est le triplet de
    bits de la $i$-ème direction.
  - L'inverse (extraction de bit) : bit $i$ de $s$ = $(s \gg i)\ \&\ 1$.
  - Le décompte $4\ \text{directions} \times 3\ \text{bits} = 12\ \text{bits} \Rightarrow 2^{12}=4096$.
- **références code (`fichier:symbole`) :**
  - `interpreter.py:Interpreter.get_state`, `interpreter.py:Interpreter._scan_ray`,
    les constantes `_BIT_DANGER/_BIT_GREEN/_BIT_RED`.
  - `interpreter.py:Interpreter.render_vision` (+ `_row_line`, `_column_symbol`).
  - `config.py` : `STATE_ENCODING_VERSION`, `N_STATES`, `SYM_*`.
  - `contracts.py:DIRECTION_ORDER` et `Action.delta` (ordre canonique des directions).
  - `environment.py:Environment.cell_symbol` (la source des symboles).
- **ne pas traiter ici :**
  - La conception/valeurs des récompenses → **étape 03**.
  - Comment $s$ est utilisé pour choisir/mettre à jour une action → **étapes 04–05**.
  - L'expansion $s \to$ vecteur de features pour le réseau (`state_to_features`) → **étape 06**.
  - La démonstration chiffrée du bonus taille variable → **étape 08**.

---

### Étape 03

- **filename :** `03-recompenses.md`
- **title :** Les récompenses et la conception du reward shaping
- **prérequis :** [01](01-vue-ensemble-rl.md), [02](02-etat-vision.md).
- **scope :**
  - Le rôle de la récompense dans le RL : elle augmente/diminue la probabilité de répéter une
    action dans une situation identique.
  - Le barème exact et sa lecture : `REWARD_EAT_GREEN = +20`, `REWARD_EAT_RED = -15`,
    `REWARD_STEP = -1`, `REWARD_DEATH = -100`.
  - **Reward shaping** : pourquoi un coût par pas négatif (`-1`) pousse à l'efficacité, pourquoi
    la mort est très pénalisée, pourquoi la pomme verte vaut nettement plus que le coût d'un pas.
  - Le mapping `Event → reward` (table `_REWARDS`) et la frontière de responsabilité :
    l'Interpréteur calcule $r$, l'agent ne le « lit » jamais directement (et l'ignore quand
    `learning` est `False`).
  - Discussion : ces valeurs sont des **hyperparamètres** réglables (pointer vers étape 08 pour
    l'effet empirique sur l'entraînement).
- **formules / notation possédées :**
  - La table de récompense $R(\text{event})$ sous forme de tableau.
  - (Optionnel) une intuition de l'horizon : avec $\gamma=0.9$, le coût par pas accumulé
    relativise les gains lointains — mais **la mécanique de $\gamma$ appartient à l'étape 04** ;
    se contenter ici de la dimension « design ».
- **références code (`fichier:symbole`) :**
  - `interpreter.py:Interpreter.get_reward`, le dict `_REWARDS`.
  - `config.py` : `REWARD_EAT_GREEN`, `REWARD_EAT_RED`, `REWARD_STEP`, `REWARD_DEATH`.
  - `contracts.py:Event` (les 4 événements) et `StepResult`.
  - `environment.py:Environment.step` et ses helpers `_resolve_move/_resolve_green/_resolve_red`
    (quel événement est émis quand).
- **ne pas traiter ici :**
  - Comment $r$ entre dans la mise à jour de $Q$ (Bellman) → **étape 04**.
  - Le rôle de $\gamma$ dans l'actualisation (mécanique) → **étape 04**.
  - L'effet mesuré des récompenses sur les modèles entraînés → **étape 08**.

---

### Étape 04

- **filename :** `04-q-learning-tabulaire.md`
- **title :** Q-learning tabulaire : équation de Bellman, mise à jour, α et γ
- **prérequis :** [02](02-etat-vision.md), [03](03-recompenses.md).
- **scope :**
  - La **fonction $Q$** : qu'estime $Q(s,a)$, et pourquoi « apprendre $Q$ » suffit pour agir
    (la politique gloutonne dérive de $Q$).
  - La **Q-table** concrète : tableau dense `(N_STATES, N_ACTIONS)` en `float32`, initialisé à 0.
  - L'**équation de Bellman d'optimalité** (forme espérance) puis la **mise à jour de
    Q-learning** (off-policy, échantillonnée) :
    $$Q(s,a) \leftarrow Q(s,a) + \alpha\big[r + \gamma \max_{a'} Q(s',a') - Q(s,a)\big].$$
  - Le rôle de $\alpha$ (`0.1`, vitesse d'apprentissage) et de $\gamma$ (`0.9`, valorisation du
    futur). Cas terminal (`done`) : la cible est simplement $r$ (pas de terme bootstrap).
  - L'**erreur TD** $\delta = r + \gamma \max_{a'} Q(s',a') - Q(s,a)$ et la lecture « on rapproche
    $Q(s,a)$ de sa cible d'un pas $\alpha$ ».
  - Le départage aléatoire des ex æquo dans l'argmax (évite un biais directionnel).
- **formules / notation possédées :**
  - Bellman optimal : $Q^*(s,a) = \mathbb{E}\!\left[r + \gamma \max_{a'} Q^*(s',a')\right]$.
  - La règle de mise à jour tabulaire (ci-dessus) — **formule centrale, possédée ici**.
  - $\delta = r + \gamma \max_{a'} Q(s',a') - Q(s,a)$.
  - Cible terminale : $\text{cible} = r$ quand `done`.
- **références code (`fichier:symbole`) :**
  - `agent.py:QTableAgent` (attribut `q`, init à zéro), `QTableAgent.learn` (la mise à jour),
    `QTableAgent._greedy_action` (argmax + départage).
  - `config.py` : `ALPHA`, `GAMMA`, `N_STATES`, `N_ACTIONS`.
  - `game.py:_run_one_game` pour la provenance de `(state, action, reward, next_state, done)`
    (décrire brièvement, le détail de la boucle est en étape 07).
- **ne pas traiter ici :**
  - Le choix de l'action / $\epsilon$ / la décroissance → **étape 05** (ici on suppose juste
    qu'on dispose d'une transition).
  - L'approche par réseau de neurones (TD semi-gradient) → **étape 06**.
  - La sérialisation `save`/`load` de la table → **étape 07**.

---

### Étape 05

- **filename :** `05-exploration-exploitation.md`
- **title :** Exploration vs exploitation : ε-greedy et la décroissance
- **prérequis :** [04](04-q-learning-tabulaire.md).
- **scope :**
  - Le dilemme exploration/exploitation et pourquoi il faut explorer (sinon on se fige sur une
    politique sous-optimale).
  - La politique **ε-greedy** : avec proba $\epsilon$ une action uniforme aléatoire, sinon
    l'action gloutonne.
  - La **décroissance** d'$\epsilon$ : multiplicative, **une fois par session** dans
    `end_session`, plancher à `EPSILON_MIN`. De `EPSILON_START = 1.0` (tout exploration au début)
    vers `0.01`.
  - Le mode **gel** (`learning = False`, flag `-dontlearn`) : exploitation pure, aucune action
    aléatoire, aucune mise à jour — sert à évaluer un modèle sans le modifier.
  - Que cette politique est **identique** pour le `QTableAgent` et le `NNAgent` (mêmes
    constantes), seule la façon de calculer les Q-valeurs diffère.
- **formules / notation possédées :**
  - La politique : $\pi(s) = \begin{cases} \text{action aléatoire} & \text{avec proba } \epsilon \\
    \arg\max_a Q(s,a) & \text{sinon}\end{cases}$
  - La décroissance : $\epsilon \leftarrow \max(\epsilon_{\min},\ \epsilon \cdot d)$ avec
    $d = $ `EPSILON_DECAY` $= 0.995$, appliquée par session.
  - (Optionnel) nombre approximatif de sessions pour atteindre le plancher :
    $\epsilon_{\text{start}} \cdot d^{n} = \epsilon_{\min}$.
- **références code (`fichier:symbole`) :**
  - `agent.py:QTableAgent.choose_action` et `_greedy_action` ; `agent.py:QTableAgent.end_session`.
  - `config.py` : `EPSILON_START`, `EPSILON_MIN`, `EPSILON_DECAY`.
  - `contracts.py:AgentP.learning` (sémantique du gel).
  - `cli.py` : flag `-dontlearn` et `_run_from_args` (qui met `agent.learning = False`).
  - (Symétrie) `nn_agent.py:NNAgent.choose_action`/`end_session` — mentionner que la logique
    ε-greedy est la même.
- **ne pas traiter ici :**
  - La mécanique de la mise à jour de $Q$ → **étape 04** (tabulaire) / **étape 06** (réseau).
  - Le détail interne du calcul des Q-valeurs du réseau → **étape 06**.
  - L'orchestration de la boucle qui appelle `end_session` → **étape 07**.

---

### Étape 06

- **filename :** `06-reseau-neurones.md`
- **title :** Le réseau de neurones : MLP, features, TD semi-gradient, rétropropagation
- **prérequis :** [02](02-etat-vision.md), [04](04-q-learning-tabulaire.md), [05](05-exploration-exploitation.md).
- **scope :**
  - Pourquoi une **alternative** à la table : approximation de fonction (le sujet autorise une
    stratégie de mise à jour alternative) ; ici un MLP NumPy « from scratch ».
  - Les **features** : `state_to_features` étend l'id en vecteur de 12 bits $\phi(s) \in \{0,1\}^{12}$.
  - L'**architecture** : $12 \to 32$ (ReLU) $\to 4$ (linéaire) ; init He / Xavier ;
    une Q-valeur par action en sortie.
  - La **passe avant** (`_forward`) et le calcul des Q-valeurs (`q_values`).
  - L'**objectif** : erreur TD semi-gradient sur **l'unité de sortie de l'action prise
    uniquement** ; perte $\tfrac12 \delta^2$. Préciser le signe utilisé dans le code
    (`td_error = Q(s,a) − cible`).
  - La **rétropropagation** explicite : gradients sur $W_2, b_2$ (unité active) puis sur
    $W_1, b_1$ via la dérivée de ReLU ; pas de SGD $\theta \leftarrow \theta - \eta \nabla$.
  - « Semi-gradient » : on ne propage pas le gradient à travers la cible (qui contient
    $\max_{a'} Q(s',a')$).
  - Comparer brièvement à la table (apprend plus lentement par session mais compétitif avec
    assez d'entraînement) — chiffres précis renvoyés à l'étape 08.
- **formules / notation possédées :**
  - Passe avant : $h = \mathrm{ReLU}(W_1^\top \phi(s) + b_1)$, $\ Q(s,\cdot) = W_2^\top h + b_2$.
  - Cible (idem Q-learning) : $y = r + \gamma \max_{a'} Q(s',a')$ (ou $y = r$ si terminal).
  - Erreur TD (signe du code) : $\delta = Q(s,a) - y$ ; perte $L = \tfrac12 \delta^2$.
  - Gradients : $\nabla_{W_2[:,a]} = \delta\, h$, $\ \nabla_{b_2[a]} = \delta$ ;
    $d_h = \delta\, W_2[:,a] \odot \mathbb{1}[h>0]$, $\ \nabla_{W_1} = \phi(s)\, d_h^\top$, $\ \nabla_{b_1} = d_h$.
  - Mise à jour : $\theta \leftarrow \theta - \eta\, \nabla_\theta L$ avec $\eta = $ `NN_LEARNING_RATE` $=0.001$.
- **références code (`fichier:symbole`) :**
  - `nn_agent.py:state_to_features`, `nn_agent.py:NNAgent` (`w1,b1,w2,b2`, `_forward`,
    `q_values`, `learn`).
  - `config.py` : `NN_HIDDEN_SIZE`, `NN_LEARNING_RATE`, `GAMMA`, `N_ACTIONS`.
  - Renvoyer à `agent.py:QTableAgent.learn` (étape 04) pour la cible TD partagée.
- **ne pas traiter ici :**
  - L'encodage de $s$ lui-même → **étape 02** (ici on part de l'id).
  - La politique ε-greedy (commune) → **étape 05**.
  - Le format de fichier des poids (`save`/`load`) et le wiring `-model nn` → **étape 07**.
  - Les performances comparées chiffrées des modèles `nn_*` → **étape 08**.

---

### Étape 07

- **filename :** `07-architecture-code.md`
- **title :** Architecture du code et cycle de vie (Environment → Interpreter → Agent, CLI, boucle, save/load)
- **prérequis :** [01](01-vue-ensemble-rl.md) à [06](06-reseau-neurones.md).
- **scope :**
  - La **carte des modules** et leurs responsabilités (reprendre le tableau du README), et le
    principe : couplage **uniquement** via `contracts.py` (Protocols + dataclasses), pas de
    dépendance entre classes concrètes.
  - Le **cycle de vie d'un pas** dans `_run_one_game` : `get_state` → `choose_action` → `step`
    → `get_reward` → `get_state` (suivant) → `learn` ; gestion de `done` et de `next_state` ;
    `end_session` à la fin de chaque partie ; `MAX_STEPS_PER_SESSION`.
  - La **CLI** : tous les flags (`-sessions`, `-save`, `-load`, `-visual`, `-dontlearn`,
    `-step-by-step`, `-speed`, `-board-size`, `-model`, `-menu`) et le wiring dans `_run_from_args`.
  - **Sélection de l'agent** : `make_agent` lit le champ `"type"` du fichier au `-load` (sinon
    `-model`) ; import paresseux de pygame (display construit seulement si `-visual on`).
  - **Sauvegarde / chargement** : schémas JSON des deux agents (`QTableAgent.save` ne stocke que
    les lignes non nulles + hyperparamètres ; `NNAgent.save` stocke les poids) ; round-trip exact.
  - Gestion propre du `KeyboardInterrupt`/quit avec respect de `-save`.
  - (Bonus display) mentionner `visualizer.py` et `menu.py` comme couche d'affichage optionnelle
    — détail fonctionnel laissé à l'étape 08.
- **formules / notation possédées :** aucune (étape « code », pas de maths nouvelles). Peut
  réutiliser le schéma de boucle de l'étape 01 en l'instanciant sur les vrais appels.
- **références code (`fichier:symbole`) :**
  - `game.py:run_sessions`, `game.py:_run_one_game`, `game.py:_present_step`,
    `game.py:_build_stats`, `game.py:_run_or_pause`, `game.py:_wait_for_enter`.
  - `cli.py:build_parser`, `cli.py:make_agent`, `cli.py:_agent_for_type`, `cli.py:_model_type`,
    `cli.py:_run_from_args`, `cli.py:_build_visualizer`, `cli.py:_should_open_lobby`.
  - `agent.py:QTableAgent.save`/`load` ; `nn_agent.py:NNAgent.save`/`load`.
  - `contracts.py` (tous les Protocols) ; `config.py:MAX_STEPS_PER_SESSION`, `DEFAULT_SEED`.
- **ne pas traiter ici :**
  - Le **détail mathématique** de `learn`/`get_state`/`get_reward` → **étapes 02–06**
    (ici on décrit l'orchestration et les signatures, pas la dérivation).
  - La présentation des modèles entraînés et l'évaluation chiffrée → **étape 08**.
  - Le fonctionnement détaillé du lobby/des widgets pygame → **étape 08** (juste les pointer).

---

### Étape 08

- **filename :** `08-entrainement-evaluation-bonus.md`
- **title :** Entraînement, modèles, évaluation et bonus
- **prérequis :** [04](04-q-learning-tabulaire.md), [05](05-exploration-exploitation.md), [06](06-reseau-neurones.md), [07](07-architecture-code.md).
- **scope :**
  - **Entraîner** un modèle : commandes types (`-sessions N -save ... -visual off`), pourquoi
    l'entraînement headless va plus vite, déterminisme (graine `42`).
  - Le dossier **`models/`** : la progression 1 → 10 → 100 → 1000 → 5000 (qtable) et les `nn_*`,
    reprendre le **tableau des résultats** (max length / max duration mesurés gelés sur 100 parties).
  - **Évaluer** un modèle sans l'altérer : `-load ... -dontlearn` (lien étape 05) ; lecture des
    métriques `max length` / `max duration` et du cap `1000` (= a survécu toute la session).
  - **Comparaison qtable vs nn** (commenter : la NN apprend plus lentement mais devient
    compétitive — 38 à 1000, 40 à 5000).
  - Les **trois bonus** : (1) longueur élevée par tiers 15/20/25/30/35 ; (2) affichage riche —
    lobby + panneau de stats en direct + contrôles clavier ; (3) **taille de plateau variable** —
    démontrer la propriété cross-size (même modèle `5000sess.txt` sur 10/15/20) grâce à l'état
    sans coordonnées (lien étape 02).
  - Renvoyer au `README.md` du projet (`../README.md`) et à la checklist de défense / norme
    (`flake8`, `pytest`).
- **formules / notation possédées :** aucune formule nouvelle ; tableaux de résultats et
  commandes. Peut rappeler la définition de « session/épisode » du glossaire.
- **références code (`fichier:symbole`) :**
  - `cli.py` (flags `-sessions`, `-board-size`, `-model`, `-menu`) ; `game.py:run_sessions`
    (impression de `Game over, max length = X, max duration = Y`).
  - `config.py` : `MAX_STEPS_PER_SESSION`, `DEFAULT_SEED`, `BOARD_SIZE`, `N_GREEN_APPLES`,
    `N_RED_APPLES`, récompenses/hyperparamètres (comme leviers de réglage).
  - `menu.py` (`LobbyConfig`, `Lobby`, `run_lobby`, widgets `Button/Stepper/Cycler/Toggle`) et
    `visualizer.py` (`Visualizer.render`, `_draw_panel`, `_panel_lines`, contrôles dans
    `process_events`/`_handle_control_key`) pour le bonus affichage.
  - Pointer `tests/test_bonus.py` (verrou cross-size) et `../README.md` (sections Models / Bonus).
- **ne pas traiter ici :**
  - La dérivation des mises à jour → **étapes 04 / 06**.
  - Le détail de l'encodage qui *rend possible* le cross-size → **étape 02** (juste le citer).
  - Le détail du wiring CLI/boucle → **étape 07** (ici, usage et résultats, pas plomberie).
