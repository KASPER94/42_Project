"""Tests for the PyTorch :class:`DQNAgent` (bonus, optional dependency).

The whole module is skipped when ``torch`` is not installed, so the suite stays
green on an evaluation machine that only installed ``requirements.txt``.
"""

from __future__ import annotations

import json

import pytest

pytest.importorskip("torch")

from learn2slither.config import N_ACTIONS, N_STATES, STATE_ENCODING_VERSION  # noqa: E402
from learn2slither.contracts import Action, AgentP  # noqa: E402
from learn2slither.dqn_agent import DQNAgent  # noqa: E402


def test_dqn_satisfies_agent_protocol(seed: int) -> None:
    """The DQN agent is recognised as an ``AgentP`` at runtime."""
    assert isinstance(DQNAgent(seed=seed), AgentP)


def test_dqn_choose_action_returns_valid_action(seed: int) -> None:
    """``choose_action`` always returns a member of :class:`Action`."""
    agent = DQNAgent(seed=seed)
    for state in range(0, N_STATES, 401):
        assert agent.choose_action(state) in set(Action)


def test_dqn_buffer_fills_and_no_train_before_warmup(seed: int) -> None:
    """Transitions accumulate but no learn step runs before warmup is reached."""
    agent = DQNAgent(warmup=10, batch_size=4, seed=seed)
    for step in range(5):
        agent.learn(step, Action.UP, reward=1.0, next_state=step + 1, done=False)
    assert len(agent.buffer) == 5
    assert agent._learn_steps == 0


def test_dqn_trains_after_warmup(seed: int) -> None:
    """Once warmup is met, each transition triggers a gradient step."""
    agent = DQNAgent(warmup=8, batch_size=4, seed=seed)
    for step in range(20):
        agent.learn(step % N_STATES, Action.DOWN, reward=1.0, next_state=step + 1, done=False)
    assert agent._learn_steps > 0


def test_dqn_frozen_learn_is_noop(seed: int) -> None:
    """With ``learning=False`` nothing is buffered and no training happens."""
    agent = DQNAgent(warmup=1, batch_size=1, seed=seed)
    agent.learning = False
    agent.learn(3, Action.DOWN, reward=99.0, next_state=4, done=True)
    assert len(agent.buffer) == 0
    assert agent._learn_steps == 0


def test_dqn_target_network_syncs(seed: int) -> None:
    """The target net matches the online net right after a sync boundary.

    With warmup/batch of 1 every call is a learn step, so 6 calls land exactly
    on the second ``target_update`` sync (steps 3 and 6) with no extra training
    afterwards to re-diverge them.
    """
    import torch

    agent = DQNAgent(warmup=1, batch_size=1, target_update=3, seed=seed)
    for step in range(6):
        agent.learn(step % N_STATES, Action.LEFT, reward=2.0, next_state=step + 1, done=False)
    assert agent._learn_steps == 6
    for online_p, target_p in zip(agent.online.parameters(), agent.target.parameters()):
        assert torch.allclose(online_p, target_p)


def test_dqn_end_session_decays_epsilon(seed: int) -> None:
    """``end_session`` decays epsilon for the DQN agent too."""
    agent = DQNAgent(epsilon=1.0, epsilon_decay=0.5, epsilon_min=0.01, seed=seed)
    agent.end_session()
    assert agent.epsilon == 0.5


def test_dqn_save_load_round_trips(tmp_path, seed: int) -> None:
    """Saving then loading reproduces every weight tensor and epsilon."""
    import torch

    agent = DQNAgent(epsilon=0.33, warmup=4, batch_size=4, seed=seed)
    for step in range(20):
        agent.learn(step % N_STATES, Action.UP, reward=1.0, next_state=step + 1, done=False)
    path = str(tmp_path / "dqn.json")
    agent.save(path)

    restored = DQNAgent(seed=seed + 1)
    restored.load(path)

    for k, v in agent.online.state_dict().items():
        assert torch.allclose(restored.online.state_dict()[k], v, atol=1e-6)
    assert restored.epsilon == agent.epsilon


def test_dqn_save_payload_schema(tmp_path, seed: int) -> None:
    """The serialized DQN file carries the documented schema fields."""
    agent = DQNAgent(seed=seed)
    path = str(tmp_path / "dqn.json")
    agent.save(path)

    with open(path, "r", encoding="utf-8") as handle:
        payload = json.load(handle)

    assert payload["type"] == "dqn"
    assert payload["encoding"] == STATE_ENCODING_VERSION
    assert payload["hidden"] == agent.hidden
    # A two-hidden-layer MLP serializes weight+bias for three Linear layers.
    assert len(payload["weights"]) == 6


def test_dqn_q_output_width(seed: int) -> None:
    """The network emits exactly one Q-value per action."""
    import torch

    agent = DQNAgent(seed=seed)
    with torch.no_grad():
        out = agent.online(agent._features(0))
    assert out.shape == (1, N_ACTIONS)
