"""Headless unit tests for the bonus lobby and the stats overlay.

The dummy SDL drivers are selected at import time so pygame can create windows
and fonts without a real display; the user validates the live window manually.
"""

from __future__ import annotations

import os

os.environ["SDL_VIDEODRIVER"] = "dummy"
os.environ["SDL_AUDIODRIVER"] = "dummy"

import pygame  # noqa: E402  (drivers must be set before this import)

from learn2slither.config import BOARD_SIZE, DEFAULT_FPS  # noqa: E402
from learn2slither.environment import Environment  # noqa: E402
from learn2slither.menu import (  # noqa: E402
    FRESH_LABEL,
    Lobby,
    LobbyConfig,
    Toggle,
)
from learn2slither.visualizer import Visualizer  # noqa: E402


def _click(x: int, y: int) -> "pygame.event.Event":
    """Build a synthetic left-button mouse-down event at ``(x, y)``."""
    return pygame.event.Event(pygame.MOUSEBUTTONDOWN, button=1, pos=(x, y))


def _key(key: int) -> "pygame.event.Event":
    """Build a synthetic key-down event for ``key``."""
    return pygame.event.Event(pygame.KEYDOWN, key=key)


def test_lobby_config_defaults_are_sane() -> None:
    """A default LobbyConfig mirrors the CLI defaults and is fresh/learning."""
    config = LobbyConfig()
    assert config.sessions == 100
    assert config.speed == DEFAULT_FPS
    assert config.board_size == BOARD_SIZE
    assert config.load is None
    assert config.model == "qtable"
    assert config.dontlearn is False
    assert config.visual == "on"


def test_toggle_flips_on_click() -> None:
    """Clicking inside an enabled toggle flips its boolean state."""
    toggle = Toggle("Don't learn", (0, 0, 100, 40))
    assert toggle.state is False
    toggle.click((10, 10))
    assert toggle.state is True
    toggle.click((10, 10))
    assert toggle.state is False


def test_disabled_toggle_ignores_clicks() -> None:
    """A disabled toggle does not change state when clicked."""
    toggle = Toggle("Don't learn", (0, 0, 100, 40), enabled=False)
    toggle.click((10, 10))
    assert toggle.state is False


def test_sessions_cycler_next_changes_value() -> None:
    """Clicking the right half of the Sessions cycler advances the preset."""
    lobby = Lobby.build(models_dir="models")
    before = lobby.sessions.value
    x, y, w, h = lobby.sessions.rect
    lobby.handle(_click(x + w - 5, y + h // 2))  # right half == next
    assert lobby.sessions.value != before


def test_speed_stepper_clamps_and_steps() -> None:
    """The speed stepper steps by 5 on the right half and clamps at the min."""
    lobby = Lobby.build(models_dir="models")
    x, y, w, h = lobby.speed.rect
    start = lobby.speed.value
    lobby.handle(_click(x + w - 5, y + h // 2))  # right half == increment
    assert lobby.speed.value == start + 5
    for _ in range(50):  # drive well past the minimum on the left half
        lobby.handle(_click(x + 5, y + h // 2))
    assert lobby.speed.value == lobby.speed.minimum


def test_start_click_produces_fresh_config() -> None:
    """Clicking Start yields a LobbyConfig; a fresh model means load is None."""
    lobby = Lobby.build(models_dir="models")
    assert lobby.state.started is False
    x, y, w, h = lobby.start.rect
    lobby.handle(_click(x + w // 2, y + h // 2))
    assert lobby.state.started is True
    config = lobby.config()
    assert isinstance(config, LobbyConfig)
    assert lobby.model.value == FRESH_LABEL
    assert config.load is None
    assert config.visual == "on"


def test_enter_starts_and_escape_quits() -> None:
    """Enter sets the started flag and Escape sets the quit flag."""
    lobby = Lobby.build(models_dir="models")
    lobby.handle(_key(pygame.K_RETURN))
    assert lobby.state.started is True

    other = Lobby.build(models_dir="models")
    other.handle(_key(pygame.K_ESCAPE))
    assert other.state.quit is True


def test_selecting_a_model_sets_load_path() -> None:
    """Cycling Model off (fresh) selects a real file and sets config.load."""
    lobby = Lobby.build(models_dir="models")
    if not lobby.models:  # repository ships models, but stay robust
        return
    x, y, w, h = lobby.model.rect
    lobby.handle(_click(x + w - 5, y + h // 2))  # next == first real model
    config = lobby.config()
    assert config.load == lobby.models[0]


def test_fresh_type_toggle_selects_nn() -> None:
    """With a fresh model, flipping the fresh-type toggle selects the nn agent."""
    lobby = Lobby.build(models_dir="models")
    lobby._refresh_enabled()
    assert lobby.fresh_type.enabled is True
    x, y, w, h = lobby.fresh_type.rect
    lobby.handle(_click(x + w // 2, y + h // 2))
    config = lobby.config()
    assert config.model == "nn"


def test_visualizer_renders_with_stats_headlessly() -> None:
    """A Visualizer constructs headlessly and renders a stats overlay frame."""
    viz = Visualizer(size=10)
    env = Environment(seed=7)
    env.reset()
    stats = {
        "session": 1,
        "sessions": 10,
        "length": env.length,
        "max_length": env.length,
        "duration": 3,
        "reward": -2.0,
        "epsilon": 0.5,
        "learning": True,
        "fps": viz.fps,
        "paused": False,
        "step_by_step": False,
    }
    viz.render(env, stats)  # should not raise
    viz.render(env)  # default stats=None path still works
    viz.close()


def test_visualizer_default_render_path_unchanged() -> None:
    """render(env) with no stats keeps the mandatory behaviour (no error)."""
    viz = Visualizer(size=8)
    env = Environment(seed=3)
    env.reset()
    viz.render(env)
    assert viz.paused is False
    assert viz.step_requested is False
    viz.close()
