# Learn2Slither — Bonus Part

> Derived from `en.subject.pdf` (v1.00), Chapter VI "Bonus Part".

⚠️ **Bonuses are only considered if all mandatory parts are correct.** Do not invest in bonuses until
the mandatory part fully works and passes evaluation.

## List of bonuses that may be accepted

- **Higher length at the end of a session** — reaching lengths of **15, 20, 25, 30, 35**.
- **A visually stunning display** — e.g., a lobby, a configuration panel, results and statistics, etc.
- **Variable board size via arguments** — the board size can be changed with arguments, and your
  snake must be able to **play with the same trained models regardless of the board size** (this
  cross-size capability is required to validate this bonus).

## Implications for the mandatory design

If you intend to pursue the variable-board-size bonus, keep it in mind early: the agent's **state
representation must be size-independent** (it already is, since it relies only on the 4-direction
vision from the head), and the environment must accept a configurable board dimension without
breaking model load/save compatibility.
