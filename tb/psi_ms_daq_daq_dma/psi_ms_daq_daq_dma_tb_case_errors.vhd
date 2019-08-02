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
package psi_ms_daq_daq_dma_tb_case_errors is
	
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
package body psi_ms_daq_daq_dma_tb_case_errors is
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
		print(">> -- Error cases from top-tb and HW --");
				
		-- Trigger in remaining data
		wait for 1 us;
		print(">> Trigger in remaining data");
		InitCase(Clk, Rst);	
		InitSubCase(0);
		ApplyCmd(2, 16#01230000#, 26, DaqSm_Cmd, DaqSm_Cmd_Vld, Clk);
		StdlCompare(0, DaqSm_HasLast(2), "HasLast high unexpectedly");		
		CheckResp(2, 26, NoEnd_s, DaqSm_Resp, DaqSm_Resp_Vld, DaqSm_Resp_Rdy, Clk);
		StdlCompare(1, DaqSm_HasLast(2), "HasLast low after incomplete frame");
		ApplyCmd(2, 16#01231000#, 30, DaqSm_Cmd, DaqSm_Cmd_Vld, Clk);	
		StdlCompare(1, DaqSm_HasLast(2), "HasLast low after completion command");
		CheckResp(2, 2, Trigger_s, DaqSm_Resp, DaqSm_Resp_Vld, DaqSm_Resp_Rdy, Clk);	
		StdlCompare(0, DaqSm_HasLast(2), "HasLast high after completion response");	
		ApplyCmd(2, 16#01232000#, 30, DaqSm_Cmd, DaqSm_Cmd_Vld, Clk);	
		CheckResp(2, 30, NoEnd_s, DaqSm_Resp, DaqSm_Resp_Vld, DaqSm_Resp_Rdy, Clk);		
		WaitAllProc(Clk);

		-- Timeout in remaining data
		wait for 1 us;
		print(">> Timeout in remaining data");
		InitCase(Clk, Rst);	
		InitSubCase(1);
		ApplyCmd(2, 16#01230000#, 26, DaqSm_Cmd, DaqSm_Cmd_Vld, Clk);	
		StdlCompare(0, DaqSm_HasLast(2), "HasLast high unexpectedly");
		CheckResp(2, 26, NoEnd_s, DaqSm_Resp, DaqSm_Resp_Vld, DaqSm_Resp_Rdy, Clk);
		StdlCompare(1, DaqSm_HasLast(2), "HasLast low after incomplete frame");
		ApplyCmd(2, 16#01231000#, 30, DaqSm_Cmd, DaqSm_Cmd_Vld, Clk);	
		StdlCompare(1, DaqSm_HasLast(2), "HasLast low after completion command");
		CheckResp(2, 2, Timeout_s, DaqSm_Resp, DaqSm_Resp_Vld, DaqSm_Resp_Rdy, Clk);	
		StdlCompare(0, DaqSm_HasLast(2), "HasLast high after completion response");	
		ApplyCmd(2, 16#01232000#, 30, DaqSm_Cmd, DaqSm_Cmd_Vld, Clk);	
		CheckResp(2, 30, NoEnd_s, DaqSm_Resp, DaqSm_Resp_Vld, DaqSm_Resp_Rdy, Clk);		
		WaitAllProc(Clk);
		
	end procedure;
	
	procedure input (
		signal Clk : in std_logic;
		signal Inp_Vld : inout std_logic_vector;
		signal Inp_Rdy : in std_logic_vector;
		signal Inp_Data : inout Input2Daq_Data_a;
		constant Generics_c : Generics_t) is
	begin
		-- Trigger in remaining data
		WaitForCase(0, Clk);
		ApplyData(2, 28, Trigger_s, Inp_Vld, Inp_Rdy, Inp_Data, Clk);
		ApplyData(2, 30, NoEnd_s, Inp_Vld, Inp_Rdy, Inp_Data, Clk, 128);
		ProcDone_V(0) :=  '1';	

		-- Timeout in remaining data
		WaitForCase(1, Clk);
		ApplyData(2, 28, Timeout_s, Inp_Vld, Inp_Rdy, Inp_Data, Clk);
		ApplyData(2, 30, NoEnd_s, Inp_Vld, Inp_Rdy, Inp_Data, Clk, 128);
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
		-- Trigger in remaining data
		WaitForCase(0, Clk);
		CheckMemCmd( 16#01230000#, 26, 0, Mem_CmdAddr, Mem_CmdSize, Mem_CmdVld, Mem_CmdRdy, Clk);
		CheckMemCmd( 16#01231000#, 2, 0, Mem_CmdAddr, Mem_CmdSize, Mem_CmdVld, Mem_CmdRdy, Clk);
		CheckMemCmd( 16#01232000#, 30, 0, Mem_CmdAddr, Mem_CmdSize, Mem_CmdVld, Mem_CmdRdy, Clk);
		ProcDone_V(1) :=  '1';
		
		-- Timeout in remaining data
		WaitForCase(1, Clk);
		CheckMemCmd( 16#01230000#, 26, 0, Mem_CmdAddr, Mem_CmdSize, Mem_CmdVld, Mem_CmdRdy, Clk);
		CheckMemCmd( 16#01231000#, 2, 0, Mem_CmdAddr, Mem_CmdSize, Mem_CmdVld, Mem_CmdRdy, Clk);
		CheckMemCmd( 16#01232000#, 30, 0, Mem_CmdAddr, Mem_CmdSize, Mem_CmdVld, Mem_CmdRdy, Clk);
		ProcDone_V(1) :=  '1';		
		
	end procedure;
	
	procedure mem_dat (
		signal Clk : in std_logic;
		signal Mem_DatData : in std_logic_vector;
		signal Mem_DatVld : in std_logic;
		signal Mem_DatRdy : inout std_logic;
		constant Generics_c : Generics_t) is
	begin
		-- Trigger in remaining data
		WaitForCase(0, Clk);
		CheckMemData(26, 0, Mem_DatData, Mem_DatVld, Mem_DatRdy, Clk, 0, "1.0");	
		CheckMemData(2, 0, Mem_DatData, Mem_DatVld, Mem_DatRdy, Clk, 26, "1.1");
		CheckMemData(30, 0, Mem_DatData, Mem_DatVld, Mem_DatRdy, Clk, 128, "1.2");
		ProcDone_V(2) :=  '1';
		
		-- Timeout in remaining data
		WaitForCase(1, Clk);
		CheckMemData(26, 0, Mem_DatData, Mem_DatVld, Mem_DatRdy, Clk, 0, "1.0");	
		CheckMemData(2, 0, Mem_DatData, Mem_DatVld, Mem_DatRdy, Clk, 26, "1.1");
		CheckMemData(30, 0, Mem_DatData, Mem_DatVld, Mem_DatRdy, Clk, 128, "1.2");
		ProcDone_V(2) :=  '1';		

	end procedure;
	
end;
