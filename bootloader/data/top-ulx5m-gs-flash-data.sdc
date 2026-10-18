# ULX5M-GS V005 board oscillator; no PLL or USB clock in this test.
create_clock -name clk25 -period 40.000 [get_ports {clk25}]
