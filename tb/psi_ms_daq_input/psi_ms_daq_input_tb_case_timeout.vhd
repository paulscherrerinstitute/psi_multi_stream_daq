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
	use work.psi_tb_compare_pkg.all;

------------------------------------------------------------
-- Package Header
------------------------------------------------------------
package psi_ms_daq_input_tb_case_timeout is
	
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
		
	shared variable CheckDone_v	: boolean := false;
		
end package;

------------------------------------------------------------
-- Package Body
------------------------------------------------------------
package body psi_ms_daq_input_tb_case_timeout is
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
		wait for 100 ns;
		wait until rising_edge(Str_Clk);
		
		-- Apply 11 samples and then wait for timeout
		print(">> Timeout - After odd number of samples");
		ApplyStrData(11, 1000, 1, Generics_c, Str_Clk, Str_Vld, Str_Rdy, Str_Data, Str_Trig, Str_Ts);
		wait until rising_edge(Str_Clk);		
		while not CheckDone_v loop
			wait until rising_edge(Str_Clk);
		end loop;
		CheckDone_v := false;
		
		-- Apply 16 samples and then wait for timeout
		print(">> Timeout - After even number of samples");
		ApplyStrData(16, 1000, 2, Generics_c, Str_Clk, Str_Vld, Str_Rdy, Str_Data, Str_Trig, Str_Ts);
		wait until rising_edge(Str_Clk);
		while not CheckDone_v loop
			wait until rising_edge(Str_Clk);
		end loop;
		CheckDone_v := false;
	
		
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
		PostTrigSpls <= std_logic_vector(to_unsigned(3, 32));
		Daq_Rdy <= '0';
		

		
		-- *** Timeout - After odd number of samples ***
		-- Check if no data is available prior to the timeout
		wait for StreamTimeout_g*(1 sec) - 1 us;
		wait until rising_edge(Clk);
		StdlCompare(0, Daq_HasLast, "HastTlast asserted unexpectedly");
		-- Check data after timeout
		wait for 2 us;
		wait until rising_edge(Clk);
		CheckAcqData (11, 1, Generics_c, FrameType_Timeout_c, Clk, Daq_Vld, Daq_Rdy, Daq_Data, Ts_Vld, Ts_Rdy, Ts_Data);	
		CheckDone_v := true;
		
		-- *** Timeout - After even number of samples *** 
		-- Check if no data is available prior to the timeout
		wait for StreamTimeout_g*(1 sec) - 1 us;
		wait until rising_edge(Clk);
		StdlCompare(0, Daq_HasLast, "HastTlast asserted unexpectedly");
		-- Check data after timeout
		wait for 2 us;
		wait until rising_edge(Clk);
		CheckAcqData (16, 2, Generics_c, FrameType_Timeout_c, Clk, Daq_Vld, Daq_Rdy, Daq_Data, Ts_Vld, Ts_Rdy, Ts_Data);
		CheckDone_v := true;
		
	end procedure;
	
end;
