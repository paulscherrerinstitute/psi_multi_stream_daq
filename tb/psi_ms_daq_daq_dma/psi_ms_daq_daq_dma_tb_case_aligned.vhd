------------------------------------------------------------------------------
--  Copyright (c) 2019 by Paul Scherrer Institute, Switzerland
--  All rights reserved.
--  Authors: Oliver Bruendler
------------------------------------------------------------------------------

------------------------------------------------------------
-- Libraries
------------------------------------------------------------
library ieee;
	use ieee.std_logic_1164.all;
	use ieee.numeric_std.all;

library work;
	use work.psi_common_math_pkg.all;
	use work.psi_common_logic_pkg.all;
	use work.psi_common_array_pkg.all;
	use work.psi_ms_daq_pkg.all;

library work;
	use work.psi_ms_daq_daq_dma_tb_pkg.all;

library work;
	use work.psi_tb_txt_util.all;
	use work.psi_tb_compare_pkg.all;
	use work.psi_tb_activity_pkg.all;

------------------------------------------------------------
-- Package Header
------------------------------------------------------------
package psi_ms_daq_daq_dma_tb_case_aligned is
	
	procedure control (
		signal Clk : in std_logic;
		signal Rst : inout std_logic;
		signal DaqSm_Cmd : inout DaqSm2DaqDma_Cmd_t;
		signal DaqSm_Cmd_Vld : inout std_logic;
		signal DaqSm_Resp : in DaqDma2DaqSm_Resp_t;
		signal DaqSm_Resp_Vld : in std_logic;
		signal DaqSm_Resp_Rdy : inout std_logic;
		signal DaqSm_HasLast : in std_logic_vector;
		constant Generics_c : Generics_t);
		
	procedure input (
		signal Clk : in std_logic;
		signal Inp_Vld : inout std_logic_vector;
		signal Inp_Rdy : in std_logic_vector;
		signal Inp_Data : inout Input2Daq_Data_a;
		constant Generics_c : Generics_t);
		
	procedure mem_cmd (
		signal Clk : in std_logic;
		signal Mem_CmdAddr : in std_logic_vector;
		signal Mem_CmdSize : in std_logic_vector;
		signal Mem_CmdVld : in std_logic;
		signal Mem_CmdRdy : inout std_logic;
		constant Generics_c : Generics_t);
		
	procedure mem_dat (
		signal Clk : in std_logic;
		signal Mem_DatData : in std_logic_vector;
		signal Mem_DatVld : in std_logic;
		signal Mem_DatRdy : inout std_logic;
		constant Generics_c : Generics_t);
		
end package;

------------------------------------------------------------
-- Package Body
------------------------------------------------------------
package body psi_ms_daq_daq_dma_tb_case_aligned is
	procedure control (
		signal Clk : in std_logic;
		signal Rst : inout std_logic;
		signal DaqSm_Cmd : inout DaqSm2DaqDma_Cmd_t;
		signal DaqSm_Cmd_Vld : inout std_logic;
		signal DaqSm_Resp : in DaqDma2DaqSm_Resp_t;
		signal DaqSm_Resp_Vld : in std_logic;
		signal DaqSm_Resp_Rdy : inout std_logic;
		signal DaqSm_HasLast : in std_logic_vector;
		constant Generics_c : Generics_t) is
	begin
		InitCase(Clk, Rst);	
		print(">> -- Aligned --");

		-- Ready always high
		print(">> Ready always high");
		InitSubCase(0);
		ApplyCmd(2, 16#01230000#, 32, DaqSm_Cmd, DaqSm_Cmd_Vld, Clk);	
		CheckResp(2, 32, NoEnd_s, DaqSm_Resp, DaqSm_Resp_Vld, DaqSm_Resp_Rdy, Clk);
		WaitAllProc(Clk);
		
		-- Data Ready toggling
		print(">> Data Ready toggling");
		InitSubCase(1);
		ApplyCmd(2, 16#01231000#, 32, DaqSm_Cmd, DaqSm_Cmd_Vld, Clk);	
		CheckResp(2, 32, NoEnd_s, DaqSm_Resp, DaqSm_Resp_Vld, DaqSm_Resp_Rdy, Clk);
		WaitAllProc(Clk);		
		
		-- Cmd Ready toggling
		print(">> Cmd Ready toggling");
		InitSubCase(2);
		ApplyCmd(2, 16#01232000#, 32, DaqSm_Cmd, DaqSm_Cmd_Vld, Clk);	
		CheckResp(2, 32, NoEnd_s, DaqSm_Resp, DaqSm_Resp_Vld, DaqSm_Resp_Rdy, Clk);
		WaitAllProc(Clk);			
		
	end procedure;
	
	procedure input (
		signal Clk : in std_logic;
		signal Inp_Vld : inout std_logic_vector;
		signal Inp_Rdy : in std_logic_vector;
		signal Inp_Data : inout Input2Daq_Data_a;
		constant Generics_c : Generics_t) is
	begin
		-- Ready always high
		WaitForCase(0, Clk);
		ApplyData(2, 32, NoEnd_s, Inp_Vld, Inp_Rdy, Inp_Data, Clk);
		ProcDone_V(0) :=  '1';
		
		-- Data Ready toggling
		WaitForCase(1, Clk);
		ApplyData(2, 32, NoEnd_s, Inp_Vld, Inp_Rdy, Inp_Data, Clk);
		ProcDone_V(0) :=  '1';		
		
		-- Cmd Ready toggling
		WaitForCase(2, Clk);
		ApplyData(2, 32, NoEnd_s, Inp_Vld, Inp_Rdy, Inp_Data, Clk);
		ProcDone_V(0) :=  '1';				
	end procedure;
	
	procedure mem_cmd (
		signal Clk : in std_logic;
		signal Mem_CmdAddr : in std_logic_vector;
		signal Mem_CmdSize : in std_logic_vector;
		signal Mem_CmdVld : in std_logic;
		signal Mem_CmdRdy : inout std_logic;
		constant Generics_c : Generics_t) is
	begin
		-- Ready always high
		WaitForCase(0, Clk);
		CheckMemCmd( 16#01230000#, 32, 0, Mem_CmdAddr, Mem_CmdSize, Mem_CmdVld, Mem_CmdRdy, Clk);
		ProcDone_V(1) :=  '1';
		
		-- Data Ready toggling
		WaitForCase(1, Clk);
		CheckMemCmd( 16#01231000#, 32, 0, Mem_CmdAddr, Mem_CmdSize, Mem_CmdVld, Mem_CmdRdy, Clk);
		ProcDone_V(1) :=  '1';	

		-- Cmd Ready toggling
		WaitForCase(2, Clk);
		CheckMemCmd( 16#01232000#, 32, 5, Mem_CmdAddr, Mem_CmdSize, Mem_CmdVld, Mem_CmdRdy, Clk);
		ProcDone_V(1) :=  '1';			
	end procedure;
	
	procedure mem_dat (
		signal Clk : in std_logic;
		signal Mem_DatData : in std_logic_vector;
		signal Mem_DatVld : in std_logic;
		signal Mem_DatRdy : inout std_logic;
		constant Generics_c : Generics_t) is
	begin
		-- Ready always high
		WaitForCase(0, Clk);
		CheckMemData(32, 0, Mem_DatData, Mem_DatVld, Mem_DatRdy, Clk);	
		ProcDone_V(2) :=  '1';
		
		-- Data Ready toggling
		WaitForCase(1, Clk);
		CheckMemData(32, 5, Mem_DatData, Mem_DatVld, Mem_DatRdy, Clk);	
		ProcDone_V(2) :=  '1';	

		-- Ready always high
		WaitForCase(2, Clk);
		CheckMemData(32, 0, Mem_DatData, Mem_DatVld, Mem_DatRdy, Clk);	
		ProcDone_V(2) :=  '1';		
	end procedure;
	
end;
