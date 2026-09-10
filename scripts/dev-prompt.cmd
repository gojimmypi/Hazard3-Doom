REM Start multiple tabs in Windows Terminal for Hazard3-Doom development environment
wt --version

wt -w "Hazard3-Doom" new-tab --title "Hazard3-Doom"  --suppressApplicationTitle wsl.exe -d Ubuntu --cd /mnt/c/workspace/Hazard3-Doom     bash -c "printf '\nTypical command:\n\n  ./scripts/inventory.sh  ./scripts/ \n\n ./scripts/inventory.sh ./bin/  \n\n  ./scripts/generate-sbom.py                   \n\n ' && exec bash"

wt -w "Hazard3-Doom" new-tab --title "Regression"    --suppressApplicationTitle wsl.exe -d Ubuntu --cd /mnt/c/workspace/Hazard3-Doom     bash -c "printf '\nTypical command:\n\n  \n\n' && exec bash"

wt -w "Hazard3-Doom" new-tab --title "sweep"         --suppressApplicationTitle wsl.exe -d Ubuntu --cd /mnt/c/workspace/Hazard3-Doom     bash -c "printf '\nTypical command:\n\n  SWEEP_JOBS=1 \\ \n  SWEEP_SKIP_SYNTH=1 \\ \n  SWEEP_ROUTE_TIMEOUT_SECONDS=7200 \\ \n    ./scripts/sweep-ulx3s-85f.sh  11-12  \n\n' && exec bash"

wt -w "Hazard3-Doom" new-tab --title "dfu"           --suppressApplicationTitle wsl.exe -d Ubuntu --cd /mnt/c/workspace/Hazard3-Doom     bash -c "printf '\nTypical command:\n\n  ./bin/fujprog-v48-win64.exe ./build/fpga_ulx3s.bit                                         \n\n' && exec bash"

wt -w "Hazard3-Doom" new-tab --title "bitstream"     --suppressApplicationTitle wsl.exe -d Ubuntu --cd /mnt/c/workspace/Hazard3-Doom     bash -c "printf '\nTypical command:\n\n  ./bin/fujprog-v48-win64.exe ./build/fpga_ulx3s.bit                                         \n\n' && exec bash"

wt -w "Hazard3-Doom" new-tab --title "Monitor build" --suppressApplicationTitle wsl.exe -d Ubuntu --cd /mnt/c/workspace/Hazard3-Doom     bash -c "printf '\nTypical command:\n\n  ./scripts/build.sh                                                                         \n\n' && exec bash"

wt -w "Hazard3-Doom" new-tab --title "OpenOCD"       --suppressApplicationTitle wsl.exe -d Ubuntu --cd /mnt/c/workspace/Hazard3-Doom     bash -c "printf '\nTypical command:\n\n  ./bin/openocd.exe -d2 -f ./third_party/Hazard3/example_soc/ulx4m-openocd-tigard-fixed.cfg  \n\n' && exec bash"

wt -w "Hazard3-Doom" new-tab --title "GDB"           --suppressApplicationTitle wsl.exe -d Ubuntu --cd /mnt/c/workspace/Hazard3-Doom     bash -c "printf '\nTypical command:\n\n  gdb                                                                                        \n\n' && exec bash"

wt -w "Hazard3-Doom" new-tab --title "Build Doom"    --suppressApplicationTitle wsl.exe -d Ubuntu --cd /mnt/c/workspace/Hazard3-Doom     bash -c "printf '\nTypical command:\n\n  ./doom/build-doom-image.sh                                                                 \n\n' && exec bash"

wt -w "Hazard3-Doom" new-tab --title "Load Doom"     --suppressApplicationTitle wsl.exe -d Ubuntu --cd /mnt/c/workspace/Hazard3-Doom     bash -c "printf '\nTypical command:\n\n  ./doom/upload-doom-image.py  ./build/doom-image/hazard3-doom.h3d --port /dev/ttyS8         \n\n' && exec bash"

wt -w "Hazard3-Doom" new-tab --title "Load WAD"      --suppressApplicationTitle wsl.exe -d Ubuntu --cd /mnt/c/workspace/Hazard3-Doom     bash -c "printf '\nTypical command:\n\n  ./doom/upload-wad.py  ./wads/DOOM.WAD  --port /dev/ttyS8                                   \n\n' && exec bash"

wt -w "Hazard3-Doom" new-tab --title "Hazard3 repo"  --suppressApplicationTitle wsl.exe -d Ubuntu --cd /mnt/c/workspace/Hazard3-ulx-doom bash -c "printf '\nTypical command:\n\n  git status --short        \n\n  git diff --cached\n\n  --stat diff --stat                  \n\n' && exec bash"

wt -w "Hazard3-Doom" new-tab --title "ULX3S Pinout"  --suppressApplicationTitle wsl.exe -d Ubuntu --cd /mnt/c/workspace/ulx3s-pinout     bash -c "printf '\nTypical command:\n\n  ./scripts/test-pinout.sh  \n\n  ./generate-pinout.py ulx3s                                 \n\n' && exec bash"