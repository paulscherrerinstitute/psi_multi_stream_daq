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
	use work.psi_ms_daq_pkg.all;

library work;
	use work.psi_ms_daq_input_tb_pkg.all;

library work;
	use work.psi_tb_txt_util.all;

------------------------------------------------------------
-- Package Header
------------------------------------------------------------
package psi_ms_daq_input_tb_case_ts_overflow is
	
	procedure stream (
		signal Str_Clk : in std_logic;
		signal Str_Vld : inout std_logic;
		signal Str_Rdy : in std_logic;
		signal Str_Data : inout std_logic_vector;
		signal Str_Trig : inout std_logic;
		signal Str_Ts : inout std_logic_vector;
		signal Clk : in std_logic;
		signal Arm : inout std_logic;
		signal IsArmed : in std_logic;
		constant Generics_c : Generics_t);
		
	procedure daq (
		signal Clk : in std_logic;
		signal PostTrigSpls : inout std_logic_vector;
		signal Mode : inout RecMode_t;
		signal Daq_Vld : in std_logic;
		signal Daq_Rdy : inout std_logic;
		signal Daq_Data : in Input2Daq_Data_t;
		signal Daq_Level : in std_logic_vector;
		signal Daq_HasLast : in std_logic;
		signal Ts_Vld : in std_logic;
		signal Ts_Rdy : inout std_logic;
		signal Ts_Data : in std_logic_vector;
		constant Generics_c : Generics_t);
		
	shared variable StrDone_v	: boolean		:= false;
	shared variable CheckDone_v	: boolean		:= false;
		
end package;

------------------------------------------------------------
-- Package Body
------------------------------------------------------------
package body psi_ms_daq_input_tb_case_ts_overflow is
	procedure stream (
		signal Str_Clk : in std_logic;
		signal Str_Vld : inout std_logic;
		signal Str_Rdy : in std_logic;
		signal Str_Data : inout std_logic_vector;
		signal Str_Trig : inout std_logic;
		signal Str_Ts : inout std_logic_vector;
		signal Clk : in std_logic;
		signal Arm : inout std_logic;
		signal IsArmed : in std_logic;
		constant Generics_c : Generics_t) is
	begin
		-- Wait for config to be applied
		print(">> TS FIFO Overflow");
		wait for 100 ns;
		wait until rising_edge(Str_Clk);
		
		-- Provoke TS Fifo Overflow
		for i in 0 to StreamTsFifoDepth_g-1 loop
			ApplyStrData(2, 1, i, Generics_c, Str_Clk, Str_Vld, Str_Rdy, Str_Data, Str_Trig, Str_Ts);
		end loop;
		StrDone_v := true;
		
		-- Add two frames frame while timestamp FIFO is in overflow condition
		while not CheckDone_v loop
			wait until rising_edge(Str_Clk);
		end loop;
		CheckDone_v := false;
		ApplyStrData(2, 1, 100, Generics_c, Str_Clk, Str_Vld, Str_Rdy, Str_Data, Str_Trig, Str_Ts);
		ApplyStrData(2, 1, 101, Generics_c, Str_Clk, Str_Vld, Str_Rdy, Str_Data, Str_Trig, Str_Ts);
		StrDone_v := true;
		
		-- Add two good frames to check recovery
		while not CheckDone_v loop
			wait until rising_edge(Str_Clk);
		end loop;
		CheckDone_v := false;	
		ApplyStrData(2, 1, 1000, Generics_c, Str_Clk, Str_Vld, Str_Rdy, Str_Data, Str_Trig, Str_Ts);
		ApplyStrData(2, 1, 1001, Generics_c, Str_Clk, Str_Vld, Str_Rdy, Str_Data, Str_Trig, Str_Ts);	
		StrDone_v := true;		
		
	end procedure;
	
	procedure daq (
		signal Clk : in std_logic;
		signal PostTrigSpls : inout std_logic_vector;
		signal Mode : inout RecMode_t;
		signal Daq_Vld : in std_logic;
		signal Daq_Rdy : inout std_logic;
		signal Daq_Data : in Input2Daq_Data_t;
		signal Daq_Level : in std_logic_vector;
		signal Daq_HasLast : in std_logic;
		signal Ts_Vld : in std_logic;
		signal Ts_Rdy : inout std_logic;
		signal Ts_Data : in std_logic_vector;
		constant Generics_c : Generics_t) is
	begin
		-- Config
		PostTrigSpls <= std_logic_vector(to_unsigned(0, 32));
		Daq_Rdy <= '0';
		
		-- After provoking overflow, read three frames to free space in TS FIFO (to check if this does not have effect until data FIFO empty)
		while not StrDone_v loop
			wait until rising_edge(Clk);
		end loop;
		StrDone_v := false;
		CheckAcqData (2, 0, Generics_c, FrameType_Trigger_c, Clk, Daq_Vld, Daq_Rdy, Daq_Data, Ts_Vld, Ts_Rdy, Ts_Data);
		CheckAcqData (2, 1, Generics_c, FrameType_Trigger_c, Clk, Daq_Vld, Daq_Rdy, Daq_Data, Ts_Vld, Ts_Rdy, Ts_Data);
		CheckAcqData (2, 2, Generics_c, FrameType_Trigger_c, Clk, Daq_Vld, Daq_Rdy, Daq_Data, Ts_Vld, Ts_Rdy, Ts_Data);
		CheckDone_v := true;
		
		-- Read remaining good frames
		while not StrDone_v loop
			wait until rising_edge(Clk);
		end loop;
		StrDone_v := false;		
		for i in 3 to StreamTsFifoDepth_g-2 loop
			CheckAcqData (2, i, Generics_c, FrameType_Trigger_c, Clk, Daq_Vld, Daq_Rdy, Daq_Data, Ts_Vld, Ts_Rdy, Ts_Data);
		end loop;
		
		-- Read bad frames
		for i in 0 to 2 loop
			CheckAcqData (2, -1, Generics_c, FrameType_Trigger_c, Clk, Daq_Vld, Daq_Rdy, Daq_Data, Ts_Vld, Ts_Rdy, Ts_Data, True);
		end loop;
		wait for 1 us; -- leave some time since recovery requires some clock cycles of empty TS FIFO and not triggers in Data FIFO
		CheckDone_v := true;
		
		-- Check two good frames to check recovery
		while not StrDone_v loop
			wait until rising_edge(Clk);
		end loop;
		StrDone_v := false;	
		CheckAcqData (2, 1000, Generics_c, FrameType_Trigger_c, Clk, Daq_Vld, Daq_Rdy, Daq_Data, Ts_Vld, Ts_Rdy, Ts_Data);
		CheckAcqData (2, 1001, Generics_c, FrameType_Trigger_c, Clk, Daq_Vld, Daq_Rdy, Daq_Data, Ts_Vld, Ts_Rdy, Ts_Data);
		
		
	end procedure;
	
end;
