# Exporting core IIR_BIQUAD to TCL
# Exporting Create HDL core command for module IIR_BIQUAD
create_hdl_core -file "[file normalize [file join [file dirname [info script]] ../src/IIR_BIQUAD.sv]]" -module {IIR_BIQUAD} -library {work} -package {}
# Exporting BIF information of  HDL core command for module IIR_BIQUAD
