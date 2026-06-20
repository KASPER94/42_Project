"""Bonus coverage: variable board size (size-independent play).

The state is pure 4-direction vision, so the exact same agent / trained model
must run on any board size without crashing. These tests pin that property.
"""

from __future__ import annotations

import os

os.environ.setdefault("SDL_VIDEODRIVER", "dummy")
os.environ.setdefault("SDL_AUDIODRIVER", "dummy")

import pytest  # noqa: E402

from learn2slither.agent import QTableAgent  # noqa: E402
from learn2slither.environment import Environment  # noqa: E402
from learn2slither.game import run_sessions  # noqa: E402
from learn2slither.interpreter import Interpreter  # noqa: E402


@pytest.mark.parametrize("size", [5, 8, 10, 16, 20])
def test_state_id_in_range_for_any_size(size):
    """get_state stays a valid 12-bit id whatever the board size."""
    env = Environment(size=size, seed=1)
    env.reset()
    state = Interpreter().get_state(env)
    assert 0 <= state < 4096


@pytest.mark.parametrize("size", [6, 10, 16, 20])
def test_pipeline_runs_on_any_board_size(size):
    """A full headless run completes on any size and starts at length 3."""
    env = Environment(size=size, seed=7)
    agent = QTableAgent(seed=7)
    max_len, max_dur = run_sessions(
        env, Interpreter(), agent, sessions=2, visualizer=None, verbose=False
    )
    assert max_len >= 3
    assert max_dur >= 1


def test_same_agent_plays_across_sizes_without_crash():
    """One agent instance drives 10x10, 15x15 and 20x20 back to back."""
    agent = QTableAgent(seed=3)
    interpreter = Interpreter()
    for size in (10, 15, 20):
        env = Environment(size=size, seed=3)
        run_sessions(env, interpreter, agent, sessions=1, visualizer=None, verbose=False)


def test_visualizer_constructs_on_large_board():
    """The pygame visualizer sizes itself to a non-default board (headless)."""
    from learn2slither.visualizer import Visualizer

    env = Environment(size=18, seed=2)
    env.reset()
    visualizer = Visualizer(size=18)
    try:
        visualizer.render(env, stats=None)
    finally:
        visualizer.close()
