# 03 — Les récompenses et la conception du reward shaping

> Le barème (+20 / −15 / −1 / −100) et pourquoi ces choix guident l'apprentissage.

**Prérequis :** [01 — Vue d'ensemble : le problème RL et la boucle agent–environnement](01-vue-ensemble-rl.md) · [02 — L'état : la vision du serpent et l'encodage 12 bits](02-etat-vision.md) · **Suite :** [04 — Q-learning tabulaire : Bellman, mise à jour, α et γ](04-q-learning-tabulaire.md)

---

## Intuition

Imaginez qu'on apprend à un chien à rapporter une balle. Si la balle revient dans la main on
donne une friandise (récompense positive) ; si le chien court vers la route on dit « non »
sèchement (récompense négative) ; et on lui retire un tout petit bout de friandise à chaque
seconde qui passe pour qu'il ne traîne pas (coût de déplacement). Avec le temps, l'animal
associe chaque situation à la conséquence de ses gestes.

Learn2Slither fonctionne exactement ainsi. À chaque pas de jeu l'`Interpreter` évalue ce qui
vient de se passer et produit un scalaire $r$ — la **récompense**. Ce signal est la seule chose
que l'agent perçoit comme « bien » ou « mal » ; il n'y a pas de règles codées explicitement, pas
d'enseignant humain, juste le barème.

Le tableau ci-dessous dit tout :

| Événement (`Event`) | Signification | Récompense $r$ |
|---|---|---|
| `Event.EAT_GREEN` | Serpent mange une pomme verte | **+20** |
| `Event.EAT_RED` | Serpent mange une pomme rouge | **−15** |
| `Event.MOVE` | Déplacement ordinaire (rien mangé) | **−1** |
| `Event.DEATH` | Game over (mur, soi-même, longueur 0) | **−100** |

Ces quatre valeurs viennent directement de `config.py` et sont les seules que l'agent
recevra jamais.

**Pourquoi ces choix ?**

- La pomme verte est largement positive (+20) : c'est l'objectif du jeu, grandir.  
- La pomme rouge est négative (−15) : manger du rouge fait rapetisser le serpent et
  risque d'abréger la partie — c'est mauvais.  
- Chaque pas coûte un petit −1 : si rester en vie était gratuit, le serpent pourrait apprendre
  à tourner indéfiniment sans jamais chercher de nourriture.  
- La mort est massivement négative (−100) : c'est le pire résultat possible, et la pénalité
  doit clairement dominer tout gain à court terme pour que l'agent ne sacrifie jamais sa vie
  par confort.

---

## En profondeur

### Le rôle formel de la récompense

Dans le cadre du **processus de décision markovien (MDP)** $(S, A, P, R, \gamma)$, la fonction
de récompense $R$ associe à chaque transition $(s, a, s')$ un scalaire $r$. L'objectif de
l'agent est de maximiser le **retour actualisé** :

$$G_t = \sum_{k \ge 0} \gamma^k\, r_{t+k}$$

Chaque récompense $r$ augmente ou diminue la probabilité que l'agent reproduise l'action $a$
dans l'état $s$ : c'est exactement ce qu'énonce le sujet (Part 4 Rewards). La mécanique précise
de cette mise à jour — l'équation de Bellman et la règle Q-learning — est détaillée en
[étape 04](04-q-learning-tabulaire.md).

### Reward shaping : pourquoi ce barème précis ?

Le *reward shaping* désigne la conception délibérée des valeurs de récompense pour guider
l'apprentissage vers un comportement souhaité.

**Coût par pas (MOVE = −1)**

Un pas ordinaire est sanctionné d'un petit coût. Sans lui, une politique qui fait tourner le
serpent en rond obtiendrait un retour $G_t = 0$, identique à une politique efficace qui mange
des pommes mais meurt rapidement. Le −1 par pas crée une pression continue vers l'efficacité :
atteindre une pomme verte en 5 pas vaut mieux qu'en 20.

**Mort (DEATH = −100) et l'équilibre avec STEP = −1**

Voici le piège classique du reward shaping : si la pénalité de mort est trop faible par rapport
au coût par pas, l'agent peut préférer mourir délibérément plutôt que de continuer à payer −1
à chaque mouvement. C'est le piège du « suicide économique ».

Avec $\text{DEATH} = -100$ et $\text{STEP} = -1$, mourir équivaut à payer *d'un coup* le
coût de 100 pas. L'horizon effectif du gain actualisé avec $\gamma = 0.9$ diminue, mais même à
courte vue la mort n'est jamais rentable tant que l'agent peut encore bouger librement. Le ratio
$|\text{DEATH}| / |\text{STEP}| = 100$ assure que la pénalité fatale écrase largement l'inconfort
du déplacement.

**Pomme verte (EAT_GREEN = +20)**

+20 représente le gain de 20 pas « gratuits » en termes de coût de déplacement. Concrètement,
manger une pomme verte compense largement les pas dépensés à l'atteindre (un plateau 10×10 a
au plus quelques dizaines de cases à traverser). Le signal est fort et non ambigu.

**Pomme rouge (EAT_RED = −15)**

−15 est intermédiaire entre STEP et DEATH. Manger du rouge est sévèrement puni mais pas fatal
en lui-même — sauf si le serpent devient trop court et meurt ensuite. Ce gradient de pénalité
crée une hiérarchie claire : éviter le mur > éviter le rouge > avancer vite > atteindre le vert.

### Frontière de responsabilité

L'`Interpreter` est l'**unique** composant autorisé à produire $r$ (règle −42 étendue aux
récompenses). La table `_REWARDS` dans `interpreter.py` associe chaque `Event` à sa valeur
numérique lue depuis `config.py` :

```python
_REWARDS = {
    Event.DEATH:     REWARD_DEATH,    # -100.0
    Event.EAT_GREEN: REWARD_EAT_GREEN, # +20.0
    Event.EAT_RED:   REWARD_EAT_RED,  # -15.0
    Event.MOVE:      REWARD_STEP,     # -1.0
}
```

La méthode `Interpreter.get_reward` se réduit à un accès de dictionnaire :
`return _REWARDS[result.event]`. L'agent reçoit le flottant $r$, mais l'ignore si
`agent.learning` vaut `False` (mode `-dontlearn`) — dans ce cas aucune mise à jour Q n'est
effectuée.

### Ces valeurs sont des hyperparamètres

`REWARD_EAT_GREEN`, `REWARD_EAT_RED`, `REWARD_STEP` et `REWARD_DEATH` sont déclarées dans
`config.py` exactement comme `ALPHA` ou `GAMMA`. On peut les modifier sans toucher au reste du
code. L'effet empirique de ces changements sur les performances des modèles entraînés est
examiné en [étape 08](08-entrainement-evaluation-bonus.md).

---

## Dans le code

| Symbole | Fichier | Rôle |
|---|---|---|
| `_REWARDS` | `interpreter.py` | Dict `Event → float`, source unique du barème |
| `Interpreter.get_reward` | `interpreter.py` | Retourne `_REWARDS[result.event]` |
| `REWARD_EAT_GREEN` | `config.py` | `+20.0` |
| `REWARD_EAT_RED` | `config.py` | `−15.0` |
| `REWARD_STEP` | `config.py` | `−1.0` |
| `REWARD_DEATH` | `config.py` | `−100.0` |
| `Event` | `contracts.py` | Enum : `MOVE`, `EAT_GREEN`, `EAT_RED`, `DEATH` |
| `StepResult` | `contracts.py` | Dataclass `(event, done, length)` transportant l'événement |

La chaîne complète pour un pas :

1. `Environment.step(action)` résout le mouvement et retourne un `StepResult`.
2. `Interpreter.get_reward(result)` lit `result.event` et retourne $r$.
3. L'agent reçoit $r$ dans son appel `learn(state, action, reward, next_state, done)`.

La logique de quel `Event` est émis (par exemple, `EAT_GREEN` quand la tête atterrit sur une
pomme verte, `DEATH` quand elle heurte un mur) vit dans `environment.py` (`_resolve_move`,
`_resolve_green`, `_resolve_red`) — mais l'`Interpreter` n'en dépend pas : il ne reçoit que
le `StepResult` final.

---

## À retenir

- La récompense $r$ est le **seul signal** qui guide l'agent : ni règles explicites, ni
  supervision humaine.
- Le barème comprend quatre valeurs : `EAT_GREEN = +20`, `EAT_RED = −15`,
  `MOVE = −1`, `DEATH = −100`.
- Le coût par pas (−1) pousse à l'efficacité ; la mort (−100) domine largement ce coût
  (ratio 100:1), ce qui élimine le piège du suicide économique.
- L'`Interpreter` est l'unique traducteur `Event → float` ; l'agent ne lit jamais le plateau.
- Ces quatre constantes sont des **hyperparamètres** modifiables dans `config.py` sans
  toucher au reste du code.
- La mécanique de comment $r$ entre dans la mise à jour de $Q$ est en [étape 04](04-q-learning-tabulaire.md).

---

## Liens

- Prérequis : [01 — Vue d'ensemble : le problème RL et la boucle agent–environnement](01-vue-ensemble-rl.md)
- Prérequis : [02 — L'état : la vision du serpent et l'encodage 12 bits](02-etat-vision.md)
- Suite : [04 — Q-learning tabulaire : Bellman, mise à jour, α et γ](04-q-learning-tabulaire.md)
- Voir aussi : [05 — Exploration vs exploitation : ε-greedy et décroissance](05-exploration-exploitation.md) (mode `-dontlearn` : l'agent ignore $r$ et n'apprend pas)
- Voir aussi : [08 — Entraînement, modèles, évaluation et bonus](08-entrainement-evaluation-bonus.md) (effet empirique des valeurs de récompense sur l'entraînement)
