# Exporting core IQ_MIXER to TCL
# Exporting Create HDL core command for module IQ_MIXER
create_hdl_core -file "[file normalize [file join [file dirname [info script]] ../src/IQ_MIXER.sv]]" -module {IQ_MIXER} -library {work} -package {}
# Exporting BIF information of  HDL core command for module IQ_MIXER
