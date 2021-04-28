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
	use work.psi_ms_daq_pkg.all;
	
------------------------------------------------------------------------------
-- Entity Declaration
------------------------------------------------------------------------------
-- $$ testcases=single_frame,multi_frame,timeout,ts_overflow,trig_in_posttrig,always_trig,backpressure,modes $$
-- $$ processes=stream,daq $$
-- $$ tbpkg=work.psi_tb_txt_util $$
entity psi_ms_daq_input is
	generic (
		StreamWidth_g			: positive	range 8 to MemoryBusWidth_c	:= 16;		-- Must be 8 bits increments and modulo MemoryBusWidth_c						$$ export=true $$
		StreamBuffer_g			: positive range 1 to 65535		:= 1024;	-- Buffer depth in QWORDs						$$ constant=32 $$
		StreamTimeout_g			: real							:= 1.0e-3;	-- Timeout in seconds							$$ constant=10.0e-6 $$
		StreamClkFreq_g			: real							:= 125.0e6;	-- Input clock frequency in Hz					$$ constant=125.0e6 $$
		StreamTsFifoDepth_g		: positive						:= 16;		-- Timestamp FIFO depth							$$ constant=3 $$
		StreamUseTs_g			: boolean						:= true		-- Enable/Disable the timestamp acquisition		$$ constant=true $$
	);
	port (
		-- Data Stream Input
		Str_Clk			: in	std_logic;									-- $$ type=clk; freq=125e6; proc=stream $$
		Str_Vld			: in	std_logic;									-- $$ proc=stream $$
		Str_Rdy			: out	std_logic;									-- $$ proc=stream $$
		Str_Data		: in	std_logic_vector(StreamWidth_g-1 downto 0);	-- $$ proc=stream $$
		Str_Trig		: in	std_logic;									-- $$ proc=stream $$
		Str_Ts			: in	std_logic_vector(63 downto 0);				-- $$ proc=stream $$
		
		-- Configuration Signals
		ClkReg			: in	std_logic;
		RstReg			: in 	std_logic;
		PostTrigSpls	: in	std_logic_vector(31 downto 0);				-- $$ proc=daq $$
		Mode			: in	RecMode_t;									-- $$ proc=daq $$
        PreTrigDisable	: in	std_logic;									-- $$ proc=daq $$
		Arm				: in	std_logic;									-- $$ proc=stream $$
		IsArmed			: out	std_logic;									-- $$ proc=stream $$
		IsRecording		: out	std_logic;									-- $$ proc=stream $$		
		
		-- DAQ control signals
		ClkMem			: in	std_logic;									-- $$ type=clk; freq=200e6; proc=daq,stream $$
		RstMem			: in	std_logic;									-- $$ type=rst; clk=Clk $$
		
		-- DAQ logic Connections
		Daq_Vld			: out	std_logic;									-- $$ proc=daq $$
		Daq_Rdy			: in	std_logic;									-- $$ proc=daq $$
		Daq_Data		: out 	Input2Daq_Data_t;							-- $$ proc=daq $$
		Daq_Level		: out	std_logic_vector(15 downto 0);				-- $$ proc=daq $$
		Daq_HasLast		: out	std_logic;									-- $$ proc=daq $$
		
		-- Timestamp connections
		Ts_Vld			: out	std_logic;									-- $$ proc=daq $$
		Ts_Rdy			: in	std_logic;									-- $$ proc=daq $$
		Ts_Data			: out	std_logic_vector(63 downto 0)				-- $$ proc=daq $$
	);
end entity;
		
------------------------------------------------------------------------------
-- Architecture Declaration
------------------------------------------------------------------------------
architecture rtl of psi_ms_daq_input is

	-- Use distributed RAM for small Timstamp FIFOs (< 64 entries)
	constant TsFifoStyle_c		: string	:= choose(StreamTsFifoDepth_g <= 64, "distributed", "block");

	-- Constants
	constant TimeoutLimit_c		: integer	:= integer(StreamClkFreq_g*StreamTimeout_g)-1;
	constant WconvFactor_c		: positive	:= MemoryBusWidth_c/StreamWidth_g;
	constant TlastCntWidth_c	: positive	:= log2ceil(StreamBuffer_g) + 1;

    constant BytesIncr_c        : unsigned(log2(MemoryBusBytes_c)-1 downto 0)
      := to_unsigned(StreamWidth_g/8, log2(MemoryBusBytes_c));
	-- Two process method
	type two_process_r is record
		ModeReg			: RecMode_t;
		ArmReg			: std_logic;
		DataSftReg		: std_logic_vector(MemoryBusWidth_c-1 downto 0);
		WordCnt			: unsigned(log2ceil(WconvFactor_c) downto 0);
        BytesCnt		: unsigned(Input2Daq_Data_Bytes_Len-1 downto 0);
		DataFifoBytes	: unsigned(Input2Daq_Data_Bytes_Len-1 downto 0);
		TrigLatch		: std_logic;
		DataFifoVld		: std_logic;
		DataFifoIsTo	: std_logic;
		DataFifoIsTrig	: std_logic;
		TimeoutCnt		: integer range 0 to TimeoutLimit_c;
		Timeout			: std_logic;
		PostTrigCnt		: unsigned(31 downto 0);
		TLastCnt		: std_logic_vector(TlastCntWidth_c-1 downto 0);
		TsLatch			: std_logic_vector(63 downto 0);
		TsOverflow		: std_logic;
		HasTlastSync	: std_logic_vector(0 to 1);
		IsArmed			: std_logic;
		RecEna			: std_logic;
        PreRecEna	    : std_logic;
        StrData         : std_logic_vector(StreamWidth_g-1 downto 0);  -- 1 clk delayed stream data
	end record;
	signal r, r_next : two_process_r;
	
	-- General Instantiation signals
	signal Str_Rst : std_logic;	

    -- DataFifo contains Data, Number of Bytes and Timeout and Trig signals
    constant DataFifo_Width_c : natural := MemoryBusWidth_c+Input2Daq_Data_Bytes_Len+2;
	-- Data FIFO signals
	signal DataFifo_InRdy		: std_logic;
	signal DataFifo_InData		: std_logic_vector(DataFifo_Width_c-1 downto 0);	
	signal DataFifo_OutData		: std_logic_vector(DataFifo_Width_c-1 downto 0);	
	signal DataFifo_PlData		: std_logic_vector(DataFifo_Width_c-1 downto 0);
	signal DataFifo_PlVld		: std_logic;
	signal DataFifo_PlRdy		: std_logic;
	signal DataFifo_Level		: std_logic_vector(log2ceil(StreamBuffer_g) downto 0);
	signal DataPl_Level			: unsigned(1 downto 0);
	
	-- Internally reused signals
	signal Daq_Data_I		: Input2Daq_Data_t;
	signal Daq_Vld_I		: std_logic;
	signal Daq_HasLast_I	: std_logic;
	signal Ts_Vld_I			: std_logic;
	
	-- Signal output side TLAST handling
	signal OutTlastCnt	: std_logic_vector(TlastCntWidth_c-1 downto 0);
	signal InTlastCnt	: std_logic_vector(TlastCntWidth_c-1 downto 0);
	
	-- Timestamp FIFO signals
	signal TsFifo_InRdy		: std_logic;
	signal TsFifo_InVld		: std_logic;
	signal TsFifo_RdData	: std_logic_vector(63 downto 0);
	signal TsFifo_AlmFull	: std_logic;
	signal TsFifo_Empty		: std_logic;
	
	-- Clock Crossing Signals
	signal PostTrigSpls_Sync 	: std_logic_vector(PostTrigSpls'range);
	signal Mode_Sync			: RecMode_t;
    signal PreTrigDisable_Sync  : std_logic;
	signal Arm_Sync 			: std_logic;
	signal RstReg_Sync			: std_logic;
	signal RstAcq_Sync			: std_logic;
	
begin
    --------------------------------------------
    -- Combinatorial Process
    --------------------------------------------
    p_comb : process(r,
                     Str_Vld, Str_Data, Str_Trig, Str_Ts, PostTrigSpls_Sync, Daq_Rdy, Ts_Rdy, Mode_Sync,
                     Arm_Sync,DataFifo_InRdy, DataFifo_InData, DataFifo_OutData, Daq_Vld_I, Daq_Data_I,
                     Daq_HasLast_I, Ts_Vld_I, OutTlastCnt, TsFifo_AlmFull, TsFifo_Empty,
                     InTlastCnt, TsFifo_InRdy, TsFifo_RdData, PreTrigDisable_Sync)
        variable v               : two_process_r;
        variable ProcessSample_v : boolean;
        variable TriggerSample_v : boolean;
        variable TrigMasked_v    : std_logic;
    begin
        -- *** Hold variables stable ***
        v := r;
		
		-- *** Simplification Variables ***
		ProcessSample_v := (DataFifo_InRdy = '1') and (Str_Vld = '1');
		
		-- *** Input Logic Stage ***
		-- Default values
		v.DataFifoIsTo		:= '0';
		v.DataFifoIsTrig	:= '0';
		v.ModeReg			:= Mode_Sync;
		v.ArmReg			:= Arm_Sync;
        if ProcessSample_v then
          v.StrData         := Str_Data;
        end if;

        
		-- Masking trigger according to recording mode
		case r.ModeReg is
			when RecMode_Continuous_c => 
				TrigMasked_v	:= Str_Trig;
			when RecMode_TriggerMask_c |
			     RecMode_SingleShot_c =>
				TrigMasked_v	:= Str_Trig and r.IsArmed;
			when RecMode_ManuelMode_c =>
				TrigMasked_v	:= r.ArmReg;
			when others => null;
		end case;

		-- Keep FifoVld high until data is written
		v.DataFifoVld		:= r.DataFifoVld and not DataFifo_InRdy;
		
		-- Trigger Latching
		if ProcessSample_v then
			v.TrigLatch				:= '0';
		else
          v.TrigLatch				:= r.TrigLatch or TrigMasked_v;
		end if;
		
		-- Detect timestamp FIFO overflows
		if StreamUseTs_g then
			v.HasTlastSync(0) := Daq_HasLast_I;
			v.HasTlastSync(1) := r.HasTlastSync(0);
			if (TsFifo_AlmFull = '1' ) and (r.DataFifoVld = '1') then
				v.TsOverflow	:= '1';
			elsif (r.HasTlastSync(1) = '0') and (TsFifo_Empty = '1' ) then
				v.TsOverflow	:= '0';
			end if;
		end if;
		
		-- Timestamp latching
		if StreamUseTs_g then
			if (TrigMasked_v = '1') and (unsigned(r.PostTrigCnt) = 0) then
				if (TsFifo_AlmFull = '1') or (r.TsOverflow = '1') then
					v.TsLatch	:= (others => '1');
				else
					v.TsLatch 	:= Str_Ts;
				end if;
			end if;
		end if;		
		
		-- Trigger handling and post trigger counter
		if ProcessSample_v then
			if r.PostTrigCnt /= 0 then
				v.PostTrigCnt	:= r.PostTrigCnt - 1;
				if r.PostTrigCnt = 1 then
					v.DataFifoIsTrig	:= '1';
					v.DataFifoVld		:= r.DataFifoVld or r.RecEna or r.PreRecEna;
					v.RecEna			:= '0';	-- stop recording after frame
                    v.PreRecEna         := '0';
				end if;
			elsif (r.TrigLatch = '1') or (TrigMasked_v = '1') then
				-- Handle incoming trigger sample
				if unsigned(PostTrigSpls_Sync) = 0 then
					v.DataFifoIsTrig	:= '1';
					v.DataFifoVld		:= r.DataFifoVld or r.RecEna or r.PreRecEna;
					v.RecEna			:= '0';	-- stop recording after frame
                    v.PreRecEna			:= '0';
				else
                  v.RecEna := '1';
                  v.PostTrigCnt	:= unsigned(PostTrigSpls_Sync);
				end if;
			end if;
		end if;
		
		-- Detect Timeout (only if data is stuck in conversion)		
		if Str_Vld = '1' or r.WordCnt = 0 then
			v.TimeoutCnt := 0;
		else
			if r.TimeoutCnt = TimeoutLimit_c then
				v.TimeoutCnt 	:= 0;
				v.Timeout		:= '1';
			else
				v.TimeoutCnt := r.TimeoutCnt + 1;
			end if;
		end if;
		
		-- TLast counter
		if (r.DataFifoVld = '1') and ((r.DataFifoIsTo = '1') or (r.DataFifoIsTrig = '1')) then
			v.TLastCnt := std_logic_vector(unsigned(r.TLastCnt) + 1);
		end if;
	
        -- Write because timeout occured
        if r.Timeout = '1' then
            v.DataFifoVld  := r.DataFifoVld or r.RecEna or r.PreRecEna;
            v.DataFifoIsTo := '1';
            v.Timeout      := '0';  -- reser timeout after data was flushed to the FIFO
        end if;
        
        -- Process input data
        if ProcessSample_v and (r.RecEna = '1' or r.PreRecEna = '1') then
          v.WordCnt  := r.WordCnt + 1;
          v.BytesCnt := r.BytesCnt + BytesIncr_c;
          -- Write because 64-bits are ready
          if r.WordCnt = WconvFactor_c-1 then
            v.DataFifoVld := r.DataFifoVld or r.RecEna or r.PreRecEna;
          end if;
          -- If the pretrigger is disabled, use delayed data to compensate for trigger detection time
          if PreTrigDisable_Sync = '1' then
            v.DataSftReg((to_integer(r.WordCnt)+1)*StreamWidth_g-1 downto to_integer(r.WordCnt)*StreamWidth_g) := r.StrData;
          else
            v.DataSftReg((to_integer(r.WordCnt)+1)*StreamWidth_g-1 downto to_integer(r.WordCnt)*StreamWidth_g) := Str_Data;
          end if;
        end if;
        -- Reset counter if data is being written to FIFO
        if v.DataFifoVld = '1' then
          v.WordCnt  := (others => '0');
          v.BytesCnt := (others => '0');
        end if;
		
		-- Convert word counter to byte counter
		v.DataFifoBytes	:= (others => '0');
		if r.Timeout = '1' then
          v.DataFifoBytes := r.BytesCnt;
		else
          v.DataFifoBytes := r.BytesCnt + BytesIncr_c;
		end if;
		
		-- Handle Arming Logic
		if (r.ModeReg /= Mode_Sync) or (r.ModeReg = RecMode_Continuous_c) or (r.ModeReg = RecMode_ManuelMode_c) then -- reset on mode change!
			v.IsArmed := '0';
		elsif r.ArmReg = '1' then
			v.IsArmed := '1';
		elsif TrigMasked_v = '1' then
			v.IsArmed := '0';
		end if;	
		
		-- Enable Recording Logic
		case r.ModeReg is
			when RecMode_Continuous_c |
				 RecMode_TriggerMask_c => 
				-- always enabled
              v.PreRecEna := not PreTrigDisable_Sync;
          when RecMode_SingleShot_c =>
              if v.ArmReg = '1' then
                  v.PreRecEna := not PreTrigDisable_Sync;
              end if;
          when RecMode_ManuelMode_c =>
				-- enable on arming (disable happens after recording)
				if v.ArmReg = '1' then
                  v.PreRecEna := '1';
				end if;
			when others => null;
		end case;
		if r.ModeReg /= Mode_Sync then
          v.RecEna := '0';
          v.PreRecEna := '0';
		end if;		
		
		-- *** Assign to signal ***
		r_next <= v;
		
	end process;
	
    --------------------------------------------
    -- Sequential Process
    --------------------------------------------
    p_seq : process(Str_Clk)
    begin
        if rising_edge(Str_Clk) then
            r <= r_next;
            if Str_Rst = '1' then
              r.WordCnt      <= (others => '0');
              r.BytesCnt     <= (others => '0');
              r.TrigLatch    <= '0';
              r.TimeoutCnt   <= 0;
              r.Timeout      <= '0';
              r.PostTrigCnt  <= (others => '0');
              r.TLastCnt     <= (others => '0');
              r.TsOverflow   <= '0';
              r.HasTlastSync <= (others => '0');
              r.IsArmed      <= '0';
              r.RecEna       <= '0';
              r.PreRecEna    <= '0';
              r.ArmReg       <= '0';
            end if;
        end if;
    end process;
	
	--------------------------------------------
	-- Output Side TLAST handling
	--------------------------------------------
	p_outlast : process(ClkMem)
		variable PlLevel_v	: unsigned(DataPl_Level'range);
	begin
		if rising_edge(ClkMem) then
			-- Default Value
			Daq_HasLast_I <= '0';
		
			-- Count TLAST read from output buffer
			if (Daq_Vld_I = '1') and (Daq_Rdy = '1') and (Daq_Data_I.Last = '1') then
				OutTlastCnt <= std_logic_vector(unsigned(OutTlastCnt) + 1);
			end if;
		
			-- Detect if there are TLASTs in the buffer
			if OutTlastCnt /= InTlastCnt then
				Daq_HasLast_I <= '1';
			end if;
			
			-- Level Calculation (add samples in PL stage)
			PlLevel_v := DataPl_Level;
			if DataFifo_PlRdy = '1' and DataFifo_PlVld = '1' then
				PlLevel_v := PlLevel_v + 1;
			end if;
			if Daq_Vld_I = '1' and Daq_Rdy = '1' then
				PlLevel_v := PlLevel_v - 1;
			end if;
			DataPl_Level <= PlLevel_v;
			-- We calculate the level one cycle late but this does not play any role (the DAQ FSM only runs after data is transferred)
			Daq_Level <= std_logic_vector(resize(unsigned(DataFifo_Level), Daq_Level'length) + DataPl_Level);			
		
			-- Reset
			if RstMem = '1' then
				OutTlastCnt 	<= (others => '0');
				Daq_Level 		<= (others => '0');
				DataPl_Level 	<= (others => '0');
			end if;	
			
		end if;
	end process;
	Daq_HasLast <= Daq_HasLast_I;

    --------------------------------------------
    -- Component Instantiation
    --------------------------------------------
    -- *** Register Interface clock crossings ***
    i_cc_reg_status : entity work.psi_common_status_cc
        generic map (
            DataWidth_g => 35
        )
        port map (
            ClkA                => ClkReg,
            RstInA              => '0',
            DataA(31 downto 0)  => PostTrigSpls,
            DataA(33 downto 32) => Mode,
            DataA(34)           => PreTrigDisable,
            ClkB                => Str_Clk,
            RstInB              => Str_Rst,
            DataB(31 downto 0)  => PostTrigSpls_Sync,
            DataB(33 downto 32) => Mode_Sync,
            DataB(34)           => PreTrigDisable_Sync
        );
		
	i_cc_status : entity work.psi_common_bit_cc
		generic map (
			NumBits_g		=> 2
		)
		port map (
			BitsA(0)	=> r.IsArmed,
			BitsA(1)	=> r.RecEna or r.PreRecEna,
			ClkB		=> ClkReg,
			BitsB(0)	=> IsArmed,
			BitsB(1)	=> IsRecording
		);

	i_cc_reg_pulse : entity work.psi_common_pulse_cc
		generic map (
			NumPulses_g => 1
		)
		port map (
			ClkA		=> ClkReg,
			RstInA		=> '0',
			PulseA(0)	=> Arm,
			ClkB		=> Str_Clk,
			RstInB		=> Str_Rst,
			RstOutB		=> open,
			PulseB(0)	=> Arm_Sync
		);
		
		
		
	-- *** Reset Handling ***
	icc_reg_rst : entity work.psi_common_bit_cc
		generic map (
			NumBits_g		=> 1
		)
		port map (
			BitsA(0)	=> RstReg,
			ClkB		=> Str_Clk,
			BitsB(0)	=> RstReg_Sync
		);
		
	icc_mem_rst : entity work.psi_common_bit_cc
		generic map (
			NumBits_g		=> 1
		)
		port map (
			BitsA(0)	=> RstMem,
			ClkB		=> Str_Clk,
			BitsB(0)	=> RstAcq_Sync
		);		
	Str_Rst <= RstReg_Sync or RstAcq_Sync;
		
	-- *** Acquisition Clock Crossing ***	
	-- Clock crossing for reset and TLAST counter
	i_cc : entity work.psi_common_status_cc
		generic map (
			DataWidth_g		=> TlastCntWidth_c
		)
		port map (
			ClkA		=> Str_Clk,
			RstInA		=> Str_Rst,
			RstOutA		=> open,
			DataA		=> r.TLastCnt,
			ClkB		=> ClkMem,
			RstInB		=> '0',			
			DataB		=> InTlastCnt
		);
	
	
    -- Data FIFO
    DataFifo_InData(MemoryBusWidth_c-1+2 downto 2) <= r.DataSftReg;
    DataFifo_InData(MemoryBusWidth_c+Input2Daq_Data_Bytes_Len+2-1
                    downto MemoryBusWidth_c+2) <= std_logic_vector(r.DataFifoBytes);
    DataFifo_InData(0) <= r.DataFifoIsTo;
    DataFifo_InData(1) <= r.DataFifoIsTrig;
	
	
	i_dfifo : entity work.psi_common_async_fifo 
		generic map (
			Width_g			=> DataFifo_Width_c,
			Depth_g			=> StreamBuffer_g,
			AlmFullOn_g		=> false,
			AlmEmptyOn_g	=> false
		)
		port map (
			InClk		=> Str_Clk,
			InRst		=> Str_Rst,
			OutClk		=> ClkMem,
			OutRst		=> '0',
			InData		=> DataFifo_InData,
			InVld		=> r.DataFifoVld,
			InRdy		=> DataFifo_InRdy,
			OutData		=> DataFifo_PlData,
			OutVld		=> DataFifo_PlVld,
			OutRdy		=> DataFifo_PlRdy,	
			OutLevel	=> DataFifo_Level
		);
		
	-- An additional pipeline stage after the FIFO is required for timing reasons
	i_dplstage : entity work.psi_common_pl_stage
		generic map (
			Width_g		=> DataFifo_Width_c,
			UseRdy_g	=> true
		)
		port map (	
			Clk			=> ClkMem,
			Rst			=> RstMem,
			InVld		=> DataFifo_PlVld,
			InRdy		=> DataFifo_PlRdy,
			InData		=> DataFifo_PlData,
			OutVld		=> Daq_Vld_I,
			OutRdy		=> Daq_Rdy,
			OutData		=> DataFifo_OutData
		);
	Str_Rdy <= DataFifo_InRdy;
		
    Daq_Data_I.Data   <= DataFifo_OutData(MemoryBusWidth_c-1+2 downto 2);
    Daq_Data_I.Bytes  <= DataFifo_OutData(MemoryBusWidth_c+Input2Daq_Data_Bytes_Len+2-1 downto MemoryBusWidth_c+2);
    Daq_Data_I.IsTo   <= DataFifo_OutData(0);
    Daq_Data_I.IsTrig <= DataFifo_OutData(1);
    Daq_Data_I.Last   <= Daq_Data_I.IsTo or Daq_Data_I.IsTrig;
    Daq_Data          <= Daq_Data_I;
    Daq_Vld           <= Daq_Vld_I;
	
	
	-- Timestamp FIFO
	g_timestamp : if StreamUseTs_g generate
		TsFifo_InVld <= r.DataFifoVld and r.DataFifoIsTrig;
	
		i_tsfifo : entity work.psi_common_async_fifo 
			generic map (
				Width_g			=> 64,
				Depth_g			=> StreamTsFifoDepth_g,
				AlmFullOn_g		=> True,
				AlmFullLevel_g	=> StreamTsFifoDepth_g-1,
				AlmEmptyOn_g	=> false,
				RamStyle_g		=> TsFifoStyle_c
			)
			port map (
				InClk		=> Str_Clk,
				InRst		=> Str_Rst,
				OutClk		=> ClkMem,
				OutRst		=> '0',
				InData		=> r.TsLatch,
				InVld		=> TsFifo_InVld,
				InRdy		=> TsFifo_InRdy,
				InAlmFull	=> TsFifo_AlmFull,
				InEmpty		=> TsFifo_Empty,
				OutData		=> TsFifo_RdData,
				OutVld		=> Ts_Vld_I,
				OutRdy		=> Ts_Rdy
			);	
		Ts_Vld	<= Ts_Vld_I;
		-- Replace data by 0xFF... if no valid timestamp is available
		Ts_Data <= (others => '1') when Ts_Vld_I = '0' else TsFifo_RdData;
	end generate;
	
	g_ntimestamp : if not StreamUseTs_g generate
		Ts_Vld <= '0';
		Ts_Data <= (others => '1');
	end generate;
		
		
	--------------------------------------------
	-- Assertions
	--------------------------------------------
	p_assert : process(ClkMem)
	begin
		if rising_edge(ClkMem) then
			assert MemoryBusWidth_c mod StreamWidth_g = 0 report "###ERROR###: psi_ms_daq_input: StreamWidth_g must be modulo division of MemoryBusWidth_c" severity error;
		end if;
	end process;
	
end;	





