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
	use work.psi_ms_daq_daq_sm_tb_pkg.all;

library work;
	use work.psi_tb_txt_util.all;
	use work.psi_tb_compare_pkg.all;
	use work.psi_tb_activity_pkg.all;

------------------------------------------------------------
-- Package Header
------------------------------------------------------------
package psi_ms_daq_daq_sm_tb_case_timestamp is
	
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
package body psi_ms_daq_daq_sm_tb_case_timestamp is
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
		print(">> -- timestamp --");	
	
		-- Timestamp handling
		print(">> Timestamp handling");
		InitTestCase(Clk, Rst);
		TestCase := 0;
		ConfigureAuto(	WinSize => 4096*2, Ringbuf => '0', Overwrite => '1', Wincnt => 2, Wincur => 0);		
		Inp_Level(2) <= LvlThreshold_c;
		for i in 0 to 4 loop			
			Ts_Data <= (0 to 3 => (others => '0'));		
			wait until rising_edge(Clk) and Dma_Cmd_Vld = '1';
			if i = 2 or i = 4 then
				Ts_Vld(2) <= '1'; 
				Ts_Data(2) <= std_logic_vector(to_unsigned(i*256, 64));
				wait until rising_edge(Clk) and Ts_Rdy(2) = '1';
				CheckLastActivity(Ts_Rdy(0), 10 us, 0);
				CheckLastActivity(Ts_Rdy(1), 10 us, 0);
				CheckLastActivity(Ts_Rdy(3), 10 us, 0);
				Ts_Data(2) <= (others => '0');	
			end if;			
		end loop;
		Ts_Vld(2) <= '0';
		Inp_Level(2) <= (others => '0');		
		ControlWaitCompl(Clk);

		-- timestamp on different stream has no effect
		print(">> timestamp on different stream has no effect");
		InitTestCase(Clk, Rst);
		TestCase := 1;
		ConfigureAuto(	WinSize => 4096*2, Ringbuf => '0', Overwrite => '1', Wincnt => 2, Wincur => 0);		
		Inp_Level(2) <= LvlThreshold_c;	
		wait until rising_edge(Clk) and Dma_Cmd_Vld = '1';
		Ts_Vld(0) <= '1'; 
		Ts_Data(2) <= std_logic_vector(to_unsigned(256, 64));
		Ts_Data(0) <= std_logic_vector(to_unsigned(256, 64));
		wait for 1 us;
		Ts_Data(2) <= std_logic_vector(to_unsigned(0, 64));
		Ts_Data(0) <= std_logic_vector(to_unsigned(0, 64));
		Ts_Vld(0) <= '0'; 
		Inp_Level(2) <= (others => '0');		
		ControlWaitCompl(Clk);
		
	end procedure;
	
	procedure dma_cmd (
		signal Clk : in std_logic;
		signal StrIrq : in std_logic_vector;
		signal Dma_Cmd : in DaqSm2DaqDma_Cmd_t;
		signal Dma_Cmd_Vld : in std_logic;
		constant Generics_c : Generics_t) is
	begin
		-- Timestamp handling
		WaitForCase(0,  Clk);
		-- First window without trigger
		ExpectDmaCmdAuto(	Stream	=> 2, MaxSize => 4096, Msg => "Wr0.0",
							Clk	=> Clk,	Dma_Cmd	=> Dma_Cmd,	Dma_Vld	=> Dma_Cmd_Vld);
		ExpectDmaCmdAuto(	Stream	=> 2, MaxSize => 4096, Msg => "Wr0.1", NextWin => true,
							Clk	=> Clk,	Dma_Cmd	=> Dma_Cmd,	Dma_Vld	=> Dma_Cmd_Vld);
		-- second window trigger in first access
		ExpectDmaCmdAuto(	Stream	=> 2, MaxSize => 4096, ExeSize=> 512, Msg => "Wr1.0", NextWin => true,
							Clk	=> Clk,	Dma_Cmd	=> Dma_Cmd,	Dma_Vld	=> Dma_Cmd_Vld);
		-- third window trigger in second access
		ExpectDmaCmdAuto(	Stream	=> 2, MaxSize => 4096, Msg => "Wr2.0",
							Clk	=> Clk,	Dma_Cmd	=> Dma_Cmd,	Dma_Vld	=> Dma_Cmd_Vld);		
		ExpectDmaCmdAuto(	Stream	=> 2, MaxSize => 4096, ExeSize=> 512, Msg => "Wr2.1", NextWin => true,
							Clk	=> Clk,	Dma_Cmd	=> Dma_Cmd,	Dma_Vld	=> Dma_Cmd_Vld);							
		ProcDone(2)	:= '1';	

		-- timestamp on different stream has no effect
		WaitForCase(1,  Clk);
		ExpectDmaCmdAuto(	Stream	=> 2, MaxSize => 4096, ExeSize=> 512, NextWin => true,
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
	begin
		-- Timestamp handling
		WaitForCase(0,  Clk);
		-- First window without trigger
		ApplyDmaRespAuto(	Stream => 2, Trigger => '0',
							Clk	=> Clk,	Dma_Resp => Dma_Resp, Dma_Resp_Vld => Dma_Resp_Vld,	Dma_Resp_Rdy => Dma_Resp_Rdy);	
		ApplyDmaRespAuto(	Stream => 2, Trigger => '0',
							Clk	=> Clk,	Dma_Resp => Dma_Resp, Dma_Resp_Vld => Dma_Resp_Vld,	Dma_Resp_Rdy => Dma_Resp_Rdy);	
		-- second window trigger in first access	
		ApplyDmaRespAuto(	Stream => 2, Trigger => '1',
							Clk	=> Clk,	Dma_Resp => Dma_Resp, Dma_Resp_Vld => Dma_Resp_Vld,	Dma_Resp_Rdy => Dma_Resp_Rdy);
		-- third window trigger in second access
		ApplyDmaRespAuto(	Stream => 2, Trigger => '0',
							Clk	=> Clk,	Dma_Resp => Dma_Resp, Dma_Resp_Vld => Dma_Resp_Vld,	Dma_Resp_Rdy => Dma_Resp_Rdy);	
		ApplyDmaRespAuto(	Stream => 2, Trigger => '1',
							Clk	=> Clk,	Dma_Resp => Dma_Resp, Dma_Resp_Vld => Dma_Resp_Vld,	Dma_Resp_Rdy => Dma_Resp_Rdy);
		ProcDone(1)	:= '1';
		
		-- timestamp on different stream has no effect
		WaitForCase(1,  Clk);
		ApplyDmaRespAuto(	Stream => 2, Trigger => '1',
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
	begin
		-- Timestamp handling
		WaitForCase(0, Clk);
		-- First window without trigger
		ExpCtxFullBurstAuto(	Stream => 2, Msg => "Wr0.0", WriteTs => CheckNotWritten,
								Clk => Clk, CtxStr_Cmd => CtxStr_Cmd, CtxStr_Resp => CtxStr_Resp, CtxWin_Cmd => CtxWin_Cmd, CtxWin_Resp => CtxWin_Resp);		
		ExpCtxFullBurstAuto(	Stream => 2, Msg => "Wr0.1", NextWin => true, WriteTs => CheckWritten, Timstamp => X"FFFFFFFFFFFFFFFF", -- without trigger, no timestamp is sampled
								Clk => Clk, CtxStr_Cmd => CtxStr_Cmd, CtxStr_Resp => CtxStr_Resp, CtxWin_Cmd => CtxWin_Cmd, CtxWin_Resp => CtxWin_Resp);	
		-- second window trigger in first access
		ExpCtxFullBurstAuto(	Stream => 2, Msg => "Wr1.0", NextWin => true, IsTrig => true, WriteTs => CheckWritten, Timstamp => X"0000000000000200",
								Clk => Clk, CtxStr_Cmd => CtxStr_Cmd, CtxStr_Resp => CtxStr_Resp, CtxWin_Cmd => CtxWin_Cmd, CtxWin_Resp => CtxWin_Resp);		
		-- third window trigger in second access
		ExpCtxFullBurstAuto(	Stream => 2, Msg => "Wr2.0", WriteTs => CheckNotWritten,
								Clk => Clk, CtxStr_Cmd => CtxStr_Cmd, CtxStr_Resp => CtxStr_Resp, CtxWin_Cmd => CtxWin_Cmd, CtxWin_Resp => CtxWin_Resp);		
		ExpCtxFullBurstAuto(	Stream => 2, Msg => "Wr2.1", NextWin => true, IsTrig => true, WriteTs => CheckWritten, Timstamp => X"0000000000000400",
								Clk => Clk, CtxStr_Cmd => CtxStr_Cmd, CtxStr_Resp => CtxStr_Resp, CtxWin_Cmd => CtxWin_Cmd, CtxWin_Resp => CtxWin_Resp);	
		ProcDone(0)	:= '1';	
		
		-- timestamp on different stream has no effect
		WaitForCase(1, Clk);
		ExpCtxFullBurstAuto(	Stream => 2, Msg => "Wr0.1", NextWin => true, IsTrig => true, WriteTs => CheckWritten, Timstamp => X"FFFFFFFFFFFFFFFF", -- No Timestamp available
								Clk => Clk, CtxStr_Cmd => CtxStr_Cmd, CtxStr_Resp => CtxStr_Resp, CtxWin_Cmd => CtxWin_Cmd, CtxWin_Resp => CtxWin_Resp);
		ProcDone(0)	:= '1';	
		
	end procedure;
	
end;
