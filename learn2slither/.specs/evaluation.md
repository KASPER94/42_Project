# Learn2Slither — Turn-in & Peer-Evaluation

> Derived from `en.subject.pdf` (v1.00), Chapter V "Turn-in and Peer-Evaluation".

## What to turn in

- Turn in your work — **board, agent, and models** — using your **Git** repository, as usual.
- **Only the work inside the repository is evaluated** during the defense.

## The `models/` folder

- You must have a **`models/` folder** containing your trained models.
- Models are saved in a **file format of your choice** (e.g., `.txt`).
- Each model can be more or less trained (few or many sessions) and may use **alternate update
  strategies** for the Q function.
- ⚠️ Training must be done **in advance** — it can take a lot of time, so generate models before the
  defense.

## Minimum models required

- At least **3 saved model files**, trained respectively with **1, 10, and 100 training sessions**.
- This must demonstrate **how the snake "learns"** as the number of sessions grows.
- You must be able to **start a new session from a saved model** in conjunction with the
  **non-learning** (`-dontlearn`) feature, to verify a model's performance without altering it.
  This will be tested during the defense.

## Expected behavior to demonstrate

Example command lines and outputs the evaluators may use:

```
$> ./snake -sessions 10 -save models/10sess.txt -visual off
...
Game over, max length = 4, max duration = 17
Save learning state in models/10sess.txt
```

```
$> ./snake -visual on -load models/100sess.txt -sessions 10 -dontlearn -step-by-step
Load trained model from models/100sess.txt
...
Game over, max length = 7, max duration = 32
```

```
$> ./snake -visual on -load models/1000sess.txt
...
Game over, max length = 12, max duration = 55
```

## Success target

- **Objective: a snake of length 10 or more by the end of the session, with an important lifetime.**
- Achieving this reliably will likely require **a lot of training sessions**.

## Practical defense checklist

- [ ] Repo clones cleanly into an empty dir and runs in the provided runtime (e.g., Python `venv`).
- [ ] `models/` contains ≥3 models (1, 10, 100 sessions) showing a clear learning progression.
- [ ] Can load any model and run with `-dontlearn` to show its true (frozen) performance.
- [ ] `-visual on/off`, `-step-by-step`, and `-sessions` all behave as shown above.
- [ ] Program never crashes unexpectedly; passes `flake8` (if Python).
