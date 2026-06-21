# Learn2Slither — préparation de la défense

> Document de travail interne (pas une exigence du sujet). À supprimer avant le
> rendu final si vous préférez un repo épuré : `git rm DEFENSE.md`.

La grille officielle est sur l'intra (login requis). Ce document reconstruit les
questions probables à partir des **exigences du sujet officiel** (version
« vision ») que ce projet implémente, et des **questions RL classiques** posées
en correction — avec les réponses ancrées dans *votre* code.

---

## 0. Le piège à connaître : deux versions du sujet

Il circule deux interprétations de Learn2Slither :

| | **Version officielle « vision »** (la vôtre) | Variante « Deep-Q » (guide leogaudin) |
|---|---|---|
| Actions | 4 absolues : UP/LEFT/DOWN/RIGHT | 3 relatives : tout droit / gauche / droite |
| État | **12 bits** de vision en croix (4 rayons × 3 bits) | 11–13 features (danger + direction + pomme) |
| Modèle imposé | **aucun** (« libre ») → Q-table tabulaire | réseau PyTorch (DQN) obligatoire |
| Affichage | **vision en croix dans le terminal** | non |

👉 **À dire au correcteur d'entrée de jeu** : « Mon projet suit le sujet officiel
basé sur la *vision* du serpent et le Q-learning tabulaire ; j'ai aussi ajouté un
agent réseau (NumPy) et un DQN PyTorch en bonus. » Ça désamorce toute confusion
si le correcteur a lu la variante Deep-Q.

---

## 1. Script de démo live (à dérouler dans l'ordre)

```bash
# 0. Environnement propre
# -- avec uv (dev, recommandé) :
uv sync                  # crée .venv + numpy/pygame/pytest/flake8
uv sync --extra dqn      # + torch (bonus DQN)
# puis préfixer les commandes par `uv run` (ex. `uv run ./snake ...`)
#
# -- avec pip (machine d'éval, sans uv) :
pip install -r requirements.txt                       # obligatoire : numpy + pygame
pip install -r requirements.txt -r requirements-dqn.txt   # + bonus DQN

# 1. Montrer la progression de l'apprentissage (modèles fournis)
./snake -load models/1sess.txt    -visual off -sessions 5 -dontlearn   # nul
./snake -load models/100sess.txt  -visual off -sessions 5 -dontlearn   # moyen
./snake -load models/1000sess.txt -visual off -sessions 5 -dontlearn   # bon

# 2. Entraîner de zéro en direct, puis sauvegarder
./snake -model qtable -visual off -sessions 100 -save models/demo.txt

# 3. Recharger et jouer en mode exploitation (pas d'apprentissage)
./snake -load models/demo.txt -visual on -speed 8 -dontlearn

# 4. Vision en croix dans le terminal + pas à pas
./snake -load models/1000sess.txt -visual on -step-by-step

# 5. Bonus : les 3 modèles
./snake -model nn  -visual off -sessions 100
./snake -model dqn -visual off -sessions 100        # nécessite torch
./snake                                              # lobby graphique (bonus)
```

Réflexe : ouvrir `-visual off` pour la vitesse (entraînement) et `-visual on`
pour montrer le comportement. `-dontlearn` gèle l'agent (epsilon ignoré, greedy).

---

## 2. État / vision — *le cœur de la correction*

**Q : Comment le serpent perçoit-il son environnement ?**
Uniquement par **4 rayons** partant de la tête (haut, gauche, bas, droite). Le
seul composant qui lit le plateau est l'`Interpreter` (`interpreter.py`) — c'est
la **règle `-42`** : l'agent ne reçoit jamais de coordonnées ni la position des
pommes hors-vision.

**Q : Comment l'état est-il encodé ? Pourquoi 4096 états ?**
Pour chaque direction, **3 bits** : `danger` (mur ou corps adjacent), `pomme
verte sur la ligne`, `pomme rouge sur la ligne`. 4 directions × 3 bits = **12
bits** → `2¹² = 4096` états (`config.N_STATES`). Voir `Interpreter.get_state` et
`_scan_ray` : danger = case adjacente, mais les pommes sont détectées **sur tout
le rayon** jusqu'au mur.

**Q : Pourquoi cet encodage et pas les coordonnées (x, y) ?**
Trois raisons : (1) respecte la règle de vision du sujet ; (2) **indépendant de
la taille du plateau** → un modèle entraîné en 10×10 marche en 15×15 (bonus
`-board-size`) ; (3) garde l'espace d'états minuscule (4096) → table exacte et
convergence rapide.

**Q : Limites de cet état ?** (question piège honnête)
Il ne distingue pas *à quelle distance* est la pomme ni la longueur du corps :
deux situations différentes peuvent partager le même id. C'est un compromis
volontaire vision/compacité. Le serpent peut donc tourner en rond → d'où le
garde-fou `MAX_STEPS_PER_SESSION = 1000`.

**Q : Montrez la vision dans le terminal.**
`render_vision` (`interpreter.py:121`) dessine la croix : colonne complète à la
verticale + ligne de la tête à l'horizontale, murs `W` aux bords, tête `H`,
corps `S`, pommes `G`/`R`. À montrer avec `-step-by-step`.

---

## 3. Q-learning — la théorie

**Q : Écrivez la règle de mise à jour.**
`Q(s,a) ← Q(s,a) + α · [ r + γ·max_a' Q(s',a') − Q(s,a) ]`, et pour un état
terminal `target = r` seulement (pas de bootstrap). Voir `agent.py:137-142`.

**Q : Que représente Q(s, a) ?**
La « qualité » espérée (récompense cumulée actualisée) de prendre l'action `a`
dans l'état `s`, puis de suivre la politique. La meilleure action = `argmax_a Q`.

**Q : Rôle de gamma (γ = 0.9) ?**
Facteur d'actualisation. Proche de 1 → l'agent valorise le futur lointain ;
proche de 0 → myope (récompense immédiate). 0.9 = bon compromis pour Snake.

**Q : Rôle d'alpha (α = 0.1) ?**
Taux d'apprentissage : de combien on corrige Q vers la cible à chaque pas. Trop
haut → instable ; trop bas → lent.

**Q : Exploration vs exploitation ? (epsilon-greedy)**
Avec proba `epsilon` → action aléatoire (exploration) ; sinon → greedy
(exploitation). `epsilon` part de **1.0**, décroît de **×0.995 par partie**
(`end_session`), plancher **0.01** (`config.py:42-44`). On garde un minimum > 0
pour ne jamais cesser totalement d'explorer.

**Q : Pourquoi décroître epsilon par *partie* et pas par *pas* ?**
Pour que le niveau d'exploration soit stable à l'intérieur d'une partie et
diminue à l'échelle de l'entraînement.

**Q : En évaluation, que vaut epsilon ?**
`-dontlearn` met `learning = False` → plus d'exploration ni de mise à jour :
politique 100 % greedy (exploitation pure).

**Q : Détail fin — pourquoi tie-break aléatoire dans l'argmax ?**
`_greedy_action` choisit au hasard parmi les Q max égaux. Sinon `argmax`
prendrait toujours la première direction → biais directionnel artificiel au
départ (toutes les Q à 0).

---

## 4. Récompenses

Valeurs dans `config.py:34-37` (mappées dans `interpreter.py:38-43`) :

| Événement | Récompense | Pourquoi |
|---|---|---|
| Pomme verte | **+20** | objectif principal (grandir) |
| Pomme rouge | **−15** | à éviter (le serpent rétrécit) |
| Pas « normal » | **−1** | pression à ne pas tourner en rond → aller au but |
| Mort | **−100** | sanction forte (mur / corps / longueur 0) |

**Q : Pourquoi un pas négatif ?** Pour décourager les boucles infinies et
pousser à trouver la pomme vite. **Q : Pourquoi la mort si punitive ?** Pour que
γ·(valeurs futures) ne « compense » jamais une collision. Ces valeurs sont
**tunables** — vous pouvez justifier les avoir réglées empiriquement.

---

## 5. Architecture du code (modularité)

Trois modules couplés **uniquement** par des `Protocol` (`contracts.py`) :
- **`Environment`** : plateau, serpent, pommes, règles (`step`, `reset`).
- **`Interpreter`** : vision → état + événement → récompense (seul à lire le
  plateau).
- **`Agent`** : le cerveau Q-learning (`choose_action`, `learn`, `save/load`).

`game.run_sessions` orchestre la boucle ; `cli.py` parse les flags. Avantage à
mettre en avant : on peut remplacer l'agent (qtable → nn → dqn) sans toucher au
reste, parce que tous respectent `AgentP`.

**Q : Comment `-load` choisit-il le bon agent ?** `make_agent` lit le champ JSON
`"type"` du fichier (`_model_type`) → instancie la bonne classe, quel que soit
`-model` (`cli.py:88-126`).

---

## 6. Sauvegarde / chargement

**Q : Format ?** JSON lisible. La Q-table ne stocke que les **lignes non nulles**
(`agent.py:158-161`) → fichier compact. Round-trip exact testé.
**Q : Montrez qu'un modèle chargé rejoue pareil.** `-load ... -dontlearn` →
comportement déterministe (seed fixe `DEFAULT_SEED = 42`).

---

## 7. Les 3 modèles (bonus) — savoir les comparer

| | Q-table (`agent.py`) | NN NumPy (`nn_agent.py`) | DQN PyTorch (`dqn_agent.py`) |
|---|---|---|---|
| Stockage de Q | table 4096×4 | poids MLP (12→32→4) | poids MLP (12→64→64→4), ×2 réseaux |
| Échantillons | transition courante | transition courante | **mini-batch du replay buffer** |
| Cible | `max q[s']` | `max Q(s')` (même réseau) | `max Q⁻(s')` (**target net figé**) |
| Stabilité | garantie (preuve) | moyenne (cible mouvante) | bonne (replay + target) |
| Sur ce sujet | **optimal** | démonstratif | sur-dimensionné |

**Phrase clé** : « Sur 4096 états discrets, la **Q-table est optimale** (prouvée,
rapide, lisible) ; le NN montre l'approximation de Q ; le DQN ajoute les deux
mécanismes (experience replay + target network) qui stabilisent l'apprentissage
par réseau — utile seulement si l'état devenait grand/continu. »

**Q (DQN) : à quoi sert l'experience replay ?** Casser la corrélation entre
transitions consécutives et réutiliser chaque expérience plusieurs fois.
**Q : à quoi sert le target network ?** Calculer une cible *stable* : sinon on
poursuit une cible qui bouge à chaque pas (oscillations). Sync tous les 500 pas.
**Q : pourquoi torch est-il optionnel ?** Import *lazy* (`cli._agent_for_type`) :
qtable/nn tournent sans torch ; seul `-model dqn` le charge.

---

## 8. Qualité / norme

- **flake8 clean** sur `src` + `tests` (`setup.cfg`, max-line 99).
- **80 tests pytest** verts (`pytest -q`). Les tests DQN se *skippent* si torch
  absent (`importorskip`).
- Tourne **directement depuis le clone** (`./snake`), aucune install du paquet.
- `Ctrl-C` propre : `KeyboardInterrupt` rattrapé, `-save` honoré en `finally`
  (`cli.py:215-233`).

---

## 9. Questions pièges fréquentes

1. **« Et si je change la taille du plateau ? »** → état indépendant de la
   taille ; un modèle 10×10 marche en 15×15 (`-board-size`, bonus).
2. **« Le serpent tourne en rond, pourquoi ? »** → l'état vision ne porte pas la
   distance ; garde-fou `MAX_STEPS_PER_SESSION`; le pas négatif y pousse contre.
3. **« Pourquoi pas un réseau partout ? »** → table optimale sur 4096 états ;
   un réseau n'apporterait rien ici, juste de l'instabilité. (Inverser le
   raisonnement pour un état pixel/continu.)
4. **« Convergence garantie ? »** → oui pour le Q-learning tabulaire (conditions
   de Robbins-Monro) ; non pour l'approximation par réseau.
5. **« Différence entre `-dontlearn` et epsilon = 0 ? »** → `-dontlearn` coupe
   *aussi* les mises à jour de Q, pas seulement l'exploration.
6. **« Montrez un état précis et décodez ses 12 bits. »** → savoir lire
   `state = bits_UP | bits_LEFT<<3 | bits_DOWN<<6 | bits_RIGHT<<9`.

---

## 10. Points faibles à assumer (honnêteté = points)

- L'état ne distingue pas la distance aux pommes ni la longueur du corps.
- Pas d'experience replay sur la Q-table ni le NN (volontaire / simplicité).
- Les valeurs de récompense sont réglées empiriquement, pas optimisées.
- Le DQN est sur-dimensionné pour ce problème — c'est un bonus pédagogique
  assumé, pas le meilleur modèle ici.
