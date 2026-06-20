"""The Learn2Slither game world: board, snake, apples and the step rules.

The :class:`Environment` owns all mutable game state. It exposes read-only
accessors (head, body cells, apple cells, per-cell symbols) that the Interpreter
and the visualizer consume; it never reaches into the Agent. State that the
agent eventually sees is derived elsewhere (the Interpreter) strictly from these
accessors, so the ``-42`` vision rule stays the Interpreter's concern.
"""

from __future__ import annotations

from typing import List, Optional, Sequence, Set, Tuple

import numpy as np

from learn2slither.config import (
    BOARD_SIZE,
    DEFAULT_SEED,
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
from learn2slither.contracts import Action, Event, StepResult

__all__ = ["Environment"]

Cell = Tuple[int, int]


class Environment:
    """The board, snake, apples and movement rules.

    The snake body is stored head-first: ``self._snake[0]`` is the head and the
    last element is the tail. Apples are stored as plain ``(row, col)`` cells.

    Attributes:
        size: Side length of the square board (cells).

    Example:
        >>> env = Environment(seed=42)
        >>> env.reset()
        >>> result = env.step(Action.UP)
    """

    def __init__(
        self,
        size: int = BOARD_SIZE,
        seed: Optional[int] = DEFAULT_SEED,
        rng: Optional[np.random.Generator] = None,
    ) -> None:
        """Create an environment.

        Args:
            size: Board side length in cells. Defaults to ``config.BOARD_SIZE``.
            seed: Seed for the internal RNG when ``rng`` is not supplied.
            rng: An explicit NumPy generator (overrides ``seed`` for sharing a
                stream across components).
        """
        self.size = int(size)
        self._rng = rng if rng is not None else np.random.default_rng(seed)
        self._snake: List[Cell] = []
        self._green: Set[Cell] = set()
        self._red: Set[Cell] = set()
        self._won = False

    # --- lifecycle ---------------------------------------------------------

    def reset(self) -> None:
        """Start a fresh game: a length-3 contiguous snake and the apples."""
        self._won = False
        self._snake = self._random_snake()
        self._green = set()
        self._red = set()
        for _ in range(N_GREEN_APPLES):
            self._spawn_apple(self._green)
        for _ in range(N_RED_APPLES):
            self._spawn_apple(self._red)

    def step(self, action: Action) -> StepResult:
        """Apply one move and resolve walls, collisions and apples.

        Args:
            action: The direction to move the head.

        Returns:
            The :class:`StepResult` describing the event, terminal flag and the
            snake length after the move resolved.
        """
        d_row, d_col = action.delta
        head_row, head_col = self._snake[0]
        new_head = (head_row + d_row, head_col + d_col)

        if self._is_wall(new_head):
            return StepResult(Event.DEATH, done=True, length=self.length)
        if self._hits_body(new_head):
            return StepResult(Event.DEATH, done=True, length=self.length)

        if new_head in self._green:
            return self._resolve_green(new_head)
        if new_head in self._red:
            return self._resolve_red(new_head)
        return self._resolve_move(new_head)

    # --- step helpers ------------------------------------------------------

    def _resolve_move(self, new_head: Cell) -> StepResult:
        """Advance the head one cell and drop the tail (length unchanged)."""
        self._snake.insert(0, new_head)
        self._snake.pop()
        return StepResult(Event.MOVE, done=False, length=self.length)

    def _resolve_green(self, new_head: Cell) -> StepResult:
        """Grow by one (keep the tail) and respawn one green apple."""
        self._snake.insert(0, new_head)
        self._green.discard(new_head)
        if not self._spawn_apple(self._green):
            return StepResult(Event.EAT_GREEN, done=True, length=self.length)
        return StepResult(Event.EAT_GREEN, done=False, length=self.length)

    def _resolve_red(self, new_head: Cell) -> StepResult:
        """Shrink by one (drop two tail cells net) and respawn one red apple."""
        self._snake.insert(0, new_head)
        self._red.discard(new_head)
        self._snake.pop()
        if self._snake:
            self._snake.pop()
        if not self._snake:
            return StepResult(Event.DEATH, done=True, length=0)
        if not self._spawn_apple(self._red):
            return StepResult(Event.EAT_RED, done=True, length=self.length)
        return StepResult(Event.EAT_RED, done=False, length=self.length)

    # --- placement ---------------------------------------------------------

    def _random_snake(self) -> List[Cell]:
        """Build a straight, on-board, length-3 snake with the head at one end.

        Returns:
            The body as a head-first list of cells.
        """
        length = INITIAL_SNAKE_LENGTH
        horizontal = bool(self._rng.integers(0, 2))
        head_first = bool(self._rng.integers(0, 2))
        if horizontal:
            row = int(self._rng.integers(0, self.size))
            start_col = int(self._rng.integers(0, self.size - length + 1))
            line = [(row, start_col + i) for i in range(length)]
        else:
            col = int(self._rng.integers(0, self.size))
            start_row = int(self._rng.integers(0, self.size - length + 1))
            line = [(start_row + i, col) for i in range(length)]
        return line if head_first else list(reversed(line))

    def _spawn_apple(self, target: Set[Cell]) -> bool:
        """Place one apple on a random empty cell.

        Args:
            target: The apple set to add the new cell to.

        Returns:
            True if an apple was placed, False if the board is full (a win).
        """
        empties = self._empty_cells()
        if not empties:
            self._won = True
            return False
        index = int(self._rng.integers(0, len(empties)))
        target.add(empties[index])
        return True

    def _empty_cells(self) -> List[Cell]:
        """List every cell not occupied by the snake or an apple."""
        occupied = set(self._snake) | self._green | self._red
        return [
            (row, col)
            for row in range(self.size)
            for col in range(self.size)
            if (row, col) not in occupied
        ]

    # --- predicates --------------------------------------------------------

    def _is_wall(self, cell: Cell) -> bool:
        """Whether a cell lies off the board."""
        row, col = cell
        return not (0 <= row < self.size and 0 <= col < self.size)

    def _hits_body(self, new_head: Cell) -> bool:
        """Whether moving to ``new_head`` collides with the snake's own body.

        The current tail vacates on an ordinary move, so stepping onto it is
        allowed (unless that cell also holds a green apple, which makes the
        snake grow and keep the tail).
        """
        if new_head not in self._snake:
            return False
        if new_head in self._green:
            return True
        return new_head != self._snake[-1]

    # --- read-only accessors ----------------------------------------------

    @property
    def length(self) -> int:
        """Current snake length."""
        return len(self._snake)

    @property
    def head(self) -> Cell:
        """The (row, col) of the snake's head."""
        return self._snake[0]

    @property
    def won(self) -> bool:
        """Whether the snake filled the board (no room to spawn an apple)."""
        return self._won

    def snake_cells(self) -> List[Cell]:
        """Snake body as a head-first copy (head at index 0)."""
        return list(self._snake)

    def green_cells(self) -> List[Cell]:
        """A copy of the green-apple cells."""
        return list(self._green)

    def red_cells(self) -> List[Cell]:
        """A copy of the red-apple cells."""
        return list(self._red)

    def cell_symbol(self, row: int, col: int) -> str:
        """Return the display symbol for a board cell.

        Args:
            row: Board row (may be off-board).
            col: Board column (may be off-board).

        Returns:
            One of the ``config.SYM_*`` symbols. Off-board cells return the wall
            symbol; the head wins over the body, apples over empty space.
        """
        cell = (row, col)
        if self._is_wall(cell):
            return SYM_WALL
        if cell == self._snake[0]:
            return SYM_HEAD
        if cell in self._snake:
            return SYM_BODY
        if cell in self._green:
            return SYM_GREEN
        if cell in self._red:
            return SYM_RED
        return SYM_EMPTY

    # --- test-only hook ----------------------------------------------------

    def _set_state(
        self,
        snake_cells: Sequence[Cell],
        green: Sequence[Cell],
        red: Sequence[Cell],
    ) -> None:
        """Install a deterministic board (test helper).

        Args:
            snake_cells: Head-first body cells (head at index 0).
            green: Green-apple cells.
            red: Red-apple cells.
        """
        self._snake = [tuple(cell) for cell in snake_cells]
        self._green = {tuple(cell) for cell in green}
        self._red = {tuple(cell) for cell in red}
        self._won = False
