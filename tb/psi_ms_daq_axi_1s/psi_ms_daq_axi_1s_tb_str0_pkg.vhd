------------------------------------------------------------------------------
--  Copyright (c) 2019 by Paul Scherrer Institute, Switzerland
--  All rights reserved.
--  Authors: Oliver Bruendler
------------------------------------------------------------------------------

------------------------------------------------------------
-- Description
------------------------------------------------------------
-- Stream 0 works in ringbuffer mode (without overwrite). It 
-- produces 8-bit data (modulo counter). IRQs are located at samples
-- containing data 30, 60 and 90. IRQs are suppressed until 15 us after
-- simulation to see if IRQ enable works correctly.
-- The IRQ handler also sets the window sample counter to zero to ensure
-- more data can be recorded after the IRQ.

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
	use work.psi_ms_daq_axi_tb_pkg.all;
	use work.psi_tb_axi_pkg.all;

------------------------------------------------------------
-- Package Header
------------------------------------------------------------
package psi_ms_daq_axi_1s_tb_str0_pkg is

	constant PrintStr0_c			: boolean	:= PrintDefault_c;

	-- Memory
	constant Str0BufStart_c			: integer	:= 16#1000#;
	constant Str0WinSize_c			: integer	:= 100;
	constant Str0Windows_c			: integer	:= 3;
	alias Memory0 : t_aslv8(0 to Str0WinSize_c*Str0Windows_c) is Memory(Str0BufStart_c to Str0BufStart_c+Str0WinSize_c*Str0Windows_c);
	
	--------------------------------------------------------
	-- Persistent State
	--------------------------------------------------------
	shared variable Str0NextWin 	: integer := 0;
	shared variable Str0WinCheck 	: integer := 0;
	shared variable Str0LastTs 		: integer;	
	shared variable Str0IrqOn 		: boolean := false;
	shared variable Str0Disabled	: boolean := false;

	--------------------------------------------------------
	-- Data Generation
	--------------------------------------------------------
	procedure Str0Sample(	signal clk	: in	std_logic;
							signal vld	: out	std_logic;
							signal trig	: out	std_logic;
							signal data : out	std_logic_vector(7 downto 0));
							
	--------------------------------------------------------
	-- IRQ Handler
	--------------------------------------------------------
	procedure Str0Handler(	signal	clk			: in	std_logic;
							signal	rqst		: out 	axi_ms_r;
							signal	rsp			: in	axi_sm_r);	

	--------------------------------------------------------
	-- Setup
	--------------------------------------------------------
	procedure Str0Setup(	signal clk			: in	std_logic;
							signal rqst			: out	axi_ms_r;
							signal rsp			: in	axi_sm_r);

	--------------------------------------------------------
	-- Update
	--------------------------------------------------------
	procedure Str0Update(	signal clk			: in	std_logic;
							signal rqst			: out	axi_ms_r;
							signal rsp			: in	axi_sm_r);							
							
							
end package;

------------------------------------------------------------
-- Package Body
------------------------------------------------------------
package body psi_ms_daq_axi_1s_tb_str0_pkg is

	--------------------------------------------------------
	-- Data Generation
	--------------------------------------------------------
	procedure Str0Sample(	signal clk	: in	std_logic;
							signal vld	: out	std_logic;
							signal trig	: out	std_logic;
							signal data : out	std_logic_vector(7 downto 0)) is
	begin
		vld <= '1';
		if (now > 15 us) and (to_integer(unsigned(data)) = 0) then	
			Str0IrqOn := true;
		end if;
		case to_integer(unsigned(data)) is
			when 30 | 60 | 90 => 	
				if Str0IrqOn then
					trig <= '1';
				end if;
			when others => null;
		end case;
		wait until rising_edge(clk);
		vld <= '0';
		trig <= '0';
		data <= std_logic_vector(unsigned(data)+1);
		wait until rising_edge(clk);
	end procedure;

	--------------------------------------------------------
	-- IRQ Handler
	--------------------------------------------------------
	procedure Str0Handler(	signal	clk			: in	std_logic;
							signal	rqst		: out 	axi_ms_r;
							signal	rsp			: in	axi_sm_r) is
		variable v : integer;
		variable curwin : integer;
		variable lastwin : integer;
		variable wincnt : integer;
		variable winstart, winend : integer;
		variable winlast : integer;
		variable addr : integer;
		variable tslo : integer;
		variable firstLoop : boolean := true;
		variable HasTrigger : boolean;
	begin	
		print("------------ Stream 0 Handler ------------", PrintStr0_c);
		HlGetMaxLvl(0, clk, rqst, rsp, v);
		print("MAXLVL: " & to_string(v), PrintStr0_c);
		HlGetCurWin(0, clk, rqst, rsp, curwin);
		print("CURWIN: " & to_string(curwin), PrintStr0_c);
		HlGetLastWin(0, clk, rqst, rsp, lastwin);
		print("LASTWIN: " & to_string(lastwin), PrintStr0_c);
		print("", PrintStr0_c);
		if Str0Disabled then
			print("Skipped, stream disabled", PrintStr0_c);
			print("", PrintStr0_c);
		else
			HlIsTrigWin(0, Str0NextWin, clk, rqst, rsp, HasTrigger);
			-- lastwin = nextwin can occur if al lwindows are filled. In all cases we only interpret windows containing triggers.
			while ((Str0NextWin /= ((lastwin+1) mod 3)) or firstLoop) and HasTrigger loop
				firstLoop := false;
				print("*** Window " & to_string(Str0NextWin) & " / Number: " & to_string(Str0WinCheck) & " ***", PrintStr0_c);	
				HlGetWinCnt(0, Str0NextWin, clk, rqst, rsp, wincnt);
				print("WINCNT: " & to_string(wincnt), PrintStr0_c);
				HlClrWinCnt(0, Str0NextWin, clk, rqst, rsp);
				HlGetWinLast(0, Str0NextWin, clk, rqst, rsp, winlast);
				print("WINLAST: " & to_string(winlast), PrintStr0_c);	
				HlGetTsLo(0, Str0NextWin, clk, rqst, rsp, tslo);
				print("WINTSLO: " & to_string(tslo), PrintStr0_c);	
				HlGetTsHi(0, Str0NextWin, clk, rqst, rsp, v);
				print("WINTSHI: " & to_string(v), PrintStr0_c);	
				winstart := Str0BufStart_c + Str0NextWin*Str0WinSize_c;
				winend := winstart + Str0WinSize_c - 1;
				case Str0WinCheck is
					when 0 => 
						-- Windows full because dat received for quite some time
						IntCompare(Str0WinSize_c, wincnt, "Stream0: WINCNT wrong");
						-- Check Values
						addr := winlast;

						for i in 256+30+3-99 to 256+30+3 loop
							if addr = winend then
								addr := winstart;
							else
								addr := addr + 1;
							end if;
							StdlvCompareInt (i mod 256, Memory(addr), "Stream0: Wrong value at 0x" & to_hstring(to_unsigned(addr,32)), false);
						end loop;						

					when 1 => 
						-- Trigger following each other with 30 samples difference
						IntCompare(30, wincnt, "Stream0: WINCNT wrong");
						IntCompare(30*2, tslo-Str0LastTs, "Stream0: TS difference wrong");
						-- Check Values
						addr := winstart;
						for i in 34 to 63 loop
							StdlvCompareInt (i, Memory(addr), "Stream0: Wrong value", false);
							addr := addr + 1; -- does never wrap
						end loop;	
						
					when 2 => 
						-- Trigger following each other with 30 samples difference
						IntCompare(30, wincnt, "Stream0: WINCNT wrong");	
						IntCompare(30*2, tslo-Str0LastTs, "Stream0: TS difference wrong");					
						-- Check Values
						addr := winstart;
						for i in 64 to 93 loop
							StdlvCompareInt (i, Memory(addr), "Stream0: Wrong value", false);
							addr := addr + 1; -- does never wrap
						end loop;						
					when 3 => 
						-- Full buffer recorded after emptying first buffer
						IntCompare(100, wincnt, "Stream0: WINCNT wrong");
						IntCompare((256-2*30)*2, tslo-Str0LastTs, "Stream0: TS difference wrong");
						-- Disable stream IRQ				
						AxiRead32(REG_CONF_IRQENA_ADDR, v, clk, rqst, rsp);
						v := IntAnd(v, 16#0FE#);
						AxiWrite32(REG_CONF_IRQENA_ADDR, v, clk, rqst, rsp);
						AxiRead32(REG_CONF_STRENA_ADDR, v, clk, rqst, rsp);
						v := IntAnd(v, 16#0FE#);
						AxiWrite32(REG_CONF_STRENA_ADDR, v, clk, rqst, rsp);
						Str0Disabled := true;					
						-- Check Values
						addr := winlast + 1;
						for i in 256+30+3-99 to 256+30+3 loop
							StdlvCompareInt (i mod 256, Memory(addr), "Stream0: Wrong value", false);
							if addr = winend then
								addr := winstart;
							else
								addr := addr + 1;
							end if;
						end loop;	
						
					when others => null;
				end case;
				print("", PrintStr0_c);
				Str0LastTs := tslo;
				Str0NextWin := (Str0NextWin + 1) mod 3;
				Str0WinCheck := Str0WinCheck + 1;
			end loop;
		end if;
	end procedure;
		
	--------------------------------------------------------
	-- Setup
	--------------------------------------------------------
	procedure Str0Setup(	signal clk			: in	std_logic;
							signal rqst			: out	axi_ms_r;
							signal rsp			: in	axi_sm_r) is
	begin
		HlCheckMaxLvl(0, 0, clk, rqst, rsp);
		HlSetPostTrig(0, 3, clk, rqst, rsp);
		HlSetMode(0, VAL_MODE_RECM_CONT, clk, rqst, rsp);
		HlConfStream(	str => 0, bufstart => Str0BufStart_c, ringbuf => true, overwrite => false, wincnt => Str0Windows_c, winsize => Str0WinSize_c, 
						clk => clk, rqst => rqst, rsp => rsp);
	end procedure;
	
	--------------------------------------------------------
	-- Update
	--------------------------------------------------------
	procedure Str0Update(	signal clk			: in	std_logic;
							signal rqst			: out	axi_ms_r;
							signal rsp			: in	axi_sm_r) is
	begin
	end;
		
end;
