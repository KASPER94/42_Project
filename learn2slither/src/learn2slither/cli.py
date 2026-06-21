"""Command-line interface and entry point for Learn2Slither.

Parses the subject's single-dash flags, assembles the environment, interpreter
and agent, then drives the session loop. The visualizer (and thus pygame) is
only imported and constructed when ``-visual on`` is requested, so headless
training never opens a window or depends on a display.
"""

from __future__ import annotations

import argparse
import json
import sys
from typing import Optional

from learn2slither.agent import QTableAgent
from learn2slither.config import BOARD_SIZE, DEFAULT_FPS, DEFAULT_SEED
from learn2slither.contracts import AgentP
from learn2slither.environment import Environment
from learn2slither.game import run_sessions
from learn2slither.interpreter import Interpreter
from learn2slither.nn_agent import NNAgent

__all__ = ["build_parser", "make_agent", "main"]


def build_parser() -> argparse.ArgumentParser:
    """Build the argument parser for the subject's single-dash flags.

    Returns:
        A configured :class:`argparse.ArgumentParser`.
    """
    parser = argparse.ArgumentParser(
        prog="snake",
        description="Learn2Slither: a Q-learning snake.",
        allow_abbrev=False,
    )
    parser.add_argument("-sessions", type=int, default=1, help="number of games to play")
    parser.add_argument("-save", type=str, default=None, help="path to save the model")
    parser.add_argument("-load", type=str, default=None, help="path to load a model")
    parser.add_argument(
        "-visual",
        choices=["on", "off"],
        default="on",
        help="enable or disable the graphical display",
    )
    parser.add_argument(
        "-dontlearn",
        dest="dontlearn",
        action="store_true",
        help="freeze the agent (exploitation only, no updates)",
    )
    parser.add_argument(
        "-step-by-step",
        dest="step_by_step",
        action="store_true",
        help="advance one step per user input",
    )
    parser.add_argument(
        "-speed",
        type=int,
        default=DEFAULT_FPS,
        help="display speed in frames/steps per second",
    )
    parser.add_argument(
        "-board-size",
        dest="board_size",
        type=int,
        default=BOARD_SIZE,
        help="board side length in cells (bonus)",
    )
    parser.add_argument(
        "-model",
        choices=["qtable", "nn", "dqn"],
        default="qtable",
        help="agent type for a fresh run (ignored when -load is given); "
        "'dqn' requires torch (see requirements-dqn.txt)",
    )
    parser.add_argument(
        "-menu",
        dest="menu",
        action="store_true",
        help="open the graphical configuration lobby (bonus); also opened "
        "automatically when no CLI arguments are given",
    )
    return parser


def make_agent(args: argparse.Namespace) -> AgentP:
    """Create the agent, loading a saved model when ``-load`` is given.

    When loading, the file's top-level JSON ``"type"`` field selects the
    concrete agent class so the right brain is restored regardless of ``-model``.

    Args:
        args: Parsed CLI arguments.

    Returns:
        An agent satisfying :class:`learn2slither.contracts.AgentP`.
    """
    if args.load:
        agent = _agent_for_type(_model_type(args.load))
        agent.load(args.load)
        print("Load trained model from {0}".format(args.load))
        return agent
    return _agent_for_type(args.model)


def _model_type(path: str) -> str:
    """Read the ``"type"`` field from a saved model file.

    Args:
        path: Path to a model file written by an agent's ``save``.

    Returns:
        The model type string (e.g. ``"qtable"`` or ``"nn"``).
    """
    with open(path, "r", encoding="utf-8") as handle:
        payload = json.load(handle)
    return str(payload.get("type", "qtable"))


def _agent_for_type(model_type: str) -> AgentP:
    """Instantiate the agent class matching ``model_type``.

    The DQN agent (and thus torch) is imported lazily so the mandatory qtable
    and nn agents never depend on torch being installed.
    """
    if model_type == "nn":
        return NNAgent(seed=DEFAULT_SEED)
    if model_type == "dqn":
        from learn2slither.dqn_agent import DQNAgent

        return DQNAgent(seed=DEFAULT_SEED)
    return QTableAgent(seed=DEFAULT_SEED)


def main(argv: Optional[list] = None) -> int:
    """Parse arguments, run the sessions and persist the model.

    The graphical lobby (bonus) opens when ``-menu`` is given or when the
    program is launched with no CLI arguments at all (a bare ``./snake``); in
    that case the chosen :class:`~learn2slither.menu.LobbyConfig` is mapped onto
    the same run path the CLI uses. Passing any existing flag keeps the original
    behaviour byte-for-byte. A user-initiated quit and ``KeyboardInterrupt`` are
    both handled cleanly and still honor ``-save`` on the way out.

    Args:
        argv: Optional argument vector (defaults to ``sys.argv[1:]``).

    Returns:
        Process exit code (0 on success).
    """
    if _should_open_lobby(argv):
        return _run_from_lobby()
    return _run_from_args(build_parser().parse_args(argv))


def _should_open_lobby(argv: Optional[list]) -> bool:
    """Whether the graphical lobby should be opened for this invocation.

    The lobby opens when ``-menu`` is requested or when no CLI arguments were
    passed at all (``./snake`` with nothing else).

    Args:
        argv: The argument vector passed to :func:`main`.

    Returns:
        ``True`` to open the lobby, ``False`` to use the parsed CLI flags.
    """
    if argv is None:
        no_args = len(sys.argv) == 1
    else:
        no_args = len(argv) == 0
    if no_args:
        return True
    return build_parser().parse_args(argv).menu


def _run_from_lobby() -> int:
    """Loop between the lobby and the game until the user quits the app.

    Each pass opens the lobby; a chosen configuration is played, then control
    returns here so the lobby reopens (the player went back via Escape or the
    run finished). Only closing the game window -- or cancelling the lobby
    itself -- exits the application.

    Returns:
        Process exit code (0).
    """
    from learn2slither.menu import run_lobby

    while True:
        config = run_lobby()
        if config is None:
            return 0
        args = build_parser().parse_args([])
        args.sessions = config.sessions
        args.speed = config.speed
        args.board_size = config.board_size
        args.load = config.load
        args.model = config.model
        args.dontlearn = config.dontlearn
        args.visual = config.visual
        if not _play(args, from_lobby=True):
            return 0


def _run_from_args(args: argparse.Namespace) -> int:
    """Play one configured run from the CLI flags and exit.

    This is the mandatory path; its behaviour is unchanged (a quit or window
    close ends the program rather than returning to any menu).

    Args:
        args: Fully populated CLI namespace.

    Returns:
        Process exit code (0 on success).
    """
    _play(args, from_lobby=False)
    return 0


def _play(args: argparse.Namespace, from_lobby: bool) -> bool:
    """Assemble the world/agent/visualizer and drive the session loop.

    Shared by the CLI-flags path and the lobby path. A user-initiated quit and
    ``KeyboardInterrupt`` are handled cleanly and still honor ``-save`` on the
    way out. When launched from the lobby and the run ends on its own, a
    game-over screen is held until the player continues.

    Args:
        args: Fully populated CLI namespace (also produced from a lobby config).
        from_lobby: Whether this run was launched from the graphical lobby.

    Returns:
        ``True`` when the lobby should reopen (the player asked to go back, or
        the run finished); ``False`` to quit the application (window closed,
        ``KeyboardInterrupt``, or a plain CLI run).
    """
    env = Environment(size=args.board_size, seed=DEFAULT_SEED)
    interpreter = Interpreter()
    agent = make_agent(args)
    if args.dontlearn:
        agent.learning = False

    visualizer = _build_visualizer(args, from_lobby=from_lobby)
    # Keep terminal vision on for visual runs and short headless runs; stay
    # quiet for multi-session headless training so the loop is not flooded.
    verbose = (args.visual == "on") or (args.sessions <= 1)
    interrupted = False
    try:
        run_sessions(
            env,
            interpreter,
            agent,
            sessions=args.sessions,
            visualizer=visualizer,
            step_by_step=args.step_by_step,
            verbose=verbose,
        )
        if from_lobby and visualizer is not None and not visualizer.stopped_by_user:
            visualizer.show_game_over()
            visualizer.wait_for_menu()
    except KeyboardInterrupt:
        print()
        interrupted = True
    finally:
        if args.save:
            agent.save(args.save)
            print("Save learning state in {0}".format(args.save))
        if visualizer is not None:
            visualizer.close()
    if interrupted or visualizer is None:
        return False
    return from_lobby and not visualizer.window_closed


def _build_visualizer(args: argparse.Namespace, from_lobby: bool = False):
    """Construct a visualizer only when the display is enabled.

    Importing pygame is deferred to here so headless runs never touch it.

    Args:
        args: Parsed CLI arguments.
        from_lobby: Whether this run was launched from the graphical lobby
            (passed through so the panel hint reads "Esc menu").

    Returns:
        A ``Visualizer`` instance, or ``None`` when ``-visual off``.
    """
    if args.visual != "on":
        return None
    from learn2slither.visualizer import Visualizer

    return Visualizer(size=args.board_size, fps=args.speed, in_lobby=from_lobby)
