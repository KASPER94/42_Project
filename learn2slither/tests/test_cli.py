"""Control-flow tests for the lobby loop in :mod:`learn2slither.cli`.

These verify the menu<->game loop without opening a window: ``run_lobby`` and
``_play`` are stubbed so only the branching logic of ``_run_from_lobby`` runs.
"""

from __future__ import annotations

import os

os.environ["SDL_VIDEODRIVER"] = "dummy"
os.environ["SDL_AUDIODRIVER"] = "dummy"

from learn2slither import cli  # noqa: E402
from learn2slither.menu import LobbyConfig  # noqa: E402


def _scripted(values):
    """Return a stub function yielding ``values`` in order, recording calls."""
    state = {"calls": 0}

    def stub(*args, **kwargs):
        index = state["calls"]
        state["calls"] += 1
        return values[index]

    stub.state = state
    return stub


def test_lobby_cancelled_immediately_exits(monkeypatch) -> None:
    """Cancelling the lobby (None) exits without ever playing."""
    run_lobby = _scripted([None])
    play = _scripted([])
    monkeypatch.setattr("learn2slither.menu.run_lobby", run_lobby)
    monkeypatch.setattr(cli, "_play", play)

    assert cli._run_from_lobby() == 0
    assert play.state["calls"] == 0


def test_window_close_quits_after_one_game(monkeypatch) -> None:
    """When a game ends with a window close (_play False), the app exits."""
    run_lobby = _scripted([LobbyConfig()])
    play = _scripted([False])
    monkeypatch.setattr("learn2slither.menu.run_lobby", run_lobby)
    monkeypatch.setattr(cli, "_play", play)

    assert cli._run_from_lobby() == 0
    assert play.state["calls"] == 1
    assert run_lobby.state["calls"] == 1


def test_return_to_menu_then_quit(monkeypatch) -> None:
    """Returning to the menu (_play True) reopens the lobby until cancelled."""
    run_lobby = _scripted([LobbyConfig(), LobbyConfig(), None])
    play = _scripted([True, True])
    monkeypatch.setattr("learn2slither.menu.run_lobby", run_lobby)
    monkeypatch.setattr(cli, "_play", play)

    assert cli._run_from_lobby() == 0
    assert play.state["calls"] == 2
    assert run_lobby.state["calls"] == 3


def test_run_from_args_is_a_plain_cli_play(monkeypatch) -> None:
    """The CLI path plays once with from_lobby False and returns exit code 0."""
    recorded = {}

    def fake_play(args, from_lobby):
        recorded["from_lobby"] = from_lobby
        return False

    monkeypatch.setattr(cli, "_play", fake_play)
    args = cli.build_parser().parse_args(["-visual", "off", "-sessions", "1"])

    assert cli._run_from_args(args) == 0
    assert recorded["from_lobby"] is False
