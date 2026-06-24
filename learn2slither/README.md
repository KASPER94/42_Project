# Learn2Slither

A reinforcement-learning snake. An agent learns **by trial and error** to play
Snake on a 10×10 board, seeing only its head's vision in the four cardinal
directions. Each move yields a reward (eat a green apple, hit a wall, etc.), and
over many training sessions the agent's Q-function adapts to maximize cumulative
reward. **Success objective: grow the snake to a length of 10 or more in a single
game while staying alive as long as possible.** A trained 1000-session model
clears this target comfortably in frozen play (see [Models](#models)).

## Architecture

The mandated three-part modular loop `Environment → Interpreter → Agent`, with
the contract types (`Action`, `Event`, `StepResult`, and the `…P` Protocols) in
[`src/learn2slither/contracts.py`](src/learn2slither/contracts.py) as the only
coupling between modules.

| Role | Module | One-liner |
| --- | --- | --- |
| **Environment** | [`environment.py`](src/learn2slither/environment.py) | The board, snake, apples and rules; resets games and resolves each `step`. |
| **Interpreter** | [`interpreter.py`](src/learn2slither/interpreter.py) | Turns the board into the snake's vision (the state id) and maps each event to a scalar reward. |
| **Agent** | [`agent.py`](src/learn2slither/agent.py) (Q-table) / [`nn_agent.py`](src/learn2slither/nn_agent.py) (neural net) | The Q-learning brain: picks an action from the state and updates its Q-function. |

Supporting modules: [`game.py`](src/learn2slither/game.py) (the session loop /
orchestrator), [`cli.py`](src/learn2slither/cli.py) (flag parsing & wiring),
[`visualizer.py`](src/learn2slither/visualizer.py) (pygame display, imported only
when `-visual on`), and [`config.py`](src/learn2slither/config.py) (single source
of truth for every tunable constant).

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

## State encoding (vision-only, 12-bit)

The Interpreter fires four rays from the snake's head — UP, LEFT, DOWN, RIGHT —
and packs **3 bits per direction**: *danger* (an adjacent wall or body cell),
*green apple in line of sight*, and *red apple in line of sight*. Four directions
× 3 bits = a **12-bit state id in `[0, 4095]`** (4096 discrete states).

The agent **only** ever receives this id. It never sees coordinates, off-vision
apple positions, or anything outside the four rays, so the encoding respects the
**−42 rule** (no cheating with hidden board knowledge). Because the bits describe
relative line-of-sight rather than absolute positions, the same state space and
the same trained model work unchanged on any board size (the `-board-size` bonus).

## Setup

```bash
python3 -m venv venv
source venv/bin/activate
pip install -r requirements.txt
```

Requirements: `numpy`, `pygame` (only needed for `-visual on`), `pytest`,
`flake8`. The repo runs straight from a clone — `./snake` puts `src/` on the
import path itself, no install step required.

## Usage

```bash
./snake -sessions 100 -visual on            # train and watch
./snake -load models/1000sess.txt -visual off   # play a trained model headless
```

| Flag | Meaning | Default |
| --- | --- | --- |
| `-sessions N` | Number of games to play (train or evaluate). | `1` |
| `-save PATH` | Save the learning state to `PATH` after the run. | *(none)* |
| `-load PATH` | Load a saved model before running (agent type is read from the file). | *(none)* |
| `-visual on\|off` | Enable/disable the pygame display. `off` is headless (no display needed). | `on` |
| `-dontlearn` | Freeze the agent: pure greedy exploitation, no Q-updates, no exploration. | off |
| `-step-by-step` | Advance one step per user input (keypress with a window, Enter when headless). | off |
| `-speed N` | Display speed in frames/steps per second (visual mode). | `10` |
| `-board-size N` | Board side length in cells (bonus; the model is board-size independent). | `10` |
| `-model qtable\|nn` | Agent type for a fresh run. Ignored when `-load` is given. | `qtable` |

A run prints `Game over, max length = X, max duration = Y` (the maxima across all
sessions) at the end. Loading prints `Load trained model from PATH`; saving prints
`Save learning state in PATH`. Runs are deterministic (seed `42`), so the same
command produces the same output every time.

## Troubleshooting — segfault with the GUI + DQN on Linux/Fedora

The optional DQN agent (`-model dqn`) depends on `torch` (see
`requirements-dqn.txt`). On Linux — Fedora in particular — running it **with the
pygame window open** can segfault, while headless (`-visual off`) and the
qtable/nn agents are fine. The cause is a native C++ runtime clash: SDL opens an
OpenGL window through Mesa (built against the system `libstdc++`), but the pip
`torch` wheel ships its own `libstdc++`/`libgomp`, and the two collide in one
process.

Launch with one of these workarounds (the first usually suffices):

```bash
# Force the system libstdc++ so torch and Mesa share one C++ runtime (best fix)
LD_PRELOAD=/usr/lib64/libstdc++.so.6 ./snake

# If that path differs on your machine, find it first:
ldconfig -p | grep libstdc++

# Fallbacks:
LIBGL_ALWAYS_SOFTWARE=1 ./snake        # software Mesa rendering (skip the GPU driver)
SDL_VIDEODRIVER=x11 ./snake            # force X11 instead of Wayland (Fedora default)

# Most robust combination:
LD_PRELOAD=/usr/lib64/libstdc++.so.6 LIBGL_ALWAYS_SOFTWARE=1 ./snake
```

The mandatory qtable/nn agents never import `torch`, so they are unaffected; only
the bonus DQN agent with the display enabled needs this.

## Example invocations

These are the three command blocks from `.specs/evaluation.md`.

```text
$> ./snake -sessions 10 -save models/10sess.txt -visual off
...
Game over, max length = 4, max duration = 17
Save learning state in models/10sess.txt
```
*Train a fresh Q-table for 10 sessions headless and persist it.*

```text
$> ./snake -visual on -load models/100sess.txt -sessions 10 -dontlearn -step-by-step
Load trained model from models/100sess.txt
...
Game over, max length = 7, max duration = 32
```
*Load a trained model and watch it play frozen, advancing one step at a time —
its true performance without any further learning.*

```text
$> ./snake -visual on -load models/1000sess.txt
...
Game over, max length = 12, max duration = 55
```
*Load the strongly-trained model and play a single game with the display on.*

(Exact lengths/durations depend on the trained models in this repo — see below.)

## Models

The `models/` folder ships pre-trained models (training is done in advance, as
the subject requires). Each is a separate fresh run of `N` sessions, so the
1 → 10 → 100 → 1000 progression demonstrates how the snake learns as sessions
grow. Files are JSON stored in `.txt`, tagged with a top-level `"type"`.

The `max length` / `max duration` columns below are measured by **loading each
model frozen** (`-dontlearn`) and playing a 100-game batch on the default 10×10:

```bash
./snake -load models/<file> -dontlearn -visual off -sessions 100
```

| File | Type | Sessions | Eval max length | Eval max duration |
| --- | --- | --- | --- | --- |
| `models/1sess.txt` | qtable | 1 | 4 | 12 |
| `models/10sess.txt` | qtable | 10 | 4 | 16 |
| `models/100sess.txt` | qtable | 100 | 5 | 28 |
| `models/1000sess.txt` | qtable | 1000 | **31** | 1000 |
| `models/5000sess.txt` | qtable | 5000 | **46** | 1000 |
| `models/nn_100sess.txt` | nn | 100 | 5 | 1000 |
| `models/nn_1000sess.txt` | nn | 1000 | **38** | 1000 |
| `models/nn_5000sess.txt` | nn | 5000 | **40** | 378 |

The trend is clearly upward with training. The 1000- and 5000-session Q-tables
blow past the length-≥10 objective (31 and 46). A `max duration` of `1000` is the
per-session step cap (`MAX_STEPS_PER_SESSION`): the snake survived the entire
session, i.e. it learned to stay alive indefinitely.

The `nn_*` files are the **alternate update strategy** — a from-scratch NumPy MLP
Q-approximator instead of a table. It learns more slowly per session (at 100
sessions it ties the table at length 5), but with enough training it is fully
competitive: **38 at 1000 sessions, 40 at 5000** — on par with (here even ahead
of) the tabular agent. So the NN is not weaker by nature, only slower to train.

## Bonus

All three bonuses from the subject (Chapter VI) are implemented. Bonuses only
count once the mandatory part is correct — it is (full `pytest` suite green,
`flake8` clean).

### 1. High length at the end of a session (tiers 15 / 20 / 25 / 30 / 35)

The trained Q-table clears every tier with room to spare. Frozen, 100-game batch
on 10×10: **max length 46** (`models/5000sess.txt`) and **31** (`models/1000sess.txt`)
— both well beyond the top tier of 35.

### 2. Visually rich display — lobby + configuration panel + live stats

Launch the graphical configuration lobby with no arguments, or with `-menu`:

```bash
./snake            # opens the lobby
./snake -menu
```

The lobby sets sessions / speed / board size / model to load / qtable-vs-nn /
"don't learn" with the mouse, then **Start**. During play a right-side panel
shows live stats — session `i/N`, length, max length, duration, total reward,
epsilon (or `frozen`), speed — with controls: **Space** pause, **↑/↓** speed,
**→** single step, **Esc** quit. (Implemented in
[`menu.py`](src/learn2slither/menu.py) and the panel in
[`visualizer.py`](src/learn2slither/visualizer.py); the CLI is unchanged when
flags are passed.)

### 3. Variable board size — the same model plays on any size

`-board-size N` changes the board. Because the state is pure 4-direction vision
(12-bit, no coordinates), a model trained on 10×10 plays **unchanged** on any
size. Verified with the SAME `models/5000sess.txt`, frozen, 100-game batches:

| Board | max length | max duration |
| --- | --- | --- |
| 10×10 | 46 | 1000 |
| 15×15 | 51 | 1000 |
| 20×20 | 52 | 1000 |

```bash
./snake -load models/5000sess.txt -visual on -board-size 15
```

This cross-size property is locked by automated tests in
[`tests/test_bonus.py`](tests/test_bonus.py).

## Defense checklist

Mirrors `.specs/evaluation.md`:

- [x] Repo clones cleanly into an empty dir and runs in the provided `venv`
      (`python3 -m venv venv && pip install -r requirements.txt`).
- [x] `models/` contains ≥3 models (1, 10, 100 sessions, plus 1000, 5000 and an
      NN model) showing a clear learning progression in the table above.
- [x] Any model can be loaded and run with `-dontlearn` to show its frozen
      performance; loading a model and running without `-save` leaves the file
      byte-identical (verified by checksum).
- [x] `-visual on/off`, `-step-by-step`, `-speed`, `-board-size` and `-sessions`
      all behave as documented.
- [x] The program never crashes: a clean quit / `KeyboardInterrupt` is handled
      and still honors `-save`.
- [x] Deterministic seed (`42`) — the same command yields identical output on
      repeat runs (reproducibility verified).
- [x] Passes `flake8` with zero errors and the full `pytest` suite is green.
- [x] All three bonuses done: high length (46), lobby + live-stats display,
      variable board size with the same model (see [Bonus](#bonus)).

## Norm

`flake8` is the project's norminette and passes clean across `src`, `tests` and
`snake`. The line length limit is `max-line-length = 99`, configured in
[`setup.cfg`](setup.cfg).

```bash
python -m flake8 src tests snake   # 0 errors
python -m pytest -q                # 69 passed
```
