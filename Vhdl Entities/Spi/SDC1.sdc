set_time_format -unit ns -decimal_places 2
create_clock -name {ActlClk} -period 20.000 -waveform {0 10} [get_ports {ActlClk}]
derive_pll_clocks
set_clock_uncertainty -from [get_clocks {ActlClk}] -to [get_clocks {ActlClk}] -setup 0.1
set_clock_uncertainty -from [get_clocks {ActlClk}] -to [get_clocks {ActlClk}] -hold 0.1
set_clock_uncertainty -from [get_clocks {Spipll|altpll_component|auto_generated|pll1|clk[0]}] -to [get_clocks {Spipll|altpll_component|auto_generated|pll1|clk[0]}] -setup 0.1
set_clock_uncertainty -from [get_clocks {Spipll|altpll_component|auto_generated|pll1|clk[0]}] -to [get_clocks {Spipll|altpll_component|auto_generated|pll1|clk[0]}] -hold 0.1
set_input_delay -add_delay -clock [get_clocks {Spipll|altpll_component|auto_generated|pll1|clk[0]}] 0.1 [get_ports {Reset_n}]
set_input_delay -add_delay -clock [get_clocks {Spipll|altpll_component|auto_generated|pll1|clk[0]}] 0.1 [get_ports {SpiClk}]
set_input_delay -add_delay -clock [get_clocks {Spipll|altpll_component|auto_generated|pll1|clk[0]}] 0.1 [get_ports {SI}]
set_input_delay -add_delay -clock [get_clocks {Spipll|altpll_component|auto_generated|pll1|clk[0]}] 0.1 [get_ports {CS}]
set_output_delay -add_delay -clock [get_clocks {Spipll|altpll_component|auto_generated|pll1|clk[0]}] 0.1 [get_ports {SO}]
set_output_delay -add_delay -clock [get_clocks {Spipll|altpll_component|auto_generated|pll1|clk[0]}] 0.1 [get_ports {SpiReady}]
set_output_delay -add_delay -clock [get_clocks {Spipll|altpll_component|auto_generated|pll1|clk[0]}] 0.1 [get_ports {Leds[0]}]
set_output_delay -add_delay -clock [get_clocks {Spipll|altpll_component|auto_generated|pll1|clk[0]}] 0.1 [get_ports {Leds[1]}]
set_output_delay -add_delay -clock [get_clocks {Spipll|altpll_component|auto_generated|pll1|clk[0]}] 0.1 [get_ports {Leds[2]}]
set_output_delay -add_delay -clock [get_clocks {Spipll|altpll_component|auto_generated|pll1|clk[0]}] 0.1 [get_ports {Leds[3]}]
set_output_delay -add_delay -clock [get_clocks {Spipll|altpll_component|auto_generated|pll1|clk[0]}] 0.1 [get_ports {Leds[4]}]
set_output_delay -add_delay -clock [get_clocks {Spipll|altpll_component|auto_generated|pll1|clk[0]}] 0.1 [get_ports {Leds[5]}]
set_output_delay -add_delay -clock [get_clocks {Spipll|altpll_component|auto_generated|pll1|clk[0]}] 0.1 [get_ports {Leds[6]}]
set_output_delay -add_delay -clock [get_clocks {Spipll|altpll_component|auto_generated|pll1|clk[0]}] 0.1 [get_ports {Leds[7]}]