"""Pygame configuration lobby for Learn2Slither (bonus).

A start screen that lets the user pick the run parameters with the mouse and
keyboard before a visual game begins. There is no free-text typing: every
parameter is set with a stepper, a cycler or a toggle so input cannot be
malformed. :func:`run_lobby` blocks until the user clicks **Start** (or presses
Enter) and returns a :class:`LobbyConfig`, or returns ``None`` when the user
quits (window close or Escape).

The lobby logic is split into a testable :class:`Lobby` (state plus
``handle(event)``) and tiny widget classes, so the blocking event loop in
:func:`run_lobby` stays short and the behaviour can be unit-tested headlessly.
"""

from __future__ import annotations

import glob
import os
from dataclasses import dataclass, field
from typing import List, Optional, Tuple

os.environ.setdefault("PYGAME_HIDE_SUPPORT_PROMPT", "1")

import pygame  # noqa: E402  (env var must be set before this import)

from learn2slither.config import (  # noqa: E402  (import after pygame guard)
    BOARD_SIZE,
    COLOR_BACKGROUND,
    COLOR_PANEL_ACCENT,
    COLOR_PANEL_DIM,
    COLOR_PANEL_TEXT,
    COLOR_WIDGET_BG,
    COLOR_WIDGET_HOVER,
    DEFAULT_FPS,
    FONT_SIZE,
)

__all__ = ["LobbyConfig", "Lobby", "Button", "Stepper", "Cycler", "Toggle", "run_lobby"]

SESSION_PRESETS: Tuple[int, ...] = (1, 10, 100, 500, 1000)
FRESH_LABEL = "(fresh)"
Rect = Tuple[int, int, int, int]

# --- Layout in pixels (kept here so the window fits the widgets exactly) -----
_MARGIN = 28
_LABEL_X = _MARGIN
_LABEL_W = 175
_CTRL_X = _MARGIN + _LABEL_W + 16          # left edge of every control box
_CTRL_W = 250                              # control box width
_ROW_H = 42                                # control box height
_ROW_PITCH = 56                            # vertical distance between rows
_FIRST_ROW_Y = 96                          # top of the first setting row
_BUTTON_ROW_Y = _FIRST_ROW_Y + 6 * _ROW_PITCH + 10
_BUTTON_GAP = 14
_TITLE_Y = 34                              # vertical centre of the title
_ARROW_PAD = 22                            # arrow inset from the box edges
WIDTH = _CTRL_X + _CTRL_W + _MARGIN        # symmetric left/right margins
HEIGHT = _BUTTON_ROW_Y + _ROW_H + _MARGIN


@dataclass
class LobbyConfig:
    """Run parameters chosen in the lobby, mirroring the CLI flags.

    Attributes:
        sessions: Number of games to play.
        speed: Display speed in frames/steps per second.
        board_size: Board side length in cells.
        load: Path to a model file to load, or ``None`` for a fresh agent.
        model: Fresh-agent type, ``"qtable"`` or ``"nn"`` (ignored when loading).
        dontlearn: Freeze the agent (exploitation only) when ``True``.
        visual: Always ``"on"`` when launched from the GUI lobby.
    """

    sessions: int = 100
    speed: int = DEFAULT_FPS
    board_size: int = BOARD_SIZE
    load: Optional[str] = None
    model: str = "qtable"
    dontlearn: bool = False
    visual: str = "on"


class _Widget:
    """Base widget: an interactive rectangle with a label and a value.

    Attributes:
        label: The caption shown to the left of the value.
        rect: The hit-test rectangle as ``(x, y, w, h)``.
        enabled: Whether the widget responds to clicks.
    """

    def __init__(self, label: str, rect: Rect, enabled: bool = True) -> None:
        """Store the label, rectangle and enabled flag."""
        self.label = label
        self.rect = rect
        self.enabled = enabled

    def hit(self, pos: Tuple[int, int]) -> bool:
        """Whether ``pos`` falls inside this widget's rectangle."""
        x, y, w, h = self.rect
        px, py = pos
        return x <= px < x + w and y <= py < y + h

    def value_text(self) -> str:
        """The current value rendered as text (overridden by subclasses)."""
        return ""


class Button(_Widget):
    """A clickable button with no value (e.g. Start / Quit)."""

    def click(self, pos: Tuple[int, int]) -> bool:
        """Return ``True`` when an enabled button is hit at ``pos``."""
        return self.enabled and self.hit(pos)


class Stepper(_Widget):
    """An integer value adjusted by ``-`` / ``+`` zones with clamping.

    Attributes:
        value: The current integer value.
        minimum: Lower clamp bound.
        maximum: Upper clamp bound.
        step: Increment applied per click.
    """

    def __init__(
        self,
        label: str,
        rect: Rect,
        value: int,
        minimum: int,
        maximum: int,
        step: int,
    ) -> None:
        """Store the value and its clamp bounds and step."""
        super().__init__(label, rect)
        self.value = value
        self.minimum = minimum
        self.maximum = maximum
        self.step = step

    def click(self, pos: Tuple[int, int]) -> None:
        """Adjust the value: the left half decrements, the right half adds."""
        if not (self.enabled and self.hit(pos)):
            return
        x, _, w, _ = self.rect
        if pos[0] < x + w // 2:
            self.value = max(self.minimum, self.value - self.step)
        else:
            self.value = min(self.maximum, self.value + self.step)

    def value_text(self) -> str:
        """Render the value flanked by the decrement/increment arrows."""
        return "-   {0}   +".format(self.value)


class Cycler(_Widget):
    """Cycles through a fixed list of options via ``<`` / ``>`` zones.

    Attributes:
        options: The selectable values in display order.
        index: Index of the current option.
    """

    def __init__(self, label: str, rect: Rect, options: List, index: int = 0) -> None:
        """Store the options and the starting index."""
        super().__init__(label, rect)
        self.options = list(options)
        self.index = index

    @property
    def value(self):
        """The currently selected option."""
        return self.options[self.index]

    def click(self, pos: Tuple[int, int]) -> None:
        """Move to the previous (left half) or next (right half) option."""
        if not (self.enabled and self.hit(pos)) or not self.options:
            return
        x, _, w, _ = self.rect
        direction = -1 if pos[0] < x + w // 2 else 1
        self.index = (self.index + direction) % len(self.options)

    def value_text(self) -> str:
        """Render the selected option between the cycle arrows."""
        return "<   {0}   >".format(self.value)


class Toggle(_Widget):
    """A boolean (or two-label) toggle flipped on click.

    Attributes:
        state: The current boolean state.
        labels: The ``(off_label, on_label)`` shown for ``False`` / ``True``.
    """

    def __init__(
        self,
        label: str,
        rect: Rect,
        state: bool = False,
        labels: Tuple[str, str] = ("off", "on"),
        enabled: bool = True,
    ) -> None:
        """Store the state, the two display labels and the enabled flag."""
        super().__init__(label, rect, enabled=enabled)
        self.state = state
        self.labels = labels

    def click(self, pos: Tuple[int, int]) -> None:
        """Flip the state when an enabled toggle is hit."""
        if self.enabled and self.hit(pos):
            self.state = not self.state

    def value_text(self) -> str:
        """Render the label matching the current state."""
        return self.labels[1] if self.state else self.labels[0]


@dataclass
class _LobbyState:
    """Mutable outcome flags the event handler reports back to the loop.

    Attributes:
        started: Set when the user confirms the configuration (Start / Enter).
        quit: Set when the user abandons the lobby (close / Quit / Escape).
    """

    started: bool = False
    quit: bool = False


@dataclass
class Lobby:
    """The lobby's widgets and state, separated from the blocking loop.

    Build a ``Lobby`` with :meth:`build`, feed it pygame events via
    :meth:`handle`, and read :attr:`state` to know when to stop. :meth:`config`
    materialises the chosen :class:`LobbyConfig`. This split keeps
    :func:`run_lobby` short and makes the widget logic unit-testable headlessly.

    Attributes:
        models: Sorted list of discovered ``*.txt`` model paths.
        widgets: All interactive widgets, in draw order.
        state: The outcome flags updated by :meth:`handle`.
    """

    models: List[str] = field(default_factory=list)
    widgets: List[_Widget] = field(default_factory=list)
    state: _LobbyState = field(default_factory=_LobbyState)
    sessions: Cycler = field(init=False)
    speed: Stepper = field(init=False)
    board: Stepper = field(init=False)
    model: Cycler = field(init=False)
    fresh_type: Toggle = field(init=False)
    dontlearn: Toggle = field(init=False)
    start: Button = field(init=False)
    quit: Button = field(init=False)

    @classmethod
    def build(cls, models_dir: str = "models") -> "Lobby":
        """Create a lobby with widgets laid out for the given model directory.

        Args:
            models_dir: Directory scanned for ``*.txt`` model files.

        Returns:
            A ready-to-use :class:`Lobby`.
        """
        lobby = cls(models=_find_models(models_dir))
        lobby._make_widgets()
        return lobby

    def _make_widgets(self) -> None:
        """Instantiate every widget on a fixed grid and register it."""
        cx, cw, h = _CTRL_X, _CTRL_W, _ROW_H
        model_options = [FRESH_LABEL] + [os.path.basename(p) for p in self.models]

        def row(i: int) -> int:
            return _FIRST_ROW_Y + i * _ROW_PITCH

        self.sessions = Cycler("Sessions", (cx, row(0), cw, h), list(SESSION_PRESETS), index=2)
        self.speed = Stepper("Speed (fps)", (cx, row(1), cw, h), DEFAULT_FPS, 1, 60, 5)
        self.board = Stepper("Board size", (cx, row(2), cw, h), BOARD_SIZE, 5, 20, 1)
        self.model = Cycler("Model", (cx, row(3), cw, h), model_options, index=0)
        self.fresh_type = Toggle("Fresh type", (cx, row(4), cw, h), labels=("qtable", "nn"))
        self.dontlearn = Toggle("Don't learn", (cx, row(5), cw, h))
        bw = (cw - _BUTTON_GAP) // 2
        self.start = Button("Start", (cx, _BUTTON_ROW_Y, bw, h))
        self.quit = Button("Quit", (cx + bw + _BUTTON_GAP, _BUTTON_ROW_Y, bw, h))
        self.widgets = [
            self.sessions, self.speed, self.board, self.model,
            self.fresh_type, self.dontlearn, self.start, self.quit,
        ]

    def _refresh_enabled(self) -> None:
        """Enable/disable context-dependent widgets before drawing/handling.

        ``Fresh type`` is only relevant for a fresh agent; ``Don't learn`` is
        only relevant once a model is loaded.
        """
        fresh = self.model.value == FRESH_LABEL
        self.fresh_type.enabled = fresh
        self.dontlearn.enabled = not fresh

    def handle(self, event: "pygame.event.Event") -> None:
        """Apply one pygame event to the lobby state.

        Args:
            event: A pygame event (mouse click, key press or quit).
        """
        self._refresh_enabled()
        if event.type == pygame.QUIT:
            self.state.quit = True
        elif event.type == pygame.KEYDOWN:
            self._handle_key(event.key)
        elif event.type == pygame.MOUSEBUTTONDOWN and event.button == 1:
            self._handle_click(event.pos)

    def _handle_key(self, key: int) -> None:
        """Map Enter to Start and Escape to quit."""
        if key in (pygame.K_RETURN, pygame.K_KP_ENTER):
            self.state.started = True
        elif key == pygame.K_ESCAPE:
            self.state.quit = True

    def _handle_click(self, pos: Tuple[int, int]) -> None:
        """Dispatch a left-click to whichever widget was hit."""
        if self.start.click(pos):
            self.state.started = True
            return
        if self.quit.click(pos):
            self.state.quit = True
            return
        self.sessions.click(pos)
        self.speed.click(pos)
        self.board.click(pos)
        self.model.click(pos)
        self.fresh_type.click(pos)
        self.dontlearn.click(pos)

    def config(self) -> LobbyConfig:
        """Materialise the chosen options into a :class:`LobbyConfig`.

        Returns:
            The configuration. When a model is selected, ``load`` is its path
            and ``model``/``dontlearn`` follow the loaded-agent widgets;
            otherwise ``load`` is ``None`` and the fresh-type toggle picks the
            agent class.
        """
        fresh = self.model.value == FRESH_LABEL
        load = None if fresh else self.models[self.model.index - 1]
        return LobbyConfig(
            sessions=int(self.sessions.value),
            speed=int(self.speed.value),
            board_size=int(self.board.value),
            load=load,
            model="nn" if (fresh and self.fresh_type.state) else "qtable",
            dontlearn=bool(self.dontlearn.state) and not fresh,
            visual="on",
        )


def _find_models(models_dir: str) -> List[str]:
    """Return the sorted ``*.txt`` model files in ``models_dir``.

    Args:
        models_dir: Directory to scan (missing directory yields an empty list).

    Returns:
        Sorted list of model file paths.
    """
    return sorted(glob.glob(os.path.join(models_dir, "*.txt")))


def run_lobby(models_dir: str = "models") -> Optional[LobbyConfig]:
    """Open the lobby window and return the chosen configuration.

    Args:
        models_dir: Directory scanned for selectable ``*.txt`` models.

    Returns:
        The chosen :class:`LobbyConfig` when the user starts, or ``None`` when
        the user closes the window or presses Escape.
    """
    pygame.init()
    screen = pygame.display.set_mode((WIDTH, HEIGHT))
    pygame.display.set_caption("Learn2Slither - Configuration")
    clock = pygame.time.Clock()
    font = _make_lobby_font(FONT_SIZE)
    title_font = _make_lobby_font(FONT_SIZE + 10)
    lobby = Lobby.build(models_dir)
    try:
        return _lobby_loop(lobby, screen, clock, font, title_font)
    finally:
        pygame.quit()


def _lobby_loop(lobby: Lobby, screen, clock, font, title_font) -> Optional[LobbyConfig]:
    """Run the blocking event/draw loop until the user starts or quits.

    Args:
        lobby: The lobby state and widgets.
        screen: The pygame display surface.
        clock: The pygame clock used to cap the frame rate.
        font: The font used for labels and values.
        title_font: The larger font used for the title.

    Returns:
        The chosen configuration, or ``None`` on quit.
    """
    while True:
        for event in pygame.event.get():
            lobby.handle(event)
        if lobby.state.quit:
            return None
        if lobby.state.started:
            return lobby.config()
        lobby._refresh_enabled()
        _draw_lobby(lobby, screen, font, title_font)
        clock.tick(30)


def _make_lobby_font(size: int) -> "pygame.font.Font":
    """Build a lobby font at ``size``, preferring the system font."""
    pygame.font.init()
    try:
        return pygame.font.SysFont(None, size)
    except Exception:  # pragma: no cover - exercised only without fonts
        return pygame.font.Font(None, size)


def _blit(screen, font, text: str, color, **anchor) -> None:
    """Render ``text`` and blit it using a ``Rect`` anchor (e.g. ``center=``)."""
    surface = font.render(text, True, color)
    screen.blit(surface, surface.get_rect(**anchor))


def _draw_lobby(lobby: Lobby, screen, font, title_font) -> None:
    """Render the centered title, subtitle and every widget for one frame."""
    screen.fill(COLOR_BACKGROUND)
    _blit(screen, title_font, "Learn2Slither", COLOR_PANEL_ACCENT,
          center=(WIDTH // 2, _TITLE_Y))
    _blit(screen, font, "configure your run", COLOR_PANEL_DIM,
          center=(WIDTH // 2, _TITLE_Y + 28))
    mouse = pygame.mouse.get_pos()
    for widget in lobby.widgets:
        _draw_widget(widget, screen, font, mouse)
    pygame.display.flip()


def _draw_widget(widget: _Widget, screen, font, mouse: Tuple[int, int]) -> None:
    """Draw one widget: hover box, left-column label and centered value.

    Stepper/Cycler arrows are drawn at the box edges so they line up with the
    left-half / right-half click zones, with the value centered between them.
    Buttons show their label centered inside the box.
    """
    x, y, w, h = widget.rect
    color = COLOR_PANEL_TEXT if widget.enabled else COLOR_PANEL_DIM
    hovered = widget.enabled and widget.hit(mouse)
    box = COLOR_WIDGET_HOVER if hovered else COLOR_WIDGET_BG
    pygame.draw.rect(screen, box, widget.rect, border_radius=8)
    cy = y + h // 2
    if isinstance(widget, Button):
        _blit(screen, font, widget.label, color, center=(x + w // 2, cy))
        return
    _blit(screen, font, widget.label, color, midleft=(_LABEL_X, cy))
    if isinstance(widget, (Stepper, Cycler)):
        left, right = ("-", "+") if isinstance(widget, Stepper) else ("<", ">")
        arrow = COLOR_PANEL_ACCENT if widget.enabled else COLOR_PANEL_DIM
        _blit(screen, font, left, arrow, center=(x + _ARROW_PAD, cy))
        _blit(screen, font, right, arrow, center=(x + w - _ARROW_PAD, cy))
        _blit(screen, font, str(widget.value), color, center=(x + w // 2, cy))
    else:
        _blit(screen, font, widget.value_text(), color, center=(x + w // 2, cy))
