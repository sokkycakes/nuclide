#!/usr/bin/env python3
"""Assert GameMessage same-channel replace semantics (HL/Quake-style).

Mirrors the timing used by GameText_DrawMessage / GameMessage_Setup:
a new message on the same channel must restart at t=0 and use THAT
message's fadein/hold/fadeout — not wait out the previous cycle.
"""

from __future__ import annotations


def lifetime(fadein: float, hold: float, fadeout: float) -> float:
    return fadein + hold + fadeout


def alpha_at(t: float, fadein: float, hold: float, fadeout: float) -> float:
    if t < 0:
        return 0.0
    if t < fadein:
        return t / fadein if fadein else 1.0
    if t < fadein + hold:
        return 1.0
    if t < fadein + hold + fadeout:
        return 1.0 - (t - fadein - hold) / fadeout if fadeout else 0.0
    return 0.0


def main() -> None:
    # Arena-style rapid centerprints: 3 -> 2 one second later.
    # Old queue behavior: "2" could not start until lifetime("3") ~= 3.0s.
    # Replace behavior: "2" starts at the moment it is sent.
    a = dict(fadein=0.5, hold=2.0, fadeout=0.5, text="3")
    assert lifetime(**{k: a[k] for k in ("fadein", "hold", "fadeout")}) == 3.0

    # After 1.0s of "3", a replace installs "2" with the same defaults.
    t_when_replaced = 1.0
    assert alpha_at(t_when_replaced, a["fadein"], a["hold"], a["fadeout"]) == 1.0

    b = dict(fadein=0.5, hold=2.0, fadeout=0.5, text="2", time=0.0)
    # Immediately after replace, we are in fade-in of the NEW message.
    assert 0.0 < alpha_at(b["time"] + 0.1, b["fadein"], b["hold"], b["fadeout"]) < 1.0
    assert b["time"] == 0.0, "replace must restart channel timer"

    # titles.txt / game_text dictate their own fade params.
    title = dict(fadein=0.0, hold=1.0, fadeout=0.25)
    assert lifetime(**title) == 1.25
    assert alpha_at(0.0, **title) == 1.0  # fadein 0 => fully visible immediately
    assert alpha_at(1.1, **title) < 1.0

    print("ok: gamemessage same-channel replace + fade params")


if __name__ == "__main__":
    main()
