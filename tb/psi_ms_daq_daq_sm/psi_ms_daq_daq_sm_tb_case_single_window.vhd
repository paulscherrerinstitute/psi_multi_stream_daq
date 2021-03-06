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
package psi_ms_daq_daq_sm_tb_case_single_window is
	
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
package body psi_ms_daq_daq_sm_tb_case_single_window is
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
		print(">> -- single window --");		
		
		-- Linear write with Overwrite
		print(">> Linear write with Overwrite");
		InitTestCase(Clk, Rst);
		TestCase := 0;
		ConfigureAuto(	WinSize => 4096+128, Ringbuf => '0', Overwrite => '1', Wincnt => 0, Wincur => 0);		
		Inp_Level(2) <= LvlThreshold_c;		
		for i in 0 to 5 loop
			wait until rising_edge(Clk) and Dma_Cmd_Vld = '1';
		end loop;
		Inp_Level(2) <= (others => '0');		
		ControlWaitCompl(Clk);			
		
		-- Ringbuf with overwrite
		print(">> Ringbuf with overwrite");
		InitTestCase(Clk, Rst);
		TestCase := 1;
		ConfigureAuto(	WinSize => 4096+128, Ringbuf => '1', Overwrite => '1', Wincnt => 0, Wincur => 0);		
		Inp_Level(2) <= LvlThreshold_c;		
		for i in 0 to 5 loop
			wait until rising_edge(Clk) and Dma_Cmd_Vld = '1';
		end loop;
		Inp_Level(2) <= (others => '0');		
		ControlWaitCompl(Clk);	

		-- Linear without overwrite, no trigger
		print(">> Linear without overwrite, no trigger");
		InitTestCase(Clk, Rst);
		TestCase := 2;
		ConfigureAuto(	WinSize => 4096+128, Ringbuf => '0', Overwrite => '0', Wincnt => 0, Wincur => 0);		
		Inp_Level(2) <= LvlThreshold_c;		
		for i in 0 to 2 loop
			wait until rising_edge(Clk) and Dma_Cmd_Vld = '1';
		end loop;
		Inp_Level(2) <= (others => '0');		
		ControlWaitCompl(Clk);		

		-- Linear without overwrite, trigger
		print(">> Linear without overwrite, trigger");
		InitTestCase(Clk, Rst);
		TestCase := 3;
		ConfigureAuto(	WinSize => 4096+128, Ringbuf => '0', Overwrite => '0', Wincnt => 0, Wincur => 0);		
		Inp_Level(2) <= LvlThreshold_c;		
		for i in 0 to 1 loop
			wait until rising_edge(Clk) and Dma_Cmd_Vld = '1';
		end loop;
		Inp_Level(2) <= (others => '0');		
		ControlWaitCompl(Clk);			
		
		-- Ringbuf without overwrite
		print(">> Ringbuf without overwrite");
		wait for 1 us;
		InitTestCase(Clk, Rst);
		TestCase := 4;
		ConfigureAuto(	WinSize => 4096+128, Ringbuf => '1', Overwrite => '0', Wincnt => 0, Wincur => 0);		
		Inp_Level(2) <= LvlThreshold_c;		
		for i in 0 to 3 loop
			wait until rising_edge(Clk) and Dma_Cmd_Vld = '1';
		end loop;
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
		-- Linear write with Overwrite
		WaitForCase(0,  Clk);
		ExpectDmaCmdAuto(	Stream	=> 2, MaxSize => 4096, Msg => "Wr0.0",
							Clk	=> Clk,	Dma_Cmd	=> Dma_Cmd,	Dma_Vld	=> Dma_Cmd_Vld);	
		ExpectDmaCmdAuto(	Stream	=> 2, MaxSize => 128, Msg => "Wr0.1", NextWin => true,
							Clk	=> Clk,	Dma_Cmd	=> Dma_Cmd,	Dma_Vld	=> Dma_Cmd_Vld);		
		ExpectDmaCmdAuto(	Stream	=> 2, MaxSize => 4096, Msg => "Wr1.0",
							Clk	=> Clk,	Dma_Cmd	=> Dma_Cmd,	Dma_Vld	=> Dma_Cmd_Vld);	
		ExpectDmaCmdAuto(	Stream	=> 2, MaxSize => 128, Msg => "Wr1.1", NextWin => true,
							Clk	=> Clk,	Dma_Cmd	=> Dma_Cmd,	Dma_Vld	=> Dma_Cmd_Vld);		
		PtrDma_v(2) := BufStart_c(2);
		--> Finished by trigger
		ExpectDmaCmdAuto(	Stream	=> 2, MaxSize => 4096, ExeSize => 512, Msg => "Wr2.0", NextWin => true,
							Clk	=> Clk,	Dma_Cmd	=> Dma_Cmd,	Dma_Vld	=> Dma_Cmd_Vld);	
		--> Next window on trigger
		PtrDma_v(2) := BufStart_c(2);
		ExpectDmaCmdAuto(	Stream	=> 2, MaxSize => 4096, Msg => "Wr3.0",
							Clk	=> Clk,	Dma_Cmd	=> Dma_Cmd,	Dma_Vld	=> Dma_Cmd_Vld);	
		ProcDone(2)	:= '1';	
		
		-- Ringbuf with overwrite
		WaitForCase(1,  Clk);
		ExpectDmaCmdAuto(	Stream	=> 2, MaxSize => 4096, Msg => "Wr0.0",
							Clk	=> Clk,	Dma_Cmd	=> Dma_Cmd,	Dma_Vld	=> Dma_Cmd_Vld);	
		ExpectDmaCmdAuto(	Stream	=> 2, MaxSize => 128, Msg => "Wr0.1", NextWin => true,
							Clk	=> Clk,	Dma_Cmd	=> Dma_Cmd,	Dma_Vld	=> Dma_Cmd_Vld);		
		ExpectDmaCmdAuto(	Stream	=> 2, MaxSize => 4096, Msg => "Wr1.0",
							Clk	=> Clk,	Dma_Cmd	=> Dma_Cmd,	Dma_Vld	=> Dma_Cmd_Vld);	
		ExpectDmaCmdAuto(	Stream	=> 2, MaxSize => 128, Msg => "Wr1.1", NextWin => true,
							Clk	=> Clk,	Dma_Cmd	=> Dma_Cmd,	Dma_Vld	=> Dma_Cmd_Vld);		
		PtrDma_v(2) := BufStart_c(2);
		--> Finished by trigger
		ExpectDmaCmdAuto(	Stream	=> 2, MaxSize => 4096, ExeSize => 512, Msg => "Wr2.0", NextWin => true,
							Clk	=> Clk,	Dma_Cmd	=> Dma_Cmd,	Dma_Vld	=> Dma_Cmd_Vld);	
		--> Next window on trigger
		PtrDma_v(2) := BufStart_c(2);
		ExpectDmaCmdAuto(	Stream	=> 2, MaxSize => 4096, Msg => "Wr3.0",
							Clk	=> Clk,	Dma_Cmd	=> Dma_Cmd,	Dma_Vld	=> Dma_Cmd_Vld);	
		ProcDone(2)	:= '1';		

		-- Linear without overwrite, no trigger
		WaitForCase(2,  Clk);
		ExpectDmaCmdAuto(	Stream	=> 2, MaxSize => 4096, Msg => "Wr0.0",
							Clk	=> Clk,	Dma_Cmd	=> Dma_Cmd,	Dma_Vld	=> Dma_Cmd_Vld);	
		ExpectDmaCmdAuto(	Stream	=> 2, MaxSize => 128, Msg => "Wr0.1", NextWin => true,
							Clk	=> Clk,	Dma_Cmd	=> Dma_Cmd,	Dma_Vld	=> Dma_Cmd_Vld);		
		ExpectDmaCmdAuto(	Stream	=> 2, MaxSize => 4096, Msg => "Wr1.0",
							Clk	=> Clk,	Dma_Cmd	=> Dma_Cmd,	Dma_Vld	=> Dma_Cmd_Vld);	
		ProcDone(2)	:= '1';	

		-- Linear without overwrite, trigger
		WaitForCase(3,  Clk);
		ExpectDmaCmdAuto(	Stream	=> 2, MaxSize => 4096, ExeSize => 4000, Msg => "Wr0.0", NextWin => true,
							Clk	=> Clk,	Dma_Cmd	=> Dma_Cmd,	Dma_Vld	=> Dma_Cmd_Vld);			
		ExpectDmaCmdAuto(	Stream	=> 2, MaxSize => 4096, Msg => "Wr1.0",
							Clk	=> Clk,	Dma_Cmd	=> Dma_Cmd,	Dma_Vld	=> Dma_Cmd_Vld);	
		ProcDone(2)	:= '1';			
		
		
		-- Ringbuf without overwrite
		WaitForCase(4,  Clk);
		ExpectDmaCmdAuto(	Stream	=> 2, MaxSize => 4096, Msg => "Wr0.0",
							Clk	=> Clk,	Dma_Cmd	=> Dma_Cmd,	Dma_Vld	=> Dma_Cmd_Vld);	
		ExpectDmaCmdAuto(	Stream	=> 2, MaxSize => 128, Msg => "Wr0.1", NextWin => true,
							Clk	=> Clk,	Dma_Cmd	=> Dma_Cmd,	Dma_Vld	=> Dma_Cmd_Vld);		
		ExpectDmaCmdAuto(	Stream	=> 2, MaxSize => 4096, ExeSize => 4000, Msg => "Wr0.2", NextWin => true,
							Clk	=> Clk,	Dma_Cmd	=> Dma_Cmd,	Dma_Vld	=> Dma_Cmd_Vld);	
		ExpectDmaCmdAuto(	Stream	=> 2, MaxSize => 4096, Msg => "Wr1.0",
							Clk	=> Clk,	Dma_Cmd	=> Dma_Cmd,	Dma_Vld	=> Dma_Cmd_Vld);								
		ProcDone(2)	:= '1';			
		
		
		-- Ringbuf with odd framesize
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
		-- Linear write with Overwrite	
		WaitForCase(0,  Clk);
		ApplyDmaRespAuto(	Stream => 2, Trigger => '0',
							Clk	=> Clk,	Dma_Resp => Dma_Resp, Dma_Resp_Vld => Dma_Resp_Vld,	Dma_Resp_Rdy => Dma_Resp_Rdy);
		ApplyDmaRespAuto(	Stream => 2, Trigger => '0',
							Clk	=> Clk,	Dma_Resp => Dma_Resp, Dma_Resp_Vld => Dma_Resp_Vld,	Dma_Resp_Rdy => Dma_Resp_Rdy);
		ApplyDmaRespAuto(	Stream => 2, Trigger => '0',
							Clk	=> Clk,	Dma_Resp => Dma_Resp, Dma_Resp_Vld => Dma_Resp_Vld,	Dma_Resp_Rdy => Dma_Resp_Rdy);	
		ApplyDmaRespAuto(	Stream => 2, Trigger => '0',
							Clk	=> Clk,	Dma_Resp => Dma_Resp, Dma_Resp_Vld => Dma_Resp_Vld,	Dma_Resp_Rdy => Dma_Resp_Rdy);	
		--> Finished by trigger
		ApplyDmaRespAuto(	Stream => 2, Trigger => '1',
							Clk	=> Clk,	Dma_Resp => Dma_Resp, Dma_Resp_Vld => Dma_Resp_Vld,	Dma_Resp_Rdy => Dma_Resp_Rdy);
		--> Next window on trigger
		ApplyDmaRespAuto(	Stream => 2, Trigger => '0',
							Clk	=> Clk,	Dma_Resp => Dma_Resp, Dma_Resp_Vld => Dma_Resp_Vld,	Dma_Resp_Rdy => Dma_Resp_Rdy);		
		ProcDone(1)	:= '1';		
		
		-- Ringbuf with overwrite
		WaitForCase(1,  Clk);
		ApplyDmaRespAuto(	Stream => 2, Trigger => '0',
							Clk	=> Clk,	Dma_Resp => Dma_Resp, Dma_Resp_Vld => Dma_Resp_Vld,	Dma_Resp_Rdy => Dma_Resp_Rdy);
		ApplyDmaRespAuto(	Stream => 2, Trigger => '0',
							Clk	=> Clk,	Dma_Resp => Dma_Resp, Dma_Resp_Vld => Dma_Resp_Vld,	Dma_Resp_Rdy => Dma_Resp_Rdy);
		ApplyDmaRespAuto(	Stream => 2, Trigger => '0',
							Clk	=> Clk,	Dma_Resp => Dma_Resp, Dma_Resp_Vld => Dma_Resp_Vld,	Dma_Resp_Rdy => Dma_Resp_Rdy);	
		ApplyDmaRespAuto(	Stream => 2, Trigger => '0',
							Clk	=> Clk,	Dma_Resp => Dma_Resp, Dma_Resp_Vld => Dma_Resp_Vld,	Dma_Resp_Rdy => Dma_Resp_Rdy);	
		--> Finished by trigger
		ApplyDmaRespAuto(	Stream => 2, Trigger => '1',
							Clk	=> Clk,	Dma_Resp => Dma_Resp, Dma_Resp_Vld => Dma_Resp_Vld,	Dma_Resp_Rdy => Dma_Resp_Rdy);
		--> Next window on trigger
		ApplyDmaRespAuto(	Stream => 2, Trigger => '0',
							Clk	=> Clk,	Dma_Resp => Dma_Resp, Dma_Resp_Vld => Dma_Resp_Vld,	Dma_Resp_Rdy => Dma_Resp_Rdy);		
		ProcDone(1)	:= '1';	

		-- Linear without overwrite, no trigger
		WaitForCase(2,  Clk);
		ApplyDmaRespAuto(	Stream => 2, Trigger => '0',
							Clk	=> Clk,	Dma_Resp => Dma_Resp, Dma_Resp_Vld => Dma_Resp_Vld,	Dma_Resp_Rdy => Dma_Resp_Rdy);
		ApplyDmaRespAuto(	Stream => 2, Trigger => '0',
							Clk	=> Clk,	Dma_Resp => Dma_Resp, Dma_Resp_Vld => Dma_Resp_Vld,	Dma_Resp_Rdy => Dma_Resp_Rdy);
		ApplyDmaRespAuto(	Stream => 2, Trigger => '0',
							Clk	=> Clk,	Dma_Resp => Dma_Resp, Dma_Resp_Vld => Dma_Resp_Vld,	Dma_Resp_Rdy => Dma_Resp_Rdy);			
		ProcDone(1)	:= '1';
		
		-- Linear without overwrite, trigger
		WaitForCase(3,  Clk);
		ApplyDmaRespAuto(	Stream => 2, Trigger => '1',
							Clk	=> Clk,	Dma_Resp => Dma_Resp, Dma_Resp_Vld => Dma_Resp_Vld,	Dma_Resp_Rdy => Dma_Resp_Rdy);
		ApplyDmaRespAuto(	Stream => 2, Trigger => '0',
							Clk	=> Clk,	Dma_Resp => Dma_Resp, Dma_Resp_Vld => Dma_Resp_Vld,	Dma_Resp_Rdy => Dma_Resp_Rdy);			
		ProcDone(1)	:= '1';		
		
		-- Ringbuf without overwrite
		WaitForCase(4,  Clk);
		ApplyDmaRespAuto(	Stream => 2, Trigger => '0',
							Clk	=> Clk,	Dma_Resp => Dma_Resp, Dma_Resp_Vld => Dma_Resp_Vld,	Dma_Resp_Rdy => Dma_Resp_Rdy);
		ApplyDmaRespAuto(	Stream => 2, Trigger => '0',
							Clk	=> Clk,	Dma_Resp => Dma_Resp, Dma_Resp_Vld => Dma_Resp_Vld,	Dma_Resp_Rdy => Dma_Resp_Rdy);
		ApplyDmaRespAuto(	Stream => 2, Trigger => '1',
							Clk	=> Clk,	Dma_Resp => Dma_Resp, Dma_Resp_Vld => Dma_Resp_Vld,	Dma_Resp_Rdy => Dma_Resp_Rdy);		
		ApplyDmaRespAuto(	Stream => 2, Trigger => '0',
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
		-- Linear write with Overwrite	
		WaitForCase(0, Clk);
		ExpCtxFullBurstAuto(	Stream => 2 ,Msg => "Wr0.0",
								Clk => Clk, CtxStr_Cmd => CtxStr_Cmd, CtxStr_Resp => CtxStr_Resp, CtxWin_Cmd => CtxWin_Cmd, CtxWin_Resp => CtxWin_Resp);
		ExpCtxFullBurstAuto(	Stream => 2, NextWin => true, Msg => "Wr0.1",
								Clk => Clk, CtxStr_Cmd => CtxStr_Cmd, CtxStr_Resp => CtxStr_Resp, CtxWin_Cmd => CtxWin_Cmd, CtxWin_Resp => CtxWin_Resp);
		ExpCtxFullBurstAuto(	Stream => 2,  Msg => "Wr1.0",
								Clk => Clk, CtxStr_Cmd => CtxStr_Cmd, CtxStr_Resp => CtxStr_Resp, CtxWin_Cmd => CtxWin_Cmd, CtxWin_Resp => CtxWin_Resp);
		ExpCtxFullBurstAuto(	Stream => 2, NextWin => true, Msg => "Wr1.1",
								Clk => Clk, CtxStr_Cmd => CtxStr_Cmd, CtxStr_Resp => CtxStr_Resp, CtxWin_Cmd => CtxWin_Cmd, CtxWin_Resp => CtxWin_Resp);
		ExpCtxFullBurstAuto(	Stream => 2, NextWin => true, IsTrig => true, Msg => "Wr2.0",
								Clk => Clk, CtxStr_Cmd => CtxStr_Cmd, CtxStr_Resp => CtxStr_Resp, CtxWin_Cmd => CtxWin_Cmd, CtxWin_Resp => CtxWin_Resp);	
		ExpCtxFullBurstAuto(	Stream => 2,  Msg => "Wr3.0",
								Clk => Clk, CtxStr_Cmd => CtxStr_Cmd, CtxStr_Resp => CtxStr_Resp, CtxWin_Cmd => CtxWin_Cmd, CtxWin_Resp => CtxWin_Resp);								
		ProcDone(0)	:= '1';	
		
		-- Ringbuf with overwrite
		WaitForCase(1, Clk);
		ExpCtxFullBurstAuto(	Stream => 2 ,Msg => "Wr0.0",
								Clk => Clk, CtxStr_Cmd => CtxStr_Cmd, CtxStr_Resp => CtxStr_Resp, CtxWin_Cmd => CtxWin_Cmd, CtxWin_Resp => CtxWin_Resp);
		ExpCtxFullBurstAuto(	Stream => 2, NextWin => true, Msg => "Wr0.1",
								Clk => Clk, CtxStr_Cmd => CtxStr_Cmd, CtxStr_Resp => CtxStr_Resp, CtxWin_Cmd => CtxWin_Cmd, CtxWin_Resp => CtxWin_Resp);
		ExpCtxFullBurstAuto(	Stream => 2,  Msg => "Wr1.0",
								Clk => Clk, CtxStr_Cmd => CtxStr_Cmd, CtxStr_Resp => CtxStr_Resp, CtxWin_Cmd => CtxWin_Cmd, CtxWin_Resp => CtxWin_Resp);
		ExpCtxFullBurstAuto(	Stream => 2, NextWin => true, Msg => "Wr1.1",
								Clk => Clk, CtxStr_Cmd => CtxStr_Cmd, CtxStr_Resp => CtxStr_Resp, CtxWin_Cmd => CtxWin_Cmd, CtxWin_Resp => CtxWin_Resp);
		ExpCtxFullBurstAuto(	Stream => 2, NextWin => true, IsTrig => true, Msg => "Wr2.0",
								Clk => Clk, CtxStr_Cmd => CtxStr_Cmd, CtxStr_Resp => CtxStr_Resp, CtxWin_Cmd => CtxWin_Cmd, CtxWin_Resp => CtxWin_Resp);	
		ExpCtxFullBurstAuto(	Stream => 2,  Msg => "Wr3.0",
								Clk => Clk, CtxStr_Cmd => CtxStr_Cmd, CtxStr_Resp => CtxStr_Resp, CtxWin_Cmd => CtxWin_Cmd, CtxWin_Resp => CtxWin_Resp);								
		ProcDone(0)	:= '1';		
		
		-- Linear without overwrite, no trigger
		WaitForCase(2, Clk);
		ExpCtxFullBurstAuto(	Stream => 2 ,Msg => "Wr0.0",
								Clk => Clk, CtxStr_Cmd => CtxStr_Cmd, CtxStr_Resp => CtxStr_Resp, CtxWin_Cmd => CtxWin_Cmd, CtxWin_Resp => CtxWin_Resp);
		ExpCtxFullBurstAuto(	Stream => 2, NextWin => true, Msg => "Wr0.1",
								Clk => Clk, CtxStr_Cmd => CtxStr_Cmd, CtxStr_Resp => CtxStr_Resp, CtxWin_Cmd => CtxWin_Cmd, CtxWin_Resp => CtxWin_Resp);
		ExpCtxReadAuto(		Stream => 2, Msg => "SW not ready 0",
							Clk => Clk, CtxStr_Cmd => CtxStr_Cmd, CtxStr_Resp => CtxStr_Resp, CtxWin_Cmd => CtxWin_Cmd, CtxWin_Resp => CtxWin_Resp);
		ExpCtxReadAuto(		Stream => 2, Msg => "SW not ready 1",
							Clk => Clk, CtxStr_Cmd => CtxStr_Cmd, CtxStr_Resp => CtxStr_Resp, CtxWin_Cmd => CtxWin_Cmd, CtxWin_Resp => CtxWin_Resp);		
		SplsWinStr_v(2)(0) := 0;
		ExpCtxFullBurstAuto(	Stream => 2 ,Msg => "SW ready",
								Clk => Clk, CtxStr_Cmd => CtxStr_Cmd, CtxStr_Resp => CtxStr_Resp, CtxWin_Cmd => CtxWin_Cmd, CtxWin_Resp => CtxWin_Resp);									
		ProcDone(0)	:= '1';	
		
		-- Linear without overwrite, trigger
		WaitForCase(3, Clk);
		ExpCtxFullBurstAuto(	Stream => 2, NextWin => true, IsTrig => true, Msg => "Wr0.0",
								Clk => Clk, CtxStr_Cmd => CtxStr_Cmd, CtxStr_Resp => CtxStr_Resp, CtxWin_Cmd => CtxWin_Cmd, CtxWin_Resp => CtxWin_Resp);
		ExpCtxReadAuto(		Stream => 2, Msg => "SW not ready 0",
							Clk => Clk, CtxStr_Cmd => CtxStr_Cmd, CtxStr_Resp => CtxStr_Resp, CtxWin_Cmd => CtxWin_Cmd, CtxWin_Resp => CtxWin_Resp);
		ExpCtxReadAuto(		Stream => 2, Msg => "SW not ready 1",
							Clk => Clk, CtxStr_Cmd => CtxStr_Cmd, CtxStr_Resp => CtxStr_Resp, CtxWin_Cmd => CtxWin_Cmd, CtxWin_Resp => CtxWin_Resp);		
		SplsWinStr_v(2)(0) := 0;
		ExpCtxFullBurstAuto(	Stream => 2 ,Msg => "SW ready",
								Clk => Clk, CtxStr_Cmd => CtxStr_Cmd, CtxStr_Resp => CtxStr_Resp, CtxWin_Cmd => CtxWin_Cmd, CtxWin_Resp => CtxWin_Resp);									
		ProcDone(0)	:= '1';			
		
		-- Ringbuf without overwrite
		WaitForCase(4, Clk);
		ExpCtxFullBurstAuto(	Stream => 2 ,Msg => "Wr0.0",
								Clk => Clk, CtxStr_Cmd => CtxStr_Cmd, CtxStr_Resp => CtxStr_Resp, CtxWin_Cmd => CtxWin_Cmd, CtxWin_Resp => CtxWin_Resp);
		ExpCtxFullBurstAuto(	Stream => 2, Msg => "Wr0.1",
								Clk => Clk, CtxStr_Cmd => CtxStr_Cmd, CtxStr_Resp => CtxStr_Resp, CtxWin_Cmd => CtxWin_Cmd, CtxWin_Resp => CtxWin_Resp);
		ExpCtxFullBurstAuto(	Stream => 2, Msg => "Wr0.3", NextWin => true, IsTrig => true,
								Clk => Clk, CtxStr_Cmd => CtxStr_Cmd, CtxStr_Resp => CtxStr_Resp, CtxWin_Cmd => CtxWin_Cmd, CtxWin_Resp => CtxWin_Resp);	
		ExpCtxReadAuto(		Stream => 2, Msg => "SW not ready 0",
							Clk => Clk, CtxStr_Cmd => CtxStr_Cmd, CtxStr_Resp => CtxStr_Resp, CtxWin_Cmd => CtxWin_Cmd, CtxWin_Resp => CtxWin_Resp);
		ExpCtxReadAuto(		Stream => 2, Msg => "SW not ready 1",
							Clk => Clk, CtxStr_Cmd => CtxStr_Cmd, CtxStr_Resp => CtxStr_Resp, CtxWin_Cmd => CtxWin_Cmd, CtxWin_Resp => CtxWin_Resp);	
		SplsWinStr_v(2)(0) := 0;
		ExpCtxFullBurstAuto(	Stream => 2 ,Msg => "SW ready",
								Clk => Clk, CtxStr_Cmd => CtxStr_Cmd, CtxStr_Resp => CtxStr_Resp, CtxWin_Cmd => CtxWin_Cmd, CtxWin_Resp => CtxWin_Resp);									
		ProcDone(0)	:= '1';			
		
		
		-- Ringbuf with odd framesize
	end procedure;
	
end;
