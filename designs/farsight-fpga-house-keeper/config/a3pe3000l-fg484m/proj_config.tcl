namespace eval ::proj {
  # Tool profiles
  set synprofile  {Synplify Pro ME}
  # set simuprofile {ModelSim ME}

  # Device details
  set die_family        {ProASIC3L}
  set die_eval          {A3PE3000L}
  set eval_package      {484 FBGA}
  set eval_part_range   {MIL}
  set die_voltage       {1.5}
  set die_speed         {STD}
  set hdl_lang          {VERILOG}
  set io_deft_std       {IO_DEFT_STD:LVTTL} 
  set restric_prob_pins {RESTRICTPROBEPINS:1} 
  set ristric_spi_pins  {RESTRICTSPIPINS:0} 
  set temp_rate         {TEMPR:MIL} 
  set vcci_1p5          {VCCI_1.5_VOLTR:COM} 
  set vcci_1p8          {VCCI_1.8_VOLTR:COM} 
  set vcci_2p5          {VCCI_2.5_VOLTR:COM} 
  set vcci_3p3          {VCCI_3.3_VOLTR:COM} 
  set volt_rate         {VOLTR:MIL} 
  
  set SimTime 100us                                                               
  set Effort_Level true                                                           
  set Repair_Min_Delay true                                                       
  set Multi_Pass_Layout false  
}
