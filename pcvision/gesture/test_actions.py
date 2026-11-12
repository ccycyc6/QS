"""Unit tests for the temporal gesture-action layer (no hardware, no GPU)."""

from __future__ import annotations

import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))

from actions import ActionConfig, GestureActions  # noqa: E402

NAMES = ["background", "fist", "open_palm", "point"]
FPS = 30.0


def feed(g, cls, gx, gy, n, t0, conf=40):
    events, t = [], t0
    for _ in range(n):
        t += 1.0 / FPS
        events.extend(g.update(cls, gx, gy, conf, t))
    return events, t


def test_hold():
    g = GestureActions(NAMES, ActionConfig(hold_seconds=0.5, window=5, min_votes=4))
    ev, _ = feed(g, 2, 40, 22, 30, 0.0)
    kinds = [e.type for e in ev]
    assert "gesture_start" in kinds, kinds
    assert "hold" in kinds, kinds
    holds = [e for e in ev if e.type == "hold"]
    assert len(holds) == 1, holds
    assert holds[0].gesture == "open_palm"


def test_swipe_left():
    g = GestureActions(NAMES, ActionConfig(hold_seconds=99, window=5, min_votes=3,
                                           swipe_cells=5, swipe_seconds=0.4))
    ev, t = feed(g, 2, 50, 22, 10, 0.0)
    # move left by 2 cells per frame for 5 frames
    for i in range(5):
        t += 1.0 / FPS
        ev.extend(g.update(2, 50 - 2 * (i + 1), 22, 40, t))
    swipes = [e for e in ev if e.type == "swipe"]
    assert swipes, [e.to_dict() for e in ev]
    assert swipes[0].direction == "left", swipes[0]


def test_negative_ends_gesture():
    g = GestureActions(NAMES, ActionConfig(window=5, min_votes=4, hold_seconds=99))
    ev, t = feed(g, 1, 40, 22, 10, 0.0)
    assert any(e.type == "gesture_start" for e in ev)
    ev2, _ = feed(g, 0, 0, 0, 8, t, conf=0)
    assert any(e.type == "gesture_end" for e in ev2), [e.to_dict() for e in ev2]


def test_noise_does_not_lock():
    g = GestureActions(NAMES, ActionConfig(window=7, min_votes=6))
    ev = []
    for i in range(30):
        ev.extend(g.update(1 + i % 3, 40, 22, 40, i / FPS))
    assert not any(e.type == "gesture_start" for e in ev), [e.to_dict() for e in ev]


if __name__ == "__main__":
    test_hold()
    test_swipe_left()
    test_negative_ends_gesture()
    test_noise_does_not_lock()
    print("actions: all tests passed")
