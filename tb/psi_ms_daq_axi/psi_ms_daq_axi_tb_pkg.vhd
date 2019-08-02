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
	use work.psi_tb_axi_pkg.all;

------------------------------------------------------------
-- Package Header
------------------------------------------------------------
package psi_ms_daq_axi_tb_pkg is

	--------------------------------------------------------
	-- Global Stuff
	--------------------------------------------------------
	constant MemSize_c		: integer					:= 16#10000#;
	signal Memory 			: t_aslv8(0 to MemSize_c-1);
	constant MaxWindows_c	: integer					:= 16;
	
	constant PrintDefault_c	: boolean					:= false;
	
	--------------------------------------------------------
	-- Register MAP
	--------------------------------------------------------
	constant REG_CONF_REGION		: integer	:= 16#0000#;
	constant REG_CONF_GCFG_ADDR		: integer	:= REG_CONF_REGION+16#000#;
	constant REG_CONF_GSTAT_ADDR	: integer	:= REG_CONF_REGION+16#004#;
	constant REG_CONF_IRQVEC_ADDR	: integer	:= REG_CONF_REGION+16#010#;
	constant REG_CONF_IRQENA_ADDR	: integer	:= REG_CONF_REGION+16#014#;
	constant REG_CONF_STRENA_ADDR	: integer	:= REG_CONF_REGION+16#020#;
	constant REG_CONF_Xn_STEP		: integer	:= 16#10#;
	constant REG_CONF_MAXLVLn		: integer	:= 16#200#;
	constant REG_CONF_POSTTRIGn		: integer	:= 16#204#;
	constant REG_CONF_MODEn			: integer	:= 16#208#;
	constant REG_CONF_LASTWINn		: integer	:= 16#20C#;
	constant VAL_MODE_RECM_CONT		: integer	:= 0*2**0;
	constant VAL_MODE_RECM_TRIGMASK	: integer	:= 1*2**0;
	constant VAL_MODE_RECM_SINGLE	: integer	:= 2*2**0;
	constant VAL_MODE_RECM_MANUAL	: integer	:= 3*2**0;
	constant VAL_MODE_ARM			: integer	:= 1*2**8;
	constant VAL_MODE_RECORDING		: integer	:= 1*2**16;
	
	constant REG_CTX_REGION			: integer	:= 16#1000#;
	constant REG_CTX_Xn_STEP		: integer	:= 16#20#;
	constant REG_CTX_SCFGn			: integer	:= 16#00#;
	constant VAL_SCFG_RINGBUF		: integer	:= 1*2**0;
	constant VAL_SCFG_OVERWRITE		: integer	:= 1*2**8;
	constant SFT_SCFG_WINCNT		: integer	:= 16;
	constant SFT_SCFG_WINCUR		: integer	:= 24;
	constant MSK_SCFG_WINCUR 		: integer	:= 16#1F000000#;
	constant REG_CTX_BUFSTARTn		: integer	:= 16#04#;
	constant REG_CTX_WINSIZEn		: integer	:= 16#08#;
	constant REG_CTX_PTRn			: integer	:= 16#0C#;	
	
	constant REG_WIN_REGION			: integer	:= 16#4000#;
	constant REG_WIN_STRn_STEP		: integer	:= MaxWindows_c*16#10#;
	constant REG_WIN_WINn_STEP		: integer	:= 16#10#;
	constant REG_WIN_WINCNT			: integer	:= 16#00#;
	constant MSK_WIN_WINCNT_CNT		: integer	:= 16#7FFFFFFF#;
	constant REG_WIN_WINLAST		: integer	:= 16#04#;
	constant REG_WIN_TSLO			: integer	:= 16#08#;
	constant REG_WIN_TSHI			: integer	:= 16#0C#;

	--------------------------------------------------------
	-- Helper Procedures
	--------------------------------------------------------
	function IntAnd(	int : in integer;
						op	: in integer) return integer;
						
	procedure print(	str : in string;
						ena	: in boolean);
	
	--------------------------------------------------------
	-- Axi Procedures
	--------------------------------------------------------	
	procedure AxiWrite32(			address		: in	integer;
									value		: in 	integer;
							signal	clk			: in	std_logic;
							signal	ms			: out 	axi_ms_r;
							signal	sm			: in	axi_sm_r);
							
	procedure AxiRead32(			address		: in	integer;
									value		: out 	integer;
							signal	clk			: in	std_logic;
							signal	ms			: out 	axi_ms_r;
							signal	sm			: in	axi_sm_r);
							
	procedure AxiExpect32(			address		: in	integer;
									value		: in 	integer;
							signal	clk			: in	std_logic;
							signal	ms			: out 	axi_ms_r;
							signal	sm			: in	axi_sm_r;
									msg			: in	string	:= "");
							
	procedure AxiWriteAndRead32(			address		: in	integer;
											value		: in 	integer;
									signal	clk			: in	std_logic;
									signal	ms			: out	axi_ms_r;
									signal 	sm			: in	axi_sm_r;
											msg			: in	string	:= "");
									
	--------------------------------------------------------
	-- High Level Procedures
	--------------------------------------------------------	
	procedure HlCheckMaxLvl(			str			: in	integer;
										expLevel	: in	integer;									
								signal	clk			: in	std_logic;
								signal	ms			: out	axi_ms_r;
								signal 	sm			: in	axi_sm_r);
								
	procedure HlSetPostTrig(			str			: in	integer;
										val 		: in	integer;
								signal	clk			: in	std_logic;
								signal	ms			: out	axi_ms_r;
								signal 	sm			: in	axi_sm_r);	

	procedure HlSetMode(				str			: in	integer;
										val 		: in	integer;
								signal	clk			: in	std_logic;
								signal	ms			: out	axi_ms_r;
								signal 	sm			: in	axi_sm_r);	

	procedure HlConfStream(				str			: in	integer;
										bufstart	: in	integer;
										ringbuf		: in	boolean;
										overwrite	: in	boolean;
										wincnt		: in	integer;
										winsize		: in	integer;
								signal	clk			: in	std_logic;
								signal	rqst		: out	axi_ms_r;
								signal 	rsp			: in	axi_sm_r);
								
	procedure HlIsRecording(			str			: in	integer;
								signal	clk			: in	std_logic;
								signal	ms			: out	axi_ms_r;
								signal 	sm			: in	axi_sm_r;									
										val			: out	boolean);			
								
	procedure HlGetPtr(					str			: in	integer;
								signal	clk			: in	std_logic;
								signal	ms			: out	axi_ms_r;
								signal 	sm			: in	axi_sm_r;									
										val			: out	integer);			

	procedure HlGetMaxLvl(				str			: in	integer;
								signal	clk			: in	std_logic;
								signal	ms			: out	axi_ms_r;
								signal 	sm			: in	axi_sm_r;									
										val			: out	integer);
										
	procedure HlGetLastWin(				str			: in	integer;
								signal	clk			: in	std_logic;
								signal	ms			: out	axi_ms_r;
								signal 	sm			: in	axi_sm_r;									
										val			: out	integer);										
										
	procedure HlGetCurWin(				str			: in	integer;
								signal	clk			: in	std_logic;
								signal	ms			: out	axi_ms_r;
								signal 	sm			: in	axi_sm_r;									
										val			: out	integer);	

	procedure HlGetWinCnt(				str			: in	integer;
										win 		: in	integer;
								signal	clk			: in	std_logic;										
								signal	ms			: out	axi_ms_r;
								signal 	sm			: in	axi_sm_r;									
										val			: out	integer);
										
	procedure HlIsTrigWin(				str			: in	integer;
										win 		: in	integer;
								signal	clk			: in	std_logic;
								signal	ms			: out	axi_ms_r;
								signal 	sm			: in	axi_sm_r;									
										val			: out	boolean);											

	procedure HlClrWinCnt(				str			: in	integer;
										win 		: in	integer;
								signal	clk			: in	std_logic;
								signal	ms			: out	axi_ms_r;
								signal 	sm			: in	axi_sm_r);											

	procedure HlGetWinLast(				str			: in	integer;
										win 		: in	integer;
								signal	clk			: in	std_logic;
								signal	ms			: out	axi_ms_r;
								signal 	sm			: in	axi_sm_r;									
										val			: out	integer);	

	procedure HlGetTsLo(				str			: in	integer;
										win 		: in	integer;
								signal	clk			: in	std_logic;
								signal	ms			: out	axi_ms_r;
								signal 	sm			: in	axi_sm_r;									
										val			: out	integer);										
							
	procedure HlGetTsHi(				str			: in	integer;
										win 		: in	integer;
								signal	clk			: in	std_logic;
								signal	ms			: out	axi_ms_r;
								signal 	sm			: in	axi_sm_r;									
										val			: out	integer);								
							
							
end package;

------------------------------------------------------------
-- Package Body
------------------------------------------------------------
package body psi_ms_daq_axi_tb_pkg is

	--------------------------------------------------------
	-- Helper Procedures
	--------------------------------------------------------
	function IntAnd(	int : in integer;
						op	: in integer) return integer is
		variable intu, opu : signed(31 downto 0);
	begin
		intu := to_signed(int, 32);
		opu := to_signed(op, 32);
		return to_integer(intu and opu);
	end function;
	
	procedure print(	str : in string;
						ena	: in boolean) is
	begin
		if ena then
			print(str);
		end if;
	end procedure;

	--------------------------------------------------------
	-- Axi Procedures
	--------------------------------------------------------
	procedure AxiWrite32(			address		: in	integer;
									value		: in 	integer;
							signal	clk			: in	std_logic;
							signal	ms			: out 	axi_ms_r;
							signal	sm			: in	axi_sm_r) is
	begin
		axi_single_write(address, value, ms, sm, clk);
	end procedure;
							
	procedure AxiRead32(			address		: in	integer;
									value		: out 	integer;
							signal	clk			: in	std_logic;
							signal	ms			: out 	axi_ms_r;
							signal	sm			: in	axi_sm_r) is
	begin
		axi_single_read(address, value, ms, sm, clk);
	end procedure;
							
	procedure AxiExpect32(			address		: in	integer;
									value		: in 	integer;
							signal	clk			: in	std_logic;
							signal	ms			: out 	axi_ms_r;
							signal	sm			: in	axi_sm_r;
									msg			: in	string	:= "") is
	begin
		axi_single_expect(address, value, ms, sm, clk, msg);
	end procedure;
	
	procedure AxiWriteAndRead32(			address		: in	integer;
											value		: in 	integer;
									signal	clk			: in	std_logic;
									signal	ms			: out	axi_ms_r;
									signal 	sm			: in	axi_sm_r;
											msg			: in	string	:= "") is
	begin
		axi_single_write(address, value, ms, sm, clk);
		wait for 400 ns;
		wait until rising_edge(clk);
		axi_single_expect(address, value, ms, sm, clk, msg);
	end procedure;	
	
	--------------------------------------------------------
	-- High Level Procedures
	--------------------------------------------------------
	procedure HlCheckMaxLvl(			str			: in	integer;
										expLevel	: in	integer;
								signal	clk			: in	std_logic;
								signal	ms			: out	axi_ms_r;
								signal 	sm			: in	axi_sm_r) is
	begin
		axi_single_expect(REG_CONF_MAXLVLn+REG_CONF_Xn_STEP*str, expLevel, ms, sm, clk, "HlCheckMaxLvl failed");
	end procedure;
	
	procedure HlSetPostTrig(			str			: in	integer;
										val 		: in	integer;
								signal	clk			: in	std_logic;
								signal	ms			: out	axi_ms_r;
								signal 	sm			: in	axi_sm_r) is
	begin
		AxiWriteAndRead32(REG_CONF_POSTTRIGn+REG_CONF_Xn_STEP*str, val, clk, ms, sm, "HlSetPostTrig failed");
	end procedure;
	
	procedure HlSetMode(				str			: in	integer;
										val 		: in	integer;
								signal	clk			: in	std_logic;
								signal	ms			: out	axi_ms_r;
								signal 	sm			: in	axi_sm_r) is
	begin
		axi_single_write(REG_CONF_MODEn+REG_CONF_Xn_STEP*str, val, ms, sm, clk);
	end procedure;	
	
	procedure HlConfStream(				str			: in	integer;
										bufstart	: in	integer;
										ringbuf		: in	boolean;
										overwrite	: in	boolean;
										wincnt		: in	integer;
										winsize		: in	integer;
								signal	clk			: in	std_logic;
								signal	rqst		: out	axi_ms_r;
								signal 	rsp			: in	axi_sm_r) is
		variable v : integer := 0;
	begin
		AxiWriteAndRead32(	REG_CTX_REGION+REG_CTX_BUFSTARTn+REG_CTX_Xn_STEP*str, 
							bufstart, clk, rqst, rsp, "HlConfStream failed BUFSTART");
		AxiWriteAndRead32(	REG_CTX_REGION+REG_CTX_WINSIZEn+REG_CTX_Xn_STEP*str,
							winsize, clk, rqst, rsp, "HlConfStream failed WINSIZE");
		if ringbuf then
			v := v + VAL_SCFG_RINGBUF;
		end if;
		if overwrite then
			v := v + VAL_SCFG_OVERWRITE;
		end if;
		v := v + (2**SFT_SCFG_WINCNT)*(wincnt-1);
		AxiWriteAndRead32(	REG_CTX_REGION+REG_CTX_SCFGn+REG_CTX_Xn_STEP*str, 
							v, clk, rqst, rsp, "HlConfStream failed SCFG");
	end procedure;
	
	procedure HlIsRecording(			str			: in	integer;
								signal	clk			: in	std_logic;
								signal	ms			: out	axi_ms_r;
								signal 	sm			: in	axi_sm_r;									
										val			: out	boolean) is
		variable v : integer := 0;
	begin
		axi_single_read(REG_CONF_REGION+REG_CONF_MODEn+REG_CONF_Xn_STEP*str,
						v, ms, sm, clk);
		if IntAnd(v, VAL_MODE_RECORDING) /= 0 then
			val := true;
		else
			val := false;
		end if;
	end procedure;
	
	procedure HlGetPtr(					str			: in	integer;
								signal	clk			: in	std_logic;
								signal	ms			: out	axi_ms_r;
								signal 	sm			: in	axi_sm_r;									
										val			: out	integer) is
	begin
		axi_single_read(REG_CTX_REGION+REG_CTX_PTRn+REG_CTX_Xn_STEP*str,
						val, ms, sm, clk);
	end procedure;
	
	procedure HlGetMaxLvl(				str			: in	integer;
								signal	clk			: in	std_logic;
								signal	ms			: out	axi_ms_r;
								signal 	sm			: in	axi_sm_r;									
										val			: out	integer) is
	begin
		axi_single_read(REG_CONF_REGION+REG_CONF_MAXLVLn+REG_CONF_Xn_STEP*str, 
						val, ms, sm, clk);
	end procedure;
	
	procedure HlGetLastWin(				str			: in	integer;
								signal	clk			: in	std_logic;
								signal	ms			: out	axi_ms_r;
								signal 	sm			: in	axi_sm_r;									
										val			: out	integer) is
	begin
		axi_single_read(REG_CONF_REGION+REG_CONF_LASTWINn+REG_CONF_Xn_STEP*str, 
						val, ms, sm, clk);
	end procedure;											
	
	procedure HlGetCurWin(				str			: in	integer;
								signal	clk			: in	std_logic;
								signal	ms			: out	axi_ms_r;
								signal 	sm			: in	axi_sm_r;									
										val			: out	integer) is
		variable v : integer;
	begin
		axi_single_read(REG_CTX_REGION+REG_CTX_SCFGn+REG_CTX_Xn_STEP*str, 
						v, ms, sm, clk);
		v := IntAnd(v, MSK_SCFG_WINCUR);
		v := v / (2**SFT_SCFG_WINCUR);
		val := v;
	end procedure;	
	
	procedure HlGetWinCnt(				str			: in	integer;
										win			: in	integer;
								signal	clk			: in	std_logic;
								signal	ms			: out	axi_ms_r;
								signal 	sm			: in	axi_sm_r;									
										val			: out	integer) is
		variable v : integer;
	begin
		axi_single_read(REG_WIN_REGION+REG_WIN_WINCNT+REG_WIN_STRn_STEP*str+REG_WIN_WINn_STEP*win, 
						v, ms, sm, clk);
		val := IntAnd(v, MSK_WIN_WINCNT_CNT);
	end procedure;	
	
	procedure HlIsTrigWin(				str			: in	integer;
										win 		: in	integer;
								signal	clk			: in	std_logic;
								signal	ms			: out	axi_ms_r;
								signal 	sm			: in	axi_sm_r;									
										val			: out	boolean) is
		variable v : integer;
	begin
		axi_single_read(REG_WIN_REGION+REG_WIN_WINCNT+REG_WIN_STRn_STEP*str+REG_WIN_WINn_STEP*win, 
						v, ms, sm, clk);
		val := v < 0;		
	end procedure;
	
	procedure HlClrWinCnt(				str			: in	integer;
										win			: in	integer;
								signal	clk			: in	std_logic;
								signal	ms			: out	axi_ms_r;
								signal 	sm			: in	axi_sm_r) is
		variable v : integer;
	begin
		axi_single_write(REG_WIN_REGION+REG_WIN_WINCNT+REG_WIN_STRn_STEP*str+REG_WIN_WINn_STEP*win, 
							0, ms, sm, clk);
	end procedure;		

	procedure HlGetWinLast(				str			: in	integer;
										win			: in	integer;
								signal	clk			: in	std_logic;
								signal	ms			: out	axi_ms_r;
								signal 	sm			: in	axi_sm_r;
										val			: out	integer) is
		variable v : integer;
	begin
		axi_single_read(REG_WIN_REGION+REG_WIN_WINLAST+REG_WIN_STRn_STEP*str+REG_WIN_WINn_STEP*win, 
						val, ms, sm, clk);
	end procedure;	

	procedure HlGetTsLo(				str			: in	integer;
										win			: in	integer;
								signal	clk			: in	std_logic;
								signal	ms			: out	axi_ms_r;
								signal 	sm			: in	axi_sm_r;									
										val			: out	integer) is
		variable v : integer;
	begin
		axi_single_read(REG_WIN_REGION+REG_WIN_TSLO+REG_WIN_STRn_STEP*str+REG_WIN_WINn_STEP*win, 
						val, ms, sm, clk);
	end procedure;	

	procedure HlGetTsHi(				str			: in	integer;
										win			: in	integer;
								signal	clk			: in	std_logic;
								signal	ms			: out	axi_ms_r;
								signal 	sm			: in	axi_sm_r;									
										val			: out	integer) is
		variable v : integer;
	begin
		axi_single_read(REG_WIN_REGION+REG_WIN_TSHi+REG_WIN_STRn_STEP*str+REG_WIN_WINn_STEP*win, 
						val, ms, sm, clk);
	end procedure;		
	
	
		
end;
