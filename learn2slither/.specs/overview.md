# Learn2Slither — Overview

> Derived from `en.subject.pdf` (v1.00). Source of truth is the PDF; this folder is a working
> reorganization of it into actionable specs.

## What this project is

An **Artificial Intelligence / Reinforcement Learning** project: a snake moves on a board and is
controlled by an intelligent agent that learns **by trial and error**. Each action the agent takes
yields positive or negative feedback (a reward) from the board. Over many training sessions the
agent adapts to maximize cumulative reward.

## The objective

- The snake must reach a length of **at least 10 cells** and **stay alive as long as possible**.
- An untrained agent fails quickly; reaching the goal requires **hundreds to thousands** of training
  sessions (configurable via the CLI).

## The reinforcement-learning loop

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

The mandated modular structure has three parts (find the most effective way for them to
communicate):

- **Environment** — the board, snake, apples, and game rules.
- **Interpreter** — turns the board into the snake's "vision" (state) and computes the reward.
- **Agent** — the Q-learning brain that picks an action from the state.

## The spec files in this folder

| File | Contents |
| --- | --- |
| `overview.md` | This file — goal, the RL loop, architecture, map of the spec. |
| `mandatory-requirements.md` | Everything that must be implemented to pass. |
| `constraints.md` | Hard rules and penalties (the things that score you 0 or −42). |
| `evaluation.md` | Turn-in format, peer-evaluation expectations, CLI examples. |
| `bonus.md` | Optional extras, only graded if the mandatory part is complete. |

## At a glance

- Board: **10×10**, **2 green apples**, **1 red apple**, snake starts at **length 3**.
- Green apple = grow (+1), red apple = shrink (−1). Wall / self-collision / length 0 = **game over**.
- State = the snake's **vision in 4 directions from its head** only (`W H S G R 0`).
- Actions = **UP, LEFT, DOWN, RIGHT** only.
- Model = **Q-learning (Q-table or neural network)** — nothing else is allowed.
- Python advised; must pass `flake8`.
