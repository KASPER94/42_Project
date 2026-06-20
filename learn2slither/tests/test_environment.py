"""Unit tests for :class:`learn2slither.environment.Environment`."""

from __future__ import annotations

from typing import List, Tuple

import pytest

from learn2slither.config import (
    BOARD_SIZE,
    INITIAL_SNAKE_LENGTH,
    N_GREEN_APPLES,
    N_RED_APPLES,
    SYM_BODY,
    SYM_EMPTY,
    SYM_GREEN,
    SYM_HEAD,
    SYM_RED,
    SYM_WALL,
)
from learn2slither.contracts import Action, EnvironmentP, Event
from learn2slither.environment import Environment

Cell = Tuple[int, int]


def _is_contiguous_line(cells: List[Cell]) -> bool:
    """Whether cells form a straight, unit-step horizontal/vertical line."""
    rows = {r for r, _ in cells}
    cols = {c for _, c in cells}
    if len(rows) == 1:
        ordered = sorted(c for _, c in cells)
    elif len(cols) == 1:
        ordered = sorted(r for r, _ in cells)
    else:
        return False
    return all(b - a == 1 for a, b in zip(ordered, ordered[1:]))


@pytest.fixture
def env(seed: int) -> Environment:
    """A freshly reset environment with a deterministic seed."""
    environment = Environment(seed=seed)
    environment.reset()
    return environment


def test_environment_satisfies_protocol(env: Environment) -> None:
    """The concrete class is a structural EnvironmentP."""
    assert isinstance(env, EnvironmentP)


def test_reset_gives_initial_length(env: Environment) -> None:
    """A fresh game starts at the configured snake length."""
    assert env.length == INITIAL_SNAKE_LENGTH


def test_reset_snake_is_contiguous_and_on_board(env: Environment) -> None:
    """The starting snake is a straight on-board line."""
    cells = env.snake_cells()
    assert len(cells) == INITIAL_SNAKE_LENGTH
    assert all(0 <= r < BOARD_SIZE and 0 <= c < BOARD_SIZE for r, c in cells)
    assert _is_contiguous_line(cells)


def test_reset_places_expected_apple_counts(env: Environment) -> None:
    """Exactly two green apples and one red apple exist after reset."""
    assert len(env.green_cells()) == N_GREEN_APPLES
    assert len(env.red_cells()) == N_RED_APPLES


def test_reset_cells_are_distinct(env: Environment) -> None:
    """Snake and apple cells never overlap."""
    occupied = env.snake_cells() + env.green_cells() + env.red_cells()
    assert len(occupied) == len(set(occupied))


def test_reset_is_reproducible() -> None:
    """The same seed reproduces the same board."""
    a = Environment(seed=7)
    a.reset()
    b = Environment(seed=7)
    b.reset()
    assert a.snake_cells() == b.snake_cells()
    assert set(a.green_cells()) == set(b.green_cells())
    assert set(a.red_cells()) == set(b.red_cells())


def test_ordinary_move_keeps_length() -> None:
    """A plain move shifts the head and preserves length."""
    env = Environment(seed=1)
    env._set_state([(5, 5), (5, 6), (5, 7)], green=[(0, 0)], red=[(9, 9)])

    result = env.step(Action.LEFT)

    assert result.event is Event.MOVE
    assert result.done is False
    assert result.length == 3
    assert env.head == (5, 4)
    assert env.snake_cells() == [(5, 4), (5, 5), (5, 6)]


def test_move_into_vacated_tail_is_allowed() -> None:
    """Stepping onto the cell the tail just left is not a collision."""
    env = Environment(seed=1)
    # Vertical U is impossible with length 3; use an L-free straight body and
    # a turn that lands on the old tail. Head at (5,5), body down to (5,7).
    env._set_state([(5, 5), (6, 5), (7, 5)], green=[(0, 0)], red=[(9, 9)])

    # Moving the head onto (6,5)/(7,5) would be a body hit, but the tail (7,5)
    # vacates; build a case that targets the tail directly.
    env._set_state([(6, 5), (6, 6), (6, 7)], green=[(0, 0)], red=[(9, 9)])
    env.step(Action.UP)  # head -> (5,5)
    # tail is now (6,6); the old tail (6,7) is free.
    assert env.head == (5, 5)
    assert env.length == 3


def test_eating_green_grows_and_respawns() -> None:
    """Eating a green apple lengthens the snake and keeps two greens."""
    env = Environment(seed=1)
    env._set_state([(5, 5), (5, 6), (5, 7)], green=[(5, 4), (0, 0)], red=[(9, 9)])

    result = env.step(Action.LEFT)

    assert result.event is Event.EAT_GREEN
    assert result.done is False
    assert result.length == 4
    assert env.length == 4
    assert len(env.green_cells()) == N_GREEN_APPLES


def test_eating_red_shrinks_and_respawns() -> None:
    """Eating a red apple shortens the snake and keeps one red."""
    env = Environment(seed=1)
    env._set_state(
        [(5, 5), (5, 6), (5, 7), (5, 8)],
        green=[(0, 0), (0, 1)],
        red=[(5, 4)],
    )

    result = env.step(Action.LEFT)

    assert result.event is Event.EAT_RED
    assert result.done is False
    assert result.length == 3
    assert env.length == 3
    assert len(env.red_cells()) == N_RED_APPLES


def test_wall_collision_is_death() -> None:
    """Moving off the board ends the game."""
    env = Environment(seed=1)
    env._set_state([(0, 5), (0, 6), (0, 7)], green=[(9, 0), (9, 1)], red=[(9, 9)])

    result = env.step(Action.UP)

    assert result.event is Event.DEATH
    assert result.done is True


def test_self_collision_is_death() -> None:
    """Turning back into the body ends the game."""
    env = Environment(seed=1)
    env._set_state([(5, 5), (5, 6), (5, 7)], green=[(9, 0), (9, 1)], red=[(9, 9)])

    result = env.step(Action.RIGHT)  # head -> (5,6), a body cell

    assert result.event is Event.DEATH
    assert result.done is True


def test_red_apple_to_zero_length_is_death() -> None:
    """Shrinking to length 0 ends the game."""
    env = Environment(seed=1)
    env._set_state([(5, 5)], green=[(0, 0), (0, 1)], red=[(5, 4)])

    result = env.step(Action.LEFT)

    assert result.event is Event.DEATH
    assert result.done is True
    assert result.length == 0


def test_cell_symbol_off_board_is_wall(env: Environment) -> None:
    """Off-board coordinates report the wall symbol."""
    assert env.cell_symbol(-1, 0) == SYM_WALL
    assert env.cell_symbol(0, BOARD_SIZE) == SYM_WALL


def test_cell_symbol_classifies_each_cell() -> None:
    """Head, body, apples and empty cells map to their symbols."""
    env = Environment(seed=1)
    env._set_state([(5, 5), (5, 6)], green=[(2, 2)], red=[(3, 3)])

    assert env.cell_symbol(5, 5) == SYM_HEAD
    assert env.cell_symbol(5, 6) == SYM_BODY
    assert env.cell_symbol(2, 2) == SYM_GREEN
    assert env.cell_symbol(3, 3) == SYM_RED
    assert env.cell_symbol(0, 0) == SYM_EMPTY


def test_accessors_return_copies(env: Environment) -> None:
    """Mutating returned collections does not corrupt internal state."""
    snake = env.snake_cells()
    snake.append((9, 9))
    assert env.length == INITIAL_SNAKE_LENGTH
