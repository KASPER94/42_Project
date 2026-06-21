"""Deep Q-Network agent (PyTorch, optional dependency).

This is the third learning brain. Like :class:`learn2slither.nn_agent.NNAgent`
it approximates the Q-function with a small MLP over the 12-bit vision state,
but it adds the two mechanisms that make value-function approximation stable:

* **Experience replay** -- transitions are stored in a fixed-size buffer and the
  network trains on random mini-batches, breaking the temporal correlation of
  consecutive steps and reusing each experience many times.
* **Target network** -- a frozen copy of the network computes the bootstrap
  target ``r + gamma * max_a' Q-(s', a')`` and is only synced every
  ``DQN_TARGET_UPDATE`` learn steps, so the target stops chasing its own tail.

``torch`` is imported at module level, so this module must only ever be imported
lazily (see :func:`learn2slither.cli._agent_for_type`); the mandatory qtable/nn
agents stay torch-free. The class satisfies
:class:`learn2slither.contracts.AgentP`.
"""

from __future__ import annotations

import json
from collections import deque
from typing import Deque, Tuple

import numpy as np
import torch
from torch import nn

from learn2slither.config import (
    DEFAULT_SEED,
    DQN_BATCH_SIZE,
    DQN_BUFFER_SIZE,
    DQN_HIDDEN_SIZE,
    DQN_LEARNING_RATE,
    DQN_TARGET_UPDATE,
    DQN_WARMUP,
    EPSILON_DECAY,
    EPSILON_MIN,
    EPSILON_START,
    GAMMA,
    N_ACTIONS,
    STATE_ENCODING_VERSION,
)
from learn2slither.contracts import Action
from learn2slither.nn_agent import state_to_features

__all__ = ["DQNAgent", "QNetwork"]

_N_FEATURES = 12
_Transition = Tuple[int, int, float, int, bool]


class QNetwork(nn.Module):
    """Two-hidden-layer MLP mapping the 12-bit state to one Q-value per action.

    Attributes:
        net: The underlying ``torch.nn.Sequential`` stack.
    """

    def __init__(self, hidden: int = DQN_HIDDEN_SIZE) -> None:
        """Build the network.

        Args:
            hidden: Width of each of the two hidden layers.
        """
        super().__init__()
        self.net = nn.Sequential(
            nn.Linear(_N_FEATURES, hidden),
            nn.ReLU(),
            nn.Linear(hidden, hidden),
            nn.ReLU(),
            nn.Linear(hidden, N_ACTIONS),
        )

    def forward(self, x: torch.Tensor) -> torch.Tensor:
        """Return Q-values for a batch of feature vectors.

        Args:
            x: Float tensor of shape ``(batch, 12)``.

        Returns:
            Float tensor of shape ``(batch, N_ACTIONS)``.
        """
        return self.net(x)


class DQNAgent:
    """Epsilon-greedy DQN with experience replay and a target network.

    The agent keeps two networks: an online network trained every step on a
    random mini-batch, and a target network used to compute the bootstrap
    target and synced from the online network every ``target_update`` steps.

    Attributes:
        online: The network being trained.
        target: The frozen network used for bootstrap targets.
        buffer: Replay buffer of ``(s, a, r, s', done)`` transitions.
        gamma: Discount factor for future reward.
        epsilon: Current exploration probability.
        epsilon_min: Floor below which ``epsilon`` never decays.
        epsilon_decay: Multiplicative decay applied each :meth:`end_session`.
        learning: When ``False`` the agent is frozen (greedy, no updates).
        rng: Seeded NumPy generator used for action sampling and replay draws.

    Example:
        >>> agent = DQNAgent(seed=0)
        >>> a = agent.choose_action(5)
        >>> agent.learn(5, a, 1.0, 6, done=False)
    """

    def __init__(
        self,
        gamma: float = GAMMA,
        lr: float = DQN_LEARNING_RATE,
        epsilon: float = EPSILON_START,
        epsilon_min: float = EPSILON_MIN,
        epsilon_decay: float = EPSILON_DECAY,
        hidden: int = DQN_HIDDEN_SIZE,
        buffer_size: int = DQN_BUFFER_SIZE,
        batch_size: int = DQN_BATCH_SIZE,
        target_update: int = DQN_TARGET_UPDATE,
        warmup: int = DQN_WARMUP,
        learning: bool = True,
        seed: int = DEFAULT_SEED,
    ) -> None:
        """Initialize the networks, optimizer and replay buffer.

        Args:
            gamma: Discount factor.
            lr: Adam learning rate.
            epsilon: Initial exploration probability.
            epsilon_min: Lower bound for ``epsilon`` after decay.
            epsilon_decay: Per-session multiplicative decay factor.
            hidden: Width of each hidden layer.
            buffer_size: Replay buffer capacity in transitions.
            batch_size: Number of transitions sampled per learn step.
            target_update: Learn steps between target-network syncs.
            warmup: Transitions to collect before training begins.
            learning: Whether the agent explores and updates its weights.
            seed: Seed for torch and the internal NumPy generator.
        """
        torch.manual_seed(seed)
        self.gamma = float(gamma)
        self.epsilon = float(epsilon)
        self.epsilon_min = float(epsilon_min)
        self.epsilon_decay = float(epsilon_decay)
        self.hidden = int(hidden)
        self.batch_size = int(batch_size)
        self.target_update = int(target_update)
        self.warmup = int(warmup)
        self.learning = bool(learning)
        self.rng = np.random.default_rng(seed)

        self.online = QNetwork(self.hidden)
        self.target = QNetwork(self.hidden)
        self.target.load_state_dict(self.online.state_dict())
        self.target.eval()
        self.optimizer = torch.optim.Adam(self.online.parameters(), lr=float(lr))
        self.loss_fn = nn.SmoothL1Loss()  # Huber loss, robust to outlier targets

        self.buffer: Deque[_Transition] = deque(maxlen=int(buffer_size))
        self._learn_steps = 0

    def _features(self, state: int) -> torch.Tensor:
        """Return the 1x12 float tensor for a single state id."""
        feats = state_to_features(state)
        return torch.from_numpy(feats).unsqueeze(0)

    def choose_action(self, state: int) -> Action:
        """Pick an action using an epsilon-greedy policy.

        When learning and a uniform draw falls below ``epsilon`` a random action
        is returned; otherwise the greedy action is chosen, breaking ties among
        the maximal Q-values uniformly at random.

        Args:
            state: Discrete state id.

        Returns:
            The selected :class:`Action`.
        """
        if self.learning and self.rng.random() < self.epsilon:
            return Action(int(self.rng.integers(N_ACTIONS)))
        with torch.no_grad():
            q_values = self.online(self._features(state)).squeeze(0).numpy()
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
        """Store the transition and take one mini-batch gradient step.

        No-op when frozen. Training is skipped until the buffer holds at least
        ``warmup`` transitions, so the first updates are not dominated by a tiny,
        highly-correlated sample. The target network is synced every
        ``target_update`` learn steps.

        Args:
            state: State the action was taken from.
            action: Action that was taken.
            reward: Reward received for the transition.
            next_state: State reached after the action.
            done: Whether the episode terminated on this transition.
        """
        if not self.learning:
            return
        self.buffer.append((int(state), int(action), float(reward), int(next_state), bool(done)))
        if len(self.buffer) < max(self.warmup, self.batch_size):
            return
        self._train_step()

    def _sample_batch(self):
        """Sample a mini-batch from the buffer as stacked tensors.

        Returns:
            A tuple ``(states, actions, rewards, next_states, dones)`` of
            tensors ready for the loss computation.
        """
        idx = self.rng.integers(len(self.buffer), size=self.batch_size)
        batch = [self.buffer[int(i)] for i in idx]
        states = np.stack([state_to_features(t[0]) for t in batch])
        next_states = np.stack([state_to_features(t[3]) for t in batch])
        actions = torch.tensor([t[1] for t in batch], dtype=torch.int64).unsqueeze(1)
        rewards = torch.tensor([t[2] for t in batch], dtype=torch.float32).unsqueeze(1)
        dones = torch.tensor([t[4] for t in batch], dtype=torch.float32).unsqueeze(1)
        return (
            torch.from_numpy(states),
            actions,
            rewards,
            torch.from_numpy(next_states),
            dones,
        )

    def _train_step(self) -> None:
        """Run one gradient step on a replayed mini-batch and sync the target."""
        states, actions, rewards, next_states, dones = self._sample_batch()

        # Q(s, a) for the taken actions.
        q_taken = self.online(states).gather(1, actions)

        # Bootstrap target from the frozen target network; zeroed past terminals.
        with torch.no_grad():
            max_next = self.target(next_states).max(dim=1, keepdim=True).values
            target = rewards + self.gamma * max_next * (1.0 - dones)

        loss = self.loss_fn(q_taken, target)
        self.optimizer.zero_grad()
        loss.backward()
        self.optimizer.step()

        self._learn_steps += 1
        if self._learn_steps % self.target_update == 0:
            self.target.load_state_dict(self.online.state_dict())

    def end_session(self) -> None:
        """Decay ``epsilon`` toward ``epsilon_min`` once a game has ended."""
        if self.learning:
            self.epsilon = max(self.epsilon_min, self.epsilon * self.epsilon_decay)

    def save(self, path: str) -> None:
        """Serialize the online weights and hyperparameters to JSON.

        Weights are stored as nested lists (not a pickled ``state_dict``) so the
        file stays JSON like the other models and ``cli._model_type`` can read
        its ``"type"`` field to pick the right agent on ``-load``.

        Args:
            path: Destination file path.
        """
        weights = {k: v.tolist() for k, v in self.online.state_dict().items()}
        payload = {
            "type": "dqn",
            "encoding": STATE_ENCODING_VERSION,
            "hidden": self.hidden,
            "epsilon": self.epsilon,
            "weights": weights,
        }
        with open(path, "w", encoding="utf-8") as handle:
            json.dump(payload, handle, indent=2)

    def load(self, path: str) -> None:
        """Restore the network weights and hyperparameters from JSON.

        Rebuilds both networks at the saved hidden size, loads the weights into
        the online network and copies them into the (frozen) target network.

        Args:
            path: Source file path written by :meth:`save`.

        Raises:
            ValueError: If the file is not a ``dqn`` model payload.
        """
        with open(path, "r", encoding="utf-8") as handle:
            payload = json.load(handle)
        if payload.get("type") != "dqn":
            raise ValueError("not a dqn model file: %r" % payload.get("type"))
        self.hidden = int(payload["hidden"])
        self.epsilon = float(payload["epsilon"])
        self.online = QNetwork(self.hidden)
        self.target = QNetwork(self.hidden)
        state_dict = {
            k: torch.tensor(v, dtype=torch.float32) for k, v in payload["weights"].items()
        }
        self.online.load_state_dict(state_dict)
        self.target.load_state_dict(state_dict)
        self.target.eval()
        self.optimizer = torch.optim.Adam(self.online.parameters(), lr=DQN_LEARNING_RATE)
