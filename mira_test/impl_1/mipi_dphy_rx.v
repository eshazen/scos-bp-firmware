// Verilog netlist produced by program LSE 
// Netlist written on Wed Jul 29 23:22:32 2026
// Source file index table: 
// Object locations will have the form @<file_index>(<first_ line>[<left_column>],<last_line>[<right_column>])
// file 0 "c:/lscc/radiant/2026.1/ip/lfmxo4/fifo_dc/rtl/lscc_lfmxo4_fifo_dc.v"
// file 1 "c:/lscc/radiant/2026.1/ip/lfmxo4/fifo_dc/rtl/lscc_lfmxo4_fifo_dc_distributed_ram.v"
// file 2 "c:/lscc/radiant/2026.1/ip/lfmxo4/fifo_dc/rtl/lscc_lfmxo4_fifo_dc_ecc.v"
// file 3 "c:/lscc/radiant/2026.1/ip/lfmxo4/fifo_dc/rtl/lscc_lfmxo4_fifo_dc_flag_and_cnts_logic.v"
// file 4 "c:/lscc/radiant/2026.1/ip/lfmxo4/fifo_dc/rtl/lscc_lfmxo4_fifo_dc_gray_reg.v"
// file 5 "c:/lscc/radiant/2026.1/ip/lfmxo4/fifo_dc/rtl/lscc_lfmxo4_fifo_dc_gray_synchronizer.v"
// file 6 "c:/lscc/radiant/2026.1/ip/lfmxo4/fifo_dc/rtl/lscc_lfmxo4_fifo_dc_harden.v"
// file 7 "c:/lscc/radiant/2026.1/ip/lfmxo4/fifo_dc/rtl/lscc_lfmxo4_fifo_dc_harden_prim.v"
// file 8 "c:/lscc/radiant/2026.1/ip/lfmxo4/fifo_dc/rtl/lscc_lfmxo4_fifo_dc_harden_rd_ctrl_logic.v"
// file 9 "c:/lscc/radiant/2026.1/ip/lfmxo4/fifo_dc/rtl/lscc_lfmxo4_fifo_dc_harden_rd_output_logic.v"
// file 10 "c:/lscc/radiant/2026.1/ip/lfmxo4/fifo_dc/rtl/lscc_lfmxo4_fifo_dc_harden_ring_counter.v"
// file 11 "c:/lscc/radiant/2026.1/ip/lfmxo4/fifo_dc/rtl/lscc_lfmxo4_fifo_dc_harden_wr_ctrl_logic.v"
// file 12 "c:/lscc/radiant/2026.1/ip/lfmxo4/fifo_dc/rtl/lscc_lfmxo4_fifo_dc_prim_gen.v"
// file 13 "c:/lscc/radiant/2026.1/ip/lfmxo4/fifo_dc/rtl/lscc_lfmxo4_fifo_dc_rd_ctrl_logic.v"
// file 14 "c:/lscc/radiant/2026.1/ip/lfmxo4/fifo_dc/rtl/lscc_lfmxo4_fifo_dc_wr_ctrl_logic.v"
// file 15 "c:/lscc/radiant/2026.1/ip/lfmxo4/ram_dp/rtl/lscc_lfmxo4_ram_dp.v"
// file 16 "c:/lscc/radiant/2026.1/ip/lfmxo4/ram_dp/rtl/lscc_lfmxo4_ram_dp_behavioral.v"
// file 17 "c:/lscc/radiant/2026.1/ip/lfmxo4/ram_dp/rtl/lscc_lfmxo4_ram_dp_functions.vh"
// file 18 "c:/lscc/radiant/2026.1/ip/lfmxo4/ram_dp/rtl/lscc_lfmxo4_ram_dp_impl.v"
// file 19 "c:/lscc/radiant/2026.1/ip/lfmxo4/ram_dp/rtl/lscc_lfmxo4_ram_dp_lut_decode.v"
// file 20 "c:/lscc/radiant/2026.1/ip/lfmxo4/ram_dp_true/rtl/lscc_lfmxo4_ram_dp_true.v"
// file 21 "c:/lscc/radiant/2026.1/ip/lfmxo4/ram_dp_true/rtl/lscc_lfmxo4_ram_dp_true_behavioral.v"
// file 22 "c:/lscc/radiant/2026.1/ip/lfmxo4/ram_dp_true/rtl/lscc_lfmxo4_ram_dp_true_ecc_decoder.v"
// file 23 "c:/lscc/radiant/2026.1/ip/lfmxo4/ram_dp_true/rtl/lscc_lfmxo4_ram_dp_true_functions.vh"
// file 24 "c:/lscc/radiant/2026.1/ip/lfmxo4/ram_dp_true/rtl/lscc_lfmxo4_ram_dp_true_impl.v"
// file 25 "c:/lscc/radiant/2026.1/ip/lfmxo4/ram_dp_true/rtl/lscc_lfmxo4_ram_dp_true_lut_decode.v"
// file 26 "c:/lscc/radiant/2026.1/ip/lfmxo4/ram_dq/rtl/hsiao_ecc_decoder.v"
// file 27 "c:/lscc/radiant/2026.1/ip/lfmxo4/ram_dq/rtl/hsiao_ecc_encoder.v"
// file 28 "c:/lscc/radiant/2026.1/ip/lfmxo4/ram_dq/rtl/lscc_lfmxo4_ram_dq.v"
// file 29 "c:/lscc/radiant/2026.1/ip/lfmxo4/ram_dq/rtl/lscc_lfmxo4_ram_dq_lut_decode.v"
// file 30 "c:/lscc/radiant/2026.1/ip/common/adder/rtl/lscc_adder.v"
// file 31 "c:/lscc/radiant/2026.1/ip/common/adder_subtractor/rtl/lscc_add_sub.v"
// file 32 "c:/lscc/radiant/2026.1/ip/common/complex_mult/rtl/lscc_complex_mult.v"
// file 33 "c:/lscc/radiant/2026.1/ip/common/counter/rtl/lscc_cntr.v"
// file 34 "c:/lscc/radiant/2026.1/ip/common/distributed_dpram/rtl/lscc_distributed_dpram.v"
// file 35 "c:/lscc/radiant/2026.1/ip/common/distributed_rom/rtl/lscc_distributed_rom.v"
// file 36 "c:/lscc/radiant/2026.1/ip/common/distributed_spram/rtl/lscc_distributed_spram.v"
// file 37 "c:/lscc/radiant/2026.1/ip/common/fifo/rtl/lscc_fifo.v"
// file 38 "c:/lscc/radiant/2026.1/ip/common/fifo_dc/rtl/lscc_fifo_dc.v"
// file 39 "c:/lscc/radiant/2026.1/ip/common/mult_accumulate/rtl/lscc_mult_accumulate.v"
// file 40 "c:/lscc/radiant/2026.1/ip/common/mult_add_sub/rtl/lscc_mult_add_sub.v"
// file 41 "c:/lscc/radiant/2026.1/ip/common/mult_add_sub_sum/rtl/lscc_mult_add_sub_sum.v"
// file 42 "c:/lscc/radiant/2026.1/ip/common/multiplier/rtl/lscc_multiplier.v"
// file 43 "c:/lscc/radiant/2026.1/ip/common/ram_dp/rtl/lscc_ram_dp.v"
// file 44 "c:/lscc/radiant/2026.1/ip/common/ram_dp_true/rtl/lscc_ram_dp_true.v"
// file 45 "c:/lscc/radiant/2026.1/ip/common/ram_dq/rtl/lscc_ram_dq.v"
// file 46 "c:/lscc/radiant/2026.1/ip/common/ram_shift_reg/rtl/lscc_shift_register.v"
// file 47 "c:/lscc/radiant/2026.1/ip/common/rom/rtl/lscc_rom.v"
// file 48 "c:/lscc/radiant/2026.1/ip/common/subtractor/rtl/lscc_subtractor.v"
// file 49 "c:/lscc/radiant/2026.1/ip/pmi/pmi_add.v"
// file 50 "c:/lscc/radiant/2026.1/ip/pmi/pmi_addsub.v"
// file 51 "c:/lscc/radiant/2026.1/ip/pmi/pmi_complex_mult.v"
// file 52 "c:/lscc/radiant/2026.1/ip/pmi/pmi_counter.v"
// file 53 "c:/lscc/radiant/2026.1/ip/pmi/pmi_distributed_dpram.v"
// file 54 "c:/lscc/radiant/2026.1/ip/pmi/pmi_distributed_rom.v"
// file 55 "c:/lscc/radiant/2026.1/ip/pmi/pmi_distributed_shift_reg.v"
// file 56 "c:/lscc/radiant/2026.1/ip/pmi/pmi_distributed_spram.v"
// file 57 "c:/lscc/radiant/2026.1/ip/pmi/pmi_fifo.v"
// file 58 "c:/lscc/radiant/2026.1/ip/pmi/pmi_fifo_dc.v"
// file 59 "c:/lscc/radiant/2026.1/ip/pmi/pmi_mac.v"
// file 60 "c:/lscc/radiant/2026.1/ip/pmi/pmi_mult.v"
// file 61 "c:/lscc/radiant/2026.1/ip/pmi/pmi_multaddsub.v"
// file 62 "c:/lscc/radiant/2026.1/ip/pmi/pmi_multaddsubsum.v"
// file 63 "c:/lscc/radiant/2026.1/ip/pmi/pmi_ram_dp.v"
// file 64 "c:/lscc/radiant/2026.1/ip/pmi/pmi_ram_dp_be.v"
// file 65 "c:/lscc/radiant/2026.1/ip/pmi/pmi_ram_dp_true.v"
// file 66 "c:/lscc/radiant/2026.1/ip/pmi/pmi_ram_dq.v"
// file 67 "c:/lscc/radiant/2026.1/ip/pmi/pmi_ram_dq_be.v"
// file 68 "c:/lscc/radiant/2026.1/ip/pmi/pmi_rom.v"
// file 69 "c:/lscc/radiant/2026.1/ip/pmi/pmi_sub.v"

//
// Verilog Description of module mipi_dphy_rx
// module wrapper written out since it is a black-box. 
//

//

module mipi_dphy_rx (sync_clk_i, sync_rst_i, lmmi_clk_i, lmmi_resetn_i, 
            lmmi_wdata_i, lmmi_wr_rdn_i, lmmi_offset_i, lmmi_request_i, 
            lmmi_ready_o, lmmi_rdata_o, lmmi_rdata_valid_o, hs_rx_data_o, 
            hs_rx_data_sync_o, clk_p_io, clk_n_io, data_p_io, data_n_io, 
            pd_dphy_i, clk_byte_o, ready_o) /* synthesis ORIG_MODULE_NAME="mipi_dphy_rx", LATTICE_IP_GENERATED="1", cpe_box=1 */ ;
    input sync_clk_i;
    input sync_rst_i;
    input lmmi_clk_i;
    input lmmi_resetn_i;
    input [3:0]lmmi_wdata_i;
    input lmmi_wr_rdn_i;
    input [4:0]lmmi_offset_i;
    input lmmi_request_i;
    output lmmi_ready_o;
    output [3:0]lmmi_rdata_o;
    output lmmi_rdata_valid_o;
    output [31:0]hs_rx_data_o;
    output [1:0]hs_rx_data_sync_o;
    inout clk_p_io;
    inout clk_n_io;
    inout [1:0]data_p_io;
    inout [1:0]data_n_io;
    input pd_dphy_i;
    output clk_byte_o;
    output ready_o;
    
    
    
endmodule
