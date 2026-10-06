#-------------------------------------------------------------------------------
# Sys Clock
#-------------------------------------------------------------------------------
create_clock -name {sys_clk_50mhz} -period 20 [ get_ports { sys_clk_50mhz } ]

create_generated_clock -name {PF_CCC_C0_inst/PF_CCC_C0_0/pll_inst_0/OUT1} -divide_by 1 -source [ get_pins { PF_CCC_C0_inst/PF_CCC_C0_0/pll_inst_0/REF_CLK_0 } ] -phase 0 [ get_pins { PF_CCC_C0_inst/PF_CCC_C0_0/pll_inst_0/OUT1 } ]