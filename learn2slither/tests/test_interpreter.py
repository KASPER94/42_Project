"""Unit tests for :class:`learn2slither.interpreter.Interpreter`."""

from __future__ import annotations

import pytest

from learn2slither.config import (
    N_STATES,
    REWARD_DEATH,
    REWARD_EAT_GREEN,
    REWARD_EAT_RED,
    REWARD_STEP,
    SYM_HEAD,
    SYM_WALL,
)
from learn2slither.contracts import Event, InterpreterP, StepResult
from learn2slither.environment import Environment
from learn2slither.interpreter import Interpreter


@pytest.fixture
def interp() -> Interpreter:
    """A fresh interpreter."""
    return Interpreter()


def test_interpreter_satisfies_protocol(interp: Interpreter) -> None:
    """The concrete class is a structural InterpreterP."""
    assert isinstance(interp, InterpreterP)


def test_get_state_known_board(interp: Interpreter) -> None:
    """A hand-built board produces the expected packed bits.

    Head (5,5), body to the right; a green apple up the column and a red apple
    along the left row. Expected per direction (UP, LEFT, DOWN, RIGHT):
      UP    -> green in line                    = 0b010 << 0  =   2
      LEFT  -> red in line                      = 0b100 << 3  =  32
      DOWN  -> nothing                          = 0b000 << 6  =   0
      RIGHT -> danger (adjacent body segment)   = 0b001 << 9  = 512
    """
    env = Environment(seed=1)
    env._set_state([(5, 5), (5, 6), (5, 7)], green=[(2, 5)], red=[(5, 2)])

    state = interp.get_state(env)

    assert state == 2 + 32 + 512


def test_get_state_wall_adjacent_is_danger(interp: Interpreter) -> None:
    """An immediately adjacent wall sets the danger bit for that direction."""
    env = Environment(seed=1)
    env._set_state([(0, 5), (1, 5), (2, 5)], green=[(9, 0)], red=[(9, 9)])

    state = interp.get_state(env)

    # UP (i=0) is off-board -> danger bit at offset 0.
    assert state & 0b001 == 0b001


def test_get_state_in_range(interp: Interpreter) -> None:
    """Any reset board encodes to a valid 12-bit state id."""
    env = Environment(seed=99)
    env.reset()

    state = interp.get_state(env)

    assert 0 <= state < N_STATES


@pytest.mark.parametrize(
    "event,expected",
    [
        (Event.DEATH, REWARD_DEATH),
        (Event.EAT_GREEN, REWARD_EAT_GREEN),
        (Event.EAT_RED, REWARD_EAT_RED),
        (Event.MOVE, REWARD_STEP),
    ],
)
def test_get_reward_maps_events(
    interp: Interpreter, event: Event, expected: float
) -> None:
    """Each event maps to its configured reward."""
    result = StepResult(event=event, done=False, length=3)
    assert interp.get_reward(result) == expected


def test_render_vision_contains_head_and_walls(interp: Interpreter) -> None:
    """The rendered cross shows the head and the bracketing walls."""
    env = Environment(seed=1)
    env._set_state([(5, 5), (5, 6), (5, 7)], green=[(2, 5)], red=[(5, 2)])

    rendered = interp.render_vision(env)

    assert SYM_HEAD in rendered
    assert SYM_WALL in rendered


def test_render_vision_head_row_spans_walls(interp: Interpreter) -> None:
    """The head's row runs wall-to-wall and is the widest line."""
    env = Environment(seed=1)
    env._set_state([(5, 5), (5, 6), (5, 7)], green=[(2, 5)], red=[(5, 2)])

    lines = interp.render_vision(env).splitlines()
    head_lines = [ln for ln in lines if SYM_HEAD in ln]

    assert len(head_lines) == 1
    head_line = head_lines[0]
    assert head_line.startswith(SYM_WALL)
    assert head_line.endswith(SYM_WALL)
    assert len(head_line) == env.size + 2
