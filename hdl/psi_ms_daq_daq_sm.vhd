------------------------------------------------------------------------------
--  Copyright (c) 2019 by Paul Scherrer Institute, Switzerland
--  All rights reserved.
--  Authors: Oliver Bruendler
------------------------------------------------------------------------------

------------------------------------------------------------------------------
-- Description
------------------------------------------------------------------------------
-- This component calculates a binary division of two fixed point values.

------------------------------------------------------------------------------
-- Libraries
------------------------------------------------------------------------------
library ieee;
	use ieee.std_logic_1164.all;
	use ieee.numeric_std.all;
	
library work;
	use work.psi_common_math_pkg.all;
	use work.psi_common_logic_pkg.all;
	use work.psi_common_array_pkg.all;
	use work.psi_ms_daq_pkg.all;

------------------------------------------------------------------------------
-- Entity Declaration
------------------------------------------------------------------------------
-- $$ testcases=single_simple,priorities,single_window,multi_window,enable,irq,timestamp $$
-- $$ processes=control,dma_cmd,dma_resp,ctx $$
-- $$ tbpkg=work.psi_tb_txt_util,work.psi_tb_compare_pkg $$
entity psi_ms_daq_daq_sm is
	generic (
		Streams_g				: positive range 1 to 32		:= 4;				-- $$ constant=4 $$		
		StreamPrio_g			: t_ainteger					:= (1, 2, 3, 1);	-- $$ constant=(1, 2, 3, 1) $$
		StreamWidth_g			: t_ainteger					:= (8, 16, 32, 64);	-- $$ constant=(8, 16, 32, 64) $$
		Windows_g				: positive range 1 to 32		:= 4;				-- $$ constant=4 $$
		MinBurstSize_g			: positive						:= 512;				-- $$ constant=512 $$
		MaxBurstSize_g			: positive						:= 512				-- $$ constant=512 $$
	);
	port (
		-- Control signals
		Clk				: in	std_logic;									-- $$ type=clk; freq=200e6; proc=control,dma_cmd,dma_resp,ctx $$
		Rst				: in	std_logic;									-- $$ proc=control $$
		GlbEna			: in	std_logic;									-- $$ proc=control; lowactive=true $$
		StrEna			: in	std_logic_vector(Streams_g-1 downto 0);		-- $$ proc=control; lowactive=true $$
		StrIrq			: out	std_logic_vector(Streams_g-1 downto 0);		-- $$ proc=control,dma_resp,dma_cmd; $$
		StrLastWin		: out	WinType_a(Streams_g-1 downto 0);
		
		-- Input logic Connections
		Inp_HasLast		: in	std_logic_vector(Streams_g-1 downto 0);		-- $$ proc=control $$
		Inp_Level		: in	t_aslv16(Streams_g-1 downto 0);				-- $$ proc=control $$
		Ts_Vld			: in	std_logic_vector(Streams_g-1 downto 0);		-- $$ proc=control $$
		Ts_Rdy			: out	std_logic_vector(Streams_g-1 downto 0);		-- $$ proc=control $$
		Ts_Data			: in	t_aslv64(Streams_g-1 downto 0);				-- $$ proc=control $$
		
		-- Dma Connections
		Dma_Cmd			: out	DaqSm2DaqDma_Cmd_t;							-- $$ proc=dma_cmd,control $$
		Dma_Cmd_Vld		: out	std_logic;									-- $$ proc=dma_cmd,control $$
		Dma_Resp		: in	DaqDma2DaqSm_Resp_t;						-- $$ proc=dma_resp $$
		Dma_Resp_Vld	: in	std_logic;									-- $$ proc=dma_resp $$
		Dma_Resp_Rdy	: out	std_logic;									-- $$ proc=dma_resp $$
		
		-- Memory Controller
		TfDone			: in	std_logic;									-- $$ proc=dma_resp $$
		
		-- Context RAM connections
		CtxStr_Cmd		: out	ToCtxStr_t;									-- $$ proc=ctx $$
		CtxStr_Resp		: in	FromCtx_t;									-- $$ proc=ctx $$
		CtxWin_Cmd		: out	ToCtxWin_t;									-- $$ proc=ctx $$
		CtxWin_Resp		: in	FromCtx_t									-- $$ proc=ctx $$
	);
end entity;
		
------------------------------------------------------------------------------
-- Architecture Declaration
------------------------------------------------------------------------------
architecture rtl of psi_ms_daq_daq_sm is

	-- Function Definitions
	function GetBitsOfStreamPrio(	InputVector	: std_logic_vector;
									Prio		: integer) 
									return std_logic_vector is
		variable Result_v : std_logic_vector(count(StreamPrio_g, Prio)-1 downto 0)	:= (others => '0');
		variable OutIdx_v : integer := 0;
	begin
		for idx in InputVector'low to InputVector'high loop
			if StreamPrio_g(idx) = Prio then
				Result_v(OutIdx_v) 	:= InputVector(idx);
				OutIdx_v 			:= OutIdx_v + 1;
			end if;
		end loop;
		return Result_v;
	end function;
	
	function GetStreamNrFromGrant(	GrantVector : std_logic_vector;
									Prio		: integer) 
									return integer is
		variable IdxCnt_v	: integer := 0;
	begin
		for idx in StreamPrio_g'low to StreamPrio_g'high loop
			if StreamPrio_g(idx) = Prio then
				if GrantVector(IdxCnt_v) = '1' then
					return idx;
				end if;
				IdxCnt_v := IdxCnt_v + 1;
			end if;			
		end loop;
		return 0;
	end function;
	
	-- Vivado Workarounds (Synthesis fail)
	subtype Log2Bytes_t is integer range 0 to log2(MaxStreamWidth_c/8);
	type Log2Bytes_a is array (natural range <>) of Log2Bytes_t;
	function CalcLog2Bytes return Log2Bytes_a is
		variable arr : Log2Bytes_a(0 to Streams_g-1);
	begin
		for i in 0 to Streams_g-1 loop
			arr(i)	:= log2(StreamWidth_g(i)/8);
		end loop;
		return arr;
	end function;
	constant Log2StrBytes_c	: Log2Bytes_a(0 to Streams_g-1) := CalcLog2Bytes;
	
	-- Component Connection Signals
	signal AvailPrio1		: std_logic_vector(count(StreamPrio_g, 1)-1 downto 0);
	signal AvailPrio2		: std_logic_vector(count(StreamPrio_g, 2)-1 downto 0);
	signal AvailPrio3		: std_logic_vector(count(StreamPrio_g, 3)-1 downto 0);
	signal GrantPrio1		: std_logic_vector(AvailPrio1'range);
	signal GrantPrio2		: std_logic_vector(AvailPrio2'range);
	signal GrantPrio3		: std_logic_vector(AvailPrio3'range);
	signal GrantVld			: std_logic_vector(3 downto 1);	
	signal IrqFifoAlmFull	: std_logic;
	signal IrqFifoEmpty		: std_logic;
	signal IrqFifoGenIrq	: std_logic;
	signal IrqFifoStream	: std_logic_vector(log2ceil(Streams_g)-1 downto 0);
	signal IrqLastWinNr		: std_logic_vector(log2ceil(Windows_g)-1 downto 0);
	signal IrqFifoIn		: std_logic_vector(log2ceil(Streams_g)+log2ceil(Windows_g) downto 0);
	signal IrqFifoOut		: std_logic_vector(log2ceil(Streams_g)+log2ceil(Windows_g) downto 0);
	
	-- Types
	type State_t is (Idle_s, CheckPrio1_s, CheckPrio2_s, CheckPrio3_s, CheckResp_s, TlastCheck_s, ReadCtxStr_s, First_s, ReadCtxWin_s, CalcAccess0_s, CalcAccess1_s, ProcResp0_s, NextWin_s, WriteCtx_s);

	-- Two process method
	type two_process_r is record
		GlbEnaReg		: std_logic;
		StrEnaReg		: std_logic_vector(Streams_g-1 downto 0);
		InpDataAvail	: std_logic_vector(Streams_g-1 downto 0);
		DataAvailArbIn	: std_logic_vector(Streams_g-1 downto 0);
		DataPending		: std_logic_vector(Streams_g-1 downto 0);
		OpenCommand		: std_logic_vector(Streams_g-1 downto 0);
		WinProtected	: std_logic_vector(Streams_g-1 downto 0); -- Set if the current window is not yet available
		NewBuffer		: std_logic_vector(Streams_g-1 downto 0);
		FirstAfterEna	: std_logic_vector(Streams_g-1 downto 0);
		FirstOngoing	: std_logic_vector(Streams_g-1 downto 0);
		GrantVldReg		: std_logic_vector(3 downto 1);
		State			: State_t;
		GrantPrio1Reg	: std_logic_vector(GrantPrio1'range);
		GrantPrio2Reg	: std_logic_vector(GrantPrio2'range);
		GrantPrio3Reg	: std_logic_vector(GrantPrio3'range);
		HasLastReg		: std_logic_vector(Inp_HasLast'range);
		HndlAfterCtxt	: State_t;
		HndlStream		: integer range 0 to Streams_g;
		HndlCtxCnt		: integer range 0 to 4;
		HndlRingbuf		: std_logic;
		HndlOverwrite	: std_logic;
		HndlWincnt		: std_logic_vector(log2ceil(Windows_g)-1 downto 0);
		HndlWincur		: std_logic_vector(log2ceil(Windows_g)-1 downto 0);
		HndlLastWinNr	: std_logic_vector(log2ceil(Windows_g)-1 downto 0);
		HndlBufstart	: std_logic_vector(31 downto 0);
		HndlWinSize		: std_logic_vector(31 downto 0);
		HndlPtr0		: std_logic_vector(31 downto 0);
		HndlPtr1		: std_logic_vector(31 downto 0);
		HndlPtr2		: std_logic_vector(31 downto 0);
		HndlLevel		: std_logic_vector(15 downto 0);
		Hndl4kMax		: std_logic_vector(12 downto 0);
		HndlWinMax		: std_logic_vector(31 downto 0);
		HndlWinEnd		: std_logic_vector(31 downto 0);
		HndlWinBytes	: std_logic_vector(32 downto 0);
		HndlWinLast		: std_logic_vector(31 downto 0);
		HndlTs			: std_logic_vector(63 downto 0);
		TfDoneCnt		: std_logic_vector(log2ceil(Streams_g)-1 downto 0);
		TfDoneReg		: std_logic;
		HndlWinDone		: std_logic;
		CtxStr_Cmd		: ToCtxStr_t;
		CtxWin_Cmd		: ToCtxWin_t;
		Dma_Cmd			: DaqSm2DaqDma_Cmd_t;
		Dma_Cmd_Vld		: std_logic;
		Dma_Resp_Rdy	: std_logic;
		Ts_Rdy			: std_logic_vector(Streams_g-1 downto 0);
		ArbDelCnt		: integer range 0 to 4;
		IrqFifoWrite	: std_logic;
		IrqFifoRead		: std_logic;
		StrIrq			: std_logic_vector(Streams_g-1 downto 0);
		StrLastWin		: WinType_a(Streams_g-1 downto 0);
		EndByTrig		: std_logic;
	end record;
	signal r, r_next : two_process_r;
	
	-- USED FOR DEBUGGING ONLY!
	-- attribute mark_debug : string;
	-- attribute mark_debug of r : signal is "true";
	
	-- Todo: mask streams that already have a transfer open at the input
	
begin
	--------------------------------------------
	-- Combinatorial Process
	--------------------------------------------
	p_comb : process(	r, Inp_HasLast, Inp_Level, Ts_Vld, Ts_Data, Dma_Resp, Dma_Resp_Vld, CtxStr_Resp, CtxWin_Resp, GlbEna, StrEna, TfDone, IrqFifoGenIrq, IrqFifoStream, IrqLastWinNr,
						GrantVld, GrantPrio1, GrantPrio2, GrantPrio3, IrqFifoAlmFull, IrqFifoEmpty)
		variable v 					: two_process_r;
	begin
		-- *** Hold variables stable ***
		v := r;
		
		-- *** Default Values ***
		v.CtxStr_Cmd.WenLo	:= '0';
		v.CtxStr_Cmd.WenHi	:= '0';
		v.CtxWin_Cmd.WenLo	:= '0';
		v.CtxWin_Cmd.WenHi	:= '0';
		v.CtxStr_Cmd.Rd 	:= '0';
		v.CtxWin_Cmd.Rd 	:= '0'; 
		v.Dma_Cmd_Vld		:= '0';
		v.Ts_Rdy			:= (others => '0');
		v.Dma_Resp_Rdy		:= '0';
		v.CtxWin_Cmd.WdatLo	:= (others => '0');
		v.CtxWin_Cmd.WdatHi := (others => '0');
		v.CtxStr_Cmd.WdatLo := (others => '0');
		v.CtxStr_Cmd.WdatHi := (others => '0');
		v.IrqFifoWrite		:= '0';
		v.IrqFifoRead		:= '0';
		v.StrIrq			:= (others => '0');
		
		
		-- *** Pure Pipelining (no functional registers) ***
		v.GrantVldReg 	:= GrantVld;
		v.GrantPrio1Reg	:= GrantPrio1;
		v.GrantPrio2Reg	:= GrantPrio2;
		v.GrantPrio3Reg := GrantPrio3;
		v.HasLastReg	:= Inp_HasLast;
		v.StrEnaReg		:= StrEna;
		v.GlbEnaReg		:= GlbEna;
		v.TfDoneReg		:= TfDone;
		
		-- *** Check Availability of a full burst ***
		for str in 0 to Streams_g-1 loop
			if unsigned(Inp_Level(str)) >= MinBurstSize_g then
				v.InpDataAvail(str) := r.StrEnaReg(str) and r.GlbEnaReg;
			else
				v.InpDataAvail(str)	:= '0';
			end if;
		end loop;
		v.DataAvailArbIn := r.InpDataAvail and (not r.OpenCommand) and (not r.WinProtected);	-- Do not arbitrate new commands on streams that already have a command
		v.DataPending := r.InpDataAvail and (not r.WinProtected);	-- Do not prevent lower priority channels from access if the window of a higher priority stream is protected
		
		-- *** Select level of currently handled FIFO ***
		v.HndlLevel := Inp_Level(r.HndlStream);
		
		-- *** State Machine ***
		case r.State is
			-- *** Idle state ***
			when Idle_s =>
				v.HndlCtxCnt	:= 0;
				v.HndlWinDone	:= '0';
				-- check if data to write is available	(only if IRQ FIFO has space for the response for sure)
				if IrqFifoAlmFull = '0' then				
					v.State 		:= CheckPrio1_s;			
					v.HndlAfterCtxt	:= CalcAccess0_s;
				end if;
				-- Delay arbitration in simulation to allow TB to react
				if r.ArbDelCnt /= 4 then
					v.State 		:= Idle_s;
					v.ArbDelCnt		:= r.ArbDelCnt + 1;
				else
					v.ArbDelCnt		:= 0;
				end if;
			
			-- *** Check for next stream to handle ***
			when CheckPrio1_s =>
				-- Handle command if prio 1 data is available
				if r.GrantVldReg(1) = '1' then
					v.State			:= ReadCtxStr_s;
					v.HndlStream	:= GetStreamNrFromGrant(r.GrantPrio1Reg, 1);
				-- If data is still pending, check for responses to schedule next transfer
				elsif (unsigned(GetBitsOfStreamPrio(r.DataPending, 1)) /= 0) and (count(StreamPrio_g, 1) /= 0)  then -- the term after the AND is required because unsigned(null-range) is not guaranteed to be zero in Vivado
					v.State			:= CheckResp_s;
				-- Otherwise check lower priority streams
				else
					v.State			:= CheckPrio2_s;
				end if;
				
			when CheckPrio2_s =>
				-- Handle command if prio 2 data is available
				if r.GrantVldReg(2) = '1' then
					v.State			:= ReadCtxStr_s;
					v.HndlStream	:= GetStreamNrFromGrant(r.GrantPrio2Reg, 2);
				-- If data is still pending, check for responses to schedule next transfer
				elsif (unsigned(GetBitsOfStreamPrio(r.DataPending, 2)) /= 0) and (count(StreamPrio_g, 2) /= 0)  then -- the term after the AND is required because unsigned(null-range) is not guaranteed to be zero in Vivado
					v.State			:= CheckResp_s;	
				-- Otherwise check lower priority streams
				else
					v.State			:= CheckPrio3_s;
				end if;	

			when CheckPrio3_s =>
				-- Handle command if prio 2 data is available
				if r.GrantVldReg(3) = '1' then
					v.State			:= ReadCtxStr_s;
					v.HndlStream	:= GetStreamNrFromGrant(r.GrantPrio3Reg, 3);
				-- Otherwise check for frame ends
				else
					v.State			:= TlastCheck_s;
				end if;
				
			when TlastCheck_s =>
				v.State := CheckResp_s;
				v.WinProtected	:= (others => '0');	-- No bursts where available on any stream, so all of them were checked and we can retry whether SW emptied a window.
				for idx in 0 to Streams_g-1 loop
					if (r.HasLastReg(idx) = '1') and (r.OpenCommand(idx) = '0') and (r.WinProtected(idx) = '0') then
						v.State			:= ReadCtxStr_s;
						v.HndlStream	:= idx;
					end if;
				end loop;
				
			when CheckResp_s =>
				-- Handle response if one is pending (less important thandata transer, therefore at the end)
				if Dma_Resp_Vld = '1' then
					v.State			:= ReadCtxStr_s;
					v.HndlAfterCtxt	:= ProcResp0_s;
					v.HndlStream	:= Dma_Resp.Stream;
					v.EndByTrig		:= Dma_Resp.Trigger;
				else
					v.State := Idle_s;
				end if;
				
			-- *** Read Context Memory ***
			-- Read information from stream memory
			when ReadCtxStr_s =>
				-- State handling
				if r.HndlCtxCnt = 4 then
					v.State			:= First_s; 
					v.HndlCtxCnt	:= 0;
				else
					v.HndlCtxCnt	:= r.HndlCtxCnt + 1;
				end if;
				
				-- Command Assertions
				v.CtxStr_Cmd.Stream := r.HndlStream;
				case r.HndlCtxCnt is
					when 0 => 	v.CtxStr_Cmd.Sel	:= CtxStr_Sel_Winend_c;
								v.CtxStr_Cmd.Rd		:= '1';
					when 1 => 	v.CtxStr_Cmd.Sel	:= CtxStr_Sel_WinsizePtr_c;
								v.CtxStr_Cmd.Rd		:= '1';
					when 2 => 	v.CtxStr_Cmd.Sel	:= CtxStr_Sel_ScfgBufstart_c;
								v.CtxStr_Cmd.Rd		:= '1';
					when others => null;
				end case;
				
				-- Response handling
				case r.HndlCtxCnt is
					when 2 =>	v.HndlWinEnd	:= CtxStr_Resp.RdatLo;
					when 3 =>	v.HndlWinSize	:= CtxStr_Resp.RdatLo;
								v.HndlPtr0		:= CtxStr_Resp.RdatHi;
					when 4 => 	v.HndlRingbuf	:= CtxStr_Resp.RdatLo(CtxStr_Sft_SCFG_RINGBUF_c);
								v.HndlOverwrite	:= CtxStr_Resp.RdatLo(CtxStr_Sft_SCFG_OVERWRITE_c);
								v.HndlWincnt	:= CtxStr_Resp.RdatLo(CtxStr_Sft_SCFG_WINCNT_c+v.HndlWincnt'high downto CtxStr_Sft_SCFG_WINCNT_c);
								v.HndlWincur	:= CtxStr_Resp.RdatLo(CtxStr_Sft_SCFG_WINCUR_c+v.HndlWincur'high downto CtxStr_Sft_SCFG_WINCUR_c);
								v.HndlBufstart	:= CtxStr_Resp.RdatHi;								
								v.Hndl4kMax		:= std_logic_vector(to_unsigned(4096, 13) - unsigned(r.HndlPtr0(11 downto 0)));	-- Calculate maximum size within this 4k Region
								v.HndlWinMax	:= std_logic_vector(unsigned(r.HndlWinEnd) - unsigned(r.HndlPtr0));				-- Calculate maximum size within this window
					when others => null;
				end case;
				
			-- Handle first access after enable
			when First_s =>
				-- State handling
				v.State			:= ReadCtxWin_s; 
				
				-- Ensure that command and response are both handled as first or not
				if r.HndlAfterCtxt = ProcResp0_s then -- responses
					-- nothing to do
				else	-- command
					v.FirstAfterEna(r.HndlStream)	:= '0';
					v.FirstOngoing(r.HndlStream) 	:= r.FirstAfterEna(r.HndlStream);
				end if;
				
				-- Update values for first access
				if v.FirstOngoing(r.HndlStream) = '1' then
					v.HndlWinEnd					:= std_logic_vector(unsigned(r.HndlBufstart) + unsigned(r.HndlWinSize));
					v.HndlPtr0						:= r.HndlBufstart;
					v.HndlWincur					:= (others => '0');
					v.Hndl4kMax						:= std_logic_vector(to_unsigned(4096, 13) - unsigned(r.HndlBufstart(11 downto 0)));
					v.HndlWinMax					:= r.HndlWinSize;
				end if;					
				
				
			-- Read information from window memory
			when ReadCtxWin_s => 
				-- State handling
				if r.HndlCtxCnt = 2 then
					v.State			:= r.HndlAfterCtxt; -- Goto state depends on the context of the read procedure
				else
					v.HndlCtxCnt	:= r.HndlCtxCnt + 1;
				end if;		

				-- Command Assertions
				v.CtxWin_Cmd.Stream := r.HndlStream;
				v.CtxWin_Cmd.Window	:= to_integer(unsigned(r.HndlWincur));
				case r.HndlCtxCnt is
					when 0 => 	v.CtxWin_Cmd.Sel	:= CtxWin_Sel_WincntWinlast_c;	
								v.CtxWin_Cmd.Rd		:= '1';
					when others => null;
				end case;	

				-- Response handling
				case r.HndlCtxCnt is
					when 2 =>	
						-- Workaround for Vivado (Range expression was resolved incorrectly)
						for i in 0 to Streams_g-1 loop
							if i = r.HndlStream then
								v.HndlWinBytes	:= '0' & ShiftLeft(CtxWin_Resp.RdatLo, Log2StrBytes_c(i)); -- guard bit required for calculations
							end if;
						end loop;
					when others => null;
				end case;				
				
			-- *** Calculate next access ***
			when CalcAccess0_s =>
				-- Calculate Command
				v.Dma_Cmd.Address	:= r.HndlPtr0;				
				v.Dma_Cmd.Stream	:= r.HndlStream;
				v.Dma_Cmd.MaxSize	:= std_logic_vector(to_unsigned(MaxBurstSize_g*8, v.Dma_Cmd.MaxSize'length)); -- 8 bytes per 64-bit QWORD
				-- State update (abort if window is not free)
				if (r.HndlOverwrite = '0') and (unsigned(r.HndlWinBytes) /= 0) and (r.NewBuffer(r.HndlStream) = '1') then
					v.State							:= Idle_s;
					v.WinProtected(r.HndlStream)	:= '1';
				else				
					v.State 					:= CalcAccess1_s;
					v.NewBuffer(r.HndlStream)	:= '0';
					-- Mark stream as active
					v.OpenCommand(r.HndlStream) := '1';
				end if;
			
			when CalcAccess1_s =>
				if unsigned(r.Hndl4kMax) < unsigned(r.HndlWinMax) then
					if unsigned(r.Dma_Cmd.MaxSize) > unsigned(r.Hndl4kMax) then
						v.Dma_Cmd.MaxSize := std_logic_vector(resize(unsigned(r.Hndl4kMax), v.dma_Cmd.MaxSize'length));
					end if;
				else	
					if unsigned(r.Dma_Cmd.MaxSize) > unsigned(r.HndlWinMax) then
						v.Dma_Cmd.MaxSize := std_logic_vector(resize(unsigned(r.HndlWinMax), v.dma_Cmd.MaxSize'length));
					end if;		
				end if;
				v.Dma_Cmd_Vld := '1';
				v.State := Idle_s;

			-- *** Handle response ***		
			-- Calculate next pointer
			when ProcResp0_s => 
				v.OpenCommand(r.HndlStream) 	:= '0';
				v.FirstOngoing(r.HndlStream) 	:= '0';
				v.HndlPtr1 	:= std_logic_vector(unsigned(r.HndlPtr0) + unsigned(Dma_Resp.Size));
				v.State		:= NextWin_s;
				-- Update window information step 1
				v.HndlWinBytes	:= std_logic_vector(unsigned(r.HndlWinBytes) + unsigned(Dma_Resp.Size));

				
			-- Calculate next window to use
			when NextWin_s =>
				-- Default Values
				v.HndlPtr2 := r.HndlPtr1;
				-- Do not wait for "transfer done" for zero size transfers (they are not passed to the memory interface)
				if unsigned(Dma_Resp.Size) /= 0 then
					v.IrqFifoWrite	:= '1';
				end if;
				-- Switch to next window if required	
				v.HndlLastWinNr	:= r.HndlWincur;
				if ((r.HndlPtr1 = r.HndlWinEnd) and (r.HndlRingbuf = '0')) or (Dma_Resp.Trigger = '1') then					
					v.HndlWinDone := '1';
					v.NewBuffer(r.HndlStream) := '1';
					if r.HndlWincur = r.HndlWincnt then
						v.HndlWincur 	:= (others => '0');
						v.HndlPtr2		:= r.HndlBufstart;
						v.HndlWinEnd	:= std_logic_vector(unsigned(r.HndlBufstart) + unsigned(r.HndlWinSize));
					else
						v.HndlWincur 	:= std_logic_vector(unsigned(r.HndlWincur) + 1);
						v.HndlPtr2		:= r.HndlWinEnd;
						v.HndlWinEnd	:= std_logic_vector(unsigned(r.HndlWinEnd) + unsigned(r.HndlWinSize));
					end if;
				end if;
				-- wraparound for ringbuffer case
				if (r.HndlPtr1 = r.HndlWinEnd) and (r.HndlRingbuf = '1') and (Dma_Resp.Trigger = '0') then
					v.HndlPtr2 := std_logic_vector(unsigned(r.HndlPtr1) - unsigned(r.HndlWinSize));
				end if;
				-- Update window information step 2 (limit to maximum value)
				if unsigned(r.HndlWinBytes) > unsigned(r.HndlWinSize) then
					v.HndlWinBytes := '0' & r.HndlWinSize; -- value has a guard bit
				end if;
				-- Store address of last sample in window
				v.HndlWinLast := std_logic_vector(unsigned(r.HndlPtr1) - StreamWidth_g(r.HndlStream)/8);
				-- Latch timestamp
				if (Dma_Resp.Trigger = '1') and (Ts_Vld(r.HndlStream) = '1') then
					v.Ts_Rdy(r.HndlStream) := '1';
					v.HndlTs := Ts_Data(r.HndlStream);
				else
					v.HndlTs := (others => '1');
				end if;
				-- Write values
				v.State := WriteCtx_s;
				v.HndlCtxCnt := 0;
				-- Response is processed
				v.Dma_Resp_Rdy := '1';
		
			-- Write Context Memory Content
			when WriteCtx_s => 
				-- Update State
				if r.HndlCtxCnt = 2 then
					v.State := Idle_s;
				else
					v.HndlCtxCnt := r.HndlCtxCnt + 1;
				end if;
				-- Write Context Memory
				v.CtxStr_Cmd.Stream := v.HndlStream;
				case r.HndlCtxCnt is
					when 0	=> 
						-- Stream Memory
						v.CtxStr_Cmd.Sel 	:= CtxStr_Sel_ScfgBufstart_c;
						v.CtxStr_Cmd.WenLo	:= '1';
						v.CtxStr_Cmd.WdatLo(CtxStr_Sft_SCFG_RINGBUF_c) := r.HndlRingbuf;
						v.CtxStr_Cmd.WdatLo(CtxStr_Sft_SCFG_OVERWRITE_c) := r.HndlOverwrite;
						v.CtxStr_Cmd.WdatLo(CtxStr_Sft_SCFG_WINCNT_c+v.HndlWincnt'high downto CtxStr_Sft_SCFG_WINCNT_c) := r.HndlWincnt;
						v.CtxStr_Cmd.WdatLo(CtxStr_Sft_SCFG_WINCUR_c+v.HndlWincur'high downto CtxStr_Sft_SCFG_WINCUR_c) := r.HndlWincur;
						-- Window Memory
						v.CtxWin_Cmd.Sel	:= CtxWin_Sel_WincntWinlast_c;
						v.CtxWin_Cmd.WenLo	:= '1';
						v.CtxWin_Cmd.WenHi	:= '1';
						v.CtxWin_Cmd.WdatLo	:= ShiftRight(r.HndlWinBytes(31 downto 0), Log2StrBytes_c(r.HndlStream));	-- cut-off guard bit and convert bytes to samples
						v.CtxWin_Cmd.WdatLo(31) := r.EndByTrig;
						v.CtxWin_Cmd.WdatHi	:= r.HndlWinLast;						
					when 1 =>	
						-- Stream Memory
						v.CtxStr_Cmd.Sel 	:= CtxStr_Sel_WinsizePtr_c;
						v.CtxStr_Cmd.WenHi	:= '1';
						v.CtxStr_Cmd.WdatHi	:= r.HndlPtr2;
						-- Window Memory
						if r.HndlWinDone = '1' then	
							v.CtxWin_Cmd.Sel	:= CtxWin_Sel_WinTs_c;
							v.CtxWin_Cmd.WenHi	:= '1';
							v.CtxWin_Cmd.WenLo	:= '1';
							v.CtxWin_Cmd.WdatLo	:= r.HndlTs(31 downto 0);
							v.CtxWin_Cmd.WdatHi := r.HndlTs(63 downto 32);
						end if;
					when 2 => 
						-- Stream Memory
						v.CtxStr_Cmd.Sel 	:= CtxStr_Sel_Winend_c;
						v.CtxStr_Cmd.WenLo	:= '1';
						v.CtxStr_Cmd.WdatLo	:= r.HndlWinEnd;
					when others => null;
				end case;			
		end case;
		
		-- *** Handle Disabled Streams ***
		for str in 0 to Streams_g-1 loop
			if (r.GlbEnaReg = '0') or (r.StrEnaReg(str) = '0') then		
				v.FirstAfterEna(str)	:= '1';
				v.NewBuffer(str)		:= '1';
			end if;
		end loop;
		
		-- *** IRQ Handling ***
		-- Feedback from memory controller
		if r.TfDoneReg = '1' then
			v.TfDoneCnt := std_logic_vector(unsigned(r.TfDoneCnt) + 1);
		end if;
		
		-- Process transfer completion
		if (unsigned(r.TfDoneCnt) /= 0) and (IrqFifoEmpty = '0') then
			v.IrqFifoRead	:= '1';
			v.TfDoneCnt := std_logic_vector(unsigned(v.TfDoneCnt) - 1);
			-- Generate IRQ if required
			if IrqFifoGenIrq = '1' then
				v.StrIrq(to_integer(unsigned(IrqFifoStream))) 		:= '1';
				v.StrLastWin(to_integer(unsigned(IrqFifoStream))) 	:= std_logic_vector(resize(unsigned(IrqLastWinNr), 5));
			end if;
		end if;	
		
		-- *** Assign to signal ***
		r_next <= v;
		
	end process;
	
	-- *** Registered Outputs ***
	CtxStr_Cmd 		<= r.CtxStr_Cmd;
	CtxWin_Cmd 		<= r.CtxWin_Cmd;
	Dma_Cmd_Vld		<= r.Dma_Cmd_Vld;
	Dma_Cmd 		<= r.Dma_Cmd;
	Dma_Resp_Rdy	<= r.Dma_Resp_Rdy;	
	Ts_Rdy			<= r.Ts_Rdy;
	StrIrq			<= r.StrIrq;
	StrLastWin		<= r.StrLastWin;
	
	--------------------------------------------
	-- Sequential Process
	--------------------------------------------
	p_seq : process(Clk)
	begin	
		if rising_edge(Clk) then	
			r <= r_next;
			if Rst = '1' then
				r.ArbDelCnt		<= 0;
				r.InpDataAvail		<= (others => '0');
				r.DataAvailArbIn	<= (others => '0');
				r.HndlStream		<= 0;
				r.State				<= Idle_s;
				r.CtxStr_Cmd.WenLo	<= '0';
				r.CtxStr_Cmd.WenHi	<= '0';
				r.CtxWin_Cmd.WenLo	<= '0';
				r.CtxWin_Cmd.WenHi	<= '0';
				r.Dma_Cmd_Vld		<= '0';
				r.OpenCommand		<= (others => '0');
				r.WinProtected		<= (others => '0');
				r.Dma_Resp_Rdy		<= '0';
				r.Ts_Rdy			<= (others => '0');
				r.GlbEnaReg			<= '0';
				r.FirstOngoing		<= (others => '0');
				r.TfDoneCnt			<= (others => '0');
				r.TfDoneReg			<= '0';
				r.IrqFifoWrite		<= '0';
				r.IrqFifoRead		<= '0';
				r.StrIrq			<= (others => '0');
				r.StrLastWin		<= (others => (others => '0'));
			end if;
		end if;
	end process;
	
	--------------------------------------------
	-- Component Instantiation
	--------------------------------------------
	-- *** Round Robin Arbiter - Prio 1 ***
	AvailPrio1 <= GetBitsOfStreamPrio(r.DataAvailArbIn, 1);
	i_rrarb_1 : entity work.psi_common_arb_priority
		generic map (
			Size_g			=> count(StreamPrio_g, 1)
		)
		port map (
			Clk				=> Clk,
			Rst				=> Rst,
			Request			=> AvailPrio1,
			Grant			=> GrantPrio1
		);	
		GrantVld(1) <= '1' when (unsigned(GrantPrio1) /= 0) and (GrantPrio1'length > 0)  else '0';
		
	-- *** Round Robin Arbiter - Prio 2 ***
	AvailPrio2 <= GetBitsOfStreamPrio(r.DataAvailArbIn, 2);
	i_rrarb_2 : entity work.psi_common_arb_priority
		generic map (
			Size_g			=> count(StreamPrio_g, 2)
		)
		port map (
			Clk				=> Clk,
			Rst				=> Rst,
			Request			=> AvailPrio2,
			Grant			=> GrantPrio2
		);
		GrantVld(2) <= '1' when (unsigned(GrantPrio2) /= 0) and (GrantPrio2'length > 0) else '0';

	-- *** Round Robin Arbiter - Prio 3 ***
	AvailPrio3 <= GetBitsOfStreamPrio(r.DataAvailArbIn, 3);
	i_rrarb_3 : entity work.psi_common_arb_priority
		generic map (
			Size_g			=> count(StreamPrio_g, 3)
		)
		port map (
			Clk				=> Clk,
			Rst				=> Rst,
			Request			=> AvailPrio3,
			Grant			=> GrantPrio3
		);	
	 GrantVld(3) <= '1' when (unsigned(GrantPrio3) /= 0) and (GrantPrio3'length > 0) else '0';


	-- *** IRQ Information FIFO ***
	-- input assembly
	IrqFifoIn(log2ceil(Streams_g)-1 downto 0)										<= std_logic_vector(to_unsigned(r.HndlStream, log2ceil(Streams_g)));
	IrqFifoIn(log2ceil(Streams_g)+log2ceil(Windows_g)-1 downto log2ceil(Streams_g))	<= r.HndlLastWinNr;
	IrqFifoIn(IrqFifoIn'high)														<= r.HndlWinDone;
	
	-- Instantiation
	i_irq_fifo : entity work.psi_common_sync_fifo
		generic map (
			Width_g			=> log2ceil(Streams_g)+log2ceil(Windows_g)+1,
			Depth_g			=> Streams_g*4,
			AlmFullOn_g		=> true,
			AlmFullLevel_g	=> Streams_g*3,
			RamStyle_g		=> "distributed"
		)
		port map (
			Clk				=> Clk,
			Rst				=> Rst,
			InData			=> IrqFifoIn,
			InVld			=> r.IrqFifoWrite,
			OutData			=> IrqFifoOut,
			OutRdy			=> r.IrqFifoRead,
			AlmFull 		=> IrqFifoAlmFull,
			Empty			=> IrqFifoEmpty
		);
		
	-- Output disassembly
	IrqFifoStream 	<= IrqFifoOut(log2ceil(Streams_g)-1 downto 0);
	IrqLastWinNr	<= IrqFifoOut(log2ceil(Streams_g)+log2ceil(Windows_g)-1 downto log2ceil(Streams_g));
	IrqFifoGenIrq	<= IrqFifoOut(IrqFifoOut'high);
		
	
end;	




