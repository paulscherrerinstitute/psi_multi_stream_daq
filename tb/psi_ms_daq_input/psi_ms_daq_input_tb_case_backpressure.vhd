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
package psi_ms_daq_input_tb_case_backpressure is
	
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
		
		
	shared variable Samples_v 			: integer := 0;
	shared variable StartReading_v		: boolean := false;
	shared variable ReadingStarted_v	: boolean := false;
		
end package;

------------------------------------------------------------
-- Package Body
------------------------------------------------------------
package body psi_ms_daq_input_tb_case_backpressure is
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
		print(">> Test Back-Pressure Handling");
		wait for 100 ns;
		wait until rising_edge(Str_Clk);
		
		-- Apply samples until the data FIFO is full
		-- Apply Input data
		Str_Trig <= '0';
		Str_Ts <= std_logic_vector(to_unsigned(0, Str_Ts'length));
		while Str_Rdy = '1' loop
			Str_Vld <= '1';			
			Str_Data <= std_logic_vector(to_unsigned(Samples_v, Generics_c.StreamWidth_g));	
			Samples_v := Samples_v + 1;			
			wait until rising_edge(Str_Clk);
			wait for 1 ns;
			if Generics_c.VldPulsed_g then
				Str_Vld <= '0';
				Str_Data <= std_logic_vector(to_unsigned(0, Generics_c.StreamWidth_g));	
				wait until rising_edge(Str_Clk);
				-- Fix in case of sample not being accepted
				if Str_Rdy = '0' then
					Samples_v := Samples_v - 1;
				end if;
			end if;
		end loop;
		
		-- Keep valid 10 more cycles
		Str_Vld <= '1';
		for i in 0 to 9 loop
			wait until rising_edge(Str_Clk);
		end loop;
		Str_Vld <= '0';
		
		-- Apply Trigger
		wait until rising_edge(Str_Clk);
		Str_Trig <= '1';
		Str_Ts <= std_logic_vector(to_unsigned(101, Str_Ts'length));
		wait until rising_edge(Str_Clk);
		Str_Trig <= '0';
		Str_Ts <= std_logic_vector(to_unsigned(0, Str_Ts'length));
		
		-- Add some more invalid samples
		Str_Vld <= '1';
		for i in 0 to 9 loop
			wait until rising_edge(Str_Clk);
		end loop;
		Str_Vld <= '0';
		StartReading_v := true;
		while not ReadingStarted_v loop
			wait until rising_edge(Str_Clk);
		end loop;

		
		-- Apply 9 more samples (trigger + 8 post-trig)
		Str_Vld <= '1';	
		for i in 0 to 8 loop
			Str_Data <= std_logic_vector(to_unsigned(Samples_v, Generics_c.StreamWidth_g));
			wait until rising_edge(Str_Clk) and Str_Rdy = '1';				
			Samples_v := Samples_v + 1;	
		end loop;
		Str_Vld <= '0';			

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
		PostTrigSpls <= std_logic_vector(to_unsigned(8, 32));
		Daq_Rdy <= '0';
		
		-- Check result
		while not StartReading_v loop
			wait until rising_edge(Clk);
		end loop;
		ReadingStarted_v := true;
		CheckAcqData (Samples_v+9, 101, Generics_c, FrameType_Trigger_c, Clk, Daq_Vld, Daq_Rdy, Daq_Data, Ts_Vld, Ts_Rdy, Ts_Data);
		
	end procedure;
	
end;
