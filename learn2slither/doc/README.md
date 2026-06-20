# Documentation Learn2Slither

Learn2Slither est un jeu Snake piloté par **apprentissage par renforcement** (Q-learning,
Python) : un agent apprend **par essai-erreur** à faire grandir le serpent, en ne voyant que la
vision de sa tête dans les quatre directions. Cette documentation explique le projet sous trois
angles — les **concepts d'IA**, les **mathématiques** et le **code** — du plus accessible au plus
détaillé. Chaque chapitre s'ouvre sur une « Intuition » avant d'« approfondir », pour un lecteur
programmeur même novice en RL.

## Table des matières

| # | Chapitre | En une ligne |
| --- | --- | --- |
| 01 | [Vue d'ensemble : le problème RL et la boucle agent–environnement](01-vue-ensemble-rl.md) | Ce qu'est le RL, la boucle Environment → Interpreter → Agent et le cadre MDP. |
| 02 | [L'état : la vision du serpent et l'encodage 12 bits](02-etat-vision.md) | Les 4 rayons depuis la tête, la règle −42 et l'id d'état dans `[0, 4095]`. |
| 03 | [Les récompenses et le reward shaping](03-recompenses.md) | Le barème (+20 / −15 / −1 / −100) et pourquoi ces choix guident l'apprentissage. |
| 04 | [Q-learning tabulaire : Bellman, mise à jour, α et γ](04-q-learning-tabulaire.md) | La Q-table et la règle de mise à jour temporelle au cœur de l'agent. |
| 05 | [Exploration vs exploitation : ε-greedy et décroissance](05-exploration-exploitation.md) | Pourquoi explorer, comment ε décroît, et le mode gelé `-dontlearn`. |
| 06 | [Le réseau de neurones : MLP, features, TD semi-gradient](06-reseau-neurones.md) | La stratégie alternative : un MLP NumPy 12→32→4 entraîné par rétropropagation. |
| 07 | [Architecture du code et cycle de vie](07-architecture-code.md) | Modules, contrats, boucle de jeu, CLI et sauvegarde/chargement des modèles. |
| 08 | [Entraînement, modèles, évaluation et bonus](08-entrainement-evaluation-bonus.md) | Entraîner, comparer les modèles, évaluer gelé, et les trois bonus. |

## Comment lire

- **Lecture linéaire (recommandée)** : 01 → 08. L'ordre va des concepts aux maths, puis au code,
  puis à la pratique ; chaque chapitre suppose les précédents.
- **Je veux juste comprendre l'idée** : lisez les sections « Intuition » de 01, 02 et 04.
- **Je connais déjà le RL** : commencez à 02 (encodage de l'état) puis 04–06 (les maths) et 07
  (le code).
- **Je veux faire tourner / évaluer le projet** : allez directement à 07 (CLI, boucle) puis 08
  (entraînement, modèles, bonus).

Pour l'installation, l'usage des commandes et les tableaux de résultats côté projet, voir le
[README du dépôt](../README.md).
