"""Neural-network Q-approximator (alternate update strategy).

A small from-scratch NumPy MLP that approximates the Q-function instead of
storing it in a table. The subject permits an alternate update strategy; this is
that secondary model, so the code favors clarity over raw speed while staying
vectorized. It satisfies :class:`learn2slither.contracts.AgentP`.

The network maps the 12 bits of a state id (one float feature per bit) through a
single ReLU hidden layer to ``N_ACTIONS`` linear Q-value outputs. Updates use a
semi-gradient temporal-difference step on the taken action's output unit only.
"""

from __future__ import annotations

import json
from typing import Tuple

import numpy as np

from learn2slither.config import (
    DEFAULT_SEED,
    EPSILON_DECAY,
    EPSILON_MIN,
    EPSILON_START,
    GAMMA,
    N_ACTIONS,
    NN_HIDDEN_SIZE,
    NN_LEARNING_RATE,
    STATE_ENCODING_VERSION,
)
from learn2slither.contracts import Action

__all__ = ["NNAgent", "state_to_features"]

_N_FEATURES = 12


def state_to_features(state: int) -> np.ndarray:
    """Expand a state id into its 12-bit feature vector.

    Args:
        state: Discrete state id in ``[0, 2**12)``.

    Returns:
        A length-12 ``float32`` array where element ``i`` is bit ``i`` of
        ``state`` (least-significant bit first).
    """
    bits = (state >> np.arange(_N_FEATURES, dtype=np.int64)) & 1
    return bits.astype(np.float32)


class NNAgent:
    """Epsilon-greedy MLP Q-approximator trained with semi-gradient TD.

    The forward pass is ``features -> ReLU(W1 x + b1) -> W2 h + b2`` producing
    one Q-value per action. Learning backpropagates the squared TD error of the
    taken action through a single SGD step.

    Attributes:
        w1: Hidden-layer weights, shape ``(N_FEATURES, hidden)``.
        b1: Hidden-layer bias, shape ``(hidden,)``.
        w2: Output-layer weights, shape ``(hidden, N_ACTIONS)``.
        b2: Output-layer bias, shape ``(N_ACTIONS,)``.
        gamma: Discount factor for future reward.
        lr: SGD learning rate.
        epsilon: Current exploration probability.
        epsilon_min: Floor below which ``epsilon`` never decays.
        epsilon_decay: Multiplicative decay applied each :meth:`end_session`.
        learning: When ``False`` the agent is frozen (pure greedy, no updates).
        rng: Seeded NumPy generator used for all randomness.

    Example:
        >>> agent = NNAgent(seed=0)
        >>> action = agent.choose_action(5)
        >>> agent.learn(5, action, 1.0, 6, done=False)
    """

    def __init__(
        self,
        gamma: float = GAMMA,
        lr: float = NN_LEARNING_RATE,
        epsilon: float = EPSILON_START,
        epsilon_min: float = EPSILON_MIN,
        epsilon_decay: float = EPSILON_DECAY,
        hidden: int = NN_HIDDEN_SIZE,
        learning: bool = True,
        seed: int = DEFAULT_SEED,
    ) -> None:
        """Initialize the MLP with small seeded random weights.

        Args:
            gamma: Discount factor.
            lr: SGD learning rate.
            epsilon: Initial exploration probability.
            epsilon_min: Lower bound for ``epsilon`` after decay.
            epsilon_decay: Per-session multiplicative decay factor.
            hidden: Number of hidden units.
            learning: Whether the agent explores and updates its weights.
            seed: Seed for the internal :func:`numpy.random.default_rng`.
        """
        self.gamma = float(gamma)
        self.lr = float(lr)
        self.epsilon = float(epsilon)
        self.epsilon_min = float(epsilon_min)
        self.epsilon_decay = float(epsilon_decay)
        self.hidden = int(hidden)
        self.learning = bool(learning)
        self.rng = np.random.default_rng(seed)

        # He-style scaling for the ReLU layer, Xavier-style for the linear head.
        scale1 = np.sqrt(2.0 / _N_FEATURES)
        scale2 = np.sqrt(1.0 / self.hidden)
        self.w1 = (self.rng.standard_normal((_N_FEATURES, self.hidden)) * scale1).astype(
            np.float32
        )
        self.b1 = np.zeros(self.hidden, dtype=np.float32)
        self.w2 = (self.rng.standard_normal((self.hidden, N_ACTIONS)) * scale2).astype(
            np.float32
        )
        self.b2 = np.zeros(N_ACTIONS, dtype=np.float32)

    def _forward(self, features: np.ndarray) -> Tuple[np.ndarray, np.ndarray]:
        """Run a forward pass.

        Args:
            features: Length-12 input feature vector.

        Returns:
            A tuple ``(hidden_activation, q_values)`` where ``q_values`` has
            length ``N_ACTIONS``.
        """
        pre = features @ self.w1 + self.b1
        hidden = np.maximum(pre, 0.0)
        q_values = hidden @ self.w2 + self.b2
        return hidden, q_values

    def q_values(self, state: int) -> np.ndarray:
        """Return the predicted Q-values for ``state``.

        Args:
            state: Discrete state id.

        Returns:
            A length-``N_ACTIONS`` ``float32`` array of Q-values.
        """
        _, q_values = self._forward(state_to_features(state))
        return q_values

    def choose_action(self, state: int) -> Action:
        """Pick an action for ``state`` using an epsilon-greedy policy.

        Args:
            state: Discrete state id.

        Returns:
            The selected :class:`Action`.
        """
        if self.learning and self.rng.random() < self.epsilon:
            return Action(int(self.rng.integers(N_ACTIONS)))
        q_values = self.q_values(state)
        best = np.flatnonzero(q_values == q_values.max())
        return Action(int(self.rng.choice(best)))

    def learn(
        self,
        state: int,
        action: Action,
        reward: float,
        next_state: int,
        done: bool,
    ) -> None:
        """Apply one semi-gradient TD update for the taken action.

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

        features = state_to_features(state)
        hidden, q_values = self._forward(features)

        if done:
            target = reward
        else:
            target = reward + self.gamma * float(self.q_values(next_state).max())

        # TD error on the taken output unit; all other outputs have zero error.
        td_error = float(q_values[action]) - target

        # Gradient of 0.5 * td_error**2 w.r.t. each parameter (backprop through
        # the single active output unit, then through the ReLU hidden layer).
        grad_w2 = np.zeros_like(self.w2)
        grad_w2[:, action] = td_error * hidden
        grad_b2 = np.zeros_like(self.b2)
        grad_b2[action] = td_error

        d_hidden = td_error * self.w2[:, action]
        d_hidden = d_hidden * (hidden > 0.0)
        grad_w1 = np.outer(features, d_hidden)
        grad_b1 = d_hidden

        self.w2 -= (self.lr * grad_w2).astype(np.float32)
        self.b2 -= (self.lr * grad_b2).astype(np.float32)
        self.w1 -= (self.lr * grad_w1).astype(np.float32)
        self.b1 -= (self.lr * grad_b1).astype(np.float32)

    def end_session(self) -> None:
        """Decay ``epsilon`` toward ``epsilon_min`` once a game has ended."""
        if self.learning:
            self.epsilon = max(self.epsilon_min, self.epsilon * self.epsilon_decay)

    def save(self, path: str) -> None:
        """Serialize the network weights and hyperparameters to JSON.

        Args:
            path: Destination file path.
        """
        payload = {
            "type": "nn",
            "encoding": STATE_ENCODING_VERSION,
            "hidden": self.hidden,
            "epsilon": self.epsilon,
            "weights": {
                "w1": self.w1.tolist(),
                "b1": self.b1.tolist(),
                "w2": self.w2.tolist(),
                "b2": self.b2.tolist(),
            },
        }
        with open(path, "w", encoding="utf-8") as handle:
            json.dump(payload, handle, indent=2)

    def load(self, path: str) -> None:
        """Restore the network weights and hyperparameters from JSON.

        Args:
            path: Source file path written by :meth:`save`.

        Raises:
            ValueError: If the file is not an ``nn`` model payload.
        """
        with open(path, "r", encoding="utf-8") as handle:
            payload = json.load(handle)
        if payload.get("type") != "nn":
            raise ValueError("not an nn model file: %r" % payload.get("type"))
        self.hidden = int(payload["hidden"])
        self.epsilon = float(payload["epsilon"])
        weights = payload["weights"]
        self.w1 = np.asarray(weights["w1"], dtype=np.float32)
        self.b1 = np.asarray(weights["b1"], dtype=np.float32)
        self.w2 = np.asarray(weights["w2"], dtype=np.float32)
        self.b2 = np.asarray(weights["b2"], dtype=np.float32)
