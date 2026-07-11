"""Shared fixtures for the Crestbound Duelists test suite."""

from __future__ import annotations

import random
import sys
from pathlib import Path

import pytest

# Make the repository root importable regardless of where pytest is invoked.
ROOT = Path(__file__).resolve().parent.parent
if str(ROOT) not in sys.path:
    sys.path.insert(0, str(ROOT))


@pytest.fixture(autouse=True)
def seeded_rng():
    """Seed the global RNG before every test so results are reproducible."""
    random.seed(1337)
    yield
