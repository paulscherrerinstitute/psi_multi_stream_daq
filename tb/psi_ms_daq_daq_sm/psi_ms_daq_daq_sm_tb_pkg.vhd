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
	use work.psi_tb_txt_util.all;
	use work.psi_tb_compare_pkg.all;

------------------------------------------------------------
-- Package Header
------------------------------------------------------------
package psi_ms_daq_daq_sm_tb_pkg is
	
	-- *** Generics Record ***
	type Generics_t is record
		Dummy : boolean; -- required since empty records are not allowed
	end record;
	
	------------------------------------------------------------
	-- Not exported Generics
	------------------------------------------------------------
	constant MaxBurstSize_g : positive := 512;
	constant StreamPrio_g : t_ainteger := (1, 2, 3, 1);
	constant StreamWidth_g : t_ainteger := (8, 16, 32, 64);
	constant MinBurstSize_g : positive := 512;
	constant Windows_g : positive := 8;
	constant Streams_g : positive := 4;
	
	------------------------------------------------------------
	-- Handwritten constants and variables
	------------------------------------------------------------
	constant Size4k_c			: positive := 4096;
	constant DataWidth_c 		: positive := 64;
	constant DataWidthBytes_c	: positive := DataWidth_c/8;
	constant LvlThreshold_c		: std_logic_vector(15 downto 0) := std_logic_vector(to_unsigned(Size4k_c/DataWidthBytes_c, 16));
	
	shared variable TestCase	: integer	:= -1;
	shared variable ProcDone	: std_logic_vector(0 to 2) := "000";
	constant AllDone			: std_logic_vector(ProcDone'range)	:= (others => '1');
	
	------------------------------------------------------------
	-- Test Case Control
	------------------------------------------------------------
	procedure InitTestCase(	signal	Clk			: in	std_logic;
							signal	Rst			: out	std_logic);
	
	procedure FinishTestCase;
	
	procedure ControlWaitCompl(	signal	Clk			: in	std_logic);
	
	procedure WaitForCase(			SubCase		: in	integer;
							signal	Clk			: in	std_logic);
													
	------------------------------------------------------------
	-- Low Level Test Functions
	------------------------------------------------------------
	shared variable DmaCmdOpen	: integer	:= 0;
	type CheckTs_t is (CheckWritten, CheckNotWritten, DontCheck);
	
	procedure ExpCtxRead(			Stream		: in	integer;
									BufStart 	: in 	integer		:= 16#01230000#;
									WinSize		: in	integer		:= 16#00100000#;
									Ptr			: in	integer		:= 16#01238000#;
									Ringbuf		: in	std_logic	:= '0';
									Overwrite	: in	std_logic	:= '0';
									Wincnt		: in	integer		:= 2;
									Wincur		: in	integer		:= 0;
									WinSel		: in	integer		:= -1;
									SamplesWin	: in 	integer;
									WinIsTrig	: in	boolean		:= false;
							signal 	Clk			: in	std_logic;
							signal 	CtxStr_Cmd	: in	ToCtxStr_t;
							signal 	CtxStr_Resp	: out	FromCtx_t;
							signal 	CtxWin_Cmd	: in	ToCtxWin_t;
							signal 	CtxWin_Resp : out	FromCtx_t;
									Msg			: in	string		:= "");
							
	procedure ExpCtxWrite(			Stream		: in	integer;
									BufStart 	: in 	integer		:= 16#01230000#;
									WinSize		: in	integer		:= 16#00100000#;
									Ptr			: in	integer		:= 16#01238000#;
									Ringbuf		: in	std_logic	:= '0';
									Overwrite	: in	std_logic	:= '0';
									Wincnt		: in	integer		:= 2;
									Wincur		: in	integer		:= 0;
									WinNext		: in	integer		:= -1;
									SamplesWin	: in 	integer;
									WinIsTrig	: in	boolean		:= false;
									WinLast		: in	integer;
									WriteTs		: in	CheckTs_t	:= DontCheck;
									Timstamp	: in	std_logic_vector(63 downto 0)	:= (others => 'X');
							signal 	Clk			: in	std_logic;
							signal 	CtxStr_Cmd	: in	ToCtxStr_t;
							signal 	CtxWin_Cmd	: in	ToCtxWin_t;
									Msg			: in	string		:= "");
							
	procedure ExpCtxUpdate(				Stream				: in	integer;
										TfSize				: in	integer;	-- in bytes
										NextWin				: in	boolean		:= false;
										IsTrig				: in	boolean		:= false;
										BufStart 			: in 	integer		:= 16#01230000#;
										WinSize				: in	integer		:= 16#00100000#;
										PtrBefore			: in	integer		:= 16#01238000#;
										Ringbuf				: in	std_logic	:= '0';
										Overwrite			: in	std_logic	:= '0';
										Wincnt				: in	integer		:= 2;
										Wincur				: in	integer		:= 0;
										SamplesWinBefore	: in 	integer;
										WriteTs				: in	CheckTs_t	:= DontCheck;
										Timstamp			: in	std_logic_vector(63 downto 0)	:= (others => 'X');
							variable	PtrAfter			: out	integer;
							signal 		Clk					: in	std_logic;
							signal 		CtxStr_Cmd			: in	ToCtxStr_t;
							signal 		CtxStr_Resp			: out	FromCtx_t;
							signal 		CtxWin_Cmd			: in	ToCtxWin_t;
							signal 		CtxWin_Resp			: out	FromCtx_t;
										Msg					: in	string		:= "");		

	procedure ExpCtxFullBurst(			Stream				: in	integer;
										TfSize				: in	integer;	-- in bytes
										NextWin				: in	boolean		:= false;
										BufStart 			: in 	integer		:= 16#01230000#;
										WinSize				: in	integer		:= 16#00100000#;
										PtrBefore			: in	integer		:= 16#01238000#;
										Ringbuf				: in	std_logic	:= '0';
										Overwrite			: in	std_logic	:= '0';
										Wincnt				: in	integer		:= 2;
										Wincur				: in	integer		:= 0;
										SamplesWinBefore	: in 	integer;
										WriteTs				: in	CheckTs_t	:= DontCheck;
										Timstamp			: in	std_logic_vector(63 downto 0)	:= (others => 'X');
							variable	PtrAfter			: out	integer;
							signal 		Clk					: in	std_logic;
							signal 		CtxStr_Cmd			: in	ToCtxStr_t;
							signal 		CtxStr_Resp			: out	FromCtx_t;
							signal 		CtxWin_Cmd			: in	ToCtxWin_t;
							signal 		CtxWin_Resp			: out	FromCtx_t;
										Msg					: in	string		:= "");									
									
	procedure ExpectDmaCmd(			Stream	: in 	integer;
									Address	: in 	integer;
									MaxSize	: in 	integer;
							signal 	Clk		: in	std_logic;
							signal 	Dma_Cmd	: in	DaqSm2DaqDma_Cmd_t;
							signal 	Dma_Vld	: in	std_logic;
									Msg		: in	string		:= "");
	
	-- The DMA response is splilt into "Apply" and "Remove" because the context memory is read in between
	procedure ApplyDmaResp(			Stream 		: in	integer;
									Size 		: in	integer;
									Trigger		: in	std_logic;
									Delay		: in	time		:= 0 ns;
							signal	Clk			: in	std_logic;
							signal Dma_Resp		: out	DaqDma2DaqSm_Resp_t;
							signal Dma_Resp_Vld	: out	std_logic;
							signal Dma_Resp_Rdy	: in	std_logic;
									Msg			: in	string		:= "");
									
									
	procedure AssertTfDone(	signal	Clk			: in	std_logic;
							signal 	TfDone		: out	std_logic);
							
	procedure CheckIrq(			MaxWait			: in	time	:= 1 us;	-- Maximum time to wait for the IRQ
								Stream			: in	integer;
								LastWin			: in	integer;
								Msg				: in	string	:= "";
						signal	Clk				: in	std_logic;
						signal	StrIrq			: in	std_logic_vector(3 downto 0);
						signal	StrLastWin		: in	WinType_a(3 downto 0));
							
	------------------------------------------------------------
	-- High Level (Auto) Functions
	------------------------------------------------------------
	type IntStrWin_t is array (0 to 3) of t_ainteger(0 to 31);
	shared variable PtrStr_v		: t_ainteger(0 to 3);
	shared variable PtrDma_v		: t_ainteger(0 to 3);	
	shared variable SplsWinStr_v	: IntStrWin_t;
	constant BufStart_c				: t_ainteger(0 to 3) := (16#01230000#, 16#02230000#, 16#03230000#, 16#04230000#);
	
	shared variable AutoWinSize_v		: integer;
	shared variable AutoRingbuf_v		: std_logic;
	shared variable AutoOverwrite_v		: std_logic;
	shared variable AutoWincnt_v		: integer;
	shared variable AutoWincur_v		: t_ainteger(0 to 3);
	shared variable AutoAccessSize_v	: t_ainteger(0 to 3);
	
	procedure ExpCtxReadAuto(		Stream		: in	integer;
							signal 	Clk			: in	std_logic;
							signal 	CtxStr_Cmd	: in	ToCtxStr_t;
							signal 	CtxStr_Resp	: out	FromCtx_t;
							signal 	CtxWin_Cmd	: in	ToCtxWin_t;
							signal 	CtxWin_Resp : out	FromCtx_t;
									Msg			: in	string		:= "");
							
	procedure ExpCtxUpdateAuto(			Stream				: in	integer;
										NextWin				: in	boolean		:= false;
										IsTrig				: in	boolean		:= false;
										WriteTs				: in	CheckTs_t	:= DontCheck;
										Timstamp			: in	std_logic_vector(63 downto 0)	:= (others => 'X');
							signal 		Clk					: in	std_logic;
							signal 		CtxStr_Cmd			: in	ToCtxStr_t;
							signal 		CtxStr_Resp			: out	FromCtx_t;
							signal 		CtxWin_Cmd			: in	ToCtxWin_t;
							signal 		CtxWin_Resp			: out	FromCtx_t;
										Msg					: in	string		:= "");	
										
	procedure ExpCtxFullBurstAuto(		Stream				: in	integer;
										NextWin				: in	boolean		:= false;
										IsTrig				: in	boolean		:= false;
										WriteTs				: in	CheckTs_t	:= DontCheck;
										Timstamp			: in	std_logic_vector(63 downto 0)	:= (others => 'X');
							signal 		Clk					: in	std_logic;
							signal 		CtxStr_Cmd			: in	ToCtxStr_t;
							signal 		CtxStr_Resp			: out	FromCtx_t;
							signal 		CtxWin_Cmd			: in	ToCtxWin_t;
							signal 		CtxWin_Resp			: out	FromCtx_t;
										Msg					: in	string		:= "");	

	procedure ConfigureAuto(	WinSize				: in	integer		:= 16#00100000#;
								Ringbuf				: in	std_logic	:= '0';
								Overwrite			: in	std_logic	:= '0';
								Wincnt				: in	integer		:= 2;
								Wincur				: in	integer		:= 0);

	procedure ExpectDmaCmdAuto(		Stream	: in 	integer;
									MaxSize	: in 	integer;
									ExeSize	: in	integer	:= -1;
									NextWin	: in	boolean := false;
							signal 	Clk		: in	std_logic;
							signal 	Dma_Cmd	: in	DaqSm2DaqDma_Cmd_t;
							signal 	Dma_Vld	: in	std_logic;
									Msg		: in	string		:= "");		

	procedure ApplyDmaRespAuto(		Stream 		: in	integer;
									Trigger		: in	std_logic;
									Delay		: in	time		:= 0 ns;
							signal	Clk			: in	std_logic;
							signal 	Dma_Resp		: out	DaqDma2DaqSm_Resp_t;
							signal 	Dma_Resp_Vld	: out	std_logic;
							signal 	Dma_Resp_Rdy	: in	std_logic;
									Msg			: in	string		:= "");		

	------------------------------------------------------------
	-- Helper Functions
	------------------------------------------------------------	
	function GetWindowOffset(	Stream			: integer;
								Ptr				: integer;
								AutoWincur_v	: t_ainteger;
								AutoWinSize_v	: integer) return integer;
								
							
end package;

------------------------------------------------------------
-- Package Body
------------------------------------------------------------
package body psi_ms_daq_daq_sm_tb_pkg is

	procedure InitTestCase(	signal	Clk			: in	std_logic;
							signal	Rst			: out	std_logic) is
	begin
		ConfigureAuto;
		ProcDone := (others => '0');	
		TestCase := -1;
		DmaCmdOpen := 0;
		PtrStr_v := BufStart_c;
		PtrDma_v := BufStart_c;
		SplsWinStr_v := (others => (others => 0));
		wait until rising_edge(Clk);
		Rst <= '1';
		wait until rising_edge(Clk);
		wait until rising_edge(Clk);
		Rst <= '0';
		wait until rising_edge(Clk);
	end procedure;
	
	procedure FinishTestCase is
	begin
		TestCase := -1;
		wait for 1 us;
	end procedure;
	
	procedure ControlWaitCompl(	signal	Clk			: in	std_logic) is
	begin
		while ProcDone /= AllDone loop
			wait until rising_edge(Clk);
		end loop;
		ProcDone := (others => '0');		
	end procedure;	

	procedure WaitForCase(			SubCase		: in	integer;
							signal	Clk			: in	std_logic) is
	begin
		while TestCase /= SubCase loop
			wait until rising_edge(Clk);
		end loop;
	end procedure;
				

	procedure ExpCtxRead(			Stream 		: in	integer;
									BufStart 	: in 	integer		:= 16#01230000#;
									WinSize		: in	integer		:= 16#00100000#;
									Ptr			: in	integer		:= 16#01238000#;
									Ringbuf		: in	std_logic	:= '0';
									Overwrite	: in	std_logic	:= '0';
									Wincnt		: in	integer		:= 2;
									Wincur		: in	integer		:= 0;
									WinSel		: in	integer		:= -1;
									SamplesWin	: in 	integer;
									WinIsTrig	: in	boolean		:= false;
							signal 	Clk			: in	std_logic;
							signal 	CtxStr_Cmd	: in	ToCtxStr_t;
							signal 	CtxStr_Resp	: out	FromCtx_t;
							signal 	CtxWin_Cmd	: in	ToCtxWin_t;
							signal 	CtxWin_Resp : out	FromCtx_t;
									Msg			: in	string		:= "") is
		variable WindowSel_v : integer;
	begin
		if WinSel = -1 then
			WindowSel_v := Wincur;
		else
			WindowSel_v := WinSel;
		end if;
		for acc in 0 to 3 loop	-- 3 read accesses are expected for stream context, 1 for window context
			wait until rising_edge(Clk) and ((CtxStr_Cmd.Rd = '1') or (CtxWin_Cmd.Rd = '1'));
			CtxStr_Resp.RdatLo <= (others => '0');
			CtxStr_Resp.RdatHi <= (others => '0');
			if CtxStr_Cmd.Rd = '1' then
				IntCompare(Stream, CtxStr_Cmd.Stream, "ApplyContext.Str: Wrong stream number - " & Msg);
				StdlCompare(0, CtxStr_Cmd.WenLo, "ApplyContext.Str: WenLo asserted - " & Msg);
				StdlCompare(0, CtxStr_Cmd.WenHi, "ApplyContext.Str: WenHi asserted - " & Msg);
				case CtxStr_Cmd.Sel is
					when CtxStr_Sel_ScfgBufstart_c =>	CtxStr_Resp.RdatLo(CtxStr_Sft_SCFG_RINGBUF_c) 	<= Ringbuf;
														CtxStr_Resp.RdatLo(CtxStr_Sft_SCFG_OVERWRITE_c) <= Overwrite;
														CtxStr_Resp.RdatLo(CtxStr_Sft_SCFG_WINCNT_c+7 downto CtxStr_Sft_SCFG_WINCNT_c) <= std_logic_vector(to_unsigned(Wincnt, 8));
														CtxStr_Resp.RdatLo(CtxStr_Sft_SCFG_WINCUR_c+7 downto CtxStr_Sft_SCFG_WINCUR_c) <= std_logic_vector(to_unsigned(Wincur, 8));
														CtxStr_Resp.RdatHi <= std_logic_vector(to_unsigned(BufStart, 32));
					when CtxStr_Sel_WinsizePtr_c =>		CtxStr_Resp.RdatLo <= std_logic_vector(to_unsigned(WinSize, 32));
														CtxStr_Resp.RdatHi <= std_logic_vector(to_unsigned(Ptr, 32));
					when CtxStr_Sel_Winend_c =>			CtxStr_Resp.RdatLo <= std_logic_vector(to_unsigned(BufStart+WinSize*(Wincur+1), 32));
					when others => report "###ERROR###: ApplyContext.Str: illegal CtxStr_Cmd.Sel - " & Msg severity error;
				end case;
			elsif CtxWin_Cmd.Rd = '1' then
				IntCompare(Stream, CtxWin_Cmd.Stream, "ApplyContext.Win: Wrong stream number - " & Msg);
				IntCompare(WindowSel_v, CtxWin_Cmd.Window, "ApplyContext.Win: Wrong window number - " & Msg);
				StdlCompare(0, CtxWin_Cmd.WenLo, "ApplyContext.Win: WenLo asserted - " & Msg);
				StdlCompare(0, CtxWin_Cmd.WenHi, "ApplyContext.Win: WenHi asserted - " & Msg);		
				case CtxWin_Cmd.Sel is
					when CtxWin_Sel_WincntWinlast_c =>	CtxWin_Resp.RdatLo(30 downto 0) <= std_logic_vector(to_unsigned(SamplesWin, 31));
														if WinIsTrig then
															CtxWin_Resp.RdatLo(31) <= '1';
														else
															CtxWin_Resp.RdatLo(31) <= '0';
														end if;
					when others => report "###ERROR###: ApplyContext.Win: illegal CtxStr_Cmd.Sel - " & Msg severity error;
				end case;					
			end if;
		end loop;
	end procedure;
		
	procedure ExpCtxWrite(			Stream		: in	integer;
									BufStart 	: in 	integer		:= 16#01230000#;
									WinSize		: in	integer		:= 16#00100000#;
									Ptr			: in	integer		:= 16#01238000#;
									Ringbuf		: in	std_logic	:= '0';
									Overwrite	: in	std_logic	:= '0';
									Wincnt		: in	integer		:= 2;
									Wincur		: in	integer		:= 0;
									WinNext		: in	integer		:= -1;
									SamplesWin	: in 	integer;
									WinIsTrig	: in	boolean		:= false;
									WinLast		: in	integer;
									WriteTs		: in	CheckTs_t	:= DontCheck;
									Timstamp	: in	std_logic_vector(63 downto 0)	:= (others => 'X');
							signal 	Clk			: in	std_logic;
							signal 	CtxStr_Cmd	: in	ToCtxStr_t;
							signal 	CtxWin_Cmd	: in	ToCtxWin_t;
									Msg			: in	string		:= "") is
									
		variable WinNext_v : integer;
	begin
		-- No window change by default
		if WinNext = -1 then
			WinNext_v := Wincur;
		else
			WinNext_v := WinNext;
		end if;
		wait until rising_edge(Clk) and CtxStr_Cmd.WenLo = '1';
		-- Stream
		IntCompare(Stream, CtxStr_Cmd.Stream, "ExpectContext.Str: Wrong stream number 0 - " & Msg);
		StdlvCompareStdlv(CtxStr_Sel_ScfgBufstart_c, CtxStr_Cmd.Sel, "ExpectContext.Str: Wrong Sel (unexpected sequence 0) - " & Msg);
		StdlCompare(0, CtxStr_Cmd.WenHi, "ExpectContext.Str: WenHi asserted in first cycle (BufStart overwritten) - " & Msg);
		StdlCompare(choose(Ringbuf='1',1,0), CtxStr_Cmd.WdatLo(CtxStr_Sft_SCFG_RINGBUF_c), "ExpectContext.Str: Wrong RINGBUFFER - " & Msg);
		StdlCompare(choose(Overwrite='1',1,0), CtxStr_Cmd.WdatLo(CtxStr_Sft_SCFG_OVERWRITE_c), "ExpectContext.Str: Wrong OVERWRITE - " & Msg);
		StdlvCompareInt(Wincnt, CtxStr_Cmd.WdatLo(CtxStr_Sft_SCFG_WINCNT_c+7 downto CtxStr_Sft_SCFG_WINCNT_c), "ExpectContext.Str: Wrong SCFG_WINCNT - " & Msg);
		StdlvCompareInt(WinNext_v, CtxStr_Cmd.WdatLo(CtxStr_Sft_SCFG_WINCUR_c+7 downto CtxStr_Sft_SCFG_WINCUR_c), "ExpectContext.Str: Wrong SCFG_WINCUR - " & Msg);
		-- Window
		IntCompare(Stream, CtxWin_Cmd.Stream, "ExpectContext.Win: Wrong stream number 0 - " & Msg);
		IntCompare(Wincur, CtxWin_Cmd.Window, "ExpectContext.Win: Wrong Window number 0 - " & Msg);
		StdlCompare(1, CtxWin_Cmd.WenLo, "ExpectContext.Win: WenLo not asserted in first cycle - " & Msg);
		StdlCompare(1, CtxWin_Cmd.WenHi, "ExpectContext.Win: WenHi not asserted in first cycle - " & Msg);
		StdlvCompareInt(SamplesWin, CtxWin_Cmd.WdatLo(30 downto 0), "ExpectContext.Win: Wrong WIN_WINCNT - " & Msg);
		StdlCompare(Choose(WinIsTrig, 1, 0), CtxWin_Cmd.WdatLo(31), "ExpectContext.Win Wrong WIN_ISTRIG - " & Msg);
		StdlvCompareInt(WinLast, CtxWin_Cmd.WdatHi, "ExpectContext.Str: Wrong WIN_WINLAST - " & Msg);
		wait until rising_edge(Clk) and CtxStr_Cmd.WenHi = '1';
		
		-- Stream
		IntCompare(Stream, CtxStr_Cmd.Stream, "ExpectContext.Str: Wrong stream number 1 - " & Msg);
		StdlvCompareStdlv(CtxStr_Sel_WinsizePtr_c, CtxStr_Cmd.Sel, "ExpectContext.Str: Wrong Sel (unexpected sequence 1) - " & Msg);
		StdlCompare(0, CtxStr_Cmd.WenLo, "ExpectContext.Str: WenLo asserted in second cycle (WinSize overwritten) - " & Msg);
		StdlvCompareInt(Ptr, CtxStr_Cmd.WdatHi, "ExpectContext.Str: Wrong PTR - " & Msg);		
		-- Window
		if WriteTs = CheckWritten then
			IntCompare(Stream, CtxWin_Cmd.Stream, "ExpectContext.Win: Wrong stream number 1 - " & Msg);
			IntCompare(Wincur, CtxWin_Cmd.Window, "ExpectContext.Win: Wrong Window number 1 - " & Msg);
			StdlCompare(1, CtxWin_Cmd.WenLo, "ExpectContext.Win: WenLo not asserted in scond cycle - " & Msg);
			StdlCompare(1, CtxWin_Cmd.WenHi, "ExpectContext.Win: WenHi not asserted in second cycle - " & Msg);
			StdlvCompareStdlv(Timstamp(31 downto 0), CtxWin_Cmd.WdatLo, "ExpectContext.Str: Wrong TS-LO - " & Msg);
			StdlvCompareStdlv(Timstamp(63 downto 32), CtxWin_Cmd.WdatHi, "ExpectContext.Str: Wrong TS-HI - " & Msg);
		elsif WriteTs = CheckNotWritten then
			StdlCompare(0, CtxWin_Cmd.WenLo, "ExpectContext.Win: WenLo asserted in scond cycle (without TS) - " & Msg);
			StdlCompare(0, CtxWin_Cmd.WenHi, "ExpectContext.Win: WenHi asserted in scond cycle (without TS) - " & Msg);
		end if;
		wait until rising_edge(Clk) and CtxStr_Cmd.WenLo = '1';
		
		-- Stream
		IntCompare(Stream, CtxStr_Cmd.Stream, "ExpectContext.Str: Wrong stream number 2 - " & Msg);
		StdlvCompareStdlv(CtxStr_Sel_Winend_c, CtxStr_Cmd.Sel, "ExpectContext.Str: Wrong Sel (unexpected sequence 2) - " & Msg);
		StdlCompare(0, CtxStr_Cmd.WenHi, "ExpectContext.Str: WenHi asserted in third cycle (Unused overwritten) - " & Msg);
		StdlvCompareInt(BufStart+WinSize*(WinNext_v+1), CtxStr_Cmd.WdatLo, "ExpectContext.Str: Wrong WINEND - " & Msg);		
	end procedure;
	
	procedure ExpCtxUpdate(				Stream				: in	integer;
										TfSize				: in	integer;	-- in bytes
										NextWin				: in	boolean		:= false;
										IsTrig				: in	boolean		:= false;
										BufStart 			: in 	integer		:= 16#01230000#;
										WinSize				: in	integer		:= 16#00100000#;
										PtrBefore			: in	integer		:= 16#01238000#;
										Ringbuf				: in	std_logic	:= '0';
										Overwrite			: in	std_logic	:= '0';
										Wincnt				: in	integer		:= 2;
										Wincur				: in	integer		:= 0;
										SamplesWinBefore	: in 	integer;
										WriteTs				: in	CheckTs_t	:= DontCheck;
										Timstamp			: in	std_logic_vector(63 downto 0)	:= (others => 'X');
							variable	PtrAfter			: out	integer;
							signal 		Clk					: in	std_logic;
							signal 		CtxStr_Cmd			: in	ToCtxStr_t;
							signal 		CtxStr_Resp			: out	FromCtx_t;
							signal 		CtxWin_Cmd			: in	ToCtxWin_t;
							signal 		CtxWin_Resp			: out	FromCtx_t;
										Msg					: in	string		:= "") is
		variable PtrAfter_v 		: integer;
		variable SampleswinAfter_v	: integer;
		variable WinLastAfter_v		: integer;
		constant StrWidthBytes_c	: integer	:= StreamWidth_g(Stream)/8;
		variable WinAfter_v			: integer;
	begin
		-- Calculations
		PtrAfter_v := PtrBefore + TfSize;
		SampleswinAfter_v := SamplesWinBefore + TfSize/StrWidthBytes_c;
		if SampleswinAfter_v > WinSize/StrWidthBytes_c then
			SampleswinAfter_v := WinSize/StrWidthBytes_c;
		end if;
		WinLastAfter_v := PtrBefore + TfSize - StrWidthBytes_c;
		if NextWin then
			if Wincur = Wincnt then
				WinAfter_v := 0;
			else
				WinAfter_v := Wincur + 1;
			end if;
			PtrAfter_v	:= BufStart+WinAfter_v*WinSize;
		else
			WinAfter_v := Wincur;
			-- wraparound for ringbuffer
			if Ringbuf = '1' then
				if PtrAfter_v >= BufStart + (Wincur+1)*WinSize then
					PtrAfter_v := PtrAfter_v - WinSize;
				end if;
			end if;
		end if;
		
		-- Read
		ExpCtxRead(	Stream 		=> Stream,
					BufStart 	=> BufStart,
					WinSize		=> WinSize,
					Ptr			=> PtrBefore,
					Ringbuf		=> Ringbuf,
					Overwrite	=> Overwrite,
					Wincnt		=> Wincnt,
					Wincur		=> Wincur,
					SamplesWin	=> SamplesWinBefore,
					Clk			=> Clk,
					CtxStr_Cmd	=> CtxStr_Cmd,
					CtxStr_Resp	=> CtxStr_Resp,
					CtxWin_Cmd	=> CtxWin_Cmd,
					CtxWin_Resp => CtxWin_Resp,
					Msg			=> Msg);
		-- Write
		ExpCtxWrite(Stream		=> Stream,
					BufStart 	=> BufStart,
					WinSize		=> WinSize,
					Ptr			=> PtrAfter_v,
					Ringbuf		=> Ringbuf,
					Overwrite	=> Overwrite,
					Wincnt		=> Wincnt,
					Wincur		=> Wincur,
					WinNext		=> WinAfter_v,
					SamplesWin	=> SampleswinAfter_v,
					WinIsTrig	=> IsTrig,
					WinLast		=> WinLastAfter_v,
					WriteTs		=> WriteTs,
					Timstamp	=> Timstamp,
					Clk			=> Clk,
					CtxStr_Cmd	=> CtxStr_Cmd,
					CtxWin_Cmd	=> CtxWin_Cmd,
					Msg			=> Msg);
		-- Output Values
		PtrAfter := PtrAfter_v;
	end procedure;
	
	procedure ExpCtxFullBurst(			Stream				: in	integer;
										TfSize				: in	integer;	-- in bytes
										NextWin				: in	boolean		:= false;
										BufStart 			: in 	integer		:= 16#01230000#;
										WinSize				: in	integer		:= 16#00100000#;
										PtrBefore			: in	integer		:= 16#01238000#;
										Ringbuf				: in	std_logic	:= '0';
										Overwrite			: in	std_logic	:= '0';
										Wincnt				: in	integer		:= 2;
										Wincur				: in	integer		:= 0;
										SamplesWinBefore	: in 	integer;
										WriteTs				: in	CheckTs_t	:= DontCheck;
										Timstamp			: in	std_logic_vector(63 downto 0)	:= (others => 'X');
							variable	PtrAfter			: out	integer;
							signal 		Clk					: in	std_logic;
							signal 		CtxStr_Cmd			: in	ToCtxStr_t;
							signal 		CtxStr_Resp			: out	FromCtx_t;
							signal 		CtxWin_Cmd			: in	ToCtxWin_t;
							signal 		CtxWin_Resp			: out	FromCtx_t;
										Msg					: in	string		:= "") is
	begin
		-- context read
		ExpCtxRead(	Stream 		=> Stream,
					BufStart 	=> BufStart,
					WinSize		=> WinSize,
					Ptr			=> PtrBefore,
					Ringbuf		=> Ringbuf,
					Overwrite	=> Overwrite,
					Wincnt		=> Wincnt,
					Wincur		=> Wincur,
					SamplesWin	=> SamplesWinBefore,
					Clk			=> Clk,
					CtxStr_Cmd	=> CtxStr_Cmd,
					CtxStr_Resp	=> CtxStr_Resp,
					CtxWin_Cmd	=> CtxWin_Cmd,
					CtxWin_Resp => CtxWin_Resp,
					Msg			=> Msg);
		-- context update
		ExpCtxUpdate(	Stream				=> Stream,
						TfSize				=> TfSize,
						NextWin				=> NextWin,
						BufStart 			=> BufStart,
						WinSize				=> WinSize,
						PtrBefore			=> PtrBefore,
						Ringbuf				=> Ringbuf,
						Overwrite			=> Overwrite,
						Wincnt				=> Wincnt,
						Wincur				=> Wincur,
						SamplesWinBefore	=> SamplesWinBefore,
						WriteTs				=> WriteTs,
						Timstamp			=> Timstamp,
						PtrAfter			=> PtrAfter,
						Clk					=> Clk,
						CtxStr_Cmd			=> CtxStr_Cmd,
						CtxStr_Resp			=> CtxStr_Resp,
						CtxWin_Cmd			=> CtxWin_Cmd,
						CtxWin_Resp 		=> CtxWin_Resp,
						Msg					=> Msg);
	end procedure;
		
	procedure ExpectDmaCmd(			Stream	: in 	integer;
									Address	: in 	integer;
									MaxSize	: in 	integer;
							signal 	Clk		: in	std_logic;
							signal 	Dma_Cmd	: in	DaqSm2DaqDma_Cmd_t;
							signal 	Dma_Vld	: in	std_logic;
									Msg		: in 	string		:= "") is
	begin
		wait until rising_edge(Clk) and Dma_Vld = '1';
		IntCompare(Stream, Dma_Cmd.Stream, "ExpectDmaCmd: Wrong stream number - " & Msg);
		StdlvCompareInt (Address, Dma_Cmd.Address, "ExpectDmaCmd: Wrong address - " & Msg);
		StdlvCompareInt (MaxSize, Dma_Cmd.MaxSize, "ExpectDmaCmd: Wrong MaxSize - " & Msg);
		wait until rising_edge(Clk);
		StdlCompare(0, Dma_Vld, "ExpectDmaCmd: Vld asserted for more than one cycle - " & Msg);
		DmaCmdOpen := DmaCmdOpen + 1;	
	end procedure;
	
	procedure ApplyDmaResp(			Stream 			: in	integer;
									Size 			: in	integer;
									Trigger			: in	std_logic;
									Delay			: in	time		:= 0 ns;
							signal	Clk				: in	std_logic;
							signal  Dma_Resp		: out	DaqDma2DaqSm_Resp_t;
							signal  Dma_Resp_Vld	: out	std_logic;
							signal  Dma_Resp_Rdy	: in	std_logic;
									Msg				: in	string		:= "") is
	begin
		while DmaCmdOpen = 0 loop
			wait until rising_edge(Clk);
		end loop;		
		wait for Delay;
		-- Send response
		wait until rising_edge(Clk);	
		Dma_Resp_Vld 		<= '1';
		Dma_Resp.Stream 	<= Stream;
		Dma_Resp.Size 		<= std_logic_vector(to_unsigned(Size, Dma_Resp.Size'length));
		Dma_Resp.Trigger	<= Trigger;
		wait until rising_edge(Clk) and Dma_Resp_Rdy = '1';
		Dma_Resp_Vld 		<= '0';
		Dma_Resp.Stream		<= 0;
		Dma_Resp.Trigger	<= 'U';
		Dma_Resp.Size		<= (others => 'U');
		DmaCmdOpen := DmaCmdOpen - 1;	
	end procedure;
	
	procedure AssertTfDone(	signal	Clk			: in	std_logic;
							signal 	TfDone		: out	std_logic) is
	begin
		wait until rising_edge(Clk);
		TfDone <= '1';
		wait until rising_edge(Clk);
		TfDone <= '0';
	end procedure;
	
	procedure CheckIrq(			MaxWait			: in	time	:= 1 us;	-- Maximum time to wait for the IRQ
								Stream			: in	integer;
								LastWin			: in	integer;
								Msg				: in	string	:= "";
						signal	Clk				: in	std_logic;
						signal	StrIrq			: in	std_logic_vector(3 downto 0);
						signal	StrLastWin		: in	WinType_a(3 downto 0)) is
		variable IrqMask_v	: std_logic_vector(StrIrq'range);
		variable IdleTimePrior_v	: time;
		variable ProcStartTime_v	: time;
	begin
		ProcStartTime_v := now;
		IrqMask_v := (others => '0');
		IrqMask_v(Stream) := '1';
		wait until rising_edge(Clk);
		wait until (StrIrq = IrqMask_v) and  rising_edge(Clk) for MaxWait;
		StdlvCompareInt (LastWin, StrLastWin(Stream), "Received wrong LastWin with IRQ - " & Msg);
		StdlvCompareStdlv (IrqMask_v, StrIrq, "IRQ was not asserted - " & Msg);
		wait until rising_edge(Clk);
		StdlvCompareInt (0, StrIrq, "IRQ was not deasserted - " & Msg);	
	end procedure;
	
	procedure ExpCtxReadAuto(		Stream		: in	integer;
							signal 	Clk			: in	std_logic;
							signal 	CtxStr_Cmd	: in	ToCtxStr_t;
							signal 	CtxStr_Resp	: out	FromCtx_t;
							signal 	CtxWin_Cmd	: in	ToCtxWin_t;
							signal 	CtxWin_Resp : out	FromCtx_t;
									Msg			: in	string		:= "") is
	begin
		ExpCtxRead(	Stream 		=> Stream,
					BufStart 	=> BufStart_c(Stream),
					WinSize		=> AutoWinSize_v,
					Ptr			=> PtrStr_v(Stream),
					Ringbuf		=> AutoRingbuf_v,
					Overwrite	=> AutoOverwrite_v,
					Wincnt		=> AutoWincnt_v,
					Wincur		=> AutoWincur_v(Stream),
					SamplesWin	=> SplsWinStr_v(Stream)(AutoWincur_v(Stream)),
					Clk			=> Clk,
					CtxStr_Cmd	=> CtxStr_Cmd,
					CtxStr_Resp	=> CtxStr_Resp,
					CtxWin_Cmd	=> CtxWin_Cmd,
					CtxWin_Resp => CtxWin_Resp,
					Msg			=> Msg);	
	end procedure;
	
	procedure ExpCtxUpdateAuto(			Stream				: in	integer;
										NextWin				: in	boolean		:= false;
										IsTrig				: in	boolean		:= false;
										WriteTs				: in	CheckTs_t	:= DontCheck;
										Timstamp			: in	std_logic_vector(63 downto 0)	:= (others => 'X');
							signal 		Clk					: in	std_logic;
							signal 		CtxStr_Cmd			: in	ToCtxStr_t;
							signal 		CtxStr_Resp			: out	FromCtx_t;
							signal 		CtxWin_Cmd			: in	ToCtxWin_t;
							signal 		CtxWin_Resp			: out	FromCtx_t;
										Msg					: in	string		:= "") is
	begin
		while DmaCmdOpen = 0 loop
			wait until rising_edge(Clk);
		end loop;	
		ExpCtxUpdate(	Stream				=> Stream,
						TfSize				=> AutoAccessSize_v(Stream),
						NextWin				=> NextWin,
						IsTrig				=> IsTrig,
						BufStart 			=> BufStart_c(Stream),
						WinSize				=> AutoWinSize_v,
						PtrBefore			=> PtrStr_v(Stream),
						Ringbuf				=> AutoRingbuf_v,
						Overwrite			=> AutoOverwrite_v,
						Wincnt				=> AutoWincnt_v,
						Wincur				=> AutoWincur_v(Stream),
						SamplesWinBefore	=> SplsWinStr_v(Stream)(AutoWincur_v(Stream)),
						WriteTs				=> WriteTs,
						Timstamp			=> Timstamp,
						PtrAfter			=> PtrStr_v(Stream),
						Clk					=> Clk,
						CtxStr_Cmd			=> CtxStr_Cmd,
						CtxStr_Resp			=> CtxStr_Resp,
						CtxWin_Cmd			=> CtxWin_Cmd,
						CtxWin_Resp 		=> CtxWin_Resp,
						Msg					=> Msg);	
		SplsWinStr_v(Stream)(AutoWincur_v(Stream)) := work.psi_common_math_pkg.min(AutoWinSize_v/(StreamWidth_g(Stream)/8), SplsWinStr_v(Stream)(AutoWincur_v(Stream))+AutoAccessSize_v(Stream)/(StreamWidth_g(Stream)/8));
		if NextWin then			
			if AutoWincur_v(Stream) = AutoWincnt_v then
				AutoWincur_v(Stream) := 0;
			else
				AutoWincur_v(Stream) := AutoWincur_v(Stream) + 1;
			end if;
		else
			-- wraparound for ringbuffer case
			if GetWindowOffset(Stream, PtrStr_v(Stream), AutoWincur_v, AutoWinSize_v) > AutoWinSize_v then
				report "###ERROR### TB assertion, unhandled window crossing" severity error;
			elsif GetWindowOffset(Stream, PtrStr_v(Stream), AutoWincur_v, AutoWinSize_v) = AutoWinSize_v then
				if AutoRingbuf_v = '1' then
					PtrStr_v(Stream) := BufStart_c(Stream);
				end if;
			end if;
		end if;
		
	end procedure;
	
	procedure ExpCtxFullBurstAuto(		Stream				: in	integer;
										NextWin				: in	boolean		:= false;
										IsTrig				: in	boolean		:= false;
										WriteTs				: in	CheckTs_t	:= DontCheck;
										Timstamp			: in	std_logic_vector(63 downto 0)	:= (others => 'X');
							signal 		Clk					: in	std_logic;
							signal 		CtxStr_Cmd			: in	ToCtxStr_t;
							signal 		CtxStr_Resp			: out	FromCtx_t;
							signal 		CtxWin_Cmd			: in	ToCtxWin_t;
							signal 		CtxWin_Resp			: out	FromCtx_t;
										Msg					: in	string		:= "") is
	begin
		ExpCtxReadAuto(	Stream		=> Stream,
						Clk			=> Clk,
						CtxStr_Cmd	=> CtxStr_Cmd,
						CtxStr_Resp	=> CtxStr_Resp,
						CtxWin_Cmd	=> CtxWin_Cmd,
						CtxWin_Resp => CtxWin_Resp,
						Msg			=> Msg);
		ExpCtxUpdateAuto(	Stream		=> Stream,
							NextWin		=> NextWin,
							IsTrig		=> IsTrig,
							WriteTs		=> WriteTs,
							Timstamp	=> Timstamp,
							Clk			=> Clk,
							CtxStr_Cmd	=> CtxStr_Cmd,
							CtxStr_Resp	=> CtxStr_Resp,
							CtxWin_Cmd	=> CtxWin_Cmd,
							CtxWin_Resp	=> CtxWin_Resp,
							Msg 		=> Msg);						
	end procedure;
	
	procedure ConfigureAuto(	WinSize				: in	integer		:= 16#00100000#;
								Ringbuf				: in	std_logic	:= '0';
								Overwrite			: in	std_logic	:= '0';
								Wincnt				: in	integer		:= 2;
								Wincur				: in	integer		:= 0) is
	begin
		AutoWinSize_v 	:= WinSize;
		AutoRingbuf_v 	:= Ringbuf;
		AutoOverwrite_v	:= Overwrite;
		AutoWincnt_v	:= Wincnt;
		AutoWincur_v	:= (others => Wincur);
	end procedure;
	
	procedure ExpectDmaCmdAuto(		Stream	: in 	integer;
									MaxSize	: in 	integer;
									ExeSize	: in	integer	:= -1;
									NextWin	: in	boolean := false;
							signal 	Clk		: in	std_logic;
							signal 	Dma_Cmd	: in	DaqSm2DaqDma_Cmd_t;
							signal 	Dma_Vld	: in	std_logic;
									Msg		: in	string		:= "") is
		variable ExeSize_v 			: integer;
		variable NextWinNr_v		: integer;
	begin
		if ExeSize = -1 then
			ExeSize_v := MaxSize;
		else
			ExeSize_v := ExeSize;
		end if;
		ExpectDmaCmd(	Stream 	=> Stream,
						Address	=> PtrDma_v(Stream),
						MaxSize	=> MaxSize,
						Clk		=> Clk,
						Dma_Cmd	=> Dma_Cmd,
						Dma_Vld	=> Dma_Vld,
						Msg		=> Msg);
		if NextWin then			
			if AutoWincur_v(Stream) = AutoWincnt_v then
				NextWinNr_v := 0;
			else
				NextWinNr_v := AutoWincur_v(Stream) + 1;
			end if;
			PtrDma_v(Stream) := BufStart_c(Stream) + NextWinNr_v*AutoWinSize_v;
		else
			PtrDma_v(Stream) := PtrDma_v(Stream) + ExeSize_v;
			-- wraparound for ringbuffer case
			if GetWindowOffset(Stream, PtrDma_v(Stream), AutoWincur_v, AutoWinSize_v) > AutoWinSize_v then
				report "###ERROR### TB assertion, unhandled window crossing" severity error;
			elsif GetWindowOffset(Stream, PtrDma_v(Stream), AutoWincur_v, AutoWinSize_v) = AutoWinSize_v then
				if AutoRingbuf_v = '1' then
					PtrDma_v(Stream) := BufStart_c(Stream) + AutoWincur_v(Stream)*AutoWinSize_v;
				end if;
			end if;
		end if;
		AutoAccessSize_v(Stream) := ExeSize_v;
	end procedure;
	
	procedure ApplyDmaRespAuto(		Stream 		: in	integer;
									Trigger		: in	std_logic;
									Delay		: in	time		:= 0 ns;
							signal	Clk			: in	std_logic;
							signal 	Dma_Resp		: out	DaqDma2DaqSm_Resp_t;
							signal 	Dma_Resp_Vld	: out	std_logic;
							signal 	Dma_Resp_Rdy	: in	std_logic;
									Msg			: in	string		:= "") is
	begin
		while DmaCmdOpen = 0 loop
			wait until rising_edge(Clk);
		end loop;		
		wait for 1 ps;
		ApplyDmaResp(	Stream 			=> Stream,
						Size 			=> AutoAccessSize_v(Stream),
						Trigger			=> Trigger,
						Delay			=> Delay,
						Clk				=> Clk,
						Dma_Resp 		=> Dma_Resp,
						Dma_Resp_Vld	=> Dma_Resp_Vld,
						Dma_Resp_Rdy	=> Dma_Resp_Rdy,
						Msg				=> Msg);
	end procedure;
	
	function GetWindowOffset(	Stream			: integer;
								Ptr				: integer;
								AutoWincur_v	: t_ainteger;
								AutoWinSize_v	: integer) return integer is
	begin
		return Ptr - BufStart_c(Stream) - AutoWincur_v(Stream)*AutoWinSize_v;
	end function;
		
end;
