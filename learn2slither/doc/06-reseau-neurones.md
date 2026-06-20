# 06 — Le réseau de neurones : MLP, features, TD semi-gradient, rétropropagation

> La stratégie alternative : un MLP NumPy « from scratch » 12→32→4 qui approxime
> $Q$ par un réseau entraîné par rétropropagation et descente de gradient stochastique.

**Prérequis :** [02 — L'état : la vision du serpent](02-etat-vision.md) · [04 — Q-learning tabulaire](04-q-learning-tabulaire.md) · [05 — Exploration vs exploitation](05-exploration-exploitation.md) · **Suite :** [07 — Architecture du code et cycle de vie](07-architecture-code.md)

---

## Intuition

Jusqu'ici, la fonction $Q$ était stockée dans une **table** : une case par paire $(s, a)$,
soit 4 096 × 4 = 16 384 valeurs indépendantes. Chaque mise à jour ne touche qu'une seule
case ; l'agent doit donc visiter chaque état suffisamment souvent pour que toutes les
cases convergent.

L'idée du **réseau de neurones** est différente : on remplace la table par un petit modèle
paramétré $Q(s,a;\theta)$. Donner le même état $s$ au modèle produit *simultanément* les
quatre Q-valeurs $Q(s,\text{UP}), Q(s,\text{LEFT}), Q(s,\text{DOWN}), Q(s,\text{RIGHT})$.
Quand on ajuste les paramètres $\theta$ pour corriger l'erreur sur *un* état, les paramètres
partagés influencent aussi les prédictions sur les états voisins : c'est la **généralisation**.

En pratique, le réseau apprend **plus lentement** que la table sur les premières sessions,
parce qu'une mise à jour déplace tous les paramètres à la fois (et peut déstabiliser des
prédictions déjà apprises). Avec un entraînement suffisant il devient compétitif : le modèle
`nn` atteint une longueur maximale comparable à la Q-table vers 100 sessions, et monte à
~38–40 après 1 000–5 000 sessions (les chiffres comparatifs précis sont en
[étape 08](08-entrainement-evaluation-bonus.md)).

Le réseau de Learn2Slither est écrit **entièrement en NumPy**, sans bibliothèque de deep
learning. C'est volontairement transparent : la rétropropagation et la descente de gradient
sont codées à la main, ce qui permet de lire chaque calcul ligne à ligne.

---

## En profondeur

### Les features : de l'id d'état au vecteur binaire

L'état $s \in [0, 4095]$ est un **entier 12 bits** (voir [étape 02](02-etat-vision.md)).
Un réseau de neurones ne peut pas travailler directement sur un entier comme indice ; il
lui faut un vecteur numérique. La fonction `state_to_features` réalise cette expansion :

$$\phi(s) = \bigl[\text{bit}_0(s),\ \text{bit}_1(s),\ \ldots,\ \text{bit}_{11}(s)\bigr] \in \{0,1\}^{12}$$

où $\text{bit}_i(s) = (s \gg i)\,\&\,1$. Le résultat est un vecteur `float32` de longueur 12.
Chaque composante correspond à un bit de la vision — danger dans une direction, pomme verte
en ligne, pomme rouge en ligne — exactement dans l'ordre de l'encodage décrit en
[étape 02](02-etat-vision.md).

Notation canonique : $\phi(s)$ est le **vecteur de features** (symbole $\phi(s)$ de la
table de notation partagée).

### Architecture du MLP

Le réseau est un **perceptron multicouche** (MLP) à une couche cachée :

```text
  φ(s)         couche cachée (ReLU)      sortie (linéaire)
 ┌─────┐         ┌──────────────┐         ┌──────────────┐
 │ 12  │ ──W1──▶ │     32       │ ──W2──▶ │      4       │
 │ bits│   +b1   │  (ReLU)      │   +b2   │  Q-valeurs   │
 └─────┘         └──────────────┘         └──────────────┘
    φ(s)              h                     Q(s, ·)
```

- **Entrée :** vecteur $\phi(s) \in \mathbb{R}^{12}$.
- **Couche cachée :** `NN_HIDDEN_SIZE = 32` neurones, activation ReLU.
- **Sortie :** `N_ACTIONS = 4` neurones **linéaires** — un Q-value par action.

Les paramètres du réseau sont $\theta = (W_1, b_1, W_2, b_2)$ avec :

| Paramètre | Forme | Initialisation |
| --- | --- | --- |
| $W_1$ | $(12, 32)$ | He : $\mathcal{N}(0,\, \sqrt{2/12})$ |
| $b_1$ | $(32,)$ | zéros |
| $W_2$ | $(32, 4)$ | Xavier : $\mathcal{N}(0,\, \sqrt{1/32})$ |
| $b_2$ | $(4,)$ | zéros |

L'initialisation He est adaptée aux couches ReLU (facteur $\sqrt{2/n_{\text{entrée}}}$) ;
l'initialisation Xavier (facteur $\sqrt{1/n_{\text{entrée}}}$) convient à la couche linéaire
de sortie.

### La passe avant (_forward)

La passe avant calcule les quatre Q-valeurs en deux étapes :

$$h = \mathrm{ReLU}\!\bigl(W_1^\top\,\phi(s) + b_1\bigr), \qquad Q(s,\cdot\,;\theta) = W_2^\top\,h + b_2$$

En notation de code (produits matriciels NumPy avec `features` vecteur ligne de forme `(12,)`,
$W_1$ de forme `(12, 32)`, $W_2$ de forme `(32, 4)`) :

```python
pre      = features @ self.w1 + self.b1   # (32,)
hidden   = np.maximum(pre, 0.0)           # ReLU → h, forme (32,)
q_values = hidden @ self.w2 + self.b2     # (4,)  → Q(s, ·)
```

`_forward` renvoie le couple `(hidden, q_values)`. Les deux sont nécessaires à la
rétropropagation.

### La cible TD et l'erreur semi-gradient

La **cible TD** est identique à celle du Q-learning tabulaire
([étape 04](04-q-learning-tabulaire.md), formule centrale) :

$$y = \begin{cases} r & \text{si terminal (done)} \\ r + \gamma\,\max_{a'} Q(s',a';\theta) & \text{sinon} \end{cases}$$

avec $\gamma = $ `GAMMA = 0.9`.

> **Semi-gradient :** on traite $y$ comme une **constante** lors du calcul du gradient —
> on ne propage *pas* le gradient à travers le terme $\max_{a'} Q(s',a';\theta)$ de la
> cible, même si ce terme dépend lui aussi de $\theta$. C'est pourquoi on parle de
> « semi-gradient » TD plutôt que de gradient complet.

La perte est $L = \tfrac{1}{2}\delta^2$ où l'erreur TD vaut :

$$\delta = Q(s,a;\theta) - y$$

**Convention de signe :** le code `nn_agent.py` calcule `td_error = float(q_values[action]) - target`
(prédiction **moins** cible, soit $\delta = Q - y$). C'est l'opposé de l'erreur TD tabulaire
$\delta = r + \gamma\max_{a'} Q(s',a') - Q(s,a)$ utilisée en étape 04. Les deux sont
cohérents : la mise à jour tabulaire ajoute $\alpha\delta_{\text{tabul.}}$, tandis que la
mise à jour du réseau soustrait $\eta\,\nabla_\theta L = \eta\,\delta_{\text{NN}}\,\nabla_\theta Q$
— dans les deux cas on **réduit** $Q(s,a)$ quand il est trop élevé et on **l'augmente**
quand il est trop bas.

Seule l'**unité de sortie de l'action prise** reçoit un gradient ; les trois autres
actions ont un gradient nul en sortie. C'est cohérent avec l'objectif : on n'a observé
qu'une transition pour l'action $a$, on ne sait rien de plus sur les autres actions que
ce que le réseau prédit déjà.

### Rétropropagation et mise à jour SGD

Le gradient de $L = \tfrac{1}{2}\delta^2$ se propage couche par couche.

**Couche de sortie** (seule la colonne $a$ est active) :

$$\nabla_{W_2[\,:\,,a]} = \delta\, h, \qquad \nabla_{b_2[a]} = \delta$$

Les autres colonnes de $W_2$ et les autres composantes de $b_2$ ont un gradient nul.

**Rétropropagation vers la couche cachée** (à travers ReLU) :

$$d_h = \delta\, W_2[\,:\,,a] \odot \mathbf{1}[h > 0]$$

où $\odot$ est le produit élément à élément et $\mathbf{1}[h > 0]$ est la dérivée de
ReLU (1 si l'activation était positive, 0 sinon).

**Couche d'entrée** :

$$\nabla_{W_1} = \phi(s)\, d_h^\top, \qquad \nabla_{b_1} = d_h$$

**Mise à jour SGD** (descente de gradient stochastique, un pas par transition) :

$$\theta \leftarrow \theta - \eta\, \nabla_\theta L, \qquad \eta = \texttt{NN\_LEARNING\_RATE} = 0.001$$

En code :

```python
# Gradients couche de sortie
grad_w2[:, action] = td_error * hidden   # δ · h
grad_b2[action]    = td_error            # δ

# Rétroprop à travers ReLU
d_hidden = td_error * self.w2[:, action]
d_hidden = d_hidden * (hidden > 0.0)     # masque dérivée ReLU

# Gradients couche d'entrée
grad_w1 = np.outer(features, d_hidden)   # φ(s) · d_h^T
grad_b1 = d_hidden

# Descente de gradient
self.w2 -= self.lr * grad_w2
self.b2 -= self.lr * grad_b2
self.w1 -= self.lr * grad_w1
self.b1 -= self.lr * grad_b1
```

---

## Dans le code

Tous les éléments décrits ci-dessus vivent dans `src/learn2slither/nn_agent.py`.

| Symbole code | Ce que c'est |
| --- | --- |
| `nn_agent.py:state_to_features` | $\phi(s)$ — expansion 12 bits en `float32` |
| `nn_agent.py:NNAgent.w1, b1, w2, b2` | paramètres $\theta$ du réseau |
| `nn_agent.py:NNAgent._forward` | passe avant : renvoie `(hidden, q_values)` |
| `nn_agent.py:NNAgent.q_values` | raccourci : `_forward` → extrait seulement les Q-valeurs |
| `nn_agent.py:NNAgent.learn` | une étape TD semi-gradient complète (calcul de la cible, `td_error`, backprop, SGD) |
| `nn_agent.py:NNAgent.choose_action` | politique ε-greedy (identique à `QTableAgent` — voir [étape 05](05-exploration-exploitation.md)) |
| `nn_agent.py:NNAgent.end_session` | décroissance d'$\epsilon$ (identique à `QTableAgent`) |
| `nn_agent.py:NNAgent.save` / `load` | sérialisation JSON des poids — détail en [étape 07](07-architecture-code.md) |

Constantes lues depuis `config.py` :

| Constante | Valeur | Rôle |
| --- | --- | --- |
| `NN_HIDDEN_SIZE` | 32 | nombre de neurones cachés |
| `NN_LEARNING_RATE` | 0.001 | $\eta$, pas SGD |
| `GAMMA` | 0.9 | $\gamma$, facteur d'actualisation |
| `N_ACTIONS` | 4 | taille de la sortie |

La cible TD elle-même est la même équation de Bellman qu'en `agent.py:QTableAgent.learn`
([étape 04](04-q-learning-tabulaire.md)) ; seul son utilisation diffère : dans la table on
met à jour **une case**, dans le réseau on propage le gradient à travers **tous les paramètres
connectés à l'unité active**.

---

## À retenir

- `state_to_features` extrait les 12 bits de l'id d'état en vecteur `float32` : $\phi(s) \in \{0,1\}^{12}$.
- L'architecture est $12 \to 32\ (\text{ReLU}) \to 4\ (\text{linéaire})$ ; une sortie par action, initialisée He/Xavier.
- La **cible TD** $y = r + \gamma\max_{a'} Q(s',a';\theta)$ est identique à celle du Q-learning tabulaire ([étape 04](04-q-learning-tabulaire.md)), traitée comme constante (semi-gradient).
- Le code calcule `td_error = Q(s,a) − y` (prédiction moins cible) ; le gradient est $\delta\,\nabla_\theta Q(s,a)$, appliqué **uniquement à l'unité de l'action prise**.
- La rétropropagation suit la règle de la chaîne couche par couche, avec le masque $\mathbf{1}[h>0]$ pour la dérivée de ReLU.
- Le réseau apprend plus lentement par session que la Q-table mais devient compétitif avec un entraînement prolongé (comparable à 100 sessions, ~38–40 de longueur max à 1 000–5 000 sessions).

---

## Liens

- Prérequis : [02 — L'état : la vision du serpent et l'encodage 12 bits](02-etat-vision.md)
- Prérequis : [04 — Q-learning tabulaire : équation de Bellman, mise à jour, α et γ](04-q-learning-tabulaire.md)
- Prérequis : [05 — Exploration vs exploitation : ε-greedy et la décroissance](05-exploration-exploitation.md)
- Suite : [07 — Architecture du code et cycle de vie](07-architecture-code.md)
- Voir aussi : [08 — Entraînement, modèles, évaluation et bonus](08-entrainement-evaluation-bonus.md) (performances comparées qtable vs nn, chiffres mesurés)
