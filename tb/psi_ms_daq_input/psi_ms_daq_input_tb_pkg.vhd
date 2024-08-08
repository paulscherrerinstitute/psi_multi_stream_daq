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
	use ieee.math_real.all;
	
library work;
	use work.psi_common_math_pkg.all;
	use work.psi_ms_daq_pkg.all;

library work;
	use work.psi_tb_txt_util.all;
	use work.psi_tb_compare_pkg.all;

------------------------------------------------------------
-- Package Header
------------------------------------------------------------
package psi_ms_daq_input_tb_pkg is
	
	-- *** Generics Record ***
	type Generics_t is record
		StreamWidth_g : positive;
		VldPulsed_g : boolean;
	end record;
	
	------------------------------------------------------------
	-- Not exported Generics
	------------------------------------------------------------
	constant IntDataWidth_g : positive := 64;
	constant StreamBuffer_g : positive := 32;
	constant StreamClkFreq_g : real := 125.0e6;
	constant StreamTsFifoDepth_g : positive := 8;
	constant StreamTimeout_g : real := 10.0e-6;
	constant StreamUseTs_g : boolean := true;
	
	-- Handwritten Stuff	
	constant FrameType_Trigger_c	: string	:= "TRIGGER";
	constant FrameType_Timeout_c	: string	:= "TIMEOUT";
	
	procedure ApplyStrData (			Samples		: in	integer;
										TrigSpl		: in	integer	:= integer'high;
										Timestamp	: in	integer;
										Generics 	: in 	Generics_t;
								signal 	Str_Clk 	: in 	std_logic;
								signal 	Str_Vld 	: inout std_logic;
								signal 	Str_Rdy 	: in 	std_logic;
								signal 	Str_Data 	: inout std_logic_vector;
								signal 	Str_Trig 	: inout std_logic;
								signal	Str_Ts		: inout std_logic_vector;
										DataOffs	: in	integer := 0);
									
	procedure CheckAcqData (			Samples		: in	integer;
										Timestamp	: in	integer;
										Generics 	: in 	Generics_t;
										FrameType	: in	string;
								signal 	Clk 		: in 	std_logic;
								signal 	Daq_Vld 	: in 	std_logic;
								signal 	Daq_Rdy 	: inout std_logic;
								signal 	Daq_Data 	: in 	Input2Daq_Data_t(Data(IntDataWidth_g-1 downto 0), Bytes(log2ceil(IntDataWidth_g/8) downto 0));
								signal 	Ts_Vld		: in 	std_logic;
								signal 	Ts_Rdy		: inout std_logic;
								signal 	Ts_Data		: in 	std_logic_vector;
										IsBadTs		: in	boolean	:= false;
										DataOffs	: in	integer := 0);
									
end package;

------------------------------------------------------------
-- Package Body
------------------------------------------------------------
package body psi_ms_daq_input_tb_pkg is

	procedure ApplyStrData (			Samples		: in	integer;
										TrigSpl		: in	integer	:= integer'high;
										Timestamp	: in	integer;
										Generics 	: in Generics_t;
								signal 	Str_Clk 	: in std_logic;
								signal 	Str_Vld 	: inout std_logic;
								signal 	Str_Rdy 	: in std_logic;
								signal 	Str_Data 	: inout std_logic_vector;
								signal 	Str_Trig 	: inout std_logic;
								signal	Str_Ts		: inout std_logic_vector;
										DataOffs	: in	integer := 0) is
	begin
		Str_Trig <= '0';
		Str_Ts <= std_logic_vector(to_unsigned(0, Str_Ts'length));
		Str_Vld <= '1';
		for SplCnt in 0 to Samples-1 loop
			Str_Vld <= '1';
			-- Apply Trigger
			if SplCnt = TrigSpl then
				Str_Trig <= '1';
				Str_Ts <= std_logic_vector(to_unsigned(Timestamp, Str_Ts'length));
			else
				Str_Trig <= '0';
				Str_Ts <= std_logic_vector(to_unsigned(0, Str_Ts'length));
			end if;
			-- Apply Data
			Str_Data <= std_logic_vector(to_unsigned(SplCnt+DataOffs, Generics.StreamWidth_g));			
			wait until rising_edge(Str_Clk);
			if Generics.VldPulsed_g then
				Str_Trig <= '0';
				Str_Vld <= '0';
				Str_Data <= std_logic_vector(to_unsigned(0, Generics.StreamWidth_g));	
				wait until rising_edge(Str_Clk);
			end if;
		end loop;
		Str_Vld <= '0';
		Str_Trig <= '0';
		Str_Ts <= std_logic_vector(to_unsigned(0, Str_Ts'length));
	end procedure;
	
	procedure CheckAcqData (			Samples		: in	integer;
										Timestamp	: in	integer;
										Generics 	: in 	Generics_t;
										FrameType	: in	string;
								signal 	Clk 		: in 	std_logic;
								signal 	Daq_Vld 	: in 	std_logic;
								signal 	Daq_Rdy 	: inout std_logic;
								signal 	Daq_Data 	: in 	Input2Daq_Data_t(Data(IntDataWidth_g-1 downto 0), Bytes(log2ceil(IntDataWidth_g/8) downto 0));
								signal 	Ts_Vld		: in 	std_logic;
								signal 	Ts_Rdy		: inout std_logic;
								signal 	Ts_Data		: in 	std_logic_vector;
										IsBadTs		: in	boolean	:= false;
										DataOffs	: in	integer := 0) is
		constant Qwords_c			: integer	:= integer(ceil(real(Samples)*real(Generics.StreamWidth_g)/64.0));
		constant SplPerQw_c			: integer	:= 64/Generics.StreamWidth_g;
		variable SplCnt_v			: integer 	:= 0;
		variable SplData_v			: std_logic_vector(Generics.StreamWidth_g-1 downto 0);
		variable DelayedToTlast_v	: boolean	:= false;	-- It is possible that an empty word (0 bytes) with TLAST is sent at thed end of the frame in case of timeouts
		constant Wraparound_c		: integer	:= choose(Generics.StreamWidth_g < 32, 2**Generics.StreamWidth_g, integer'high);
	begin
		wait until rising_edge(Clk);
		Daq_Rdy <= '1';
		for qw in 0 to Qwords_c-1 loop
			-- Wait for data
			wait until rising_edge(Clk) and Daq_Vld = '1';
			-- Check data
			for spl in 0 to SplPerQw_c-1 loop
				if SplCnt_v < Samples then
					SplData_v := Daq_Data.Data((spl+1)*Generics.StreamWidth_g-1 downto spl*Generics.StreamWidth_g);
					StdlvCompareInt((SplCnt_v+DataOffs) mod Wraparound_c, SplData_v, "received wrong data, sample" & IndexString(SplCnt_v), false);
					SplCnt_v := SplCnt_v + 1;
				end if;
			end loop;
			-- Check last, bytes
			if qw = Qwords_c-1 then
				-- If TLAST is not asserted, we can expect a delayed TLAST because of a timeout
				if Daq_Data.Last = '0' then
					DelayedToTlast_v := true;
				end if;		
				StdlvCompareInt(Samples*Generics.StreamWidth_g/8-qw*8, Daq_Data.Bytes, "last bytes not correct", false);
			else
				StdlCompare(0, Daq_Data.Last, "last asserted unexpectedly, QWORD" & IndexString(qw));
				StdlvCompareInt(8, Daq_Data.Bytes, "bytes not 8, QWORD" & IndexString(qw), false);
			end if;
			-- Check IsTrig
			if FrameType = FrameType_Trigger_c and qw = Qwords_c-1 then
				StdlCompare(1, Daq_Data.IsTrig, "IsTrig not asserted, QWORD" & IndexString(qw));
			else
				StdlCompare(0, Daq_Data.IsTrig, "IsTrig asserted unexpectedly, QWORD" & IndexString(qw));
			end if;
			-- Check IsTo
			if FrameType = FrameType_Timeout_c and qw = Qwords_c-1 and not DelayedToTlast_v then
				StdlCompare(1, Daq_Data.IsTo, "IsTo not asserted, QWORD" & IndexString(qw));
			else
				StdlCompare(0, Daq_Data.IsTo, "IsTo asserted unexpectedly, QWORD" & IndexString(qw));
			end if;	
		end loop;
		-- Check delayed TLAST
		if DelayedToTlast_v then
			wait until rising_edge(Clk) and Daq_Vld = '1';
			if FrameType = FrameType_Timeout_c then
				StdlCompare(1, Daq_Data.IsTo, "IsTo not asserted, QWORD" & IndexString(Qwords_c));
				StdlvCompareInt(0, Daq_Data.Bytes, "delayed TLAST must have zero data bytes", false);
				StdlCompare(0, Daq_Data.IsTrig, "delayed TLAST must be non-Trigger");
				StdlCompare(1, Daq_Data.Last, "delayed TLAST must have LAST asserted");
			else
				report "###ERROR###: Delayed TLAST is only possible for timeout frames" severity error;
			end if;
		end if;
		Daq_Rdy <= '0';
				
		-- Check timestamp
		if FrameType = FrameType_Trigger_c then
			if not IsBadTs then
				StdlCompare(1, Ts_Vld, "Ts_Vld not asserted");
			end if;
			StdlvCompareInt(Timestamp, Ts_Data, "Received wrong timestamp", true);
			Ts_Rdy <= '1';
			wait until rising_edge(Clk);
			Ts_Rdy <= '0';
			wait until rising_edge(Clk);
		else
			StdlCompare(0, Ts_Vld, "Ts_Vld asserted unexpectedly for timeout fram");
		end if;
			
	end procedure;
		
end;
