"""Unit tests for the learning agents.

Covers the tabular :class:`QTableAgent` and the NumPy MLP :class:`NNAgent`:
their epsilon-greedy action selection, learning updates, frozen-mode behavior,
and exact save/load round-trips.
"""

from __future__ import annotations

import numpy as np

from learn2slither.agent import QTableAgent
from learn2slither.config import (
    GAMMA,
    N_ACTIONS,
    N_STATES,
    STATE_ENCODING_VERSION,
)
from learn2slither.contracts import Action, AgentP
from learn2slither.nn_agent import NNAgent, state_to_features


# --- QTableAgent ------------------------------------------------------------


def test_qtable_satisfies_agent_protocol(seed: int) -> None:
    """The table agent is recognised as an ``AgentP`` at runtime."""
    assert isinstance(QTableAgent(seed=seed), AgentP)


def test_qtable_starts_zeroed(seed: int) -> None:
    """A fresh Q-table is all zeros with the contracted shape and dtype."""
    agent = QTableAgent(seed=seed)
    assert agent.q.shape == (N_STATES, N_ACTIONS)
    assert agent.q.dtype == np.float32
    assert not agent.q.any()


def test_qtable_choose_action_returns_valid_action(seed: int) -> None:
    """``choose_action`` always returns a member of :class:`Action`."""
    agent = QTableAgent(seed=seed)
    for state in range(0, N_STATES, 257):
        assert agent.choose_action(state) in set(Action)


def test_qtable_learn_moves_value_toward_target(seed: int) -> None:
    """One terminal update nudges ``Q[state, action]`` toward the reward."""
    agent = QTableAgent(alpha=0.5, seed=seed)
    state, action, reward = 10, Action.UP, 7.0

    agent.learn(state, action, reward, next_state=11, done=True)

    # target == reward (done) and Q started at 0, so move == alpha * reward.
    np.testing.assert_allclose(agent.q[state, action], 0.5 * reward, rtol=1e-6)


def test_qtable_learn_uses_discounted_next_max(seed: int) -> None:
    """A non-terminal update bootstraps from ``gamma * max(Q[next_state])``."""
    agent = QTableAgent(alpha=1.0, gamma=GAMMA, seed=seed)
    next_state = 5
    agent.q[next_state, Action.RIGHT] = 10.0

    agent.learn(0, Action.UP, reward=1.0, next_state=next_state, done=False)

    expected = 1.0 + GAMMA * 10.0
    np.testing.assert_allclose(agent.q[0, Action.UP], expected, rtol=1e-6)


def test_qtable_frozen_learn_is_noop(seed: int) -> None:
    """With ``learning=False`` the Q-table is never mutated."""
    agent = QTableAgent(seed=seed)
    agent.learning = False
    before = agent.q.copy()

    agent.learn(3, Action.DOWN, reward=99.0, next_state=4, done=True)

    np.testing.assert_array_equal(agent.q, before)


def test_qtable_frozen_choose_action_is_greedy(seed: int) -> None:
    """A frozen agent ignores epsilon and returns the argmax action."""
    agent = QTableAgent(epsilon=1.0, seed=seed)
    agent.learning = False
    state = 42
    agent.q[state] = np.array([0.0, 5.0, 0.0, 0.0], dtype=np.float32)

    for _ in range(20):
        assert agent.choose_action(state) == Action.LEFT


def test_qtable_greedy_breaks_ties_randomly(seed: int) -> None:
    """Equal maxima are selected with random tie-breaking, not a fixed index."""
    agent = QTableAgent(epsilon=0.0, seed=seed)
    state = 1
    agent.q[state] = np.array([1.0, 1.0, 0.0, 0.0], dtype=np.float32)

    chosen = {agent.choose_action(state) for _ in range(50)}
    assert chosen == {Action.UP, Action.LEFT}


def test_qtable_end_session_decays_epsilon(seed: int) -> None:
    """``end_session`` multiplies epsilon by the decay factor when learning."""
    agent = QTableAgent(epsilon=1.0, epsilon_decay=0.5, epsilon_min=0.01, seed=seed)
    agent.end_session()
    assert agent.epsilon == 0.5


def test_qtable_end_session_respects_floor(seed: int) -> None:
    """Epsilon never decays below ``epsilon_min``."""
    agent = QTableAgent(epsilon=0.02, epsilon_decay=0.5, epsilon_min=0.01, seed=seed)
    agent.end_session()
    assert agent.epsilon == 0.01


def test_qtable_save_load_round_trips(tmp_path, seed: int) -> None:
    """Saving then loading reproduces the Q-table and hyperparameters."""
    agent = QTableAgent(alpha=0.3, gamma=0.8, epsilon=0.25, seed=seed)
    agent.q[0] = np.array([1.5, -2.0, 3.25, 0.0], dtype=np.float32)
    agent.q[100] = np.array([0.0, 0.0, 0.0, -0.5], dtype=np.float32)
    path = str(tmp_path / "qtable.json")
    agent.save(path)

    restored = QTableAgent(seed=seed)
    restored.load(path)

    np.testing.assert_allclose(restored.q, agent.q, rtol=1e-6, atol=1e-7)
    assert restored.alpha == agent.alpha
    assert restored.gamma == agent.gamma
    assert restored.epsilon == agent.epsilon


def test_qtable_save_stores_only_nonzero_rows(tmp_path, seed: int) -> None:
    """The serialized file omits rows that are all zero."""
    import json

    agent = QTableAgent(seed=seed)
    agent.q[7] = np.array([0.0, 1.0, 0.0, 0.0], dtype=np.float32)
    path = str(tmp_path / "qtable.json")
    agent.save(path)

    with open(path, "r", encoding="utf-8") as handle:
        payload = json.load(handle)

    assert payload["type"] == "qtable"
    assert payload["encoding"] == STATE_ENCODING_VERSION
    assert list(payload["q"].keys()) == ["7"]


# --- NNAgent ----------------------------------------------------------------


def test_state_to_features_extracts_bits() -> None:
    """``state_to_features`` returns the 12 bits, least-significant first."""
    features = state_to_features(0b101)
    assert features.shape == (12,)
    assert features.dtype == np.float32
    expected = np.zeros(12, dtype=np.float32)
    expected[0] = 1.0
    expected[2] = 1.0
    np.testing.assert_array_equal(features, expected)


def test_nn_satisfies_agent_protocol(seed: int) -> None:
    """The NN agent is recognised as an ``AgentP`` at runtime."""
    assert isinstance(NNAgent(seed=seed), AgentP)


def test_nn_weight_shapes(seed: int) -> None:
    """Weight matrices have the expected layer shapes and float32 dtype."""
    agent = NNAgent(seed=seed)
    assert agent.w1.shape == (12, agent.hidden)
    assert agent.b1.shape == (agent.hidden,)
    assert agent.w2.shape == (agent.hidden, N_ACTIONS)
    assert agent.b2.shape == (N_ACTIONS,)
    assert agent.w1.dtype == np.float32


def test_nn_choose_action_returns_valid_action(seed: int) -> None:
    """``choose_action`` always returns a member of :class:`Action`."""
    agent = NNAgent(seed=seed)
    for state in range(0, N_STATES, 401):
        assert agent.choose_action(state) in set(Action)


def test_nn_frozen_learn_is_noop(seed: int) -> None:
    """With ``learning=False`` the weights are never mutated."""
    agent = NNAgent(seed=seed)
    agent.learning = False
    before = agent.w2.copy()

    agent.learn(3, Action.DOWN, reward=99.0, next_state=4, done=True)

    np.testing.assert_array_equal(agent.w2, before)


def test_nn_learn_reduces_td_error(seed: int) -> None:
    """Repeated updates on one transition shrink the TD error toward zero."""
    agent = NNAgent(lr=0.05, seed=seed)
    state, action, reward = 123, Action.RIGHT, 5.0

    def td_error() -> float:
        return abs(float(agent.q_values(state)[action]) - reward)

    initial = td_error()
    for _ in range(200):
        agent.learn(state, action, reward, next_state=state, done=True)
    final = td_error()

    assert final < initial


def test_nn_end_session_decays_epsilon(seed: int) -> None:
    """``end_session`` decays epsilon for the NN agent too."""
    agent = NNAgent(epsilon=1.0, epsilon_decay=0.5, epsilon_min=0.01, seed=seed)
    agent.end_session()
    assert agent.epsilon == 0.5


def test_nn_save_load_round_trips(tmp_path, seed: int) -> None:
    """Saving then loading reproduces every weight array and epsilon."""
    agent = NNAgent(epsilon=0.33, seed=seed)
    # Train a little so the weights are non-trivial before serialising.
    for step in range(10):
        agent.learn(step, Action.UP, reward=1.0, next_state=step + 1, done=False)
    path = str(tmp_path / "nn.json")
    agent.save(path)

    restored = NNAgent(seed=seed + 1)
    restored.load(path)

    np.testing.assert_allclose(restored.w1, agent.w1, rtol=1e-6, atol=1e-7)
    np.testing.assert_allclose(restored.b1, agent.b1, rtol=1e-6, atol=1e-7)
    np.testing.assert_allclose(restored.w2, agent.w2, rtol=1e-6, atol=1e-7)
    np.testing.assert_allclose(restored.b2, agent.b2, rtol=1e-6, atol=1e-7)
    assert restored.epsilon == agent.epsilon
    assert restored.w1.dtype == np.float32


def test_nn_save_payload_schema(tmp_path, seed: int) -> None:
    """The serialized NN file carries the documented schema fields."""
    import json

    agent = NNAgent(seed=seed)
    path = str(tmp_path / "nn.json")
    agent.save(path)

    with open(path, "r", encoding="utf-8") as handle:
        payload = json.load(handle)

    assert payload["type"] == "nn"
    assert payload["encoding"] == STATE_ENCODING_VERSION
    assert payload["hidden"] == agent.hidden
    assert set(payload["weights"]) == {"w1", "b1", "w2", "b2"}
