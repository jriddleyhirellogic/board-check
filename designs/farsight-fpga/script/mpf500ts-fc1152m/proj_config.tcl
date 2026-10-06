namespace eval ::proj {
  # Tool profiles
  set synprofile  {Synplify Pro ME}
  set simuprofile {QuestaSim ME}

  # Device details
  set die_family              {PolarFire}
  set die_name                {MPF500TS}
  set die_package             {FC1152}
  set die_part_range          {MIL}
  set die_voltage             {1.0}
  set die_speed               {STD}
  set hdl_lang                {VERILOG}
  set block_mode              {0}
  set use_relative_path       {1}
  set restrict_probe_pins     {RESTRICTPROBEPINS:0}
  set restrict_spi_pins       {RESTRICTSPIPINS:0}
  set io_default_std          {IO_DEFT_STD:LVCMOS 1.8V}
  set sys_ctrl_suspend        {SYSTEM_CONTROLLER_SUSPEND_MODE:0}
  set reserve_migration_pins  {RESERVEMIGRATIONPINS:0}
  set temp_range              {TEMPR:MIL}
  set vcci_1p2_volt_range     {VCCI_1.2_VOLTR:MIL}
  set vcci_1p5_volt_range     {VCCI_1.5_VOLTR:MIL}
  set vcci_1p8_volt_range     {VCCI_1.8_VOLTR:MIL}
  set vcci_2p5_volt_range     {VCCI_2.5_VOLTR:MIL}
  set vcci_3p3_volt_range     {VCCI_3.3_VOLTR:MIL}
  set volt_range              {VOLTR:MIL} 


  set SimTime 100us                                                               
  set Effort_Level true                                                           
  set Repair_Min_Delay true                                                       
  set Multi_Pass_Layout false  
}
