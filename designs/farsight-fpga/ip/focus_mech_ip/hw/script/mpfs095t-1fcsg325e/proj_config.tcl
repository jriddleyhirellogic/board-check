namespace eval ::proj {
  # Tool profiles
  set synprofile  {Synplify Pro ME}
  set simuprofile {QuestaSim ME}

  # Device details
  set die_family      {PolarFireSoC}
  set die_eval        {MPFS095T}
  set eval_package    {FCSG325}
  set eval_part_range {EXT}
  set die_voltage     {1.0}
  set die_speed       {-1}
  set hdl_lang        {VERILOG}

  set SimTime 100us                                                               
  set Effort_Level true                                                           
  set Repair_Min_Delay true                                                       
  set Multi_Pass_Layout false  
}
