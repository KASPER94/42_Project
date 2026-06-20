"""Shared pytest fixtures.

Adds ``src`` to the import path so ``import learn2slither...`` works without an
install step, and exposes a few small fixtures the module tests reuse.
"""

from __future__ import annotations

import os
import sys

import pytest

_ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
_SRC = os.path.join(_ROOT, "src")
if _SRC not in sys.path:
    sys.path.insert(0, _SRC)


@pytest.fixture
def seed() -> int:
    """A fixed seed for deterministic tests."""
    return 1234
