#!/bin/bash

cd /mnt/c/workspace/Hazard3-Doom/bootloader-serv

RUN=build-ulx5m-gs/serv-seed-sweep-20261020T041312Z-20957

# Verify that the netlist and constraints are unchanged.
sha256sum -c "$RUN/inputs.sha256"

# Confirm the implementation exists.
test -s "$RUN/seed-74.txt"

# Create the v16g1 diagnostic bitstream.
gmpack "$RUN/seed-74.txt" build-ulx5m-gs/top_ulx5m_gs_flash_read-serv-v16g1-seed74.bit

ls -lh build-ulx5m-gs/top_ulx5m_gs_flash_read-serv-v16g1-seed74.bit
