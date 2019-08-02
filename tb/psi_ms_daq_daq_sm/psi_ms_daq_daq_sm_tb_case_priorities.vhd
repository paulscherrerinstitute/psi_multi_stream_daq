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
	use work.psi_common_array_pkg.all;

------------------------------------------------------------
-- Package Header
------------------------------------------------------------
package psi_ms_daq_daq_sm_tb_case_priorities is
	
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
		
	constant StreamOrder_c	: t_ainteger	:= (3, 0, 1, 2);
		
end package;

------------------------------------------------------------
-- Package Body
------------------------------------------------------------
package body psi_ms_daq_daq_sm_tb_case_priorities is
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
	begin
		print(">> -- priorities --");		
		
		-- Check correct order on parallel assertion
		InitTestCase(Clk, Rst);
		print(">> Check correct order on parallel assertion");
		TestCase := 0;
		for i in 0 to 3 loop
			Inp_Level(i) <= std_logic_vector(to_unsigned(Size4k_c/DataWidthBytes_c, Inp_Level(i)'length));
		end loop;
		for i in 0 to 3 loop
			wait until rising_edge(Clk) and Dma_Cmd_Vld = '1';
			Inp_Level(Dma_Cmd.Stream) <= (others => '0');
		end loop;
		ControlWaitCompl(Clk);	

		-- Round Robin behavior
		InitTestCase(Clk, Rst);
		print(">> Round Robin behavior");
		TestCase := 1;		
		Inp_Level(0) <= std_logic_vector(to_unsigned(Size4k_c/DataWidthBytes_c, Inp_Level(0)'length));
		Inp_Level(3) <= std_logic_vector(to_unsigned(Size4k_c/DataWidthBytes_c, Inp_Level(3)'length));
		Inp_Level(1) <= std_logic_vector(to_unsigned(Size4k_c/DataWidthBytes_c, Inp_Level(1)'length));
		for i in 0 to 3 loop
			wait until rising_edge(Clk) and Dma_Cmd_Vld = '1';
		end loop;
		Inp_Level(0) <= (others => '0');
		Inp_Level(3) <= (others => '0');
		wait until rising_edge(Clk) and Dma_Cmd_Vld = '1';	
		Inp_Level(1) <= (others => '0');	
		ControlWaitCompl(Clk);	
		
		-- Reassertion of high-priority streams
		InitTestCase(Clk, Rst);
		print(">> Reassertion of high-priority streams");
		TestCase := 2;			
		Inp_Level(0) <= std_logic_vector(to_unsigned(Size4k_c/DataWidthBytes_c, Inp_Level(0)'length));
		Inp_Level(1) <= std_logic_vector(to_unsigned(Size4k_c/DataWidthBytes_c, Inp_Level(1)'length));
		wait until rising_edge(Clk) and Dma_Cmd_Vld = '1';
		Inp_Level(0) <= (others => '0');
		wait until rising_edge(Clk) and Dma_Cmd_Vld = '1';
		Inp_Level(0) <= std_logic_vector(to_unsigned(Size4k_c/DataWidthBytes_c, Inp_Level(0)'length));
		wait until rising_edge(Clk) and Dma_Cmd_Vld = '1';
		Inp_Level(0) <= (others => '0');
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
		variable Stream_v : integer;
	begin
		-- Check correct order on parallel assertion
		WaitForCase(0,  Clk);
		for i in 0 to 3 loop
			ExpectDmaCmdAuto(	Stream	=> StreamOrder_c(i), MaxSize => Size4k_c,
								Clk	=> Clk,	Dma_Cmd	=> Dma_Cmd,	Dma_Vld	=> Dma_Cmd_Vld);	
		end loop;
		ProcDone(2)	:= '1';	
		
		-- Round Robin behavior
		WaitForCase(1,  Clk);
		for i in 0 to 1 loop
			for s in 0 to 1 loop
				ExpectDmaCmdAuto(	Stream	=> choose(s=0, 3, 0), MaxSize => Size4k_c, Msg => "i=" & to_string(i) & ", s=" & to_string(s),
									Clk	=> Clk,	Dma_Cmd	=> Dma_Cmd,	Dma_Vld	=> Dma_Cmd_Vld);
			end loop;
		end loop;
		ExpectDmaCmdAuto(	Stream	=> 1, MaxSize => Size4k_c,
							Clk	=> Clk,	Dma_Cmd	=> Dma_Cmd,	Dma_Vld	=> Dma_Cmd_Vld);		
		ProcDone(2)	:= '1';		
		
		-- Reassertion of high-priority streams
		WaitForCase(2,  Clk);
		ExpectDmaCmdAuto(	Stream	=> 0, MaxSize => Size4k_c, Msg => "HP0",
							Clk	=> Clk,	Dma_Cmd	=> Dma_Cmd,	Dma_Vld	=> Dma_Cmd_Vld);
		ExpectDmaCmdAuto(	Stream	=> 1, MaxSize => Size4k_c, Msg => "LP0",
							Clk	=> Clk,	Dma_Cmd	=> Dma_Cmd,	Dma_Vld	=> Dma_Cmd_Vld);
		ExpectDmaCmdAuto(	Stream	=> 0, MaxSize => Size4k_c, Msg => "HP1",
							Clk	=> Clk,	Dma_Cmd	=> Dma_Cmd,	Dma_Vld	=> Dma_Cmd_Vld);
		ExpectDmaCmdAuto(	Stream	=> 1, MaxSize => Size4k_c, Msg => "LP1",
							Clk	=> Clk,	Dma_Cmd	=> Dma_Cmd,	Dma_Vld	=> Dma_Cmd_Vld);	
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
		variable Stream_v : integer;
	begin
		-- Check correct order on parallel assertion
		WaitForCase(0,  Clk);
		for i in 0 to 3 loop
			ApplyDmaResp(	Stream => StreamOrder_c(i),	Size => Size4k_c, Trigger => '0',
							Clk	=> Clk,	Dma_Resp => Dma_Resp, Dma_Resp_Vld => Dma_Resp_Vld,	Dma_Resp_Rdy => Dma_Resp_Rdy);
		end loop;
		ProcDone(1)	:= '1';

		-- Round Robin behavior	
		WaitForCase(1,  Clk);
		for i in 0 to 1 loop
			for s in 0 to 1 loop
				ApplyDmaResp(	Stream => choose(s=0, 3, 0), Size => Size4k_c, Trigger => '0',
								Clk	=> Clk,	Dma_Resp => Dma_Resp, Dma_Resp_Vld => Dma_Resp_Vld,	Dma_Resp_Rdy => Dma_Resp_Rdy);
			end loop;
		end loop;
		ApplyDmaResp(	Stream => 1, Size => Size4k_c, Trigger => '0',
						Clk	=> Clk,	Dma_Resp => Dma_Resp, Dma_Resp_Vld => Dma_Resp_Vld,	Dma_Resp_Rdy => Dma_Resp_Rdy);	
		ProcDone(1)	:= '1';
		
		-- Reassertion of high-priority streams
		WaitForCase(2,  Clk);
		ApplyDmaResp(	Stream => 0, Size => Size4k_c, Trigger => '0',
						Clk	=> Clk,	Dma_Resp => Dma_Resp, Dma_Resp_Vld => Dma_Resp_Vld,	Dma_Resp_Rdy => Dma_Resp_Rdy);
		ApplyDmaResp(	Stream => 1, Size => Size4k_c, Trigger => '0',
						Clk	=> Clk,	Dma_Resp => Dma_Resp, Dma_Resp_Vld => Dma_Resp_Vld,	Dma_Resp_Rdy => Dma_Resp_Rdy);
		ApplyDmaResp(	Stream => 0, Size => Size4k_c, Trigger => '0',
						Clk	=> Clk,	Dma_Resp => Dma_Resp, Dma_Resp_Vld => Dma_Resp_Vld,	Dma_Resp_Rdy => Dma_Resp_Rdy);
		ApplyDmaResp(	Stream => 1, Size => Size4k_c, Trigger => '0',
						Clk	=> Clk,	Dma_Resp => Dma_Resp, Dma_Resp_Vld => Dma_Resp_Vld,	Dma_Resp_Rdy => Dma_Resp_Rdy);						
		ProcDone(1)	:= '1';
		
		
	end procedure;
	
	procedure ctx (
		signal Clk : in std_logic;
		signal CtxStr_Cmd : in ToCtxStr_t;
		signal CtxStr_Resp : inout FromCtx_t;
		signal CtxWin_Cmd : in ToCtxWin_t;
		signal CtxWin_Resp : inout FromCtx_t;
		constant Generics_c : Generics_t) is
		variable Ptr_v : integer;
		variable Stream_v : integer;
		variable PtrStr_v	: t_ainteger(0 to 3);
		variable SplsStr_v	: t_ainteger(0 to 3)	:= (others => 0);
	begin
		-- Check two 4k Transfers in a row on stream 0
		WaitForCase(0, Clk);
		-- Requests are handled before responses
		for i in 0 to 3 loop
			ExpCtxReadAuto(	Stream => StreamOrder_c(i), 
							Clk => Clk, CtxStr_Cmd => CtxStr_Cmd, CtxStr_Resp => CtxStr_Resp, CtxWin_Cmd => CtxWin_Cmd, CtxWin_Resp => CtxWin_Resp);
		end loop;
		for i in 0 to 3 loop
			ExpCtxUpdateAuto(	Stream => StreamOrder_c(i),
								Clk => Clk, CtxStr_Cmd => CtxStr_Cmd, CtxStr_Resp => CtxStr_Resp, CtxWin_Cmd => CtxWin_Cmd, CtxWin_Resp => CtxWin_Resp);
		end loop;
		ProcDone(0)	:= '1';	
		
		-- Round Robin behavior
		WaitForCase(1, Clk);
		PtrStr_v := (16#00000#, 16#10000#, 16#20000#, 16#30000#);
		-- First high prio command
		ExpCtxReadAuto(	Stream => 3, 
						Clk => Clk, CtxStr_Cmd => CtxStr_Cmd, CtxStr_Resp => CtxStr_Resp, CtxWin_Cmd => CtxWin_Cmd, CtxWin_Resp => CtxWin_Resp);
		-- Second high prio stream can immediately send the next command
		ExpCtxReadAuto(	Stream => 0, 
						Clk => Clk, CtxStr_Cmd => CtxStr_Cmd, CtxStr_Resp => CtxStr_Resp, CtxWin_Cmd => CtxWin_Cmd, CtxWin_Resp => CtxWin_Resp);		
		-- Wait for response and schnedule next high prio command
		ExpCtxUpdateAuto(	Stream => 3,
							Clk => Clk, CtxStr_Cmd => CtxStr_Cmd, CtxStr_Resp => CtxStr_Resp, CtxWin_Cmd => CtxWin_Cmd, CtxWin_Resp => CtxWin_Resp);
		ExpCtxReadAuto(	Stream => 3, 
						Clk => Clk, CtxStr_Cmd => CtxStr_Cmd, CtxStr_Resp => CtxStr_Resp, CtxWin_Cmd => CtxWin_Cmd, CtxWin_Resp => CtxWin_Resp);
		-- Wait for response and schnedule next high prio command	
		ExpCtxUpdateAuto(	Stream => 0,
							Clk => Clk, CtxStr_Cmd => CtxStr_Cmd, CtxStr_Resp => CtxStr_Resp, CtxWin_Cmd => CtxWin_Cmd, CtxWin_Resp => CtxWin_Resp);		
		ExpCtxReadAuto(	Stream => 0, 
						Clk => Clk, CtxStr_Cmd => CtxStr_Cmd, CtxStr_Resp => CtxStr_Resp, CtxWin_Cmd => CtxWin_Cmd, CtxWin_Resp => CtxWin_Resp);								
		-- No more high prio data, so low prio command follows
		ExpCtxReadAuto(	Stream => 1, 
						Clk => Clk, CtxStr_Cmd => CtxStr_Cmd, CtxStr_Resp => CtxStr_Resp, CtxWin_Cmd => CtxWin_Cmd, CtxWin_Resp => CtxWin_Resp);			
		-- pending responses
		ExpCtxUpdateAuto(	Stream => 3, Msg => "RobinLast3",
							Clk => Clk, CtxStr_Cmd => CtxStr_Cmd, CtxStr_Resp => CtxStr_Resp, CtxWin_Cmd => CtxWin_Cmd, CtxWin_Resp => CtxWin_Resp);
		ExpCtxUpdateAuto(	Stream => 0, Msg => "RobinLast0",
							Clk => Clk, CtxStr_Cmd => CtxStr_Cmd, CtxStr_Resp => CtxStr_Resp, CtxWin_Cmd => CtxWin_Cmd, CtxWin_Resp => CtxWin_Resp);
		ExpCtxUpdateAuto(	Stream => 1, Msg => "RobinLast1",
							Clk => Clk, CtxStr_Cmd => CtxStr_Cmd, CtxStr_Resp => CtxStr_Resp, CtxWin_Cmd => CtxWin_Cmd, CtxWin_Resp => CtxWin_Resp);								
		ProcDone(0)	:= '1';	
		
		-- Reassertion of high-priority streams
		WaitForCase(2, Clk);
		-- Start high-prio transfer
		ExpCtxReadAuto(	Stream => 0, Msg => "Start HP0",
						Clk => Clk, CtxStr_Cmd => CtxStr_Cmd, CtxStr_Resp => CtxStr_Resp, CtxWin_Cmd => CtxWin_Cmd, CtxWin_Resp => CtxWin_Resp);	
		-- Start low-prio transfer
		ExpCtxReadAuto(	Stream => 1, Msg => "Start LP0",
						Clk => Clk, CtxStr_Cmd => CtxStr_Cmd, CtxStr_Resp => CtxStr_Resp, CtxWin_Cmd => CtxWin_Cmd, CtxWin_Resp => CtxWin_Resp);	
		-- High-prio data available, so wait for high-prio response and restart transfer
		ExpCtxUpdateAuto(	Stream => 0, Msg => "Finish HP0",
							Clk => Clk, CtxStr_Cmd => CtxStr_Cmd, CtxStr_Resp => CtxStr_Resp, CtxWin_Cmd => CtxWin_Cmd, CtxWin_Resp => CtxWin_Resp);
		ExpCtxReadAuto(	Stream => 0, Msg => "Start HP1",
						Clk => Clk, CtxStr_Cmd => CtxStr_Cmd, CtxStr_Resp => CtxStr_Resp, CtxWin_Cmd => CtxWin_Cmd, CtxWin_Resp => CtxWin_Resp);
		-- Low-prio data available, so wait for high-prio response and restart transfer
		ExpCtxUpdateAuto(	Stream => 1, Msg => "Finish LP0",
							Clk => Clk, CtxStr_Cmd => CtxStr_Cmd, CtxStr_Resp => CtxStr_Resp, CtxWin_Cmd => CtxWin_Cmd, CtxWin_Resp => CtxWin_Resp);
		ExpCtxReadAuto(	Stream => 1, Msg => "Start LP1",
						Clk => Clk, CtxStr_Cmd => CtxStr_Cmd, CtxStr_Resp => CtxStr_Resp, CtxWin_Cmd => CtxWin_Cmd, CtxWin_Resp => CtxWin_Resp);
		-- Completion of last high prio transfer
		ExpCtxUpdateAuto(	Stream => 0, Msg => "Finish HP1",
							Clk => Clk, CtxStr_Cmd => CtxStr_Cmd, CtxStr_Resp => CtxStr_Resp, CtxWin_Cmd => CtxWin_Cmd, CtxWin_Resp => CtxWin_Resp);						
		-- Completion of last low prio transfer
		ExpCtxUpdateAuto(	Stream => 1, Msg => "Finish LP1",
							Clk => Clk, CtxStr_Cmd => CtxStr_Cmd, CtxStr_Resp => CtxStr_Resp, CtxWin_Cmd => CtxWin_Cmd, CtxWin_Resp => CtxWin_Resp);
							
		ProcDone(0)	:= '1';	
	end procedure;
	
end;
