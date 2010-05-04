-------------------------------------------------------------------------------
--
-- Title       : VME64xCore_Top
-- Design      : VME64xCore
-- Author      : Ziga Kroflic
-- Company     : Cosylab
--
-------------------------------------------------------------------------------
--
-- File        : VME64xCore_Top.vhd
-- Generated   : Tue Mar 30 09:41:05 2010
-- From        : interface description file
-- By          : Itf2Vhdl ver. 1.20
--
-------------------------------------------------------------------------------
--
-- Description : 
--
-------------------------------------------------------------------------------


library IEEE;
use IEEE.STD_LOGIC_1164.all;

entity VME64xCore_Top is
    port(
        clk_i :             in STD_LOGIC;
                            
        VME_AS_n_i :        in STD_LOGIC;
        VME_RST_n_i :       in STD_LOGIC;
        VME_WRITE_n_i :     in STD_LOGIC;
        VME_AM_i :          in STD_LOGIC_VECTOR(5 downto 0);
        VME_DS_n_i :        in STD_LOGIC_VECTOR(1 downto 0);
        VME_GA_i :          in STD_LOGIC_VECTOR(5 downto 0);
        VME_BERR_n_o :      out STD_LOGIC;
        VME_DTACK_n_o :     out STD_LOGIC;
        VME_RETRY_n_o :     out STD_LOGIC;
        VME_LWORD_n_b :     inout STD_LOGIC;
        VME_ADDR_b :        inout STD_LOGIC_VECTOR(31 downto 1);
        VME_DATA_b :        inout STD_LOGIC_VECTOR(31 downto 0);
        VME_BBSY_n_i :      in STD_LOGIC;
        VME_IRQ_n_o :       out std_logic_vector(6 downto 0);
        VME_IACKIN_n_i :    in std_logic;
        VME_IACKOUT_n_o :   out std_logic;
        
        VME_DTACK_OE_o:     out std_logic;
        VME_DATA_DIR_o:     out std_logic;
        VME_DATA_OE_o:      out std_logic;
        VME_ADDR_DIR_o:     out std_logic;
        VME_ADDR_OE_o:      out std_logic;
       
           RST_i:           in std_logic;
        DAT_i:              in std_logic_vector(63 downto 0);
        DAT_o:              out std_logic_vector(63 downto 0);
        ADR_o:              out std_logic_vector(63 downto 0);
        CYC_o:              out std_logic;
        ERR_i:              in std_logic;
        LOCK_o:             out std_logic;
        RTY_i:              in std_logic;
        SEL_o:              out std_logic_vector(7 downto 0);
        STB_o:              out std_logic;
        ACK_i:              in std_logic;
        WE_o:               out std_logic;
        IRQ_i:              in std_logic_vector(6 downto 0)
  );
end VME64xCore_Top;


architecture RTL of VME64xCore_Top is 

component VME_bus
  port(
        clk_i :             in STD_LOGIC;
        reset_o:            out STD_LOGIC;
     
         -- VME signals
        VME_RST_n_i :         in STD_LOGIC;
        VME_AS_n_i :          in STD_LOGIC;
        VME_LWORD_n_b :       inout STD_LOGIC;
        VME_RETRY_n_o :       out STD_LOGIC;
        VME_WRITE_n_i :       in STD_LOGIC;
        VME_DS_n_i :          in STD_LOGIC_VECTOR(1 downto 0);
        VME_GA_i :            in STD_LOGIC_VECTOR(5 downto 0);             -- Geographical Address and GA parity
        VME_DTACK_n_o :       out STD_LOGIC;
        VME_BERR_n_o :        out STD_LOGIC;
        VME_ADDR_b :          inout STD_LOGIC_VECTOR(31 downto 1);
        VME_DATA_b :          inout STD_LOGIC_VECTOR(31 downto 0);
        VME_AM_i :            in std_logic_vector(5 downto 0);
        VME_BBSY_n_i :        in std_logic;
        VME_IACKIN_n_i:       in std_logic;
        
        VME_DTACK_OE_o:       out std_logic;
        VME_DATA_DIR_o:       out std_logic;
        VME_DATA_OE_o:        out std_logic;
        VME_ADDR_DIR_o:       out std_logic;
        VME_ADDR_OE_o:        out std_logic;
        
        -- CROM
        CRaddr_o:             out std_logic_vector(18 downto 0);
        CRdata_i:             in std_logic_vector(7 downto 0);
        
        -- CRAM
        CRAMaddr_o:           out std_logic_vector(18 downto 0);
        CRAMdata_o:           out std_logic_vector(7 downto 0);
        CRAMdata_i:           in std_logic_vector(7 downto 0);
        CRAMwea_o:            out std_logic;
        
        -- WB signals
        memReq_o:             out std_logic;
        memAckWB_i:           in std_logic;
        wbData_o:             out std_logic_vector(63 downto 0);
        wbData_i:             in std_logic_vector(63 downto 0);
        locAddr_o:            out std_logic_vector(63 downto 0);
        wbSel_o:              out std_logic_vector(7 downto 0);
        RW_o:                 out std_logic;
        lock_o:               out std_logic;
        cyc_o:                out std_logic;
        err_i:                in std_logic;
        rty_i:                in std_logic;
        mainFSMreset_o:       out std_logic;
        
        -- IRQ controller signals
        irqDTACK_i:          in std_logic;
        IACKinProgress_i:    in std_logic;
        IDtoData_i:          in std_logic;
        
        -- 2eSST related signals
        FIFOwren_o:         out std_logic;
        FIFOdata_o:         out std_logic_vector(63 downto 0);
        SSTinProgress_o:    out std_logic;
        WBbusy_i:           in std_logic
		
         );
end component; 

component WB_bus is   
    port (
        clk_i:           in std_logic;
        reset_i:         in std_logic;                        -- propagated from VME
        
        RST_i:           in std_logic;
        DAT_i:           in std_logic_vector(63 downto 0);
        DAT_o:           out std_logic_vector(63 downto 0);
        ADR_o:           out std_logic_vector(63 downto 0);
        CYC_o:           out std_logic;
        ERR_i:           in std_logic;
        LOCK_o:          out std_logic;
        RTY_i:           in std_logic;
        SEL_o:           out std_logic_vector(7 downto 0);
        STB_o:           out std_logic;
        ACK_i:           in std_logic;
        WE_o:            out std_logic;
        IRQ_i:           in std_logic_vector(6 downto 0);
        
        memReq_i:        in std_logic;                 
        memAck_o:        out std_logic;                  
        locData_o:       out std_logic_vector(63 downto 0); 
        locData_i:       in std_logic_vector(63 downto 0);
        locAddr_i:       in std_logic_vector(63 downto 0);
        sel_i:           in std_logic_vector(7 downto 0);
        RW_i:            in std_logic;                 
        lock_i:          in std_logic;                 
        IRQ_o:           out std_logic_vector(6 downto 0);
        err_o:           out std_logic;
        rty_o:           out std_logic;
        cyc_i:           in std_logic;
        
        mainFSMreset_i:  in std_logic;
        
        FIFOrden_o:      out std_logic;
        FIFOdata_i:      in std_logic_vector(63 downto 0);
        FIFOempty_i:     in std_logic;
        SSTinProgress_i: in std_logic;
        WBbusy_o:        out std_logic
        
        );    
end component; 

component IRQ_controller is
     port(
        clk_i :             in std_logic;
        reset_i :           in std_logic;
        VME_IRQ_n_o :       out std_logic_vector(6 downto 0);
        VME_IACKIN_n_i :    in std_logic;
        VME_IACKOUT_n_o :   out std_logic;
        VME_AS_n_i :        in STD_LOGIC;
        VME_DS_n_i :        in STD_LOGIC_VECTOR(1 downto 0);
        irqDTACK_o :        out std_logic;
        IACKinProgress_o:   out std_logic;
        IRQ_i:              in std_logic_vector(6 downto 0);
        locAddr_i:          in std_logic_vector(3 downto 1);
        IDtoData_o:         out std_logic
        );
end component;

component CR
  port (
       addra :    in STD_LOGIC_VECTOR(11 downto 0);
       clka :     in STD_LOGIC;
       douta :    out STD_LOGIC_VECTOR(7 downto 0)
  );
end component;

component CRAM is
    port (
    clka:    IN std_logic;
    wea:     IN std_logic_VECTOR(0 downto 0);
    addra:   IN std_logic_VECTOR(8 downto 0);
    dina:    IN std_logic_VECTOR(7 downto 0);
    douta:   OUT std_logic_VECTOR(7 downto 0));
end component;

component FIFO is
    port (
    clk:   IN std_logic;
    din:   IN std_logic_VECTOR(63 downto 0);
    rd_en: IN std_logic;
    rst:   IN std_logic;
    wr_en: IN std_logic;
    dout:  OUT std_logic_VECTOR(63 downto 0);
    empty: OUT std_logic;
    full:  OUT std_logic);
end component;

signal s_CRAMdataOut: std_logic_vector(7 downto 0);
signal s_CRAMaddr: std_logic_vector(18 downto 0);   
signal s_CRAMdataIn: std_logic_vector(7 downto 0); 
signal s_CRAMwea: std_logic;    
signal s_CRaddr: std_logic_vector(18 downto 0);     
signal s_CRdata: std_logic_vector(7 downto 0);     
signal s_RW: std_logic; 
signal s_lock: std_logic;
signal s_locAddr: std_logic_vector(63 downto 0);   
signal s_WBdataIn: std_logic_vector(63 downto 0);  
signal s_WBdataOut: std_logic_vector(63 downto 0); 
signal s_WBsel: std_logic_vector(7 downto 0);     
signal s_memAckWB: std_logic;  
signal s_memReq: std_logic;
signal s_IRQ: std_logic_vector(6 downto 0);
signal s_cyc: std_logic;
signal s_reset: std_logic; 
signal s_err: std_logic;
signal s_rty: std_logic;

signal s_irqDTACK: std_logic;      
signal s_IACKinProgress: std_logic;

signal s_mainFSMreset: std_logic;

signal s_FIFOwren: std_logic;
signal s_FIFOdin: std_logic_vector(63 downto 0); 
signal s_FIFOdout: std_logic_vector(63 downto 0);
signal s_FIFOempty: std_logic;
signal s_FIFOfull: std_logic;
signal s_FIFOrden: std_logic;
signal s_SSTinProgress: std_logic;
signal s_WBbusy: std_logic;

signal s_IDtoData: std_logic;

begin

VME_bus_1 : VME_bus
  port map(
       VME_AM_i =>           VME_AM_i,
       VME_AS_n_i =>         VME_AS_n_i,
       VME_DS_n_i =>         VME_DS_n_i,
       VME_GA_i =>           VME_GA_i,
       VME_RST_n_i =>        VME_RST_n_i,
       VME_WRITE_n_i =>      VME_WRITE_n_i,
       VME_BERR_n_o =>       VME_BERR_n_o,
       VME_DTACK_n_o =>      VME_DTACK_n_o,
       VME_RETRY_n_o =>      VME_RETRY_n_o,
       VME_ADDR_b =>         VME_ADDR_b,
       VME_DATA_b =>         VME_DATA_b,
       VME_LWORD_n_b =>      VME_LWORD_n_b,
       VME_BBSY_n_i =>        VME_BBSY_n_i,
       VME_IACKIN_n_i =>     VME_IACKIN_n_i,
       
       VME_DTACK_OE_o =>     VME_DTACK_OE_o,
       VME_DATA_DIR_o =>     VME_DATA_DIR_o,
       VME_DATA_OE_o =>      VME_DATA_OE_o, 
       VME_ADDR_DIR_o =>     VME_ADDR_DIR_o,
       VME_ADDR_OE_o =>      VME_ADDR_OE_o, 
                            
       clk_i =>              clk_i,
       reset_o =>            s_reset,
                            
       CRAMdata_i =>         s_CRAMdataOut,
       CRAMaddr_o =>         s_CRAMaddr,
       CRAMdata_o =>         s_CRAMdataIn,
       CRAMwea_o =>          s_CRAMwea,
       CRaddr_o =>           s_CRaddr,
       CRdata_i =>           s_CRdata,
       RW_o =>               s_RW,
       lock_o =>             s_lock,
       cyc_o =>              s_cyc,
                            
       locAddr_o =>          s_locAddr,
       wbData_o =>           s_WBdataIn,
       wbData_i =>           s_WBdataOut,
       wbSel_o =>            s_WBsel,
       memAckWB_i =>         s_memAckWB,
       memReq_o =>           s_memReq,
       err_i =>              s_err,
       rty_i =>              s_rty,
       mainFSMreset_o =>     s_mainFSMreset,
                            
       irqDTACK_i =>         s_irqDTACK,
       IACKinProgress_i =>   s_IACKinProgress,
       IDtoData_i =>         s_IDtoData,
       
       FIFOwren_o =>         s_FIFOwren,   
       FIFOdata_o =>         s_FIFOdin,
       SSTinProgress_o =>    s_SSTinProgress,
       WBbusy_i    =>        s_WBbusy
  );
  
WB_bus_1: WB_bus  
    port map(
        clk_i =>     clk_i,
        reset_i =>   s_reset,
        
        RST_i =>     RST_i,
        DAT_i =>     DAT_i,
        DAT_o =>     DAT_o,
        ADR_o =>     ADR_o,
        CYC_o =>     CYC_o,
        ERR_i =>     ERR_i,
        LOCK_o =>    LOCK_o,
        RTY_i =>     RTY_i,
        SEL_o =>     SEL_o,
        STB_o =>     STB_o,
        ACK_i =>     ACK_i,
        WE_o =>      WE_o,
        IRQ_i =>     IRQ_i,
        
        memReq_i =>         s_memReq,       
        memAck_o =>         s_memAckWB,                
        locData_o =>        s_wbDataOut,
        locData_i =>        s_wbDataIn,
        locAddr_i =>        s_locAddr,
        sel_i =>            s_wbSel,
        RW_i =>             s_RW,              
        lock_i =>           s_lock,                
        IRQ_o =>            s_IRQ,
        err_o =>            s_err,
        rty_o =>            s_rty,
        cyc_i =>            s_cyc,
        mainFSMreset_i =>   s_mainFSMreset,
        
        FIFOrden_o =>       s_FIFOrden,
        FIFOdata_i =>       s_FIFOdout,
        FIFOempty_i =>       s_FIFOempty,
        SSTinProgress_i =>   s_SSTinProgress,
        WBbusy_o =>           s_WBbusy
        );
        
IRQ_controller_1: IRQ_controller
     port map(
         clk_i =>            clk_i,
         reset_i =>          s_reset,
        VME_IRQ_n_o =>       VME_IRQ_n_o,    
        VME_IACKIN_n_i =>    VME_IACKIN_n_i,        
        VME_IACKOUT_n_o =>   VME_IACKOUT_n_o,        
        VME_AS_n_i =>        VME_AS_n_i,            
        VME_DS_n_i =>        VME_DS_n_i,    
        irqDTACK_o =>        s_irqDTACK,
        IACKinProgress_o =>  s_IACKinProgress,
        IRQ_i =>             IRQ_i,
        locAddr_i =>         s_locAddr(3 downto 1),
        IDtoData_o =>        s_IDtoData
        );

CR_1 : CR
      port map(
       addra => s_CRaddr(11 downto 0),
       clka =>  clk_i,
       douta => s_CRdata
      );
  
CRAM_1: CRAM
    port map(
        clka =>     clk_i,
        wea(0) =>   s_CRAMwea,
        addra =>    s_CRAMaddr(8 downto 0),
        dina =>     s_CRAMdataIn,
        douta =>    s_CRAMdataOut
        );
        
FIFO_1: FIFO
    port map(
        clk =>   clk_i,
        din =>   s_FIFOdin,
        rd_en => s_FIFOrden,
        rst =>   s_reset,
        wr_en => s_FIFOwren,
        dout =>  s_FIFOdout,
        empty => s_FIFOempty,
        full =>  s_FIFOfull
    );

end RTL;