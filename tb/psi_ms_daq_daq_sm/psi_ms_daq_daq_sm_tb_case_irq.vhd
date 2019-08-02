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
package psi_ms_daq_daq_sm_tb_case_irq is
	
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
package body psi_ms_daq_daq_sm_tb_case_irq is
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
		print(">> -- irq --");	
		
		-- Normal Order
		print(">> Normal Order");
		InitTestCase(Clk, Rst);
		TestCase := 0;
		ConfigureAuto(	WinSize => 4096, Ringbuf => '0', Overwrite => '1', Wincnt => 2, Wincur => 0);	
		Inp_Level(0) <= LvlThreshold_c;		
		wait until rising_edge(Clk) and Dma_Cmd_Vld = '1';
		Inp_Level(0) <= (others => '0');
		ControlWaitCompl(Clk);			
		
		-- Flipped Order
		print(">> Flipped Order");
		InitTestCase(Clk, Rst);
		TestCase := 1;
		ConfigureAuto(	WinSize => 4096, Ringbuf => '0', Overwrite => '1', Wincnt => 2, Wincur => 0);	
		Inp_Level(0) <= LvlThreshold_c;		
		wait until rising_edge(Clk) and Dma_Cmd_Vld = '1';
		Inp_Level(0) <= (others => '0');
		ControlWaitCompl(Clk);			
		
		-- IRQ FIFO full
		-- ... FIFO is full after Streams (4) x 3 = 12 open transfers
		print(">> IRQ FIFO full");
		InitTestCase(Clk, Rst);
		TestCase := 2;
		ConfigureAuto(	WinSize => 4096, Ringbuf => '0', Overwrite => '1', Wincnt => 2, Wincur => 0);	
		Inp_Level(0) <= LvlThreshold_c;	
		-- Fill FIFO
		for i in 0 to 11 loop
			wait until rising_edge(Clk) and Dma_Cmd_Vld = '1';
		end loop;
		-- Checked transfer
		wait until rising_edge(Clk) and Dma_Cmd_Vld = '1';
		Inp_Level(0) <= (others => '0');
		ControlWaitCompl(Clk);		

		-- Multi-Stream
		wait for 1 us;
		print(">> Multi-Stream");
		InitTestCase(Clk, Rst);
		TestCase := 3;
		ConfigureAuto(	WinSize => 4096, Ringbuf => '0', Overwrite => '1', Wincnt => 2, Wincur => 0);	
		for i in 3 downto 0 loop
			Inp_Level(i) <= LvlThreshold_c;	
			wait until rising_edge(Clk) and Dma_Cmd_Vld = '1';			
			Inp_Level(i) <= (others => '0');
			wait for 200 ns;
		end loop;
		ControlWaitCompl(Clk);			
		
		-- Win-Change without trigger
		wait for 1 us;
		print(">> Win-Change without trigger");
		InitTestCase(Clk, Rst);
		TestCase := 4;
		ConfigureAuto(	WinSize => 4096*2, Ringbuf => '0', Overwrite => '1', Wincnt => 2, Wincur => 0);	
		Inp_Level(0) <= LvlThreshold_c;		
		wait until rising_edge(Clk) and Dma_Cmd_Vld = '1';
		wait until rising_edge(Clk) and Dma_Cmd_Vld = '1';
		wait until rising_edge(Clk) and Dma_Cmd_Vld = '1';
		Inp_Level(0) <= (others => '0');
		ControlWaitCompl(Clk);	

		-- No IRQ on Ringbuf Wrap
		print(">> No IRQ on Ringbuf Wrap");
		InitTestCase(Clk, Rst);
		TestCase := 5;
		ConfigureAuto(	WinSize => 4096*2, Ringbuf => '1', Overwrite => '1', Wincnt => 2, Wincur => 0);	
		Inp_Level(0) <= LvlThreshold_c;		
		wait until rising_edge(Clk) and Dma_Cmd_Vld = '1';
		wait until rising_edge(Clk) and Dma_Cmd_Vld = '1';
		wait until rising_edge(Clk) and Dma_Cmd_Vld = '1';
		Inp_Level(0) <= (others => '0');
		ControlWaitCompl(Clk);		
		
	end procedure;
	
	procedure dma_cmd (
		signal Clk : in std_logic;
		signal StrIrq : in std_logic_vector;
		signal Dma_Cmd : in DaqSm2DaqDma_Cmd_t;
		signal Dma_Cmd_Vld : in std_logic;
		constant Generics_c : Generics_t) is
	begin
		-- Normal Order
		WaitForCase(0,  Clk);
		ExpectDmaCmdAuto(	Stream	=> 0, MaxSize => 4096, ExeSize=> 512, Msg => "Wr0.0",
							Clk	=> Clk,	Dma_Cmd	=> Dma_Cmd,	Dma_Vld	=> Dma_Cmd_Vld);
		ProcDone(2)	:= '1';			
		
		-- Flipped Order
		WaitForCase(1,  Clk);
		ExpectDmaCmdAuto(	Stream	=> 0, MaxSize => 4096, ExeSize=> 512, Msg => "Wr0.0",
							Clk	=> Clk,	Dma_Cmd	=> Dma_Cmd,	Dma_Vld	=> Dma_Cmd_Vld);
		ProcDone(2)	:= '1';			
		
		-- IRQ FIFO full
		WaitForCase(2,  Clk);
		-- Fill FIFO
		for i in 0 to 11 loop
			ExpectDmaCmdAuto(	Stream	=> 0, MaxSize => 4096, ExeSize=> 512, Msg => "Wr" & to_string(i), NextWin => true,
								Clk	=> Clk,	Dma_Cmd	=> Dma_Cmd,	Dma_Vld	=> Dma_Cmd_Vld);
		end loop;
		-- Checked transfer
		CheckNoActivity(Dma_Cmd_Vld, 1 us, 0, "Full");
		ExpectDmaCmdAuto(	Stream	=> 0, MaxSize => 4096, ExeSize=> 512, Msg => "Wr12", NextWin => true,
							Clk	=> Clk,	Dma_Cmd	=> Dma_Cmd,	Dma_Vld	=> Dma_Cmd_Vld);
		ProcDone(2)	:= '1';	
		
		-- Multi-Stream
		WaitForCase(3,  Clk);
		for i in 3 downto 0 loop
			ExpectDmaCmdAuto(	Stream	=> i, MaxSize => 4096, ExeSize=> 512*(i+1), Msg => "Wr" & to_string(i), NextWin => true,
								Clk	=> Clk,	Dma_Cmd	=> Dma_Cmd,	Dma_Vld	=> Dma_Cmd_Vld);		
		end loop;
		ProcDone(2)	:= '1';	
		
		-- Win-Change without trigger
		WaitForCase(4,  Clk);
		ExpectDmaCmdAuto(	Stream	=> 0, MaxSize => 4096, Msg => "Wr0",
							Clk	=> Clk,	Dma_Cmd	=> Dma_Cmd,	Dma_Vld	=> Dma_Cmd_Vld);	
		ExpectDmaCmdAuto(	Stream	=> 0, MaxSize => 4096, Msg => "Wr0", NextWin => true,
							Clk	=> Clk,	Dma_Cmd	=> Dma_Cmd,	Dma_Vld	=> Dma_Cmd_Vld);	
		ExpectDmaCmdAuto(	Stream	=> 0, MaxSize => 4096, Msg => "Wr0",
							Clk	=> Clk,	Dma_Cmd	=> Dma_Cmd,	Dma_Vld	=> Dma_Cmd_Vld);								
		ProcDone(2)	:= '1';	
		
		-- No IRQ on Ringbuf Wrap
		WaitForCase(5,  Clk);
		ExpectDmaCmdAuto(	Stream	=> 0, MaxSize => 4096, Msg => "Wr0",
							Clk	=> Clk,	Dma_Cmd	=> Dma_Cmd,	Dma_Vld	=> Dma_Cmd_Vld);	
		ExpectDmaCmdAuto(	Stream	=> 0, MaxSize => 4096, Msg => "Wr0", 
							Clk	=> Clk,	Dma_Cmd	=> Dma_Cmd,	Dma_Vld	=> Dma_Cmd_Vld);	
		ExpectDmaCmdAuto(	Stream	=> 0, MaxSize => 4096, Msg => "Wr0",
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
		-- Normal Order
		WaitForCase(0,  Clk);
		ApplyDmaRespAuto(	Stream => 0, Trigger => '1',
							Clk	=> Clk,	Dma_Resp => Dma_Resp, Dma_Resp_Vld => Dma_Resp_Vld,	Dma_Resp_Rdy => Dma_Resp_Rdy);	
		wait for 200 ns;
		StdlvCompareStdlv ("0000", StrIrq, "IRQs asserted unexpectedly");
		assert StrIrq'last_event > 200 ns report "###ERROR###: IRQs not idle" severity error;
		AssertTfDone(Clk, TfDone);
		CheckIrq(MaxWait => (1 us), Stream => 0, LastWin => 0, Clk => Clk, StrIrq => StrIrq, StrLastWin => StrLastWin);	
		ProcDone(1)	:= '1';	
		
		-- Flipped Order
		WaitForCase(1,  Clk);
		AssertTfDone(Clk, TfDone);
		wait for 200 ns;
		StdlvCompareStdlv ("0000", StrIrq, "IRQs asserted unexpectedly");
		assert StrIrq'last_event > 200 ns report "###ERROR###: IRQs not idle" severity error;
		ApplyDmaRespAuto(	Stream => 0, Trigger => '1',
							Clk	=> Clk,	Dma_Resp => Dma_Resp, Dma_Resp_Vld => Dma_Resp_Vld,	Dma_Resp_Rdy => Dma_Resp_Rdy);		
		CheckIrq(MaxWait => (1 us), Stream => 0, LastWin => 0, Clk => Clk, StrIrq => StrIrq, StrLastWin => StrLastWin);		
		ProcDone(1)	:= '1';			
		
		-- IRQ FIFO full
		WaitForCase(2,  Clk);
		-- Fill FIFO
		for i in 0 to 11 loop
			ApplyDmaRespAuto(	Stream => 0, Trigger => '1',
								Clk	=> Clk,	Dma_Resp => Dma_Resp, Dma_Resp_Vld => Dma_Resp_Vld,	Dma_Resp_Rdy => Dma_Resp_Rdy);	
		end loop;
		-- Wait
		wait for 1.1 us;
		-- Send IRQs
		for i in 0 to 11 loop
			AssertTfDone(Clk, TfDone);
			CheckIrq(MaxWait => (1 us), Stream => 0, LastWin => i mod 3, Clk => Clk, StrIrq => StrIrq, StrLastWin => StrLastWin);		
		end loop;
		-- Last transfer
		ApplyDmaRespAuto(	Stream => 0, Trigger => '1',
							Clk	=> Clk,	Dma_Resp => Dma_Resp, Dma_Resp_Vld => Dma_Resp_Vld,	Dma_Resp_Rdy => Dma_Resp_Rdy);	
		AssertTfDone(Clk, TfDone);
		CheckIrq(MaxWait => (1 us), Stream => 0, LastWin => 0, Clk => Clk, StrIrq => StrIrq, StrLastWin => StrLastWin);			
		ProcDone(1)	:= '1';	
		
		-- Multi-Stream
		WaitForCase(3,  Clk);
		for i in 3 downto 0 loop
			ApplyDmaRespAuto(	Stream => i, Trigger => '1',
								Clk	=> Clk,	Dma_Resp => Dma_Resp, Dma_Resp_Vld => Dma_Resp_Vld,	Dma_Resp_Rdy => Dma_Resp_Rdy);	
		end loop;
		for i in 3 downto 0 loop
			AssertTfDone(Clk, TfDone);
			CheckIrq(MaxWait => (1 us), Stream => i, LastWin => 0, Clk => Clk, StrIrq => StrIrq, StrLastWin => StrLastWin);	
		end loop;		
		ProcDone(1)	:= '1';	
		
		-- Win-Change without trigger
		WaitForCase(4,  Clk);
		wait for 100 ns;
		ApplyDmaRespAuto(	Stream => 0, Trigger => '0',
							Clk	=> Clk,	Dma_Resp => Dma_Resp, Dma_Resp_Vld => Dma_Resp_Vld,	Dma_Resp_Rdy => Dma_Resp_Rdy);		
		AssertTfDone(Clk, TfDone);
		CheckNoActivityStlv(StrIrq, 100 ns, 0, "Before Window Change");
		wait for 100 ns;
		ApplyDmaRespAuto(	Stream => 0, Trigger => '0',
							Clk	=> Clk,	Dma_Resp => Dma_Resp, Dma_Resp_Vld => Dma_Resp_Vld,	Dma_Resp_Rdy => Dma_Resp_Rdy);	
		AssertTfDone(Clk, TfDone);
		CheckIrq(MaxWait => (1 us), Stream => 0, LastWin => 0, Clk => Clk, StrIrq => StrIrq, StrLastWin => StrLastWin);		
		wait for 100 ns;
		ApplyDmaRespAuto(	Stream => 0, Trigger => '0',
							Clk	=> Clk,	Dma_Resp => Dma_Resp, Dma_Resp_Vld => Dma_Resp_Vld,	Dma_Resp_Rdy => Dma_Resp_Rdy);
		AssertTfDone(Clk, TfDone);
		CheckNoActivityStlv(StrIrq, 100 ns, 0, "After Window Change");
		ProcDone(1)	:= '1';	
		
		-- No IRQ on Ringbuf Wrap
		WaitForCase(5,  Clk);
		wait for 100 ns;
		ApplyDmaRespAuto(	Stream => 0, Trigger => '0',
							Clk	=> Clk,	Dma_Resp => Dma_Resp, Dma_Resp_Vld => Dma_Resp_Vld,	Dma_Resp_Rdy => Dma_Resp_Rdy);		
		AssertTfDone(Clk, TfDone);
		CheckNoActivityStlv(StrIrq, 100 ns, 0, "Before Wrap");
		wait for 100 ns;
		ApplyDmaRespAuto(	Stream => 0, Trigger => '0',
							Clk	=> Clk,	Dma_Resp => Dma_Resp, Dma_Resp_Vld => Dma_Resp_Vld,	Dma_Resp_Rdy => Dma_Resp_Rdy);	
		AssertTfDone(Clk, TfDone);
		CheckNoActivityStlv(StrIrq, 100 ns, 0, "Wrap");
		wait for 100 ns;
		ApplyDmaRespAuto(	Stream => 0, Trigger => '0',
							Clk	=> Clk,	Dma_Resp => Dma_Resp, Dma_Resp_Vld => Dma_Resp_Vld,	Dma_Resp_Rdy => Dma_Resp_Rdy);
		AssertTfDone(Clk, TfDone);
		CheckNoActivityStlv(StrIrq, 100 ns, 0, "After Wrap");
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
		-- Normal Order
		WaitForCase(0, Clk);
		ExpCtxFullBurstAuto(	Stream => 0, Msg => "Wr0.0", NextWin => true, IsTrig => true,
								Clk => Clk, CtxStr_Cmd => CtxStr_Cmd, CtxStr_Resp => CtxStr_Resp, CtxWin_Cmd => CtxWin_Cmd, CtxWin_Resp => CtxWin_Resp);								
		ProcDone(0)	:= '1';			
		
		-- Flipped Order
		WaitForCase(1, Clk);
		ExpCtxFullBurstAuto(	Stream => 0, Msg => "Wr0.0", NextWin => true, IsTrig => true,
								Clk => Clk, CtxStr_Cmd => CtxStr_Cmd, CtxStr_Resp => CtxStr_Resp, CtxWin_Cmd => CtxWin_Cmd, CtxWin_Resp => CtxWin_Resp);								
		ProcDone(0)	:= '1';			
		
		-- IRQ FIFO full
		WaitForCase(2, Clk);
		for i in 0 to 11 loop
			ExpCtxFullBurstAuto(	Stream => 0, NextWin => true, IsTrig => true,
								Clk => Clk, CtxStr_Cmd => CtxStr_Cmd, CtxStr_Resp => CtxStr_Resp, CtxWin_Cmd => CtxWin_Cmd, CtxWin_Resp => CtxWin_Resp);
		end loop;
		ExpCtxFullBurstAuto(	Stream => 0, NextWin => true, IsTrig => true,
								Clk => Clk, CtxStr_Cmd => CtxStr_Cmd, CtxStr_Resp => CtxStr_Resp, CtxWin_Cmd => CtxWin_Cmd, CtxWin_Resp => CtxWin_Resp);
		ProcDone(0)	:= '1';
		
		-- Multi-Stream
		WaitForCase(3, Clk);
		for i in 3 downto 0 loop
			ExpCtxFullBurstAuto(	Stream => i, NextWin => true, IsTrig => true,
									Clk => Clk, CtxStr_Cmd => CtxStr_Cmd, CtxStr_Resp => CtxStr_Resp, CtxWin_Cmd => CtxWin_Cmd, CtxWin_Resp => CtxWin_Resp);	
		end loop;
		ProcDone(0)	:= '1';			
		
		-- Win-Change without trigger
		WaitForCase(4, Clk);
		ExpCtxFullBurstAuto(	Stream => 0, Msg => "Wr0.0", 
								Clk => Clk, CtxStr_Cmd => CtxStr_Cmd, CtxStr_Resp => CtxStr_Resp, CtxWin_Cmd => CtxWin_Cmd, CtxWin_Resp => CtxWin_Resp);
		ExpCtxFullBurstAuto(	Stream => 0, Msg => "Wr0.1", NextWin => true,
								Clk => Clk, CtxStr_Cmd => CtxStr_Cmd, CtxStr_Resp => CtxStr_Resp, CtxWin_Cmd => CtxWin_Cmd, CtxWin_Resp => CtxWin_Resp);
		ExpCtxFullBurstAuto(	Stream => 0, Msg => "Wr1.0",
								Clk => Clk, CtxStr_Cmd => CtxStr_Cmd, CtxStr_Resp => CtxStr_Resp, CtxWin_Cmd => CtxWin_Cmd, CtxWin_Resp => CtxWin_Resp);								
		ProcDone(0)	:= '1';	
		
		-- No IRQ on Ringbuf Wrap
		WaitForCase(5, Clk);
		ExpCtxFullBurstAuto(	Stream => 0, Msg => "Wr0.0", 
								Clk => Clk, CtxStr_Cmd => CtxStr_Cmd, CtxStr_Resp => CtxStr_Resp, CtxWin_Cmd => CtxWin_Cmd, CtxWin_Resp => CtxWin_Resp);
		ExpCtxFullBurstAuto(	Stream => 0, Msg => "Wr0.1", 
								Clk => Clk, CtxStr_Cmd => CtxStr_Cmd, CtxStr_Resp => CtxStr_Resp, CtxWin_Cmd => CtxWin_Cmd, CtxWin_Resp => CtxWin_Resp);
		ExpCtxFullBurstAuto(	Stream => 0, Msg => "Wr0.2",
								Clk => Clk, CtxStr_Cmd => CtxStr_Cmd, CtxStr_Resp => CtxStr_Resp, CtxWin_Cmd => CtxWin_Cmd, CtxWin_Resp => CtxWin_Resp);								
		ProcDone(0)	:= '1';			
		
	end procedure;
	
end;
