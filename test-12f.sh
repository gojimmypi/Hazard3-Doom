rm -f third_party/Hazard3/example_soc/synth/fpga_ulx3s_12f.json

HAZARD3_MEMORY_PROFILE=64m \
    make -C third_party/Hazard3/example_soc/synth \
    -f ULX3S_12F.mk synth

pushd third_party/Hazard3/example_soc/synth

nextpnr-ecp5 \
    --seed 55 \
    --placer heap \
    --12k \
    --speed 6 \
    --package CABGA381 \
    --lpf fpga_ulx3s.lpf \
    --json fpga_ulx3s_12f.json \
    --textcfg fpga_ulx3s_12f-55.config \
    --timing-allow-fail \
    --quiet \
    --log fpga_ulx3s_12f-55-speed6.log

grep "Max frequency for clock" \
    fpga_ulx3s_12f-55-speed6.log

popd