##############################################################################
#  Copyright (c) 2019 by Paul Scherrer Institute, Switzerland
#  All rights reserved.
#  Authors: Oliver Bruendler
##############################################################################

#Constants
set LibPath "../../../VHDL"

#Import psi::sim
namespace import psi::sim::*

#Set library
add_library psi_ms_daq

#suppress messages
compile_suppress 135,1236,1073,1246
run_suppress 8684,3479,3813,8009,3812

# Library
add_sources $LibPath {
	psi_tb/hdl/psi_tb_txt_util.vhd \
	psi_tb/hdl/psi_tb_compare_pkg.vhd \
	psi_tb/hdl/psi_tb_activity_pkg.vhd \
	psi_common/hdl/psi_common_array_pkg.vhd \
	psi_common/hdl/psi_common_math_pkg.vhd \
	psi_tb/hdl/psi_tb_axi_pkg.vhd \
	psi_common/hdl/psi_common_logic_pkg.vhd \
	psi_common/hdl/psi_common_sdp_ram.vhd \
	psi_common/hdl/psi_common_pulse_cc.vhd \
	psi_common/hdl/psi_common_bit_cc.vhd \
	psi_common/hdl/psi_common_simple_cc.vhd \
	psi_common/hdl/psi_common_status_cc.vhd \
	psi_common/hdl/psi_common_async_fifo.vhd \
	psi_common/hdl/psi_common_arb_priority.vhd \
	psi_common/hdl/psi_common_sync_fifo.vhd \
	psi_common/hdl/psi_common_tdp_ram.vhd \
	psi_common/hdl/psi_common_axi_master_simple.vhd \
	psi_common/hdl/psi_common_wconv_n2xn.vhd \
	psi_common/hdl/psi_common_axi_master_full.vhd \
	psi_common/hdl/psi_common_pl_stage.vhd \
	psi_common/hdl/psi_common_axi_slave_ipif.vhd \
} -tag lib

# project sources
add_sources "../hdl" {
	psi_ms_daq_pkg.vhd \
	psi_ms_daq_input.vhd \
	psi_ms_daq_daq_sm.vhd \
	psi_ms_daq_daq_dma.vhd \
	psi_ms_daq_axi_if.vhd \
	psi_ms_daq_reg_axi.vhd \
	psi_ms_daq_axi.vhd \
} -tag src

# testbenches
add_sources "../tb" {
	psi_ms_daq_input/psi_ms_daq_input_tb_pkg.vhd \
	psi_ms_daq_input/psi_ms_daq_input_tb_case_single_frame.vhd \
	psi_ms_daq_input/psi_ms_daq_input_tb_case_multi_frame.vhd \
	psi_ms_daq_input/psi_ms_daq_input_tb_case_timeout.vhd \
	psi_ms_daq_input/psi_ms_daq_input_tb_case_ts_overflow.vhd \
	psi_ms_daq_input/psi_ms_daq_input_tb_case_trig_in_posttrig.vhd \
	psi_ms_daq_input/psi_ms_daq_input_tb_case_backpressure.vhd \
	psi_ms_daq_input/psi_ms_daq_input_tb_case_always_trig.vhd \
	psi_ms_daq_input/psi_ms_daq_input_tb_case_modes.vhd \
	psi_ms_daq_input/psi_ms_daq_input_tb.vhd \
	psi_ms_daq_daq_sm/psi_ms_daq_daq_sm_tb_pkg.vhd \
	psi_ms_daq_daq_sm/psi_ms_daq_daq_sm_tb_case_single_window.vhd \
	psi_ms_daq_daq_sm/psi_ms_daq_daq_sm_tb_case_single_simple.vhd \
	psi_ms_daq_daq_sm/psi_ms_daq_daq_sm_tb_case_priorities.vhd \
	psi_ms_daq_daq_sm/psi_ms_daq_daq_sm_tb_case_multi_window.vhd \
	psi_ms_daq_daq_sm/psi_ms_daq_daq_sm_tb_case_enable.vhd \
	psi_ms_daq_daq_sm/psi_ms_daq_daq_sm_tb_case_irq.vhd \
	psi_ms_daq_daq_sm/psi_ms_daq_daq_sm_tb_case_timestamp.vhd \
	psi_ms_daq_daq_sm/psi_ms_daq_daq_sm_tb.vhd \
	psi_ms_daq_daq_dma/psi_ms_daq_daq_dma_tb_pkg.vhd \
	psi_ms_daq_daq_dma/psi_ms_daq_daq_dma_tb_case_unaligned.vhd \
	psi_ms_daq_daq_dma/psi_ms_daq_daq_dma_tb_case_no_data_read.vhd \
	psi_ms_daq_daq_dma/psi_ms_daq_daq_dma_tb_case_input_empty.vhd \
	psi_ms_daq_daq_dma/psi_ms_daq_daq_dma_tb_case_empty_timeout.vhd \
	psi_ms_daq_daq_dma/psi_ms_daq_daq_dma_tb_case_data_full.vhd \
	psi_ms_daq_daq_dma/psi_ms_daq_daq_dma_tb_case_cmd_full.vhd \
	psi_ms_daq_daq_dma/psi_ms_daq_daq_dma_tb_case_aligned.vhd \
	psi_ms_daq_daq_dma/psi_ms_daq_daq_dma_tb_case_errors.vhd \
	psi_ms_daq_daq_dma/psi_ms_daq_daq_dma_tb.vhd \
	psi_ms_daq_axi/psi_ms_daq_axi_tb_pkg.vhd \
	psi_ms_daq_axi/psi_ms_daq_axi_tb_str0_pkg.vhd \
	psi_ms_daq_axi/psi_ms_daq_axi_tb_str1_pkg.vhd \
	psi_ms_daq_axi/psi_ms_daq_axi_tb_str2_pkg.vhd \
	psi_ms_daq_axi/psi_ms_daq_axi_tb_str3_pkg.vhd \
	psi_ms_daq_axi/psi_ms_daq_axi_tb.vhd \
	psi_ms_daq_axi_1s/psi_ms_daq_axi_1s_tb_str0_pkg.vhd \
	psi_ms_daq_axi_1s/psi_ms_daq_axi_1s_tb.vhd \
} -tag tb
	
#TB Runs
create_tb_run "psi_ms_daq_input_tb"
tb_run_add_arguments \
	"-gStreamWidth_g=8 -gVldPulsed_g=false" \
	"-gStreamWidth_g=8 -gVldPulsed_g=true" \
	"-gStreamWidth_g=16 -gVldPulsed_g=false" \
	"-gStreamWidth_g=32 -gVldPulsed_g=false" \
	"-gStreamWidth_g=64 -gVldPulsed_g=false" \
	"-gStreamWidth_g=64 -gVldPulsed_g=true"
add_tb_run

create_tb_run "psi_ms_daq_daq_sm_tb"
add_tb_run

create_tb_run "psi_ms_daq_daq_dma_tb"
add_tb_run

create_tb_run "psi_ms_daq_axi_tb"
add_tb_run

create_tb_run "psi_ms_daq_axi_1s_tb"
add_tb_run








