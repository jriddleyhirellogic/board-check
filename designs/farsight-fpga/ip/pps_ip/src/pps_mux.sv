module pps_mux(
    input  logic en_local_pps,
    input  logic local_pps_in,
    input  logic extrn_pps_in,
    output logic pps_out
);

assign pps_out = en_local_pps ? local_pps_in : extrn_pps_in;

endmodule
