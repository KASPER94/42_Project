# Learn2Slither — Mandatory Requirements

> Derived from `en.subject.pdf` (v1.00), Chapter IV "Mandatory part".

Everything below must be implemented for the project to be functional and gradable.

## 1. Environment / Board (Part 1)

- Board size: **10 cells × 10 cells**.
- **Two green apples**, each in a random cell.
- **One red apple**, in a random cell.
- Snake starts at **length 3 cells**, placed **randomly and contiguously** on the board.
- Collision rules:
  - Snake hits a **wall** → game over, training session ends.
  - Snake collides with **its own tail** → game over, training session ends.
  - Snake's length drops to **0** → game over, training session ends.
- Apple rules:
  - Eats a **green apple** → length **increases by 1**; a new green apple appears.
  - Eats a **red apple** → length **decreases by 1**; a new red apple appears.
- **Training sessions** (a.k.a. games / rounds): the main program takes a CLI parameter for **how
  many sessions** to run. Many sessions are needed for the agent to learn.
- **Graphical interface** required:
  - Displays the board and its items over time (each agent choice updates the board).
  - Display **speed must be configurable**, and **at least one human-readable speed** must exist.
  - A **step-by-step mode** must be available.
  - Color legend: **green = green apple**, **red = red apple**, **blue = snake**.

## 2. State / Snake vision (Part 2)

- The snake can **only see in the 4 directions from its head**.
- The program prints this vision to the **terminal** before asking the agent to move.
- Symbol meanings:
  - `W` = Wall
  - `H` = Snake Head
  - `S` = Snake body segment
  - `G` = Green apple
  - `R` = Red apple
  - `0` = Empty space
- ⚠️ You may **only** provide the agent the information visible to the snake (see `constraints.md`).

## 3. Action (Part 3)

- The agent can perform **only 4 actions**: **UP, LEFT, DOWN, RIGHT**.
- Decisions must be made **solely from the snake's vision (state)** — head + the 4 directions.
- The **board is displayed graphically** in a dedicated window; the **state/vision and the chosen
  action are printed in the terminal**.

## 4. Rewards (Part 4)

- You define the positive and negative rewards. A suggested scheme:
  - Eats a **red apple** → negative reward.
  - Eats a **green apple** → positive reward.
  - Eats **nothing** → smaller negative reward.
  - **Game over** (wall / self / length 0) → larger negative reward.
- The reward for an action raises/lowers the chance the agent repeats that choice in an identical
  situation.

## 5. Q-learning (Part 5)

- Implement a model using a **Q function** to evaluate the quality of an action in a given state.
  Implementable as **Q-values in a Q-table** or a **Neural Network**.
- **Updating the Q function**: adjust Q-values from the reward received after each action. You may
  train multiple models with different update approaches.
- **Exploration vs Exploitation**: sometimes take random actions to discover beneficial ones rather
  than always picking the current best.
- **Iterative learning**: repeat interact → act → receive reward → update; when a session ends, start
  a new one to continue learning.
- **Export / import models**: at any time, export a single file capturing the agent's full learning
  state (mostly the Q-values). The same file can be imported to restore the agent to that level.
- **Exploitation without learning**: a config switch that prevents learning — the agent ignores the
  board's reward and the Q function is not updated. Used to evaluate a model without altering it.
- During training, it must be possible to **remove the graphical display and terminal output** to
  speed up the process.

## 6. Technical structure (Part 6)

- The program must be **modular** to allow each part to be evaluated independently:
  **Environment → Interpreter → Agent** (see the diagram in `overview.md`).
- You choose how the modules communicate.

## 7. Command-line interface (from the turn-in examples)

Support flags equivalent to:

- `-sessions <N>` — number of training sessions.
- `-save <path>` — save the learning state to a file (e.g., `models/10sess.txt`).
- `-load <path>` — load a trained model from a file.
- `-visual on|off` — enable/disable the graphical display.
- `-dontlearn` — exploitation-without-learning mode.
- `-step-by-step` — step-by-step execution.

Example invocations:

```
$> ./snake -sessions 10 -save models/10sess.txt -visual off
$> ./snake -visual on -load models/100sess.txt -sessions 10 -dontlearn -step-by-step
$> ./snake -visual on -load models/1000sess.txt
```

Expected terminal output includes lines such as: `Game over, max length = X, max duration = Y`.
