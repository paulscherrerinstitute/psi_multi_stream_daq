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
package psi_ms_daq_daq_dma_tb_case_no_data_read is
	
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
		
	shared variable SubCase	: integer := 0;
		
end package;

------------------------------------------------------------
-- Package Body
------------------------------------------------------------
package body psi_ms_daq_daq_dma_tb_case_no_data_read is
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
		print(">> -- No data read --");
		
		-- No Data on first request
		print(">> No Data on first request");
		InitCase(Clk, Rst);	
		InitSubCase(0);
		ApplyCmd(2, 16#01230000#, 30, DaqSm_Cmd, DaqSm_Cmd_Vld, Clk);	
		CheckResp(2, 0, NoEnd_s, DaqSm_Resp, DaqSm_Resp_Vld, DaqSm_Resp_Rdy, Clk);
		SubCase := 1;
		ApplyCmd(2, 16#01231000#, 30, DaqSm_Cmd, DaqSm_Cmd_Vld, Clk);	
		CheckResp(2, 30, NoEnd_s, DaqSm_Resp, DaqSm_Resp_Vld, DaqSm_Resp_Rdy, Clk);	
		WaitAllProc(Clk);	
		SubCase := 0;		

		-- No Data on second request
		wait for 1 us;
		print(">> No Data on second request");
		InitCase(Clk, Rst);	
		InitSubCase(1);
		ApplyCmd(2, 16#01230000#, 32, DaqSm_Cmd, DaqSm_Cmd_Vld, Clk);	
		CheckResp(2, 32, NoEnd_s, DaqSm_Resp, DaqSm_Resp_Vld, DaqSm_Resp_Rdy, Clk);
		ApplyCmd(2, 16#01231000#, 30, DaqSm_Cmd, DaqSm_Cmd_Vld, Clk);	
		CheckResp(2, 0, NoEnd_s, DaqSm_Resp, DaqSm_Resp_Vld, DaqSm_Resp_Rdy, Clk);	
		SubCase := 1;
		ApplyCmd(2, 16#01232000#, 30, DaqSm_Cmd, DaqSm_Cmd_Vld, Clk);	
		CheckResp(2, 30, NoEnd_s, DaqSm_Resp, DaqSm_Resp_Vld, DaqSm_Resp_Rdy, Clk);			
		WaitAllProc(Clk);	
		SubCase := 0;	
		
		-- No Data with leftover bytes
		wait for 1 us;
		print(">> No Data with leftover bytes");
		InitCase(Clk, Rst);	
		InitSubCase(2);
		ApplyCmd(2, 16#01230000#, 30, DaqSm_Cmd, DaqSm_Cmd_Vld, Clk);	
		CheckResp(2, 30, NoEnd_s, DaqSm_Resp, DaqSm_Resp_Vld, DaqSm_Resp_Rdy, Clk);
		ApplyCmd(2, 16#01231000#, 30, DaqSm_Cmd, DaqSm_Cmd_Vld, Clk);	
		CheckResp(2, 2, NoEnd_s, DaqSm_Resp, DaqSm_Resp_Vld, DaqSm_Resp_Rdy, Clk);	
		SubCase := 1;
		ApplyCmd(2, 16#01232000#, 30, DaqSm_Cmd, DaqSm_Cmd_Vld, Clk);	
		CheckResp(2, 30, NoEnd_s, DaqSm_Resp, DaqSm_Resp_Vld, DaqSm_Resp_Rdy, Clk);			
		WaitAllProc(Clk);	
		SubCase := 0;	
		
	end procedure;
	
	procedure input (
		signal Clk : in std_logic;
		signal Inp_Vld : inout std_logic_vector;
		signal Inp_Rdy : in std_logic_vector;
		signal Inp_Data : inout Input2Daq_Data_a;
		constant Generics_c : Generics_t) is
	begin
		-- No Data on first request
		WaitForCase(0, Clk);
		while SubCase < 1 loop	
			wait until rising_edge(Clk);
		end loop;
		ApplyData(2, 30, NoEnd_s, Inp_Vld, Inp_Rdy, Inp_Data, Clk);
		ProcDone_V(0) :=  '1';
		
		-- No Data on second request
		WaitForCase(1, Clk);
		ApplyData(2, 32, NoEnd_s, Inp_Vld, Inp_Rdy, Inp_Data, Clk);
		while SubCase < 1 loop	
			wait until rising_edge(Clk);
		end loop;
		ApplyData(2, 30, NoEnd_s, Inp_Vld, Inp_Rdy, Inp_Data, Clk, 32);
		ProcDone_V(0) :=  '1';		
		
		-- No Data with leftover bytes
		WaitForCase(2, Clk);
		ApplyData(2, 32, NoEnd_s, Inp_Vld, Inp_Rdy, Inp_Data, Clk);
		while SubCase < 1 loop	
			wait until rising_edge(Clk);
		end loop;
		ApplyData(2, 30, NoEnd_s, Inp_Vld, Inp_Rdy, Inp_Data, Clk, 32);
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
		-- No Data on first request
		WaitForCase(0, Clk);
		while SubCase < 1 loop	
			StdlCompare(0, Mem_CmdVld, "Unexpected memory command");		
			wait until rising_edge(Clk);
		end loop;		
		CheckMemCmd( 16#01231000#, 30, 0, Mem_CmdAddr, Mem_CmdSize, Mem_CmdVld, Mem_CmdRdy, Clk);
		ProcDone_V(1) :=  '1';
		
		-- No Data on second request
		WaitForCase(1, Clk);
		CheckMemCmd( 16#01230000#, 32, 0, Mem_CmdAddr, Mem_CmdSize, Mem_CmdVld, Mem_CmdRdy, Clk);
		while SubCase < 1 loop	
			StdlCompare(0, Mem_CmdVld, "Unexpected memory command");		
			wait until rising_edge(Clk);
		end loop;		
		CheckMemCmd( 16#01232000#, 30, 0, Mem_CmdAddr, Mem_CmdSize, Mem_CmdVld, Mem_CmdRdy, Clk);
		ProcDone_V(1) :=  '1';		
		
		-- No Data with leftover bytes
		WaitForCase(2, Clk);
		CheckMemCmd( 16#01230000#, 30, 0, Mem_CmdAddr, Mem_CmdSize, Mem_CmdVld, Mem_CmdRdy, Clk);
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
		-- No Data on first request
		WaitForCase(0, Clk);
		while SubCase < 1 loop		
			wait until rising_edge(Clk);
			StdlCompare(0, Mem_DatVld, "Unexpected memory data");	
		end loop;		
		CheckMemData(30, 0, Mem_DatData, Mem_DatVld, Mem_DatRdy, Clk, 0, "1.1");	
		ProcDone_V(2) :=  '1';
		
		-- No Data on second request
		WaitForCase(1, Clk);
		CheckMemData(32, 0, Mem_DatData, Mem_DatVld, Mem_DatRdy, Clk, 0, "1.0");
		while SubCase < 1 loop					
			wait until rising_edge(Clk);
			StdlCompare(0, Mem_DatVld, "Unexpected memory data");	
		end loop;		
		CheckMemData(30, 0, Mem_DatData, Mem_DatVld, Mem_DatRdy, Clk, 32, "1.2");	
		ProcDone_V(2) :=  '1';	

		-- No Data with leftover bytes
		WaitForCase(2, Clk);
		CheckMemData(30, 0, Mem_DatData, Mem_DatVld, Mem_DatRdy, Clk, 0, "1.0");
		CheckMemData(2, 0, Mem_DatData, Mem_DatVld, Mem_DatRdy, Clk, 30, "1.1");
		CheckMemData(30, 0, Mem_DatData, Mem_DatVld, Mem_DatRdy, Clk, 30+2, "1.2");	
		ProcDone_V(2) :=  '1';		
	end procedure;
	
end;
