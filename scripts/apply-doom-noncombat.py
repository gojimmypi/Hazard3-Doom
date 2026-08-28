#!/usr/bin/env python3
# -----------------------------------------------------------------------------
# File:        apply-doom-noncombat.py
# Path:        scripts/apply-doom-noncombat.py
#
# Project:     Hazard3-Doom
# Purpose:     Apply the Hazard3 Supercon noncombat source transform to a
#              prepared DoomGeneric build tree.
#
# Copyright (c) 2026 gojimmypi
#
# Licensed under the Apache License, Version 2.0.
#
# SPDX-License-Identifier: Apache-2.0
#
# This software is provided under the terms of the applicable license.
# See LICENSES/Apache-2.0.txt for the complete license terms.
# See LICENSING.md for project licensing policy and scope.
# -----------------------------------------------------------------------------

"""Apply Hazard3 Supercon noncombat behavior to a prepared DoomGeneric tree."""

from __future__ import annotations

import argparse
from pathlib import Path

G_MARKER = "hazard3_noncombat_g_game_enabled"
R_MARKER = "hazard3_noncombat_r_things_enabled"


def fail(message: str) -> None:
    raise SystemExit(f"apply-doom-noncombat.py: {message}")


def find_function(text: str, signature: str) -> tuple[int, int, int]:
    start = text.find(signature)
    if start < 0:
        fail(f"could not locate function {signature!r}")
    open_brace = text.find("{", start)
    if open_brace < 0:
        fail(f"could not locate opening brace for {signature!r}")

    depth = 0
    for pos in range(open_brace, len(text)):
        if text[pos] == "{":
            depth += 1
        elif text[pos] == "}":
            depth -= 1
            if depth == 0:
                return start, open_brace, pos
    fail(f"could not locate closing brace for {signature!r}")


def update_g_game(path: Path) -> None:
    text = path.read_text(encoding="utf-8")

    # G_PlayerReborn has only loadout initialization after playerstate. Replace
    # that whole tail, avoiding dependence on tabs or any stale prior transform.
    _, open_brace, close_brace = find_function(text, "void G_PlayerReborn (int player)")
    body = text[open_brace + 1:close_brace]
    anchor = "    p->playerstate = PST_LIVE;"
    anchor_pos = body.find(anchor)
    if anchor_pos < 0:
        fail("could not locate G_PlayerReborn playerstate anchor")
    keep_end = anchor_pos + len(anchor)
    replacement = """
    /* Hazard3 Supercon noncombat loadout: no gun, 200 armor, zero ammo. */
    p->health = deh_initial_health;
    p->armorpoints = 200;
    p->armortype = 2;
    p->readyweapon = p->pendingweapon = wp_fist;
    p->weaponowned[wp_fist] = true;
    p->weaponowned[wp_pistol] = false;

    for (i=0 ; i<NUMAMMO ; i++)
    {
        p->ammo[i] = 0;
        p->maxammo[i] = maxammo[i];
    }
"""
    body = body[:keep_end] + replacement
    text = text[:open_brace + 1] + body + text[close_brace:]

    # Remove Fire generation as a region bounded by stable statements.
    _, open_brace, close_brace = find_function(
        text, "void G_BuildTiccmd (ticcmd_t* cmd, int maketic)"
    )
    body = text[open_brace + 1:close_brace]
    chat = "    cmd->chatchar = HU_dequeueChatChar();"
    use = "    if (gamekeydown[key_use]"
    a = body.find(chat)
    b = body.find(use, a + len(chat)) if a >= 0 else -1
    if a < 0 or b < 0:
        fail("could not locate G_BuildTiccmd buttons region")
    after_chat = a + len(chat)
    body = (
        body[:after_chat]
        + "\n\n    /* Hazard3 Supercon noncombat: Fire is intentionally ignored. */\n\n"
        + body[b:]
    )
    text = text[:open_brace + 1] + body + text[close_brace:]

    if G_MARKER not in text:
        insert = text.find("//\n// G_BuildTiccmd")
        if insert < 0:
            fail("could not locate G_BuildTiccmd marker insertion point")
        marker = (
            "/* Build-verification symbol for the dedicated noncombat image. */\n"
            f"const int {G_MARKER} = 1;\n\n"
        )
        text = text[:insert] + marker + text[insert:]

    # Final assertions on exactly the functions we changed.
    _, ob, cb = find_function(text, "void G_PlayerReborn (int player)")
    reborn = text[ob + 1:cb]
    for item in (
        "p->armorpoints = 200;",
        "p->armortype = 2;",
        "p->weaponowned[wp_pistol] = false;",
        "p->ammo[i] = 0;",
    ):
        if item not in reborn:
            fail(f"G_PlayerReborn verification missing {item!r}")
    if "deh_initial_bullets" in reborn or "wp_pistol;" in reborn:
        fail("armed loadout remains in G_PlayerReborn")

    _, ob, cb = find_function(text, "void G_BuildTiccmd (ticcmd_t* cmd, int maketic)")
    if "cmd->buttons |= BT_ATTACK" in text[ob + 1:cb]:
        fail("BT_ATTACK assignment remains in G_BuildTiccmd")

    path.write_text(text, encoding="utf-8")


def update_r_things(path: Path) -> None:
    text = path.read_text(encoding="utf-8")
    _, open_brace, close_brace = find_function(text, "void R_DrawMasked (void)")
    body = text[open_brace + 1:close_brace]

    marker_comment = "    // draw the psprites on top of everything"
    a = body.find(marker_comment)
    if a < 0:
        transformed = "Hazard3 Supercon noncombat: omit first-person weapon/fist overlay."
        if transformed not in body:
            fail("could not locate R_DrawMasked player-sprite tail")
    else:
        body = (
            body[:a]
            + "    /* Hazard3 Supercon noncombat: omit first-person weapon/fist overlay. */\n"
        )
        text = text[:open_brace + 1] + body + text[close_brace:]

    if R_MARKER not in text:
        insert = text.find("//\n// R_DrawMasked")
        if insert < 0:
            fail("could not locate R_DrawMasked marker insertion point")
        marker = (
            "/* Build-verification symbol for the dedicated noncombat image. */\n"
            f"const int {R_MARKER} = 1;\n\n"
        )
        text = text[:insert] + marker + text[insert:]

    _, ob, cb = find_function(text, "void R_DrawMasked (void)")
    if "R_DrawPlayerSprites" in text[ob + 1:cb]:
        fail("first-person player-sprite draw remains in R_DrawMasked")

    path.write_text(text, encoding="utf-8")


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("doomgeneric_dir", type=Path)
    args = parser.parse_args()

    root = args.doomgeneric_dir.resolve()
    if "third_party/doomgeneric" in root.as_posix():
        fail("refusing to modify third_party/doomgeneric directly")

    g_game = root / "g_game.c"
    r_things = root / "r_things.c"
    if not g_game.is_file():
        fail(f"missing source: {g_game}")
    if not r_things.is_file():
        fail(f"missing source: {r_things}")

    update_g_game(g_game)
    update_r_things(r_things)
    print("Applied and verified Hazard3 Supercon noncombat hooks.")


if __name__ == "__main__":
    main()
