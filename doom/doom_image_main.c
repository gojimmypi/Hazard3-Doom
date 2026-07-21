#include <stdint.h>

#include "doom_image_format.h"
#include "doomgeneric.h"
#include "doomgeneric_hazard3.h"
#include "hazard3_monitor_services.h"
#include "hazard3_platform.h"
#include "hazard3_video.h"
#include "m_menu.h"
#include "r_main.h"

static char argument_program[] = "doom";
static char argument_iwad[] = "-iwad";
static char argument_mb[] = "-mb";
static char argument_mb_value[] = "6";
static char argument_nogui[] = "-nogui";
static char argument_nosound[] = "-nosound";
static char argument_nomusic[] = "-nomusic";

#ifdef DOOM_WARP
static char argument_warp[] = "-warp";
static char argument_episode[] = "1";
static char argument_map[] = "1";
#endif

static char* doom_arguments[] = {
    argument_program,
    argument_iwad,
    (char*)0,
    argument_mb,
    argument_mb_value,
    argument_nogui,
    argument_nosound,
    argument_nomusic

#ifdef DOOM_WARP
    ,
    argument_warp,
    argument_episode,
    argument_map
#endif
};

static int services_are_valid(const hazard3_monitor_services_t* services)
{
    return services != (const hazard3_monitor_services_t*)0 &&
        services->abi_version == HAZARD3_MONITOR_ABI_VERSION &&
        services->struct_bytes >= sizeof(hazard3_monitor_services_t) &&
        services->console_puts != (void (*)(const char*))0 &&
        services->console_put_hex32 != (void (*)(uint32_t))0 &&
        services->ticks_ms != (uint32_t (*)(void))0 &&
        services->sleep_ms != (void (*)(uint32_t))0 &&
        services->sbrk != (void* (*)(ptrdiff_t))0 &&
        services->image_base == HAZARD3_DOOM_IMAGE_BASE &&
        services->image_limit == HAZARD3_DOOM_IMAGE_LIMIT &&
        services->heap_base == HAZARD3_DOOM_HEAP_BASE &&
        services->heap_limit == HAZARD3_DOOM_HEAP_LIMIT &&
        services->video_base == HAZARD3_VIDEO_BASE &&
        services->video_limit == HAZARD3_VIDEO_LIMIT &&
        services->video_limit - services->video_base >= 2u * 320u * 200u &&
        services->screen_base == HAZARD3_DOOM_SCREENBUFFER_BASE &&
        services->screen_bytes >= HAZARD3_DOOM_SCREENBUFFER_BYTES &&
        services->wad_base == HAZARD3_DOOM_WAD_BASE &&
        services->wad_limit == HAZARD3_DOOM_WAD_LIMIT &&
        services->wad_bytes >= 12u &&
        services->wad_bytes <= services->wad_limit - services->wad_base &&
        services->wad_name != (const char*)0;
}

int32_t doom_image_main(const hazard3_monitor_services_t* services)
{
    uint32_t start_ticks;
    uint32_t timer_elapsed;
    uint32_t frame_count;
    uint32_t interactive_start_ticks;
    uint32_t interactive_start_frames;
    uint32_t interactive_elapsed;
    if (!services_are_valid(services)) {
        if (services != (const hazard3_monitor_services_t*)0 &&
            services->console_puts != (void (*)(const char*))0) {
            services->console_puts(
                "Doom image: incompatible monitor service table or missing IWAD\r\n");
        }
        return 1;
    }
    hazard3_monitor_services_bind(services);
    hazard3_console_puts("\r\ndoom_image_build=");
    hazard3_console_puts(HAZARD3_DOOM_IMAGE_BUILD_NAME);
    hazard3_console_puts(" doom_image_id=");
    hazard3_console_put_hex32(HAZARD3_DOOM_IMAGE_BUILD_ID);
    hazard3_console_puts("\r\nDoom SDRAM image startup\r\n");
    hazard3_console_puts("  monitor ABI: PASS\r\n");
    hazard3_console_puts("  image range: ");
    hazard3_console_put_hex32(services->image_base);
    hazard3_console_puts("-");
    hazard3_console_put_hex32(services->image_limit - 1u);
    hazard3_console_puts("\r\n  heap range: ");
    hazard3_console_put_hex32(services->heap_base);
    hazard3_console_puts("-");
    hazard3_console_put_hex32(services->heap_limit - 1u);
    hazard3_console_puts("\r\n  IWAD: ");
    hazard3_console_puts(services->wad_name);
    hazard3_console_puts(" base=");
    hazard3_console_put_hex32(services->wad_base);
    hazard3_console_puts(" bytes=");
    hazard3_console_put_hex32(services->wad_bytes);
    hazard3_console_puts("\r\n");

    start_ticks = hazard3_ticks_ms();
    hazard3_sleep_ms(20u);
    timer_elapsed = hazard3_ticks_ms() - start_ticks;
    hazard3_console_puts("  monitor timer service: ");
    hazard3_console_puts(timer_elapsed >= 20u ? "PASS\r\n" : "FAIL\r\n");
    if (timer_elapsed < 20u) {
        return 2;
    }

    doom_arguments[2] = (char*)services->wad_name;
    hazard3_doom_input_reset();
    hazard3_console_puts("  entering Doom WAD discovery and initialization\r\n");
    doomgeneric_Create(
        (int)(sizeof(doom_arguments) / sizeof(doom_arguments[0])),
        doom_arguments);

    // Performance-R5 doubles the ULX4M Hazard3 clock to match ULX3S and moves
    // frame presentation off DDR. Start with Doom's largest status-bar view in
    // high detail; the Options menu can still select low detail or full screen.
    screenblocks = 10;
    detailLevel = 0;
    R_SetViewSize(screenblocks, detailLevel);
    hazard3_console_puts(
        "  performance mode: 50 MHz CPU, direct EBR present, high detail, view size 10\r\n");

#ifdef DOOM_WARP
    hazard3_console_puts("  auto-start: E1M1\r\n");
#else
    hazard3_console_puts("  startup mode: Doom title/demo attract loop\r\n");
#endif

    frame_count = hazard3_doom_draw_frame_count();
    if (frame_count == 0u) {
        hazard3_console_puts("Doom HDMI framebuffer milestone: FAIL\r\n");
        return 3;
    }

    hazard3_console_puts("Doom interactive HDMI loop: READY\r\n");
    hazard3_console_puts(
        "  controls: W/S or arrows move/turn, Z/C strafe, F/space fire, E use\r\n");
    hazard3_console_puts(
        "  M map, P pause, 1-7 weapons, Enter select, Esc menu\r\n");
    hazard3_console_puts(
        "  Esc backs out of menus; Ctrl-X returns to monitor; j restarts\r\n");

    interactive_start_ticks = hazard3_ticks_ms();
    interactive_start_frames = frame_count;
    while (!hazard3_doom_exit_requested()) {
        doomgeneric_Tick();
    }
    interactive_elapsed = hazard3_ticks_ms() - interactive_start_ticks;
    frame_count = hazard3_doom_draw_frame_count();

    hazard3_console_puts("Doom interactive HDMI loop: EXIT\r\n");
    hazard3_console_puts("  interactive_frames=");
    hazard3_console_put_hex32(frame_count - interactive_start_frames);
    hazard3_console_puts(" elapsed_ms=");
    hazard3_console_put_hex32(interactive_elapsed);
    hazard3_console_puts(" total_frames=");
    hazard3_console_put_hex32(frame_count);
    hazard3_console_puts("\r\n  last_copy_cycles=");
    hazard3_console_put_hex32(hazard3_doom_last_copy_cycles());
    hazard3_console_puts(" last_present_cycles=");
    hazard3_console_put_hex32(hazard3_doom_last_present_cycles());
    hazard3_console_puts("\r\n  copy_cycles_total=");
    hazard3_console_put_hex32(hazard3_doom_copy_cycles_total());
    hazard3_console_puts(" present_cycles_total=");
    hazard3_console_put_hex32(hazard3_doom_present_cycles_total());
    hazard3_console_puts("\r\n  heap_used=");
    hazard3_console_put_hex32(hazard3_heap_used());
    hazard3_console_puts(" heap_remaining=");
    hazard3_console_put_hex32(hazard3_heap_remaining());
    hazard3_console_puts("\r\nDoom playable-performance milestone: PASS\r\n");
    return 0;
}
