# Exporting core RST_HANDLER to TCL
# Exporting Create HDL core command for module RST_HANDLER
create_hdl_core -file "[file normalize [file join [file dirname [info script]] ../src/RST_HANDLER.v]]" -module {RST_HANDLER} -library {work} -package {}
# Exporting BIF information of  HDL core command for module RST_HANDLER
