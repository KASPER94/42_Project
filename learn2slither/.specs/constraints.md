# Learn2Slither — Constraints & Penalties

> Derived from `en.subject.pdf` (v1.00), Chapters III–IV. These are the hard rules. Violating them
> causes penalties, a non-functional verdict, or an automatic **0**.

## Score-zero rules (do not break these)

- **Model type is restricted.** You must use a **Q function** (Q-table or Neural Network). **No other
  model is allowed; otherwise a score of 0 is given.**
- **No unexpected crashes.** The program must not quit unexpectedly (apart from genuinely undefined
  behaviors). If it does, the project is considered **non-functional and receives a 0**.

## The −42 penalty rule

- You may **only provide the agent the information visible to the snake** — its head plus what it sees
  in the **4 directions**. **Providing more information results in a penalty of −42.**
  - Concretely: the agent's input/state must be derived **solely** from the 4-direction vision
    (`W H S G R 0`). Do not feed it absolute coordinates, the full board, apple positions outside the
    line of sight, etc.

## Action-space constraint

- The agent may perform **only 4 actions**: UP, LEFT, DOWN, RIGHT — nothing else.

## General / environment rules (Chapter III)

- You may use a campus computer **or** a virtual machine:
  - VM: any OS; install all required software yourself.
  - Campus: ensure all tools are installed (or installable on your account); ensure you have disk
    space (use `goinfre` if available). **Everything must be installed before the evaluation.**
- **Only the work committed to the assigned git repository is graded.** The repo is `git clone`d into
  a **new empty directory** where the runtime environment must be available (e.g., a Python `venv`).
- **Language**: free choice, but **Python is advised** (many helpful libraries). If using Python it
  **must respect the norm**:
  - `pip install flake8`
  - `alias norminette_python=flake8`

## Implementation invariants worth enforcing in code

- State fed to the agent is computed by the **Interpreter** strictly from the snake's vision.
- Reward is also computed by the Interpreter/Environment, **never** read by the agent when
  `-dontlearn` is active.
- Saved model files must round-trip: a file written by `-save` must be loadable by `-load` and
  reproduce the same agent behavior.
