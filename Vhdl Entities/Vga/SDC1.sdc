set_time_format -unit ns -decimal_places 2
create_clock -name {InputClk} -period 20.000 -waveform {0 10} [get_ports {InputClk}]
derive_pll_clocks
set_clock_uncertainty -from [get_clocks {InputClk}] -to [get_clocks {InputClk}] -setup 0.1
set_clock_uncertainty -from [get_clocks {InputClk}] -to [get_clocks {InputClk}] -hold 0.1
set_clock_uncertainty -from [get_clocks {VgaPll|altpll_component|auto_generated|pll1|clk[0]}] -to [get_clocks {VgaPll|altpll_component|auto_generated|pll1|clk[0]}] -setup 0.1
set_clock_uncertainty -from [get_clocks {VgaPll|altpll_component|auto_generated|pll1|clk[0]}] -to [get_clocks {VgaPll|altpll_component|auto_generated|pll1|clk[0]}] -hold 0.1
set_input_delay -add_delay -clock [get_clocks {VgaPll|altpll_component|auto_generated|pll1|clk[0]}] 0.1 [get_ports {Reset_n}]
set_output_delay -add_delay -clock [get_clocks {VgaPll|altpll_component|auto_generated|pll1|clk[0]}] 0.1 [get_ports {HsyncClk}]
set_output_delay -add_delay -clock [get_clocks {VgaPll|altpll_component|auto_generated|pll1|clk[0]}] 0.1 [get_ports {VsyncClk}]
set_output_delay -add_delay -clock [get_clocks {VgaPll|altpll_component|auto_generated|pll1|clk[0]}] 0.1 [get_ports {R[0]}]
set_output_delay -add_delay -clock [get_clocks {VgaPll|altpll_component|auto_generated|pll1|clk[0]}] 0.1 [get_ports {R[1]}]
set_output_delay -add_delay -clock [get_clocks {VgaPll|altpll_component|auto_generated|pll1|clk[0]}] 0.1 [get_ports {R[2]}]
set_output_delay -add_delay -clock [get_clocks {VgaPll|altpll_component|auto_generated|pll1|clk[0]}] 0.1 [get_ports {R[3]}]
set_output_delay -add_delay -clock [get_clocks {VgaPll|altpll_component|auto_generated|pll1|clk[0]}] 0.1 [get_ports {R[4]}]
set_output_delay -add_delay -clock [get_clocks {VgaPll|altpll_component|auto_generated|pll1|clk[0]}] 0.1 [get_ports {R[5]}]
set_output_delay -add_delay -clock [get_clocks {VgaPll|altpll_component|auto_generated|pll1|clk[0]}] 0.1 [get_ports {R[6]}]
set_output_delay -add_delay -clock [get_clocks {VgaPll|altpll_component|auto_generated|pll1|clk[0]}] 0.1 [get_ports {R[7]}]
set_output_delay -add_delay -clock [get_clocks {VgaPll|altpll_component|auto_generated|pll1|clk[0]}] 0.1 [get_ports {G[0]}]
set_output_delay -add_delay -clock [get_clocks {VgaPll|altpll_component|auto_generated|pll1|clk[0]}] 0.1 [get_ports {G[1]}]
set_output_delay -add_delay -clock [get_clocks {VgaPll|altpll_component|auto_generated|pll1|clk[0]}] 0.1 [get_ports {G[2]}]
set_output_delay -add_delay -clock [get_clocks {VgaPll|altpll_component|auto_generated|pll1|clk[0]}] 0.1 [get_ports {G[3]}]
set_output_delay -add_delay -clock [get_clocks {VgaPll|altpll_component|auto_generated|pll1|clk[0]}] 0.1 [get_ports {G[4]}]
set_output_delay -add_delay -clock [get_clocks {VgaPll|altpll_component|auto_generated|pll1|clk[0]}] 0.1 [get_ports {G[5]}]
set_output_delay -add_delay -clock [get_clocks {VgaPll|altpll_component|auto_generated|pll1|clk[0]}] 0.1 [get_ports {G[6]}]
set_output_delay -add_delay -clock [get_clocks {VgaPll|altpll_component|auto_generated|pll1|clk[0]}] 0.1 [get_ports {G[7]}]
set_output_delay -add_delay -clock [get_clocks {VgaPll|altpll_component|auto_generated|pll1|clk[0]}] 0.1 [get_ports {B[0]}]
set_output_delay -add_delay -clock [get_clocks {VgaPll|altpll_component|auto_generated|pll1|clk[0]}] 0.1 [get_ports {B[1]}]
set_output_delay -add_delay -clock [get_clocks {VgaPll|altpll_component|auto_generated|pll1|clk[0]}] 0.1 [get_ports {B[2]}]
set_output_delay -add_delay -clock [get_clocks {VgaPll|altpll_component|auto_generated|pll1|clk[0]}] 0.1 [get_ports {B[3]}]
set_output_delay -add_delay -clock [get_clocks {VgaPll|altpll_component|auto_generated|pll1|clk[0]}] 0.1 [get_ports {B[4]}]
set_output_delay -add_delay -clock [get_clocks {VgaPll|altpll_component|auto_generated|pll1|clk[0]}] 0.1 [get_ports {B[5]}]
set_output_delay -add_delay -clock [get_clocks {VgaPll|altpll_component|auto_generated|pll1|clk[0]}] 0.1 [get_ports {B[6]}]
set_output_delay -add_delay -clock [get_clocks {VgaPll|altpll_component|auto_generated|pll1|clk[0]}] 0.1 [get_ports {B[7]}]