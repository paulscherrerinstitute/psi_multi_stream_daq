------------------------------------------------------------------------------
--  Copyright (c) 2019 by Paul Scherrer Institute, Switzerland
--  All rights reserved.
--  Authors: Oliver Bruendler
------------------------------------------------------------------------------

------------------------------------------------------------------------------
-- Libraries
------------------------------------------------------------------------------
library ieee;
	use ieee.std_logic_1164.all;
	use ieee.numeric_std.all;

    use ieee.math_real.all;
    
library work;
	use work.psi_common_math_pkg.all;
    use work.psi_ms_daq_pkg.all;
    
------------------------------------------------------------------------------
-- Entity Declaration
------------------------------------------------------------------------------
entity psi_ms_daq_axi_if is
	generic (
		AxiDataWidth_g			: natural range 64 to 1024	:= 64;
		AxiMaxBeats_g			: natural range 1 to 256	:= 256;
		AxiMaxOpenTrasactions_g	: natural range 1 to 8		:= 8;
		MaxOpenCommands_g		: positive					:= 16;
		DataFifoDepth_g			: natural					:= 1024;
		RamBehavior_g			: string					:= "RBW"
	);
	port (
		-- Control Signals
		Clk				: in 	std_logic;
		Rst_n			: in 	std_logic;
		
		-- Write Command
		Cmd_Addr		: in	std_logic_vector(31 downto 0);
		Cmd_Size		: in	std_logic_vector(31 downto 0);  
		Cmd_Vld			: in	std_logic;
		Cmd_Rdy			: out	std_logic;
		
		-- Write Data
		Dat_Data		: in	std_logic_vector(MemoryBusWidth_c-1 downto 0);
		Dat_Vld			: in	std_logic;
		Dat_Rdy			: out	std_logic;
		
		-- Response
		Done			: out	std_logic;
			
		-- AXI Address Write Channel
		M_Axi_AwAddr	: out	std_logic_vector(31 downto 0);									
		M_Axi_AwLen		: out	std_logic_vector(7 downto 0);													
		M_Axi_AwSize	: out	std_logic_vector(2 downto 0);													
		M_Axi_AwBurst	: out	std_logic_vector(1 downto 0);													
		M_Axi_AwLock	: out	std_logic;																		
		M_Axi_AwCache	: out	std_logic_vector(3 downto 0);													
		M_Axi_AwProt	: out	std_logic_vector(2 downto 0);													
		M_Axi_AwValid	: out	std_logic;                                                  					
		M_Axi_AwReady	: in	std_logic                                             	:= '0';			     	
	
		-- AXI Write Data Channel                                                           					
		M_Axi_WData		: out	std_logic_vector(AxiDataWidth_g-1 downto 0);                					
		M_Axi_WStrb		: out	std_logic_vector(AxiDataWidth_g/8-1 downto 0);              					
		M_Axi_WLast		: out	std_logic;                                                  					
		M_Axi_WValid	: out	std_logic;                                                  					
		M_Axi_WReady	: in	std_logic                                              := '0';				    
	
		-- AXI Write Response Channel                                                      
		M_Axi_BResp		: in	std_logic_vector(1 downto 0)                           := (others => '0');	    
		M_Axi_BValid	: in	std_logic                                              := '0';				    
		M_Axi_BReady	: out	std_logic;                                                  					
	
		-- AXI Read Address Channel                                               
		M_Axi_ArAddr	: out	std_logic_vector(31 downto 0);                					
		M_Axi_ArLen		: out	std_logic_vector(7 downto 0);                               					
		M_Axi_ArSize	: out	std_logic_vector(2 downto 0);                               					
		M_Axi_ArBurst	: out	std_logic_vector(1 downto 0);                               					
		M_Axi_ArLock	: out	std_logic;                                                  					
		M_Axi_ArCache	: out	std_logic_vector(3 downto 0);                               					
		M_Axi_ArProt	: out	std_logic_vector(2 downto 0);                               					
		M_Axi_ArValid	: out	std_logic;                                                  					
		M_Axi_ArReady	: in	std_logic                                           	:= '0';					
	
		-- AXI Read Data Channel                                                      
		M_Axi_RData		: in	std_logic_vector(AxiDataWidth_g-1 downto 0)             := (others => '0');    	
		M_Axi_RResp		: in	std_logic_vector(1 downto 0)                            := (others => '0');	    
		M_Axi_RLast		: in	std_logic                                               := '0';				    
		M_Axi_RValid	: in	std_logic                                               := '0';				    
		M_Axi_RReady	: out	std_logic		                                        						
	);
end entity;
		
------------------------------------------------------------------------------
-- Architecture Declaration
------------------------------------------------------------------------------
architecture rtl of psi_ms_daq_axi_if is	
	signal Rst					: std_logic;
	
	subtype CommandAddrRng_c 	is natural range 31 downto 0;
	subtype CommandSizeRng_c	is natural range 63 downto 32;
	constant WrCmdWidth_c		: integer	:= CommandSizeRng_c'high+1;	
	signal InfoFifoIn			: std_logic_vector(WrCmdWidth_c-1 downto 0);
	signal InfoFifoOut			: std_logic_vector(WrCmdWidth_c-1 downto 0);
	signal WrCmdFifo_Vld		: std_logic;
	signal WrCmdFifo_Rdy		: std_logic;
	signal WrCmdFifo_Addr		: std_logic_vector(31 downto 0);
	signal WrCmdFifo_Size		: std_logic_vector(31 downto 0);
	signal DoneI				: std_logic;
	signal ErrorI				: std_logic;

begin
	Rst <= not Rst_n;
	
	InfoFifoIn(CommandAddrRng_c) <= Cmd_Addr;
    InfoFifoIn(CommandSizeRng_c) <= Cmd_Size;

    	
	i_wrinfo_fifo : entity work.psi_common_sync_fifo
		generic map (
			Width_g			=> WrCmdWidth_c,
			Depth_g			=> MaxOpenCommands_g*16,
			RamStyle_g		=> "distributed"
		)
		port map (
			Clk			=> Clk,
			Rst			=> Rst,
			InData		=> InfoFifoIn,
			InVld		=> Cmd_Vld,
			InRdy		=> Cmd_Rdy,
			OutData		=> InfoFifoOut,
			OutVld		=> WrCmdFifo_Vld,
			OutRdy		=> WrCmdFifo_Rdy
		);
		
	WrCmdFifo_Addr <= InfoFifoOut(CommandAddrRng_c);
	WrCmdFifo_Size <= InfoFifoOut(CommandSizeRng_c);	

	i_axi : entity work.psi_common_axi_master_full
		generic map (
			AxiAddrWidth_g				=> 32,
			AxiDataWidth_g				=> AxiDataWidth_g,
			AxiMaxBeats_g				=> AxiMaxBeats_g,
			AxiMaxOpenTrasactions_g		=> AxiMaxOpenTrasactions_g,
			UserTransactionSizeBits_g	=> 32,
			DataFifoDepth_g				=> DataFifoDepth_g,
			DataWidth_g					=> MemoryBusWidth_c,
			ImplRead_g					=> false,
			ImplWrite_g					=> true,
			RamBehavior_g				=> RamBehavior_g
		)
		port map (
			-- Control Signals
			M_Axi_Aclk		=> Clk,
			M_Axi_Aresetn	=> Rst_n,			
			-- User Command Interface Write
			CmdWr_Addr		=> WrCmdFifo_Addr,
			CmdWr_Size		=> WrCmdFifo_Size,
			CmdWr_LowLat	=> '0',
			CmdWr_Vld		=> WrCmdFifo_Vld,
			CmdWr_Rdy		=> WrCmdFifo_Rdy,			
			-- User Command Interface Read (unused)
			CmdRd_Addr		=> (others => '0'),
			CmdRd_Size		=> (others => '0'),
			CmdRd_LowLat	=> '0',
			CmdRd_Vld		=> '0',
			CmdRd_Rdy		=> open,			
			-- Write Data
			WrDat_Data		=> Dat_Data,
			WrDat_Vld		=> Dat_Vld,
			WrDat_Rdy		=> Dat_Rdy,
			-- Read Data (unused)
			RdDat_Data		=> open,
			RdDat_Vld		=> open,
			RdDat_Rdy		=> '0',		
			-- Response
			Wr_Done			=> DoneI,
			Wr_Error		=> ErrorI,
			Rd_Done			=> open,
			Rd_Error		=> open,
			-- AXI Address Write Channel
			M_Axi_AwAddr	=> M_Axi_AwAddr,
			M_Axi_AwLen		=> M_Axi_AwLen,
			M_Axi_AwSize	=> M_Axi_AwSize,
			M_Axi_AwBurst	=> M_Axi_AwBurst,
			M_Axi_AwLock	=> M_Axi_AwLock,
			M_Axi_AwCache	=> M_Axi_AwCache,
			M_Axi_AwProt	=> M_Axi_AwProt,
			M_Axi_AwValid	=> M_Axi_AwValid,
			M_Axi_AwReady	=> M_Axi_AwReady,
			-- AXI Write Data Channel 
			M_Axi_WData		=> M_Axi_WData,
			M_Axi_WStrb		=> M_Axi_WStrb,	
			M_Axi_WLast		=> M_Axi_WLast,	
			M_Axi_WValid	=> M_Axi_WValid,
			M_Axi_WReady	=> M_Axi_WReady,
			-- AXI Write Response Channel                                                      
			M_Axi_BResp		=> M_Axi_BResp,
			M_Axi_BValid	=> M_Axi_BValid,
			M_Axi_BReady	=> M_Axi_BReady,
			-- AXI Read Address Channel                                               
			M_Axi_ArAddr	=> M_Axi_ArAddr,	
			M_Axi_ArLen		=> M_Axi_ArLen,	
			M_Axi_ArSize	=> M_Axi_ArSize,	
			M_Axi_ArBurst	=> M_Axi_ArBurst,	
			M_Axi_ArLock	=> M_Axi_ArLock,	
			M_Axi_ArCache	=> M_Axi_ArCache,	
			M_Axi_ArProt	=> M_Axi_ArProt,	
			M_Axi_ArValid	=> M_Axi_ArValid,	
			M_Axi_ArReady	=> M_Axi_ArReady,	
			-- AXI Read Data Channel                                                      
			M_Axi_RData		=> M_Axi_RData,
			M_Axi_RResp		=> M_Axi_RResp,	
			M_Axi_RLast		=> M_Axi_RLast,	
			M_Axi_RValid	=> M_Axi_RValid,
			M_Axi_RReady	=> M_Axi_RReady
		);	
       
	Done <= DoneI or ErrorI;
	
	
end;	





