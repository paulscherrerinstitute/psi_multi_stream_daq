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
	use work.psi_common_array_pkg.all;
	use work.psi_ms_daq_pkg.all;

library work;
	use work.psi_ms_daq_daq_sm_tb_pkg.all;

library work;
	use work.psi_tb_txt_util.all;
	use work.psi_tb_compare_pkg.all;

------------------------------------------------------------
-- Package Header
------------------------------------------------------------
package psi_ms_daq_daq_sm_tb_case_single_simple is
	
	procedure control (
		signal Clk : in std_logic;
		signal Rst : inout std_logic;
		signal GlbEna : inout std_logic;
		signal StrEna : inout std_logic_vector;
		signal StrIrq : in std_logic_vector;
		signal Inp_HasLast : inout std_logic_vector;
		signal Inp_Level : inout t_aslv16;
		signal Ts_Vld : inout std_logic_vector;
		signal Ts_Rdy : in std_logic_vector;
		signal Ts_Data : inout t_aslv64;
		signal Dma_Cmd : in DaqSm2DaqDma_Cmd_t;
		signal Dma_Cmd_Vld : in std_logic;
		constant Generics_c : Generics_t);
		
	procedure dma_cmd (
		signal Clk : in std_logic;
		signal StrIrq : in std_logic_vector;
		signal Dma_Cmd : in DaqSm2DaqDma_Cmd_t;
		signal Dma_Cmd_Vld : in std_logic;
		constant Generics_c : Generics_t);
		
	procedure dma_resp (
		signal Clk : in std_logic;
		signal StrIrq : in std_logic_vector;
		signal Dma_Resp : inout DaqDma2DaqSm_Resp_t;
		signal Dma_Resp_Vld : inout std_logic;
		signal Dma_Resp_Rdy : in std_logic;
		signal TfDone : inout std_logic;
		signal StrLastWin : in WinType_a(Streams_g-1 downto 0);
		constant Generics_c : Generics_t);
		
	procedure ctx (
		signal Clk : in std_logic;
		signal CtxStr_Cmd : in ToCtxStr_t;
		signal CtxStr_Resp : inout FromCtx_t;
		signal CtxWin_Cmd : in ToCtxWin_t;
		signal CtxWin_Resp : inout FromCtx_t;
		constant Generics_c : Generics_t);
		
end package;

------------------------------------------------------------
-- Package Body
------------------------------------------------------------
package body psi_ms_daq_daq_sm_tb_case_single_simple is
	procedure control (
		signal Clk : in std_logic;
		signal Rst : inout std_logic;
		signal GlbEna : inout std_logic;
		signal StrEna : inout std_logic_vector;
		signal StrIrq : in std_logic_vector;
		signal Inp_HasLast : inout std_logic_vector;
		signal Inp_Level : inout t_aslv16;
		signal Ts_Vld : inout std_logic_vector;
		signal Ts_Rdy : in std_logic_vector;
		signal Ts_Data : inout t_aslv64;
		signal Dma_Cmd : in DaqSm2DaqDma_Cmd_t;
		signal Dma_Cmd_Vld : in std_logic;
		constant Generics_c : Generics_t) is
		variable StartTime_v : time;
	begin
		print(">> -- single_simple --");
		InitTestCase(Clk, Rst);
		
		-- Check Steady behavior
		print(">> Check Steady Behavior");
		TestCase := 0;
		StartTime_v := now;
		while now < StartTime_v + 1 us loop
			StdlvCompareInt(0, Ts_Rdy, "Ts_Rdy high in steady check");
			wait until rising_edge(Clk);
		end loop;
		ControlWaitCompl(Clk);
		
		-- No reaction on insignificant leven
		print(">> No reaction on insignificant leven");
		TestCase := 1;
		StartTime_v := now;
		while now < StartTime_v + 1 us loop
			StdlvCompareInt(0, Ts_Rdy, "Ts_Rdy high in steady check");
			wait until rising_edge(Clk);
		end loop;
		ControlWaitCompl(Clk);	
		
		-- First transfer after startup, 4k Aligned
		-- .. This is required to bypass all special handling for the first transfer after enabling a stream.
		print(">> First transfer after startup, 4k Aligned");	
		TestCase := 2;
		for str in 0 to 3 loop
			Inp_Level(str) <= std_logic_vector(to_unsigned(Size4k_c/DataWidthBytes_c, Inp_Level(str)'length));
			wait until rising_edge(Clk) and Dma_Cmd_Vld = '1';
			Inp_Level(str) <= (others => '0');	
			wait for 1 us;
		end loop;
		ControlWaitCompl(Clk);
		
		-- Check a single 4k aligned burst on stream 1
		print(">> most simple 4k Aligned transfer");
		TestCase := 3;
		Inp_Level(1) <= std_logic_vector(to_unsigned(Size4k_c/DataWidthBytes_c, Inp_Level(0)'length));
		wait until rising_edge(Clk) and Dma_Cmd_Vld = '1';
		Inp_Level(1) <= (others => '0');		
		ControlWaitCompl(Clk);
		
		-- Check two 4k Transfers in a row on stream 0
		print(">> two 4k Aligned transfers");	
		TestCase := 4;
		Inp_Level(0) <= std_logic_vector(to_unsigned(Size4k_c/DataWidthBytes_c, Inp_Level(0)'length));
		wait until rising_edge(Clk) and Dma_Cmd_Vld = '1';
		wait until rising_edge(Clk) and Dma_Cmd_Vld = '1';
		Inp_Level(0) <= (others => '0');
		ControlWaitCompl(Clk);	

		-- Check maximum Transfer size limitation
		print(">> Transfer size limitation to 4k");	
		TestCase := 5;
		Inp_Level(0) <= std_logic_vector(to_unsigned(Size4k_c*2/DataWidthBytes_c, Inp_Level(0)'length));
		wait until rising_edge(Clk) and Dma_Cmd_Vld = '1';
		Inp_Level(0) <= (others => '0');
		ControlWaitCompl(Clk);			
		
		-- Check 4k boundary limitation
		print(">> Check 4k boundary limitation");	
		TestCase := 6;
		Inp_Level(0) <= std_logic_vector(to_unsigned(Size4k_c/DataWidthBytes_c, Inp_Level(0)'length));
		wait until rising_edge(Clk) and Dma_Cmd_Vld = '1';
		Inp_Level(0) <= (others => '0');
		ControlWaitCompl(Clk);		
		
		-- Check window size limitation
		print(">> Check window size limitation");	
		TestCase := 7;
		Inp_Level(1) <= std_logic_vector(to_unsigned(Size4k_c/DataWidthBytes_c, Inp_Level(0)'length));
		wait until rising_edge(Clk) and Dma_Cmd_Vld = '1';
		Inp_Level(1) <= (others => '0');
		ControlWaitCompl(Clk);		
		
		-- check response smaller than request
		print(">> check response smaller than request");	
		TestCase := 8;
		Inp_Level(1) <= std_logic_vector(to_unsigned(Size4k_c/DataWidthBytes_c, Inp_Level(0)'length));
		wait until rising_edge(Clk) and Dma_Cmd_Vld = '1';
		Inp_Level(1) <= (others => '0');
		ControlWaitCompl(Clk);	
		
		FinishTestCase;
		
	end procedure;
	
	procedure dma_cmd (
		signal Clk : in std_logic;
		signal StrIrq : in std_logic_vector;
		signal Dma_Cmd : in DaqSm2DaqDma_Cmd_t;
		signal Dma_Cmd_Vld : in std_logic;
		constant Generics_c : Generics_t) is
		variable StartTime_v : time;
	begin
		-- Check Steady behavior
		WaitForCase(0, Clk);
		StartTime_v := now;
		while now < StartTime_v + 1 us loop
			StdlCompare(0, Dma_Cmd_Vld, "Dma_Cmd_Vld high in steady check");
			wait until rising_edge(Clk);
		end loop;
		ProcDone(2)	:= '1';
		
		-- No reaction on insignificant level
		WaitForCase(1, Clk);
		StartTime_v := now;
		while now < StartTime_v + 1 us loop
			StdlCompare(0, Dma_Cmd_Vld, "Dma_Cmd_Vld high in insignificant level");
			wait until rising_edge(Clk);
		end loop;
		ProcDone(2)	:= '1';		
		
		-- First transfer after startup, 4k Aligned
		WaitForCase(2, Clk);
		for str in 0 to 3 loop
			ExpectDmaCmd(	Stream	=> str,
							Address	=> 16#01230000#,
							MaxSize	=> Size4k_c,
							Clk		=> Clk,
							Dma_Cmd	=> Dma_Cmd,
							Dma_Vld	=> Dma_Cmd_Vld);		
		end loop;
		ProcDone(2)	:= '1';	
		
		-- Check a single 4k aligned burst on stream 1
		WaitForCase(3, Clk);
		ExpectDmaCmd(	Stream	=> 1,
						Address	=> 16#01238000#,
						MaxSize	=> Size4k_c,
						Clk		=> Clk,
						Dma_Cmd	=> Dma_Cmd,
						Dma_Vld	=> Dma_Cmd_Vld);			
		ProcDone(2)	:= '1';	
		
		-- Check two 4k Transfers in a row on stream 0
		WaitForCase(4, Clk);
		for i in 0 to 1 loop
			ExpectDmaCmd(	Stream	=> 0,
							Address	=> 16#01238000# + i*16#1000#,
							MaxSize	=> Size4k_c,
							Clk		=> Clk,
							Dma_Cmd	=> Dma_Cmd,
							Dma_Vld	=> Dma_Cmd_Vld,
							Msg		=> "Tf" & to_string(i));	
		end loop;
		ProcDone(2)	:= '1';		

		-- Check maximum Transfer size limitation
		WaitForCase(5, Clk);
		ExpectDmaCmd(	Stream	=> 0,
						Address	=> 16#01238000#,
						MaxSize	=> Size4k_c,
						Clk		=> Clk,
						Dma_Cmd	=> Dma_Cmd,
						Dma_Vld	=> Dma_Cmd_Vld);			
		ProcDone(2)	:= '1';	
		
		-- Check 4k boundary limitation
		WaitForCase(6, Clk);
		ExpectDmaCmd(	Stream	=> 0,
						Address	=> 16#01238000#+384,
						MaxSize	=> Size4k_c-384,
						Clk		=> Clk,
						Dma_Cmd	=> Dma_Cmd,
						Dma_Vld	=> Dma_Cmd_Vld);			
		ProcDone(2)	:= '1';	
		
		-- Check window size limitation
		WaitForCase(7, Clk);
		ExpectDmaCmd(	Stream	=> 1,
						Address	=> 16#01230000#,
						MaxSize	=> 502,
						Clk		=> Clk,
						Dma_Cmd	=> Dma_Cmd,
						Dma_Vld	=> Dma_Cmd_Vld);			
		ProcDone(2)	:= '1';		

		-- check response smaller than request
		WaitForCase(8, Clk);
		ExpectDmaCmd(	Stream	=> 1,
						Address	=> 16#01230000#,
						MaxSize	=> Size4k_c,
						Clk		=> Clk,
						Dma_Cmd	=> Dma_Cmd,
						Dma_Vld	=> Dma_Cmd_Vld);			
		ProcDone(2)	:= '1';			
		
	end procedure;
	
	procedure dma_resp (
		signal Clk : in std_logic;
		signal StrIrq : in std_logic_vector;
		signal Dma_Resp : inout DaqDma2DaqSm_Resp_t;
		signal Dma_Resp_Vld : inout std_logic;
		signal Dma_Resp_Rdy : in std_logic;
		signal TfDone : inout std_logic;
		signal StrLastWin : in WinType_a(Streams_g-1 downto 0);
		constant Generics_c : Generics_t) is
		variable StartTime_v : time;
	begin
		-- Check Steady behavior
		WaitForCase(0, Clk);
		StartTime_v := now;
		while now < StartTime_v + 1 us loop
			StdlCompare(0, Dma_Resp_Rdy, "Dma_Resp_Rdy high in steady check");
			wait until rising_edge(Clk);
		end loop;
		ProcDone(1)	:= '1';
		
		-- No reaction on insignificant level
		WaitForCase(1, Clk);	
		StartTime_v := now;
		while now < StartTime_v + 1 us loop
			StdlCompare(0, Dma_Resp_Rdy, "Dma_Resp_Rdy high in insignificant level");
			wait until rising_edge(Clk);
		end loop;
		ProcDone(1)	:= '1';		
		
		-- First transfer after startup, 4k Aligned
		WaitForCase(2, Clk);	
		for str in 0 to 3 loop
			ApplyDmaResp(	Stream 			=> str,
							Size			=> Size4k_c,
							Trigger			=> '0',
							Delay			=> 200 ns,
							Clk				=> Clk,
							Dma_Resp		=> Dma_Resp,
							Dma_Resp_Vld	=> Dma_Resp_Vld,
							Dma_Resp_Rdy	=> Dma_Resp_Rdy);
		end loop;
		ProcDone(1)	:= '1';		

		
		-- Check a single 4k aligned burst on stream 1
		WaitForCase(3, Clk);	
		ApplyDmaResp(	Stream 			=> 1,
						Size			=> Size4k_c,
						Trigger			=> '0',
						Delay			=> 200 ns,
						Clk				=> Clk,
						Dma_Resp		=> Dma_Resp,
						Dma_Resp_Vld	=> Dma_Resp_Vld,
						Dma_Resp_Rdy	=> Dma_Resp_Rdy);									
		ProcDone(1)	:= '1';		

		-- Check two 4k Transfers in a row on stream 0
		WaitForCase(4, Clk);	
		for i in 0 to 1 loop
			ApplyDmaResp(	Stream 			=> 0,
							Size			=> Size4k_c,
							Trigger			=> '0',
							Delay			=> 0 ns,
							Clk				=> Clk,
							Dma_Resp		=> Dma_Resp,
							Dma_Resp_Vld	=> Dma_Resp_Vld,
							Dma_Resp_Rdy	=> Dma_Resp_Rdy,
							Msg				=> "Tf" & to_string(i));
		end loop;
		ProcDone(1)	:= '1';	
		
		-- Check maximum Transfer size limitation
		WaitForCase(5, Clk);	
		ApplyDmaResp(	Stream 			=> 0,
						Size			=> Size4k_c,
						Trigger			=> '0',
						Clk				=> Clk,
						Dma_Resp		=> Dma_Resp,
						Dma_Resp_Vld	=> Dma_Resp_Vld,
						Dma_Resp_Rdy	=> Dma_Resp_Rdy);									
		ProcDone(1)	:= '1';	
		
		-- Check 4k boundary limitation
		WaitForCase(6, Clk);	
		ApplyDmaResp(	Stream 			=> 0,
						Size			=> Size4k_c-384,
						Trigger			=> '0',
						Clk				=> Clk,
						Dma_Resp		=> Dma_Resp,
						Dma_Resp_Vld	=> Dma_Resp_Vld,
						Dma_Resp_Rdy	=> Dma_Resp_Rdy);									
		ProcDone(1)	:= '1';	
		
		-- Check window size limitation
		WaitForCase(7, Clk);	
		ApplyDmaResp(	Stream 			=> 1,
						Size			=> 502,
						Trigger			=> '0',
						Clk				=> Clk,
						Dma_Resp		=> Dma_Resp,
						Dma_Resp_Vld	=> Dma_Resp_Vld,
						Dma_Resp_Rdy	=> Dma_Resp_Rdy);									
		ProcDone(1)	:= '1';		

		-- check response smaller than request
		WaitForCase(8, Clk);	
		ApplyDmaResp(	Stream 			=> 1,
						Size			=> 500,
						Trigger			=> '0',
						Clk				=> Clk,
						Dma_Resp		=> Dma_Resp,
						Dma_Resp_Vld	=> Dma_Resp_Vld,
						Dma_Resp_Rdy	=> Dma_Resp_Rdy);									
		ProcDone(1)	:= '1';				
		
	end procedure;
	
	procedure ctx (
		signal Clk : in std_logic;
		signal CtxStr_Cmd : in ToCtxStr_t;
		signal CtxStr_Resp : inout FromCtx_t;
		signal CtxWin_Cmd : in ToCtxWin_t;
		signal CtxWin_Resp : inout FromCtx_t;
		constant Generics_c : Generics_t) is
		variable StartTime_v 	: time;
		variable PtrStr1_v 		: integer;
	begin
		-- Check Steady behavior
		WaitForCase(0, Clk);
		StartTime_v := now;
		while now < StartTime_v + 1 us loop
			StdlCompare(0, CtxStr_Cmd.WenLo, "CtxStr_Cmd.WenLo high in steady check");
			StdlCompare(0, CtxStr_Cmd.WenHi, "CtxStr_Cmd.WenHi high in steady check");
			StdlCompare(0, CtxWin_Cmd.WenLo, "CtxWin_Cmd.WenLo high in steady check");
			StdlCompare(0, CtxWin_Cmd.WenHi, "CtxWin_Cmd.WenHi high in steady check");
			wait until rising_edge(Clk);
		end loop;		
		ProcDone(0)	:= '1';
		
		-- No reaction on insignificant leven
		WaitForCase(1, Clk);
		StartTime_v := now;
		while now < StartTime_v + 1 us loop
			StdlCompare(0, CtxStr_Cmd.WenLo, "CtxStr_Cmd.WenLo high in insignificant level");
			StdlCompare(0, CtxStr_Cmd.WenHi, "CtxStr_Cmd.WenHi high in insignificant level");
			StdlCompare(0, CtxWin_Cmd.WenLo, "CtxWin_Cmd.WenLo high in insignificant level");
			StdlCompare(0, CtxWin_Cmd.WenHi, "CtxWin_Cmd.WenHi high in insignificant level");
			wait until rising_edge(Clk);
		end loop;		
		ProcDone(0)	:= '1';		
		
		-- First transfer after startup, 4k Aligned
		WaitForCase(2, Clk);
		for str in 0 to 3 loop
			PtrStr1_v := 16#01230000#;
			ExpCtxFullBurst(	Stream				=> str,
								TfSize				=> Size4k_c,
								PtrBefore			=> PtrStr1_v,
								SamplesWinBefore	=> 0,
								PtrAfter			=> PtrStr1_v,
								Clk					=> Clk,
								CtxStr_Cmd			=> CtxStr_Cmd,
								CtxStr_Resp			=> CtxStr_Resp,
								CtxWin_Cmd 			=> CtxWin_Cmd,
								CtxWin_Resp			=> CtxWin_Resp,
								Msg					=> "Str" & to_string(str));
		end loop;
		ProcDone(0)	:= '1';	
		
		-- Check a single 4k aligned burst on stream 1
		WaitForCase(3, Clk);
		PtrStr1_v := 16#01238000#;
		ExpCtxFullBurst(	Stream				=> 1,
							TfSize				=> Size4k_c,
							PtrBefore			=> PtrStr1_v,
							SamplesWinBefore	=> 0,
							PtrAfter			=> PtrStr1_v,
							Clk					=> Clk,
							CtxStr_Cmd			=> CtxStr_Cmd,
							CtxStr_Resp			=> CtxStr_Resp,
							CtxWin_Cmd 			=> CtxWin_Cmd,
							CtxWin_Resp			=> CtxWin_Resp);
		ProcDone(0)	:= '1';	
		
		-- Check two 4k Transfers in a row on stream 0
		WaitForCase(4, Clk);
		PtrStr1_v := 16#01238000#;
		for i in 0 to 1 loop
			ExpCtxFullBurst(	Stream				=> 0,
								TfSize				=> Size4k_c,
								PtrBefore			=> PtrStr1_v,
								SamplesWinBefore	=> 0,
								PtrAfter			=> PtrStr1_v,
								Clk					=> Clk,
								CtxStr_Cmd			=> CtxStr_Cmd,
								CtxStr_Resp			=> CtxStr_Resp,
								CtxWin_Cmd 			=> CtxWin_Cmd,
								CtxWin_Resp			=> CtxWin_Resp);
		end loop;
		ProcDone(0)	:= '1';	
		
		-- Check maximum Transfer size limitation
		WaitForCase(5, Clk);
		PtrStr1_v := 16#01238000#;
		ExpCtxFullBurst(	Stream				=> 0,
							TfSize				=> Size4k_c,
							PtrBefore			=> PtrStr1_v,
							SamplesWinBefore	=> 0,
							PtrAfter			=> PtrStr1_v,
							Clk					=> Clk,
							CtxStr_Cmd			=> CtxStr_Cmd,
							CtxStr_Resp			=> CtxStr_Resp,
							CtxWin_Cmd 			=> CtxWin_Cmd,
							CtxWin_Resp			=> CtxWin_Resp);
		ProcDone(0)	:= '1';	

		-- Check 4k boundary limitation
		WaitForCase(6, Clk);
		PtrStr1_v := 16#01238000#+384;
		ExpCtxFullBurst(	Stream				=> 0,
							TfSize				=> Size4k_c-384,
							PtrBefore			=> PtrStr1_v,
							SamplesWinBefore	=> 0,
							PtrAfter			=> PtrStr1_v,
							Clk					=> Clk,
							CtxStr_Cmd			=> CtxStr_Cmd,
							CtxStr_Resp			=> CtxStr_Resp,
							CtxWin_Cmd 			=> CtxWin_Cmd,
							CtxWin_Resp			=> CtxWin_Resp);
		assert PtrStr1_v = 16#01239000# report "###ERROR###: Unexpected pointer value after transfer" severity error;
		ProcDone(0)	:= '1';	

		-- Check window size limitation	
		WaitForCase(7, Clk);
		PtrStr1_v := 16#01230000#;
		ExpCtxFullBurst(	Stream				=> 1,
							BufStart			=> 16#01230000#,
							TfSize				=> 502,
							NextWin				=> true,
							WinSize				=> 502,
							PtrBefore			=> PtrStr1_v,
							SamplesWinBefore	=> 0,
							PtrAfter			=> PtrStr1_v,
							Clk					=> Clk,
							CtxStr_Cmd			=> CtxStr_Cmd,
							CtxStr_Resp			=> CtxStr_Resp,
							CtxWin_Cmd 			=> CtxWin_Cmd,
							CtxWin_Resp			=> CtxWin_Resp);
		ProcDone(0)	:= '1';	
		
		-- check response smaller than request
		WaitForCase(8, Clk);
		PtrStr1_v := 16#01230000#;
		ExpCtxFullBurst(	Stream				=> 1,
							BufStart			=> 16#01230000#,
							TfSize				=> 500,
							PtrBefore			=> PtrStr1_v,
							SamplesWinBefore	=> 0,
							PtrAfter			=> PtrStr1_v,
							Clk					=> Clk,
							CtxStr_Cmd			=> CtxStr_Cmd,
							CtxStr_Resp			=> CtxStr_Resp,
							CtxWin_Cmd 			=> CtxWin_Cmd,
							CtxWin_Resp			=> CtxWin_Resp);
		assert PtrStr1_v = 16#01230000#+500 report "###ERROR###: Unexpected pointer value after transfer" severity error;
		ProcDone(0)	:= '1';			
		
	end procedure;
	
end;
	