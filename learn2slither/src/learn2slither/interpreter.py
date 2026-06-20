"""Vision and reward: turn the board into the snake's state and its reward.

The :class:`Interpreter` is the *only* component allowed to read the board and
hand information to the agent, and it does so strictly through the four rays
leaving the head (the ``-42`` rule). The state id is a 12-bit integer; no
coordinates or off-vision apple positions ever reach the agent.
"""

from __future__ import annotations

from typing import List, Tuple

from learn2slither.config import (
    REWARD_DEATH,
    REWARD_EAT_GREEN,
    REWARD_EAT_RED,
    REWARD_STEP,
    SYM_BODY,
    SYM_GREEN,
    SYM_HEAD,
    SYM_RED,
    SYM_WALL,
)
from learn2slither.contracts import (
    DIRECTION_ORDER,
    EnvironmentP,
    Event,
    StepResult,
)

__all__ = ["Interpreter"]

# Bit layout within each direction's 3-bit group.
_BIT_DANGER = 0
_BIT_GREEN = 1
_BIT_RED = 2

_REWARDS = {
    Event.DEATH: REWARD_DEATH,
    Event.EAT_GREEN: REWARD_EAT_GREEN,
    Event.EAT_RED: REWARD_EAT_RED,
    Event.MOVE: REWARD_STEP,
}


class Interpreter:
    """Encodes the head's 4-direction vision and maps events to rewards.

    The encoding is version ``v1``: for each direction in
    :data:`contracts.DIRECTION_ORDER` (UP, LEFT, DOWN, RIGHT) three bits are
    packed at offset ``3 * i`` -- danger (bit 0), green in line (bit 1) and red
    in line (bit 2) -- yielding a state id in ``[0, 4095]``.

    Example:
        >>> interp = Interpreter()
        >>> state = interp.get_state(env)
        >>> reward = interp.get_reward(result)
    """

    def get_state(self, env: EnvironmentP) -> int:
        """Encode the head's vision into a state id.

        Args:
            env: The environment to read the board from.

        Returns:
            A 12-bit integer in ``[0, 4095]`` describing what each ray sees.
        """
        head_row, head_col = env.head
        state = 0
        for i, action in enumerate(DIRECTION_ORDER):
            bits = self._scan_ray(env, head_row, head_col, action.delta)
            state |= bits << (3 * i)
        return state

    def _scan_ray(
        self,
        env: EnvironmentP,
        head_row: int,
        head_col: int,
        delta: Tuple[int, int],
    ) -> int:
        """Walk one ray from the head to the wall and collect its 3 bits.

        Args:
            env: The environment being scanned.
            head_row: Head row coordinate.
            head_col: Head column coordinate.
            delta: ``(d_row, d_col)`` step for this direction.

        Returns:
            The 3-bit value (danger, green, red) for this direction.
        """
        d_row, d_col = delta
        row, col = head_row + d_row, head_col + d_col
        first = env.cell_symbol(row, col)
        bits = 0
        if first in (SYM_WALL, SYM_BODY):  # adjacent wall or body == danger
            bits |= 1 << _BIT_DANGER

        while env.cell_symbol(row, col) != SYM_WALL:
            symbol = env.cell_symbol(row, col)
            if symbol == SYM_GREEN:
                bits |= 1 << _BIT_GREEN
            elif symbol == SYM_RED:
                bits |= 1 << _BIT_RED
            row, col = row + d_row, col + d_col
        return bits

    def get_reward(self, result: StepResult) -> float:
        """Map a step outcome to its scalar reward.

        Args:
            result: The outcome of the last :meth:`Environment.step`.

        Returns:
            The configured reward for ``result.event``.
        """
        return _REWARDS[result.event]

    def render_vision(self, env: EnvironmentP) -> str:
        """Build the terminal vision cross around the head.

        The full column through the head is drawn vertically (with ``W`` walls
        at top and bottom); every row other than the head's shows only the
        head-column character, indented to align beneath the head. The head's
        own row is drawn in full (with ``W`` walls at the left and right) and
        the head itself is shown as ``H``.

        Args:
            env: The environment to render.

        Returns:
            A multi-line, human-readable string.
        """
        head_row, head_col = env.head
        # Indent so the column aligns with the head's position in the full row.
        indent = " " * (head_col + 1)
        lines: List[str] = []
        for row in range(-1, env.size + 1):
            if row == head_row:
                lines.append(self._row_line(env, head_row))
            else:
                lines.append(indent + self._column_symbol(env, row, head_col))
        return "\n".join(lines)

    def _row_line(self, env: EnvironmentP, row: int) -> str:
        """Render the head's full row from wall to wall."""
        symbols = [SYM_WALL]
        for col in range(env.size):
            symbols.append(env.cell_symbol(row, col))
        symbols.append(SYM_WALL)
        return "".join(symbols)

    def _column_symbol(self, env: EnvironmentP, row: int, col: int) -> str:
        """Render a single column cell (``W`` for the bracketing walls)."""
        if row < 0 or row >= env.size:
            return SYM_WALL
        symbol = env.cell_symbol(row, col)
        return SYM_HEAD if (row, col) == env.head else symbol
