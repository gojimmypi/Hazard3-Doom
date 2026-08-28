#!/bin/bash
# -----------------------------------------------------------------------------
# File:        doom_sources.sh
# Path:        doom/doom_sources.sh
#
# Project:     Hazard3-Doom
# Purpose:     Define the upstream DoomGeneric source set used by Hazard3-Doom
#              builds.
#
# Copyright (c) 2026 gojimmypi
#
# Licensed under the GNU General Public License, version 2 or later.
#
# SPDX-License-Identifier: GPL-2.0-or-later
#
# This software is provided WITHOUT ANY WARRANTY.
# See LICENSES/GPL-2.0.txt for the complete license terms.
# See LICENSING.md for project licensing policy and scope.
# -----------------------------------------------------------------------------


# Source list derived from ozkl/doomgeneric doomgeneric/Makefile.
# The Xlib platform file is intentionally replaced by doomgeneric_hazard3.c.
#
# This array is consumed by scripts that source this file.
# shellcheck disable=SC2034
DOOMGENERIC_SOURCES=(
    dummy.c
    am_map.c
    doomdef.c
    doomstat.c
    dstrings.c
    d_event.c
    d_items.c
    d_iwad.c
    d_loop.c
    d_main.c
    d_mode.c
    d_net.c
    f_finale.c
    f_wipe.c
    g_game.c
    hu_lib.c
    hu_stuff.c
    info.c
    i_cdmus.c
    i_endoom.c
    i_joystick.c
    i_scale.c
    i_sound.c
    i_system.c
    i_timer.c
    memio.c
    m_argv.c
    m_bbox.c
    m_cheat.c
    m_config.c
    m_controls.c
    m_fixed.c
    m_menu.c
    m_misc.c
    m_random.c
    p_ceilng.c
    p_doors.c
    p_enemy.c
    p_floor.c
    p_inter.c
    p_lights.c
    p_map.c
    p_maputl.c
    p_mobj.c
    p_plats.c
    p_pspr.c
    p_saveg.c
    p_setup.c
    p_sight.c
    p_spec.c
    p_switch.c
    p_telept.c
    p_tick.c
    p_user.c
    r_bsp.c
    r_data.c
    r_draw.c
    r_main.c
    r_plane.c
    r_segs.c
    r_sky.c
    r_things.c
    sha1.c
    sounds.c
    statdump.c
    st_lib.c
    st_stuff.c
    s_sound.c
    tables.c
    v_video.c
    wi_stuff.c
    w_checksum.c
    w_file.c
    w_main.c
    w_wad.c
    z_zone.c
    w_file_stdc.c
    i_input.c
    i_video.c
    doomgeneric.c
)
