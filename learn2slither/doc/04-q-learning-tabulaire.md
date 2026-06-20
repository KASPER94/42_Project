# 04 — Q-learning tabulaire : équation de Bellman, mise à jour, α et γ

> La Q-table et la règle de mise à jour temporelle au cœur du `QTableAgent` : ce qu'est une Q-valeur, comment l'équation de Bellman guide chaque correction, et pourquoi α et γ pilotent la vitesse et l'horizon de l'apprentissage.

**Prérequis :** [02 — L'état : la vision du serpent et l'encodage 12 bits](02-etat-vision.md) · [03 — Les récompenses et le reward shaping](03-recompenses.md) · **Suite :** [05 — Exploration vs exploitation : ε-greedy et décroissance](05-exploration-exploitation.md)

---

## Intuition

Imaginez un serpent qui joue indéfiniment et note dans un grand tableau, pour chaque situation possible et pour chaque direction, « combien cette direction m'a rapporté en moyenne ». Au début tout vaut 0 ; chaque partie enrichit peu à peu ces notes. Après assez d'expériences, la meilleure direction dans chaque situation se lit directement dans le tableau : c'est la case avec la plus haute valeur.

C'est exactement ce que fait le `QTableAgent`. La « note » pour la paire (situation $s$, direction $a$) s'appelle une **Q-valeur**, notée $Q(s,a)$. L'ensemble de ces notes est la **Q-table**.

Lors de chaque pas de jeu, l'agent dispose d'une transition complète :

> Il était dans l'état $s$, a pris l'action $a$, a reçu la récompense $r$, et s'est retrouvé dans l'état $s'$.

Il met alors à jour la Q-valeur correspondante selon une règle simple : *corriger un peu la note actuelle vers ce qu'elle devrait être*, en tenant compte aussi de ce qui pourra arriver dans les états suivants. Cette correction est appelée **erreur TD** (temporal-difference). Le paramètre $\alpha$ (taux d'apprentissage) contrôle l'ampleur de chaque correction, et $\gamma$ (facteur d'actualisation) décide de combien on valorise le futur par rapport au présent.

---

## En profondeur

### La fonction Q et la politique gloutonne

La **Q-valeur optimale** $Q^*(s,a)$ est définie comme la récompense cumulée actualisée attendue en partant de l'état $s$, en prenant l'action $a$, puis en jouant toujours de façon optimale :

$$Q^*(s,a) = \mathbb{E}\!\left[r + \gamma \max_{a'} Q^*(s',a')\right]$$

C'est l'**équation de Bellman d'optimalité**. Elle dit : la valeur optimale de $(s, a)$ est la récompense immédiate $r$ plus la meilleure valeur atteignable depuis $s'$, escomptée par $\gamma$.

Un agent qui connaît $Q^*$ n'a plus qu'à être **glouton** (*greedy*) : choisir dans chaque état $s$ l'action qui maximise la Q-valeur,

$$\pi(s) = \arg\max_a Q(s,a),$$

pour obtenir une politique optimale. Apprendre $Q$ est donc suffisant pour agir — il n'est pas nécessaire de modéliser explicitement les transitions de l'environnement.

### La règle de mise à jour Q-learning

En pratique $Q^*$ est inconnue et on l'approche par échantillons. Après avoir observé la transition $(s, a, r, s', \mathtt{done})$, on construit une **cible TD** :

$$\text{cible} = \begin{cases} r & \text{si } \mathtt{done} \text{ (état terminal)} \\ r + \gamma \displaystyle\max_{a'} Q(s',a') & \text{sinon} \end{cases}$$

Puis on rapproche $Q(s,a)$ de cette cible d'un pas proportionnel à $\alpha$ :

$$\boxed{Q(s,a) \leftarrow Q(s,a) + \alpha\big[r + \gamma \max_{a'} Q(s',a') - Q(s,a)\big]}$$

Le terme entre crochets est l'**erreur TD** :

$$\delta = r + \gamma \max_{a'} Q(s',a') - Q(s,a)$$

On peut relire la règle comme : $Q(s,a) \leftarrow Q(s,a) + \alpha \cdot \delta$, c'est-à-dire « on corrige $Q(s,a)$ dans la direction de son erreur, d'un pas de taille $\alpha$ ».

**Cas terminal.** Quand `done` est vrai (le serpent est mort sur cette transition), il n'y a pas d'état suivant à bootstrapper : la cible est simplement $r$, soit $\text{cible} = r$. L'erreur TD devient $\delta = r - Q(s,a)$ et la mise à jour pousse directement $Q(s,a)$ vers $r$.

### Le rôle de α (taux d'apprentissage)

$\alpha = 0.1$ dans Learn2Slither. Un $\alpha$ proche de 1 ferait sauter brusquement $Q(s,a)$ à la valeur cible à chaque mise à jour, effaçant l'historique des transitions passées. Un $\alpha$ très faible rendrait l'apprentissage extrêmement lent. La valeur 0.1 est un compromis classique : chaque mise à jour déplace $Q(s,a)$ de 10 % de l'écart entre la valeur actuelle et la cible.

### Le rôle de γ (facteur d'actualisation)

$\gamma = 0.9$ dans Learn2Slither. Il détermine l'importance accordée aux récompenses futures :

- $\gamma = 0$ : l'agent est myope, il n'optimise que la récompense immédiate.
- $\gamma = 1$ : toutes les récompenses futures, aussi lointaines soient-elles, comptent autant que l'immédiate.
- $\gamma = 0.9$ : une récompense reçue dans $k$ pas ne vaut que $0.9^k$ fois une récompense immédiate. Après 10 pas, elle ne pèse plus que $\approx 35\,\%$ de son montant.

Avec $\gamma = 0.9$ et un coût par pas de $-1$, accumuler 10 pas sans pomme coûte approximativement $\sum_{k=0}^{9} 0.9^k \cdot (-1) \approx -6.5$ en valeur actualisée, bien moins que la récompense verte ($+20$) escomptée.

### Pourquoi 4 096 × 4 entrées ?

L'état $s$ est un identifiant 12 bits ∈ $[0, 4095]$ (voir [étape 02](02-etat-vision.md)), donc `N_STATES = 4096`. Il y a 4 actions possibles (`UP=0, LEFT=1, DOWN=2, RIGHT=3`), donc `N_ACTIONS = 4`. La Q-table est un tableau dense `(4096, 4)` en `float32`, soit 16 384 entrées et environ 64 Ko en mémoire — parfaitement tenable.

### Exemple numérique

Supposons que l'agent se trouve dans l'état $s = 42$, prend l'action $a = \mathtt{UP}$ (0), mange une pomme verte et passe dans l'état $s' = 7$. Les valeurs courantes sont :

| $Q(42, \mathtt{UP})$ | $Q(42, \mathtt{LEFT})$ | $Q(42, \mathtt{DOWN})$ | $Q(42, \mathtt{RIGHT})$ | $\max_{a'} Q(7, \cdot)$ |
| --- | --- | --- | --- | --- |
| 2.0 | 0.5 | −1.0 | 1.5 | 3.0 |

La transition n'est pas terminale (`done = False`), la récompense est $r = +20$ (`REWARD_EAT_GREEN`).

**Cible :**
$$\text{cible} = r + \gamma \max_{a'} Q(s',a') = 20 + 0.9 \times 3.0 = 22.7$$

**Erreur TD :**
$$\delta = \text{cible} - Q(s,a) = 22.7 - 2.0 = 20.7$$

**Mise à jour :**
$$Q(42, \mathtt{UP}) \leftarrow 2.0 + 0.1 \times 20.7 = 2.0 + 2.07 = 4.07$$

La Q-valeur de `(42, UP)` passe de 2.0 à 4.07 — elle s'est rapprochée de la cible de 10 %.

### Départage aléatoire des ex æquo

Lors de l'inférence gloutonne, si plusieurs actions ont la même Q-valeur maximale, l'argmax de NumPy renverrait toujours le premier indice, créant un **biais directionnel** (tendance à toujours préférer `UP` en cas d'égalité). Le `QTableAgent` évite cela en tirant au sort parmi les actions maximales via `_greedy_action`.

---

## Dans le code

### La Q-table : `agent.py:QTableAgent`

L'attribut `q` est initialisé à zéro dans `__init__` :

```python
self.q = np.zeros((N_STATES, N_ACTIONS), dtype=np.float32)
```

Toutes les Q-valeurs démarrent à 0, ce qui est cohérent avec une politique neutre (aucune préférence initiale).

### La mise à jour : `agent.py:QTableAgent.learn`

```python
def learn(self, state, action, reward, next_state, done):
    if not self.learning:
        return
    if done:
        target = reward
    else:
        target = reward + self.gamma * float(self.q[next_state].max())
    current = float(self.q[state, action])
    self.q[state, action] = current + self.alpha * (target - current)
```

**Convention de signe :** le code calcule `target - current` (cible moins valeur actuelle), c'est-à-dire $+\delta$ dans notre notation. La mise à jour est donc `current + alpha * (target - current)`, ce qui est bien $Q(s,a) + \alpha \cdot \delta$ — ajout d'une fraction de l'erreur TD positive (note : le `NNAgent` de l'étape 06 utilisera le signe inverse, `Q(s,a) − cible`, pour sa descente de gradient explicite ; les deux sont cohérents).

Le branchement `if done` implémente directement le cas terminal : quand le serpent meurt, on ne bootstrappe pas sur `next_state` (qui ne serait plus valide) ; la cible est simplement `reward`.

### L'action gloutonne : `agent.py:QTableAgent._greedy_action`

```python
def _greedy_action(self, state):
    row = self.q[state]
    best = np.flatnonzero(row == row.max())
    return int(self.rng.choice(best))
```

`np.flatnonzero(row == row.max())` collecte tous les indices à valeur maximale ; `rng.choice` en tire un uniformément. (Le choix entre exploration et exploitation est géré dans `choose_action` — voir [étape 05](05-exploration-exploitation.md).)

### Les hyperparamètres : `config.py`

| Constante | Valeur | Rôle |
| --- | --- | --- |
| `ALPHA` | `0.1` | $\alpha$ : taux d'apprentissage |
| `GAMMA` | `0.9` | $\gamma$ : facteur d'actualisation |
| `N_STATES` | `4096` | nombre de lignes de la Q-table |
| `N_ACTIONS` | `4` | nombre de colonnes de la Q-table |

### Provenance de la transition : `game.py:_run_one_game`

La transition $(s, a, r, s', \mathtt{done})$ est assemblée par la boucle de jeu : `get_state` produit $s$, `choose_action` produit $a$, `Environment.step` produit l'événement, `get_reward` produit $r$, un second `get_state` produit $s'$, et `done` est le flag de fin de partie. Le détail complet de ce câblage est décrit dans [l'étape 07](07-architecture-code.md).

---

## À retenir

- $Q(s,a)$ estime la récompense cumulée attendue en prenant l'action $a$ dans l'état $s$ puis en jouant de façon optimale ; connaître $Q$ suffit pour agir (politique gloutonne).
- La règle de mise à jour est $Q(s,a) \leftarrow Q(s,a) + \alpha\,\delta$ avec $\delta = r + \gamma \max_{a'} Q(s',a') - Q(s,a)$ ; dans le code, cela s'écrit `current + alpha * (target - current)`.
- **Cas terminal** : quand `done` est vrai, la cible est simplement $r$ — aucun bootstrap sur l'état suivant.
- $\alpha = 0.1$ contrôle la vitesse de chaque correction ; $\gamma = 0.9$ pondère les récompenses futures (à 10 pas, un gain ne pèse plus que ~35 %).
- La Q-table a 4 096 × 4 entrées parce que l'état est un identifiant 12 bits et il y a 4 actions.
- Les ex æquo dans l'argmax sont départagés aléatoirement pour éviter tout biais directionnel.

---

## Liens

- Prérequis : [02 — L'état : la vision du serpent et l'encodage 12 bits](02-etat-vision.md)
- Prérequis : [03 — Les récompenses et le reward shaping](03-recompenses.md)
- Suite : [05 — Exploration vs exploitation : ε-greedy et décroissance](05-exploration-exploitation.md)
- Voir aussi : [06 — Le réseau de neurones : MLP, features, TD semi-gradient](06-reseau-neurones.md) (la même cible TD, mais avec approximation de fonction et signe de δ inversé dans le code)
- Voir aussi : [07 — Architecture du code et cycle de vie](07-architecture-code.md) (comment la transition est construite et passée à `learn`)
