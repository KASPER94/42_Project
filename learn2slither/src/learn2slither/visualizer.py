"""Pygame board visualizer for Learn2Slither.

Renders the environment in a dedicated square window: a dark background, a faint
grid, the green apples, the single red apple and the blue snake (with a lighter
head). The visualizer is pure I/O -- it only reads the environment's accessors
and never touches the agent, the interpreter or the game rules.

The module sets ``PYGAME_HIDE_SUPPORT_PROMPT`` *before* importing pygame so the
library's startup banner never pollutes stdout (the terminal output is part of
the graded contract).
"""

from __future__ import annotations

import os
from typing import Optional, Tuple

os.environ.setdefault("PYGAME_HIDE_SUPPORT_PROMPT", "1")

import pygame  # noqa: E402  (env var must be set before this import)

from learn2slither.config import (  # noqa: E402  (import after pygame guard)
    CELL_PIXELS,
    COLOR_BACKGROUND,
    COLOR_GREEN_APPLE,
    COLOR_GRID,
    COLOR_HEAD,
    COLOR_PANEL_ACCENT,
    COLOR_PANEL_BG,
    COLOR_PANEL_TEXT,
    COLOR_RED_APPLE,
    COLOR_SNAKE,
    DEFAULT_FPS,
    FONT_SIZE,
    PANEL_PIXELS,
)
from learn2slither.contracts import EnvironmentP  # noqa: E402

__all__ = ["Visualizer"]

Color = Tuple[int, int, int]


class Visualizer:
    """Draws the board with pygame and reads keyboard/quit events.

    The board occupies a ``size * cell_pixels`` square on the left; a
    ``PANEL_PIXELS`` wide strip on the right shows live run statistics when a
    ``stats`` mapping is passed to :meth:`render` (the default ``stats=None``
    path draws only the board, exactly as before). The visualizer owns the
    pygame display surface, a clock and a font; it is only constructed when the
    visual display is enabled and is closed explicitly via :meth:`close`.

    Attributes:
        size: Board side length in cells.
        cell_pixels: Pixel size of one board cell.
        fps: Display speed (frames/steps per second) for :meth:`tick`.
        paused: Whether playback is paused (toggled live with Space/P).
        step_requested: Set True when the user asks for a single step.

    Example:
        >>> viz = Visualizer(10, fps=10)
        >>> viz.render(env)
        >>> running = viz.process_events()
        >>> viz.tick()
        >>> viz.close()
    """

    def __init__(
        self,
        size: int,
        cell_pixels: int = CELL_PIXELS,
        fps: int = DEFAULT_FPS,
        title: str = "Learn2Slither",
        in_lobby: bool = False,
    ) -> None:
        """Create the window, clock and font.

        Args:
            size: Board side length in cells.
            cell_pixels: Pixel size of one board cell.
            fps: Display speed for frame-rate-based pacing.
            title: Window caption.
            in_lobby: Whether this run was launched from the graphical lobby;
                only changes the on-panel hint (Escape returns to the menu
                instead of quitting the application).
        """
        self.size = int(size)
        self.cell_pixels = int(cell_pixels)
        self.fps = max(1, int(fps))
        self.in_lobby = bool(in_lobby)
        self.paused = False
        self.step_requested = False
        # Why the loop stopped: the window's close button (quit the app) versus
        # the Escape key (return to the lobby when launched from it).
        self.window_closed = False
        self.escaped = False
        pygame.init()
        self._board_side = self.size * self.cell_pixels
        width = self._board_side + PANEL_PIXELS
        self._screen = pygame.display.set_mode((width, self._board_side))
        pygame.display.set_caption(title)
        self._clock = pygame.time.Clock()
        self._font = self._make_font()

    @staticmethod
    def _make_font() -> "pygame.font.Font":
        """Build the panel font, preferring the system font.

        Returns:
            A usable pygame font, falling back to the bundled default when no
            system font is available.
        """
        pygame.font.init()
        try:
            return pygame.font.SysFont(None, FONT_SIZE)
        except Exception:  # pragma: no cover - exercised only without fonts
            return pygame.font.Font(None, FONT_SIZE)

    def render(self, env: EnvironmentP, stats: Optional[dict] = None) -> None:
        """Draw one frame of the board, plus the stats panel when given.

        The board is drawn exactly as before. When ``stats`` is ``None`` no
        panel is drawn beyond filling its background, so the mandatory display
        behaviour is preserved.

        Args:
            env: The environment to read cells from.
            stats: Optional mapping of run statistics to show on the panel.
        """
        self._screen.fill(COLOR_BACKGROUND)
        self._draw_grid()
        for row, col in env.green_cells():
            self._fill_cell(row, col, COLOR_GREEN_APPLE)
        for row, col in env.red_cells():
            self._fill_cell(row, col, COLOR_RED_APPLE)
        self._draw_snake(env)
        if stats is not None:
            self._draw_panel(stats)
        pygame.display.flip()

    def _draw_panel(self, stats: dict) -> None:
        """Draw the right-hand statistics strip from a stats mapping.

        Args:
            stats: Mapping with the keys produced by the game loop (session,
                sessions, length, max_length, duration, reward, epsilon,
                learning and fps).
        """
        panel = pygame.Rect(self._board_side, 0, PANEL_PIXELS, self._board_side)
        pygame.draw.rect(self._screen, COLOR_PANEL_BG, panel)
        for index, (text, color) in enumerate(self._panel_lines(stats)):
            surface = self._font.render(text, True, color)
            self._screen.blit(surface, (self._board_side + 12, 14 + index * 26))

    def _panel_lines(self, stats: dict) -> "list":
        """Build the (text, color) lines shown on the stats panel.

        Args:
            stats: The run statistics mapping.

        Returns:
            A list of ``(text, color)`` pairs in display order.
        """
        text = COLOR_PANEL_TEXT
        accent = COLOR_PANEL_ACCENT
        mode = "PAUSED" if stats.get("paused") else (
            "STEP" if stats.get("step_by_step") else "RUNNING"
        )
        return [
            ("Learn2Slither", accent),
            ("Session {0}/{1}".format(stats.get("session", 0), stats.get("sessions", 0)), text),
            ("Length    {0}".format(stats.get("length", 0)), text),
            ("Max len   {0}".format(stats.get("max_length", 0)), text),
            ("Duration  {0}".format(stats.get("duration", 0)), text),
            ("Reward    {0:.1f}".format(float(stats.get("reward", 0.0))), text),
            ("Epsilon   {0}".format(self._epsilon_text(stats)), text),
            ("Speed     {0} fps".format(stats.get("fps", self.fps)), text),
            (mode, accent),
            ("Space pause  Up/Dn speed", COLOR_PANEL_TEXT),
            ("Right step   Esc {0}".format("menu" if self.in_lobby else "quit"),
             COLOR_PANEL_TEXT),
        ]

    @staticmethod
    def _epsilon_text(stats: dict) -> str:
        """Format epsilon, or ``"frozen"`` when learning is off or unknown."""
        epsilon = stats.get("epsilon")
        if not stats.get("learning", True) or epsilon is None:
            return "frozen"
        return "{0:.3f}".format(float(epsilon))

    def _draw_snake(self, env: EnvironmentP) -> None:
        """Draw the snake body in blue with a lighter head."""
        cells = env.snake_cells()
        for row, col in cells[1:]:
            self._fill_cell(row, col, COLOR_SNAKE)
        if cells:
            head_row, head_col = cells[0]
            self._fill_cell(head_row, head_col, COLOR_HEAD)

    def _draw_grid(self) -> None:
        """Draw the faint grid lines over the background."""
        side = self.size * self.cell_pixels
        for i in range(self.size + 1):
            offset = i * self.cell_pixels
            pygame.draw.line(self._screen, COLOR_GRID, (offset, 0), (offset, side))
            pygame.draw.line(self._screen, COLOR_GRID, (0, offset), (side, offset))

    def _fill_cell(self, row: int, col: int, color: Color) -> None:
        """Fill the cell at ``(row, col)`` with ``color`` (inset by 1px)."""
        rect = pygame.Rect(
            col * self.cell_pixels + 1,
            row * self.cell_pixels + 1,
            self.cell_pixels - 1,
            self.cell_pixels - 1,
        )
        pygame.draw.rect(self._screen, color, rect)

    def tick(self) -> None:
        """Cap the loop to ``self.fps`` for human-readable playback speed."""
        self._clock.tick(self.fps)

    def process_events(self) -> bool:
        """Pump pending pygame events and apply live controls.

        Beyond quit detection, Space/P toggle :attr:`paused`, Up/``+`` and
        Down/``-`` adjust :attr:`fps` (clamped to ``>= 1``) and Right/Return set
        :attr:`step_requested`.

        Returns:
            ``False`` if the user asked to quit (window close or the Escape
            key), otherwise ``True``. The reason is recorded on
            :attr:`window_closed` / :attr:`escaped` for the caller.
        """
        for event in pygame.event.get():
            if event.type == pygame.QUIT:
                self.window_closed = True
                return False
            if event.type == pygame.KEYDOWN:
                if event.key == pygame.K_ESCAPE:
                    self.escaped = True
                    return False
                self._handle_control_key(event.key)
        return True

    @property
    def stopped_by_user(self) -> bool:
        """Whether the user actively stopped the run (window close or Escape)."""
        return self.window_closed or self.escaped

    def _handle_control_key(self, key: int) -> None:
        """Apply a single live-control key press to the mutable state.

        Args:
            key: A pygame key constant from a ``KEYDOWN`` event.
        """
        if key in (pygame.K_SPACE, pygame.K_p):
            self.paused = not self.paused
        elif key in (pygame.K_UP, pygame.K_PLUS, pygame.K_KP_PLUS, pygame.K_EQUALS):
            self.fps = self.fps + 1
        elif key in (pygame.K_DOWN, pygame.K_MINUS, pygame.K_KP_MINUS):
            self.fps = max(1, self.fps - 1)
        elif key in (pygame.K_RIGHT, pygame.K_RETURN):
            self.step_requested = True

    def wait_for_step(self) -> bool:
        """Block until the user advances one step or quits.

        Advance keys are Space and the Right arrow. Window close and Escape quit.

        Returns:
            ``True`` when the user advances a step, ``False`` when they quit.
        """
        advance_keys = (pygame.K_SPACE, pygame.K_RIGHT)
        while True:
            event = pygame.event.wait()
            if event.type == pygame.QUIT:
                self.window_closed = True
                return False
            if event.type == pygame.KEYDOWN:
                if event.key == pygame.K_ESCAPE:
                    self.escaped = True
                    return False
                if event.key in advance_keys:
                    return True

    def show_game_over(self) -> None:
        """Dim the board and draw a centered game-over prompt, then flip.

        Used by the lobby flow after a run finishes on its own so the final
        frame stays visible until the player chooses to continue.
        """
        overlay = pygame.Surface((self._board_side, self._board_side), pygame.SRCALPHA)
        overlay.fill((0, 0, 0, 180))
        self._screen.blit(overlay, (0, 0))
        hint = "any key: menu    close: quit"
        self._blit_centered("GAME OVER", COLOR_PANEL_ACCENT, -16)
        self._blit_centered(hint, COLOR_PANEL_TEXT, 16)
        pygame.display.flip()

    def _blit_centered(self, text: str, color: Color, dy: int) -> None:
        """Blit ``text`` centered on the board, offset vertically by ``dy``."""
        surface = self._font.render(text, True, color)
        center = (self._board_side // 2, self._board_side // 2 + dy)
        self._screen.blit(surface, surface.get_rect(center=center))

    def wait_for_menu(self) -> None:
        """Block on the game-over screen until the user continues or quits.

        Any key or mouse click returns (caller reopens the menu); closing the
        window sets :attr:`window_closed` so the caller can quit the app.
        """
        while True:
            event = pygame.event.wait()
            if event.type == pygame.QUIT:
                self.window_closed = True
                return
            if event.type in (pygame.KEYDOWN, pygame.MOUSEBUTTONDOWN):
                return

    def close(self) -> None:
        """Tear down pygame and close the window."""
        pygame.quit()
