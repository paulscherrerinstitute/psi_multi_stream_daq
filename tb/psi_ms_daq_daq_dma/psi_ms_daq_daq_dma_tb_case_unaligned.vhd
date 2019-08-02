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
package psi_ms_daq_daq_dma_tb_case_unaligned is
	
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
package body psi_ms_daq_daq_dma_tb_case_unaligned is
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
		print(">> -- Unaligned --");
				
		-- End Unaligned
		print(">> End Unaligned");
		InitCase(Clk, Rst);	
		InitSubCase(0);
		ApplyCmd(2, 16#01230000#, 30, DaqSm_Cmd, DaqSm_Cmd_Vld, Clk);	
		CheckResp(2, 30, NoEnd_s, DaqSm_Resp, DaqSm_Resp_Vld, DaqSm_Resp_Rdy, Clk);
		ApplyCmd(2, 16#01231000#, 29, DaqSm_Cmd, DaqSm_Cmd_Vld, Clk);	
		CheckResp(2, 29, NoEnd_s, DaqSm_Resp, DaqSm_Resp_Vld, DaqSm_Resp_Rdy, Clk);	
		ApplyCmd(2, 16#01232000#, 30, DaqSm_Cmd, DaqSm_Cmd_Vld, Clk);	
		CheckResp(2, 30, NoEnd_s, DaqSm_Resp, DaqSm_Resp_Vld, DaqSm_Resp_Rdy, Clk);		
		WaitAllProc(Clk);	
		
		-- QWord Split
		print(">> QWord Split");
		InitCase(Clk, Rst);	
		InitSubCase(1);
		ApplyCmd(2, 16#01230000#, 30, DaqSm_Cmd, DaqSm_Cmd_Vld, Clk);	
		CheckResp(2, 30, NoEnd_s, DaqSm_Resp, DaqSm_Resp_Vld, DaqSm_Resp_Rdy, Clk);
		ApplyCmd(2, 16#01231000#, 29, DaqSm_Cmd, DaqSm_Cmd_Vld, Clk);	
		CheckResp(2, 29, NoEnd_s, DaqSm_Resp, DaqSm_Resp_Vld, DaqSm_Resp_Rdy, Clk);	
		ApplyCmd(2, 16#01232000#, 30, DaqSm_Cmd, DaqSm_Cmd_Vld, Clk);	
		CheckResp(2, 30, NoEnd_s, DaqSm_Resp, DaqSm_Resp_Vld, DaqSm_Resp_Rdy, Clk);		
		WaitAllProc(Clk);		
		
		-- QWord Split, Rdy Toggling
		print(">> QWord Split, Rdy Toggling");
		InitCase(Clk, Rst);	
		InitSubCase(2);
		ApplyCmd(2, 16#01230000#, 30, DaqSm_Cmd, DaqSm_Cmd_Vld, Clk);	
		CheckResp(2, 30, NoEnd_s, DaqSm_Resp, DaqSm_Resp_Vld, DaqSm_Resp_Rdy, Clk);
		ApplyCmd(2, 16#01231000#, 29, DaqSm_Cmd, DaqSm_Cmd_Vld, Clk);	
		CheckResp(2, 29, NoEnd_s, DaqSm_Resp, DaqSm_Resp_Vld, DaqSm_Resp_Rdy, Clk);	
		ApplyCmd(2, 16#01232000#, 30, DaqSm_Cmd, DaqSm_Cmd_Vld, Clk);	
		CheckResp(2, 30, NoEnd_s, DaqSm_Resp, DaqSm_Resp_Vld, DaqSm_Resp_Rdy, Clk);		
		WaitAllProc(Clk);	

		-- mixed streams
		print(">> mixed streams");
		InitCase(Clk, Rst);	
		InitSubCase(3);
		ApplyCmd(2, 16#02000000#, 30, DaqSm_Cmd, DaqSm_Cmd_Vld, Clk);	
		ApplyCmd(1, 16#01000000#, 23, DaqSm_Cmd, DaqSm_Cmd_Vld, Clk);	
		CheckResp(2, 30, NoEnd_s, DaqSm_Resp, DaqSm_Resp_Vld, DaqSm_Resp_Rdy, Clk);
		CheckResp(1, 23, NoEnd_s, DaqSm_Resp, DaqSm_Resp_Vld, DaqSm_Resp_Rdy, Clk);
		ApplyCmd(2, 16#02000001#, 33, DaqSm_Cmd, DaqSm_Cmd_Vld, Clk);	
		ApplyCmd(1, 16#01000001#, 21, DaqSm_Cmd, DaqSm_Cmd_Vld, Clk);	
		CheckResp(2, 33, NoEnd_s, DaqSm_Resp, DaqSm_Resp_Vld, DaqSm_Resp_Rdy, Clk);
		CheckResp(1, 21, NoEnd_s, DaqSm_Resp, DaqSm_Resp_Vld, DaqSm_Resp_Rdy, Clk);	
		ApplyCmd(1, 16#01000002#, 11, DaqSm_Cmd, DaqSm_Cmd_Vld, Clk);
		ApplyCmd(2, 16#02000002#, 11, DaqSm_Cmd, DaqSm_Cmd_Vld, Clk);	
		CheckResp(1, 11, NoEnd_s, DaqSm_Resp, DaqSm_Resp_Vld, DaqSm_Resp_Rdy, Clk);	
		CheckResp(2, 11, NoEnd_s, DaqSm_Resp, DaqSm_Resp_Vld, DaqSm_Resp_Rdy, Clk);				
		WaitAllProc(Clk);				

		-- End Aligned
		print(">> End Aligned");
		InitCase(Clk, Rst);	
		InitSubCase(4);
		ApplyCmd(2, 16#01230000#, 30, DaqSm_Cmd, DaqSm_Cmd_Vld, Clk);	
		CheckResp(2, 30, NoEnd_s, DaqSm_Resp, DaqSm_Resp_Vld, DaqSm_Resp_Rdy, Clk);
		ApplyCmd(2, 16#01231000#, 34, DaqSm_Cmd, DaqSm_Cmd_Vld, Clk);	
		CheckResp(2, 34, NoEnd_s, DaqSm_Resp, DaqSm_Resp_Vld, DaqSm_Resp_Rdy, Clk);	
		ApplyCmd(2, 16#01232000#, 30, DaqSm_Cmd, DaqSm_Cmd_Vld, Clk);	
		CheckResp(2, 30, NoEnd_s, DaqSm_Resp, DaqSm_Resp_Vld, DaqSm_Resp_Rdy, Clk);		
		WaitAllProc(Clk);			

		-- Unaligned end by trigger (with rem-word)
		print(">> Unaligned end by trigger (with rem-word)");
		InitCase(Clk, Rst);	
		InitSubCase(5);
		ApplyCmd(2, 16#01230000#, 30, DaqSm_Cmd, DaqSm_Cmd_Vld, Clk);	
		CheckResp(2, 30, NoEnd_s, DaqSm_Resp, DaqSm_Resp_Vld, DaqSm_Resp_Rdy, Clk);
		ApplyCmd(2, 16#01231000#, 64, DaqSm_Cmd, DaqSm_Cmd_Vld, Clk);	
		CheckResp(2, 29, Trigger_s, DaqSm_Resp, DaqSm_Resp_Vld, DaqSm_Resp_Rdy, Clk);	
		ApplyCmd(2, 16#01232000#, 30, DaqSm_Cmd, DaqSm_Cmd_Vld, Clk);	
		CheckResp(2, 30, NoEnd_s, DaqSm_Resp, DaqSm_Resp_Vld, DaqSm_Resp_Rdy, Clk);		
		WaitAllProc(Clk);	

		-- Unaligned end by trigger (without rem-word)
		print(">> Unaligned end by trigger (without rem-word)");
		InitCase(Clk, Rst);	
		InitSubCase(6);
		ApplyCmd(2, 16#01230000#, 30, DaqSm_Cmd, DaqSm_Cmd_Vld, Clk);	
		CheckResp(2, 30, NoEnd_s, DaqSm_Resp, DaqSm_Resp_Vld, DaqSm_Resp_Rdy, Clk);
		ApplyCmd(2, 16#01231000#, 64, DaqSm_Cmd, DaqSm_Cmd_Vld, Clk);	
		CheckResp(2, 25, Trigger_s, DaqSm_Resp, DaqSm_Resp_Vld, DaqSm_Resp_Rdy, Clk);	
		ApplyCmd(2, 16#01232000#, 30, DaqSm_Cmd, DaqSm_Cmd_Vld, Clk);	
		CheckResp(2, 30, NoEnd_s, DaqSm_Resp, DaqSm_Resp_Vld, DaqSm_Resp_Rdy, Clk);		
		WaitAllProc(Clk);			
		
		-- Unaligned end by timeout
		print(">> Unaligned end by timeout");
		InitCase(Clk, Rst);	
		InitSubCase(7);
		ApplyCmd(2, 16#01230000#, 30, DaqSm_Cmd, DaqSm_Cmd_Vld, Clk);	
		CheckResp(2, 30, NoEnd_s, DaqSm_Resp, DaqSm_Resp_Vld, DaqSm_Resp_Rdy, Clk);
		ApplyCmd(2, 16#01231000#, 64, DaqSm_Cmd, DaqSm_Cmd_Vld, Clk);	
		CheckResp(2, 29, Timeout_s, DaqSm_Resp, DaqSm_Resp_Vld, DaqSm_Resp_Rdy, Clk);	
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
		-- End Unaligned
		WaitForCase(0, Clk);
		ApplyData(2, 30, NoEnd_s, Inp_Vld, Inp_Rdy, Inp_Data, Clk);
		ApplyData(2, 29, NoEnd_s, Inp_Vld, Inp_Rdy, Inp_Data, Clk, 30);
		ApplyData(2, 30, NoEnd_s, Inp_Vld, Inp_Rdy, Inp_Data, Clk, 30+29);
		ProcDone_V(0) :=  '1';
		
		-- QWord Split
		WaitForCase(1, Clk);
		ApplyData(2, 30+29+30, NoEnd_s, Inp_Vld, Inp_Rdy, Inp_Data, Clk);
		ProcDone_V(0) :=  '1';		
		
		-- QWord Split, Rdy Toggling
		WaitForCase(2, Clk);
		ApplyData(2, 30+29+30, NoEnd_s, Inp_Vld, Inp_Rdy, Inp_Data, Clk);
		ProcDone_V(0) :=  '1';	

		-- mixed streams	
		WaitForCase(3, Clk);
		ApplyData(2, 32, NoEnd_s, Inp_Vld, Inp_Rdy, Inp_Data, Clk);
		ApplyData(1, 24, NoEnd_s, Inp_Vld, Inp_Rdy, Inp_Data, Clk);
		ApplyData(2, 32, NoEnd_s, Inp_Vld, Inp_Rdy, Inp_Data, Clk, 32);
		ApplyData(1, 20, NoEnd_s, Inp_Vld, Inp_Rdy, Inp_Data, Clk, 24);
		ApplyData(1, 12, NoEnd_s, Inp_Vld, Inp_Rdy, Inp_Data, Clk, 20+24);
		ApplyData(2, 12, NoEnd_s, Inp_Vld, Inp_Rdy, Inp_Data, Clk, 32+32);
		ProcDone_V(0) :=  '1';		

		-- End Aligned
		WaitForCase(4, Clk);
		ApplyData(2, 30+34+30, NoEnd_s, Inp_Vld, Inp_Rdy, Inp_Data, Clk);
		ProcDone_V(0) :=  '1';	

		-- Unaligned end by trigger (with rem-word)	
		WaitForCase(5, Clk);
		ApplyData(2, 30+29, Trigger_s, Inp_Vld, Inp_Rdy, Inp_Data, Clk, 0);
		ApplyData(2, 30, NoEnd_s, Inp_Vld, Inp_Rdy, Inp_Data, Clk, 30+29);
		ProcDone_V(0) :=  '1';		
		
		-- Unaligned end by trigger (without rem-word)	
		WaitForCase(6, Clk);
		ApplyData(2, 30+25, Trigger_s, Inp_Vld, Inp_Rdy, Inp_Data, Clk, 0);
		ApplyData(2, 30, NoEnd_s, Inp_Vld, Inp_Rdy, Inp_Data, Clk, 30+25);
		ProcDone_V(0) :=  '1';	

		-- Unaligned end by timeout
		WaitForCase(7, Clk);
		ApplyData(2, 30+29, Timeout_s, Inp_Vld, Inp_Rdy, Inp_Data, Clk, 0);
		ApplyData(2, 30, NoEnd_s, Inp_Vld, Inp_Rdy, Inp_Data, Clk, 30+29);
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
		-- End Unaligned
		WaitForCase(0, Clk);
		CheckMemCmd( 16#01230000#, 30, 0, Mem_CmdAddr, Mem_CmdSize, Mem_CmdVld, Mem_CmdRdy, Clk);
		CheckMemCmd( 16#01231000#, 29, 0, Mem_CmdAddr, Mem_CmdSize, Mem_CmdVld, Mem_CmdRdy, Clk);
		CheckMemCmd( 16#01232000#, 30, 0, Mem_CmdAddr, Mem_CmdSize, Mem_CmdVld, Mem_CmdRdy, Clk);
		ProcDone_V(1) :=  '1';
		
		-- QWord Split
		WaitForCase(1, Clk);
		CheckMemCmd( 16#01230000#, 30, 0, Mem_CmdAddr, Mem_CmdSize, Mem_CmdVld, Mem_CmdRdy, Clk);
		CheckMemCmd( 16#01231000#, 29, 0, Mem_CmdAddr, Mem_CmdSize, Mem_CmdVld, Mem_CmdRdy, Clk);
		CheckMemCmd( 16#01232000#, 30, 0, Mem_CmdAddr, Mem_CmdSize, Mem_CmdVld, Mem_CmdRdy, Clk);
		ProcDone_V(1) :=  '1';		
		
		-- QWord Split, Rdy Toggling
		WaitForCase(2, Clk);
		CheckMemCmd( 16#01230000#, 30, 0, Mem_CmdAddr, Mem_CmdSize, Mem_CmdVld, Mem_CmdRdy, Clk);
		CheckMemCmd( 16#01231000#, 29, 0, Mem_CmdAddr, Mem_CmdSize, Mem_CmdVld, Mem_CmdRdy, Clk);
		CheckMemCmd( 16#01232000#, 30, 0, Mem_CmdAddr, Mem_CmdSize, Mem_CmdVld, Mem_CmdRdy, Clk);
		ProcDone_V(1) :=  '1';		

		-- mixed streams
		WaitForCase(3, Clk);
		CheckMemCmd( 16#02000000#, 30, 0, Mem_CmdAddr, Mem_CmdSize, Mem_CmdVld, Mem_CmdRdy, Clk, "2.0");
		CheckMemCmd( 16#01000000#, 23, 0, Mem_CmdAddr, Mem_CmdSize, Mem_CmdVld, Mem_CmdRdy, Clk, "1.0");
		CheckMemCmd( 16#02000001#, 33, 0, Mem_CmdAddr, Mem_CmdSize, Mem_CmdVld, Mem_CmdRdy, Clk, "2.1");
		CheckMemCmd( 16#01000001#, 21, 0, Mem_CmdAddr, Mem_CmdSize, Mem_CmdVld, Mem_CmdRdy, Clk, "1.1");
		CheckMemCmd( 16#01000002#, 11, 0, Mem_CmdAddr, Mem_CmdSize, Mem_CmdVld, Mem_CmdRdy, Clk, "1.2");
		CheckMemCmd( 16#02000002#, 11, 0, Mem_CmdAddr, Mem_CmdSize, Mem_CmdVld, Mem_CmdRdy, Clk, "2.2");
		ProcDone_V(1) :=  '1';	

		-- End Aligned
		WaitForCase(4, Clk);
		CheckMemCmd( 16#01230000#, 30, 0, Mem_CmdAddr, Mem_CmdSize, Mem_CmdVld, Mem_CmdRdy, Clk);
		CheckMemCmd( 16#01231000#, 34, 0, Mem_CmdAddr, Mem_CmdSize, Mem_CmdVld, Mem_CmdRdy, Clk);
		CheckMemCmd( 16#01232000#, 30, 0, Mem_CmdAddr, Mem_CmdSize, Mem_CmdVld, Mem_CmdRdy, Clk);
		ProcDone_V(1) :=  '1';		
		
		-- Unaligned end by trigger (with rem-word)
		WaitForCase(5, Clk);
		CheckMemCmd( 16#01230000#, 30, 0, Mem_CmdAddr, Mem_CmdSize, Mem_CmdVld, Mem_CmdRdy, Clk);
		CheckMemCmd( 16#01231000#, 29, 0, Mem_CmdAddr, Mem_CmdSize, Mem_CmdVld, Mem_CmdRdy, Clk);
		CheckMemCmd( 16#01232000#, 30, 0, Mem_CmdAddr, Mem_CmdSize, Mem_CmdVld, Mem_CmdRdy, Clk);
		ProcDone_V(1) :=  '1';	

		-- Unaligned end by trigger (without rem-word)
		WaitForCase(6, Clk);
		CheckMemCmd( 16#01230000#, 30, 0, Mem_CmdAddr, Mem_CmdSize, Mem_CmdVld, Mem_CmdRdy, Clk);
		CheckMemCmd( 16#01231000#, 25, 0, Mem_CmdAddr, Mem_CmdSize, Mem_CmdVld, Mem_CmdRdy, Clk);
		CheckMemCmd( 16#01232000#, 30, 0, Mem_CmdAddr, Mem_CmdSize, Mem_CmdVld, Mem_CmdRdy, Clk);
		ProcDone_V(1) :=  '1';		
		
		-- Unaligned end by timeout
		WaitForCase(7, Clk);
		CheckMemCmd( 16#01230000#, 30, 0, Mem_CmdAddr, Mem_CmdSize, Mem_CmdVld, Mem_CmdRdy, Clk);
		CheckMemCmd( 16#01231000#, 29, 0, Mem_CmdAddr, Mem_CmdSize, Mem_CmdVld, Mem_CmdRdy, Clk);
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
		-- End Unaligned
		WaitForCase(0, Clk);
		CheckMemData(30, 0, Mem_DatData, Mem_DatVld, Mem_DatRdy, Clk, 0, "1.0");	
		CheckMemData(29, 0, Mem_DatData, Mem_DatVld, Mem_DatRdy, Clk, 30, "1.1");
		CheckMemData(30, 0, Mem_DatData, Mem_DatVld, Mem_DatRdy, Clk, 30+29, "1.2");
		ProcDone_V(2) :=  '1';
		
		-- QWord Split
		WaitForCase(1, Clk);
		CheckMemData(30, 0, Mem_DatData, Mem_DatVld, Mem_DatRdy, Clk);	
		CheckMemData(29, 0, Mem_DatData, Mem_DatVld, Mem_DatRdy, Clk, 30);
		CheckMemData(30, 0, Mem_DatData, Mem_DatVld, Mem_DatRdy, Clk, 30+29);
		ProcDone_V(2) :=  '1';	

		-- QWord Split, Rdy Toggling
		WaitForCase(2, Clk);
		CheckMemData(30, 5, Mem_DatData, Mem_DatVld, Mem_DatRdy, Clk);	
		CheckMemData(29, 5, Mem_DatData, Mem_DatVld, Mem_DatRdy, Clk, 30);
		CheckMemData(30, 5, Mem_DatData, Mem_DatVld, Mem_DatRdy, Clk, 30+29);
		ProcDone_V(2) :=  '1';	

		-- mixed streams
		WaitForCase(3, Clk);
		CheckMemData(30, 0, Mem_DatData, Mem_DatVld, Mem_DatRdy, Clk, 0, "2.0");	
		CheckMemData(23, 0, Mem_DatData, Mem_DatVld, Mem_DatRdy, Clk, 0, "1.0");
		CheckMemData(33, 0, Mem_DatData, Mem_DatVld, Mem_DatRdy, Clk, 30, "2.1");
		CheckMemData(21, 0, Mem_DatData, Mem_DatVld, Mem_DatRdy, Clk, 23, "1.1");
		CheckMemData(11, 0, Mem_DatData, Mem_DatVld, Mem_DatRdy, Clk, 23+21, "1.2");
		CheckMemData(11, 0, Mem_DatData, Mem_DatVld, Mem_DatRdy, Clk, 30+33, "2.2");		
		ProcDone_V(2) :=  '1';			
		
		-- End Unaligned
		WaitForCase(4, Clk);
		CheckMemData(30, 0, Mem_DatData, Mem_DatVld, Mem_DatRdy, Clk, 0, "1.0");	
		CheckMemData(34, 0, Mem_DatData, Mem_DatVld, Mem_DatRdy, Clk, 30, "1.1");
		CheckMemData(30, 0, Mem_DatData, Mem_DatVld, Mem_DatRdy, Clk, 30+34, "1.2");
		ProcDone_V(2) :=  '1';	

		-- Unaligned end by trigger (with rem-word)
		WaitForCase(5, Clk);
		CheckMemData(30, 0, Mem_DatData, Mem_DatVld, Mem_DatRdy, Clk, 0, "1.0");	
		CheckMemData(29, 0, Mem_DatData, Mem_DatVld, Mem_DatRdy, Clk, 30, "1.1");
		CheckMemData(30, 0, Mem_DatData, Mem_DatVld, Mem_DatRdy, Clk, 30+29, "1.2");
		ProcDone_V(2) :=  '1';
		
		-- Unaligned end by trigger (without rem-word)
		WaitForCase(6, Clk);
		CheckMemData(30, 0, Mem_DatData, Mem_DatVld, Mem_DatRdy, Clk, 0, "1.0");	
		CheckMemData(25, 0, Mem_DatData, Mem_DatVld, Mem_DatRdy, Clk, 30, "1.1");
		CheckMemData(30, 0, Mem_DatData, Mem_DatVld, Mem_DatRdy, Clk, 30+25, "1.2");
		ProcDone_V(2) :=  '1';

		-- Unaligned end by timeout		
		WaitForCase(7, Clk);
		CheckMemData(30, 0, Mem_DatData, Mem_DatVld, Mem_DatRdy, Clk, 0, "1.0");	
		CheckMemData(29, 0, Mem_DatData, Mem_DatVld, Mem_DatRdy, Clk, 30, "1.1");
		CheckMemData(30, 0, Mem_DatData, Mem_DatVld, Mem_DatRdy, Clk, 30+29, "1.2");
		ProcDone_V(2) :=  '1';		
	end procedure;
	
end;
