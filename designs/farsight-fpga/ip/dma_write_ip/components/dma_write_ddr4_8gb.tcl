# Exporting core word_alignment to TCL
# Exporting Create HDL core command for module word_alignment
set hdl_file "[file normalize [file join [file dirname [info script]] ./../src/dma_write_ddr4_8gb.sv]]"
create_hdl_core -file ${hdl_file} -module {dma_write_ddr4_8gb} -library {work} -package {}
# Exporting BIF information of  HDL core command for module word_alignment
