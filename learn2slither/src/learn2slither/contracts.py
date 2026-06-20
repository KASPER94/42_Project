"""Shared contract between Environment, Interpreter and Agent.

These types are the *only* coupling between the three modules. Each module
depends on the Protocols here, never on another module's concrete class, so the
build agents can implement them independently.
"""

from __future__ import annotations

from dataclasses import dataclass
from enum import Enum, IntEnum
from typing import Dict, List, Protocol, Tuple, runtime_checkable

__all__ = [
    "Action",
    "DIRECTION_ORDER",
    "Event",
    "StepResult",
    "EnvironmentP",
    "InterpreterP",
    "AgentP",
]


class Action(IntEnum):
    """The four moves. Integer values index Q-value vectors in this order."""

    UP = 0
    LEFT = 1
    DOWN = 2
    RIGHT = 3

    @property
    def delta(self) -> Tuple[int, int]:
        """(d_row, d_col) offset applied to the head for this action."""
        return _DELTAS[self]


_DELTAS: Dict[Action, Tuple[int, int]] = {
    Action.UP: (-1, 0),
    Action.LEFT: (0, -1),
    Action.DOWN: (1, 0),
    Action.RIGHT: (0, 1),
}

# Canonical direction ordering used to pack the state bits. Keep it identical to
# the Action integer order so state and action share one mental model.
DIRECTION_ORDER: List[Action] = [
    Action.UP,
    Action.LEFT,
    Action.DOWN,
    Action.RIGHT,
]


class Event(Enum):
    """What happened on a single environment step."""

    MOVE = "move"
    EAT_GREEN = "green"
    EAT_RED = "red"
    DEATH = "death"


@dataclass(frozen=True)
class StepResult:
    """Outcome of ``Environment.step``.

    Attributes:
        event: What happened this step (drives the reward).
        done: True when the game is over (wall / self / length 0 / max steps).
        length: The snake's length after the step resolved.
    """

    event: Event
    done: bool
    length: int


@runtime_checkable
class EnvironmentP(Protocol):
    """The board, snake, apples and rules."""

    size: int

    def reset(self) -> None:
        """Start a fresh game: random snake (length 3) and apples."""

    def step(self, action: Action) -> StepResult:
        """Apply one move and return the resulting :class:`StepResult`."""

    @property
    def length(self) -> int:
        """Current snake length."""

    @property
    def head(self) -> Tuple[int, int]:
        """(row, col) of the snake's head."""

    def cell_symbol(self, row: int, col: int) -> str:
        """Symbol for a board cell (off-board returns the wall symbol)."""


@runtime_checkable
class InterpreterP(Protocol):
    """Turns the board into the snake's vision (state) and the reward."""

    def get_state(self, env: EnvironmentP) -> int:
        """Encode the head's 4-direction vision into a state id (0..4095)."""

    def get_reward(self, result: StepResult) -> float:
        """Map a :class:`StepResult` to a scalar reward."""

    def render_vision(self, env: EnvironmentP) -> str:
        """Build the terminal vision cross around the head."""


@runtime_checkable
class AgentP(Protocol):
    """The Q-learning brain. ``learning`` False == exploitation only."""

    learning: bool

    def choose_action(self, state: int) -> Action:
        """Pick an action for the given state (epsilon-greedy when learning)."""

    def learn(
        self,
        state: int,
        action: Action,
        reward: float,
        next_state: int,
        done: bool,
    ) -> None:
        """Update the Q function from one transition (no-op when frozen)."""

    def end_session(self) -> None:
        """Hook called when a game ends (e.g. to decay epsilon)."""

    def save(self, path: str) -> None:
        """Serialize the full learning state to a file."""

    def load(self, path: str) -> None:
        """Restore the learning state previously written by :meth:`save`."""
