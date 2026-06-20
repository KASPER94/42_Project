"""Session loop: wire the environment, interpreter and agent together.

This module is the thin orchestrator. It owns no game rules and no learning
maths -- it only drives the contract: read the state, ask the agent to act, step
the world, hand the reward back to the agent, and (optionally) draw the frame
and pace the loop. All business logic lives in the engine and agent modules.
"""

from __future__ import annotations

from typing import Dict, Optional, Tuple

from learn2slither.config import MAX_STEPS_PER_SESSION
from learn2slither.contracts import AgentP, EnvironmentP, InterpreterP
from learn2slither.visualizer import Visualizer

__all__ = ["run_sessions"]


def run_sessions(
    env: EnvironmentP,
    interpreter: InterpreterP,
    agent: AgentP,
    *,
    sessions: int,
    visualizer: Optional[Visualizer] = None,
    step_by_step: bool = False,
    verbose: bool = True,
    max_steps: int = MAX_STEPS_PER_SESSION,
) -> Tuple[int, int]:
    """Run ``sessions`` games and report the best length and duration.

    Args:
        env: The game world to drive.
        interpreter: Turns the board into state and reward.
        agent: The learning brain (frozen if its ``learning`` flag is False).
        sessions: Number of games to play.
        visualizer: Optional pygame visualizer; ``None`` runs headless.
        step_by_step: Gate each step on user input (keypress or Enter).
        verbose: Print the snake's vision and chosen action each step.
        max_steps: Hard cap on steps per game.

    Returns:
        A ``(max_length, max_duration)`` tuple over all sessions.
    """
    max_length = 0
    max_duration = 0
    for index in range(sessions):
        length, duration, quit_requested = _run_one_game(
            env,
            interpreter,
            agent,
            visualizer=visualizer,
            step_by_step=step_by_step,
            verbose=verbose,
            max_steps=max_steps,
            session=index + 1,
            sessions=sessions,
            max_length=max_length,
        )
        max_length = max(max_length, length)
        max_duration = max(max_duration, duration)
        agent.end_session()
        if quit_requested:
            break
    print("Game over, max length = {0}, max duration = {1}".format(max_length, max_duration))
    return max_length, max_duration


def _run_one_game(
    env: EnvironmentP,
    interpreter: InterpreterP,
    agent: AgentP,
    *,
    visualizer: Optional[Visualizer],
    step_by_step: bool,
    verbose: bool,
    max_steps: int,
    session: int = 1,
    sessions: int = 1,
    max_length: int = 0,
) -> Tuple[int, int, bool]:
    """Play a single game until the snake dies or hits ``max_steps``.

    Args:
        session: 1-based index of this game (for the stats overlay).
        sessions: Total number of games (for the stats overlay).
        max_length: Best length seen in prior games (for the stats overlay).

    Returns:
        A ``(length, duration, quit_requested)`` tuple. ``quit_requested`` is
        True when the user asked to stop via the visualizer.
    """
    env.reset()
    state = interpreter.get_state(env)
    best_length = max(max_length, env.length)
    duration = 0
    reward_total = 0.0
    while True:
        if verbose:
            print(interpreter.render_vision(env))
        action = agent.choose_action(state)
        if verbose:
            print("Action: {0}".format(action.name))
        result = env.step(action)
        reward = interpreter.get_reward(result)
        next_state = interpreter.get_state(env) if not result.done else state
        agent.learn(state, action, reward, next_state, result.done)
        state = next_state
        duration += 1
        reward_total += reward
        best_length = max(best_length, result.length)
        stats = _build_stats(
            agent, session, sessions, env.length, best_length,
            duration, reward_total, step_by_step, visualizer,
        )
        if not _present_step(env, visualizer, step_by_step, stats):
            return best_length, duration, True
        if result.done or duration >= max_steps:
            return best_length, duration, False


def _build_stats(
    agent: AgentP,
    session: int,
    sessions: int,
    length: int,
    max_length: int,
    duration: int,
    reward: float,
    step_by_step: bool,
    visualizer: Optional[Visualizer],
) -> Optional[Dict]:
    """Assemble the stats mapping for the overlay, or ``None`` when headless.

    Returns:
        A dict consumed by ``Visualizer.render``, or ``None`` if there is no
        visualizer (so the headless path stays allocation-free and unchanged).
    """
    if visualizer is None:
        return None
    return {
        "session": session,
        "sessions": sessions,
        "length": length,
        "max_length": max_length,
        "duration": duration,
        "reward": reward,
        "epsilon": getattr(agent, "epsilon", None),
        "learning": getattr(agent, "learning", True),
        "fps": visualizer.fps,
        "paused": visualizer.paused,
        "step_by_step": step_by_step,
    }


def _present_step(
    env: EnvironmentP,
    visualizer: Optional[Visualizer],
    step_by_step: bool,
    stats: Optional[Dict] = None,
) -> bool:
    """Draw the frame and pace or gate the loop for one step.

    With a visualizer: render the board plus the stats overlay, then either
    wait for a keypress (step-by-step) or honour live pause/step controls and
    cap the frame rate. Without a visualizer: gate on Enter when step-by-step,
    otherwise do nothing (behaviour unchanged from the mandatory part).

    Returns:
        ``False`` if the user asked to quit, otherwise ``True``.
    """
    if visualizer is None:
        if step_by_step:
            return _wait_for_enter()
        return True
    visualizer.render(env, stats)
    if step_by_step:
        return visualizer.wait_for_step()
    return _run_or_pause(env, visualizer, stats)


def _run_or_pause(
    env: EnvironmentP,
    visualizer: Visualizer,
    stats: Optional[Dict],
) -> bool:
    """Advance one frame, blocking here while the user has paused playback.

    While paused, events keep being pumped and the frame re-rendered so the
    overlay stays live and responsive, but the game does not advance until the
    user unpauses or requests a single step (Right/Return).

    Returns:
        ``False`` if the user asked to quit, otherwise ``True``.
    """
    while True:
        if not visualizer.process_events():
            return False
        if not visualizer.paused or visualizer.step_requested:
            visualizer.step_requested = False
            visualizer.tick()
            return True
        if stats is not None:
            stats["paused"] = True
            stats["fps"] = visualizer.fps
        visualizer.render(env, stats)
        visualizer.tick()


def _wait_for_enter() -> bool:
    """Block on ``input`` for headless step-by-step mode.

    Returns:
        ``False`` if stdin is closed (EOF), otherwise ``True``.
    """
    try:
        input("Press Enter to step (Ctrl-D to quit)... ")
    except EOFError:
        return False
    return True
