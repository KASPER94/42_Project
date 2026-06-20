"""Tabular Q-learning agent.

This is the primary learning brain: a classic Q-table mapping each of the
``N_STATES`` discrete vision states to a vector of ``N_ACTIONS`` Q-values. It
satisfies :class:`learn2slither.contracts.AgentP` so the orchestrator can drive
it without knowing the concrete type.
"""

from __future__ import annotations

import json
from typing import Dict, List

import numpy as np

from learn2slither.config import (
    ALPHA,
    DEFAULT_SEED,
    EPSILON_DECAY,
    EPSILON_MIN,
    EPSILON_START,
    GAMMA,
    N_ACTIONS,
    N_STATES,
    STATE_ENCODING_VERSION,
)
from learn2slither.contracts import Action

__all__ = ["QTableAgent"]


class QTableAgent:
    """Epsilon-greedy tabular Q-learning agent.

    The Q-function is a dense ``(N_STATES, N_ACTIONS)`` array of ``float32``.
    Exploration follows an epsilon-greedy policy that decays once per game; ties
    among the greedy maxima are broken randomly so the agent does not develop a
    directional bias from ``argmax``.

    Attributes:
        q: The Q-table, shape ``(N_STATES, N_ACTIONS)``, ``dtype=float32``.
        alpha: Learning rate for the temporal-difference update.
        gamma: Discount factor for future reward.
        epsilon: Current exploration probability.
        epsilon_min: Floor below which ``epsilon`` never decays.
        epsilon_decay: Multiplicative decay applied each :meth:`end_session`.
        learning: When ``False`` the agent is frozen (pure greedy, no updates).
        rng: Seeded NumPy generator used for all randomness.

    Example:
        >>> agent = QTableAgent(seed=0)
        >>> action = agent.choose_action(0)
        >>> agent.learn(0, action, 1.0, 1, done=False)
    """

    def __init__(
        self,
        alpha: float = ALPHA,
        gamma: float = GAMMA,
        epsilon: float = EPSILON_START,
        epsilon_min: float = EPSILON_MIN,
        epsilon_decay: float = EPSILON_DECAY,
        learning: bool = True,
        seed: int = DEFAULT_SEED,
    ) -> None:
        """Initialize the agent with a zeroed Q-table.

        Args:
            alpha: Learning rate.
            gamma: Discount factor.
            epsilon: Initial exploration probability.
            epsilon_min: Lower bound for ``epsilon`` after decay.
            epsilon_decay: Per-session multiplicative decay factor.
            learning: Whether the agent explores and updates its Q-table.
            seed: Seed for the internal :func:`numpy.random.default_rng`.
        """
        self.q = np.zeros((N_STATES, N_ACTIONS), dtype=np.float32)
        self.alpha = float(alpha)
        self.gamma = float(gamma)
        self.epsilon = float(epsilon)
        self.epsilon_min = float(epsilon_min)
        self.epsilon_decay = float(epsilon_decay)
        self.learning = bool(learning)
        self.rng = np.random.default_rng(seed)

    def choose_action(self, state: int) -> Action:
        """Pick an action for ``state`` using an epsilon-greedy policy.

        When learning and a uniform draw falls below ``epsilon`` a random action
        is returned. Otherwise the greedy action is chosen, breaking ties among
        the maximum Q-values uniformly at random.

        Args:
            state: Discrete state id in ``[0, N_STATES)``.

        Returns:
            The selected :class:`Action`.
        """
        if self.learning and self.rng.random() < self.epsilon:
            return Action(int(self.rng.integers(N_ACTIONS)))
        return Action(self._greedy_action(state))

    def _greedy_action(self, state: int) -> int:
        """Return the argmax action for ``state`` with random tie-breaking.

        Args:
            state: Discrete state id in ``[0, N_STATES)``.

        Returns:
            The integer index of a maximal Q-value.
        """
        row = self.q[state]
        best = np.flatnonzero(row == row.max())
        return int(self.rng.choice(best))

    def learn(
        self,
        state: int,
        action: Action,
        reward: float,
        next_state: int,
        done: bool,
    ) -> None:
        """Apply one tabular Q-learning update from a transition.

        No-op when the agent is frozen (``learning`` is ``False``).

        Args:
            state: State the action was taken from.
            action: Action that was taken.
            reward: Reward received for the transition.
            next_state: State reached after the action.
            done: Whether the episode terminated on this transition.
        """
        if not self.learning:
            return
        if done:
            target = reward
        else:
            target = reward + self.gamma * float(self.q[next_state].max())
        current = float(self.q[state, action])
        self.q[state, action] = current + self.alpha * (target - current)

    def end_session(self) -> None:
        """Decay ``epsilon`` toward ``epsilon_min`` once a game has ended."""
        if self.learning:
            self.epsilon = max(self.epsilon_min, self.epsilon * self.epsilon_decay)

    def save(self, path: str) -> None:
        """Serialize the Q-table and hyperparameters to a JSON file.

        Only non-zero Q-table rows are stored to keep the file small and
        human-readable. See the module docstring of the loader for the schema.

        Args:
            path: Destination file path.
        """
        rows: Dict[str, List[float]] = {}
        nonzero_states = np.flatnonzero(np.any(self.q != 0.0, axis=1))
        for state in nonzero_states:
            rows[str(int(state))] = [float(v) for v in self.q[state]]
        payload = {
            "type": "qtable",
            "encoding": STATE_ENCODING_VERSION,
            "alpha": self.alpha,
            "gamma": self.gamma,
            "epsilon": self.epsilon,
            "q": rows,
        }
        with open(path, "w", encoding="utf-8") as handle:
            json.dump(payload, handle, indent=2)

    def load(self, path: str) -> None:
        """Restore the Q-table and hyperparameters from a JSON file.

        Rebuilds the zeroed table then fills the stored non-zero rows so the
        round-trip is exact (within float tolerance).

        Args:
            path: Source file path written by :meth:`save`.

        Raises:
            ValueError: If the file is not a Q-table payload.
        """
        with open(path, "r", encoding="utf-8") as handle:
            payload = json.load(handle)
        if payload.get("type") != "qtable":
            raise ValueError("not a qtable model file: %r" % payload.get("type"))
        self.alpha = float(payload["alpha"])
        self.gamma = float(payload["gamma"])
        self.epsilon = float(payload["epsilon"])
        self.q = np.zeros((N_STATES, N_ACTIONS), dtype=np.float32)
        for state_str, values in payload["q"].items():
            self.q[int(state_str)] = np.asarray(values, dtype=np.float32)
