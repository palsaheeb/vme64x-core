--______________________________________________________________________________|
--                             VME TO WB INTERFACE                              |
--                                                                              |
--                                CERN,BE/CO-HT                                 |
--______________________________________________________________________________|
-- File:                           VME_bus.vhd                                  |
--______________________________________________________________________________|
-- Description:                                                                 |

-- This block acts as interface between the VMEbus and the CR/CSR space or WBbus.
--                                                                              |
--                             _____________VME_bus________________             |
--                            |                    _______         |            |
--                            |         ______    | M     |        |            |
--                            |        | A  D |   | A   F |    ____|            |
--                            |        | C  E |   | I   S |   |  W |            |
--                            |        | C  C |   | N   M |   |  B |            |
--                    VME     |        | E  O |   |       |   |    |            |
--                    BUS     |        | S  D |   |_______|   |  M |            |
--                            |        | S  E |               |  A |            |
--                            |        |______|               |  S |            |
--                            |         ______    ___________ |  T |            |
--                            |        |   I  |  |  OTHER    ||  E |            |
--                            |        |   N  |  |  DATA &   ||  R |            |
--                            |        |   I  |  |  ADDR     ||____|            |
--                            |        |   T  |  |  PROCESS  |     |            |
--                            |        |______|  |___________|     |            |
--                            |____________________________________|            |
--                                                                              |                                 
-- The INIT component performs the initialization of the core after the power-up|
-- and the software reset.                                                      |
-- The Access decode component decodes the address to check if the board is the |
-- responding Slave. This component is of fundamental importance, indeed only   |
-- one Slave can answer to th Master!                                           |
-- In the right side you can see the WB Master who implements the Wb Pipelined  |
-- single read/write protocol.                                                  |
-- In this code there are other process to elaborate the data and address lines.|
-- Inside each component is possible read a more detailed description.          |
--______________________________________________________________________________
-- Authors:                                      
--               Pablo Alvarez Sanchez (Pablo.Alvarez.Sanchez@cern.ch)                             
--               Davide Pedretti       (Davide.Pedretti@cern.ch)  
-- Date         06/2012                                                                           
-- Version      v0.01  
--______________________________________________________________________________
--                               GNU LESSER GENERAL PUBLIC LICENSE                                
--                              ------------------------------------                              
-- This source file is free software; you can redistribute it and/or modify it under the terms of 
-- the GNU Lesser General Public License as published by the Free Software Foundation; either     
-- version 2.1 of the License, or (at your option) any later version.                             
-- This source is distributed in the hope that it will be useful, but WITHOUT ANY WARRANTY;       
-- without even the implied warranty of MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.     
-- See the GNU Lesser General Public License for more details.                                    
-- You should have received a copy of the GNU Lesser General Public License along with this       
-- source; if not, download it from http://www.gnu.org/licenses/lgpl-2.1.html                     
---------------------------------------------------------------------------------------

library IEEE;
use IEEE.STD_LOGIC_1164.all;
use IEEE.numeric_std.all;
use IEEE.numeric_std.unsigned;

use work.vme64x_pack.all;

entity VME_bus is
   port(
          clk_i                : in  std_logic;
          reset_o              : out std_logic;
          -- VME signals                                                              
          VME_RST_n_i          : in  std_logic;
          VME_AS_n_i           : in  std_logic;
          VME_LWORD_n_b_o      : out std_logic;
          VME_LWORD_n_b_i      : in  std_logic;
          VME_RETRY_n_o        : out std_logic;
          VME_RETRY_OE_o       : out std_logic;
          VME_WRITE_n_i        : in  std_logic;
          VME_DS_n_i           : in  std_logic_vector(1 downto 0);
          VME_GA_i             : in  std_logic_vector(5 downto 0); --Geograp. Address
          VME_DTACK_n_o        : out std_logic;
          VME_DTACK_OE_o       : out std_logic;
          VME_BERR_o           : out std_logic;
          VME_ADDR_b_i         : in  std_logic_vector(31 downto 1);  
          VME_ADDR_b_o         : out std_logic_vector(31 downto 1);
          VME_ADDR_DIR_o       : out std_logic;
          VME_ADDR_OE_N_o      : out std_logic;
          VME_DATA_b_i         : in  std_logic_vector(31 downto 0);   
          VME_DATA_b_o         : out std_logic_vector(31 downto 0);
          VME_DATA_DIR_o       : out std_logic;
          VME_DATA_OE_N_o      : out std_logic;
          VME_AM_i             : in  std_logic_vector(5 downto 0);     
          VME_BBSY_n_i         : in  std_logic;  -- not used
          VME_IACK_n_i         : in  std_logic;  -- USE VME_IACK_n_i and NOT VME_IACKIN_n_i !!!!
			                                        -- because VME_IACKIN_n_i is delayed the more you
                                                 -- are away from Slots 0
          -- WB signals
          memReq_o             : out std_logic;
          memAckWB_i           : in  std_logic;
          wbData_o             : out std_logic_vector(63 downto 0);
          wbData_i             : in  std_logic_vector(63 downto 0);
          locAddr_o            : out std_logic_vector(63 downto 0);
          wbSel_o              : out std_logic_vector(7 downto 0);
          RW_o                 : out std_logic;
          cyc_o                : out std_logic;
          err_i                : in  std_logic;
          rty_i                : in  std_logic;
          stall_i              : in  std_logic;
          psize_o              : out std_logic_vector(8 downto 0);                    
          --FIFO Signals
          VMEtoWB              : out std_logic;
          WBtoVME              : out std_logic;
          FifoMux              : out std_logic;
          transfer_done_i      : in  std_logic;  
          transfer_done_o      : out std_logic;  
          --CR/CSR space signals:
          CRAMaddr_o           : out std_logic_vector(18 downto 0);
          CRAMdata_o           : out std_logic_vector(7 downto 0);
          CRAMdata_i           : in  std_logic_vector(7 downto 0);
          CRAMwea_o            : out std_logic;
          CRaddr_o             : out std_logic_vector(11 downto 0);
          CRdata_i             : in  std_logic_vector(7 downto 0);
          VME_GA_oversampled_o : out std_logic_vector(5 downto 0);    
          en_wr_CSR            : out std_logic;
          CrCsrOffsetAddr      : out std_logic_vector(18 downto 0);
          CSRData_o            : out std_logic_vector(7 downto 0);
          CSRData_i            : in  std_logic_vector(7 downto 0);
          err_flag_o           : out std_logic;
          reset_flag_i         : in  std_logic;
          Ader0                : in  std_logic_vector(31 downto 0);
          Ader1                : in  std_logic_vector(31 downto 0);
          Ader2                : in  std_logic_vector(31 downto 0);
          Ader3                : in  std_logic_vector(31 downto 0);
          Ader4                : in  std_logic_vector(31 downto 0);
          Ader5                : in  std_logic_vector(31 downto 0);
          Ader6                : in  std_logic_vector(31 downto 0);
          Ader7                : in  std_logic_vector(31 downto 0);
          ModuleEnable         : in  std_logic;
          MBLT_Endian_i        : in  std_logic_vector(2 downto 0);     
          Sw_Reset             : in  std_logic;
          BAR_i                : in  std_logic_vector(4 downto 0);
          numBytes             : out std_logic_vector(12 downto 0);
          transfTime           : out std_logic_vector(39 downto 0);
          -- Debug Davide
          leds                 : out std_logic_vector(7 downto 0)
       );
end VME_bus;

architecture RTL of VME_bus is

   signal s_reset                     : std_logic;                  

  -- Input signals
   signal s_VMEaddrInput              : unsigned(31 downto 1);
   signal s_VMEdataInput              : unsigned(31 downto 0);
   signal s_LWORDinput                : std_logic;                                    

  -- External buffer signals
   signal s_dtackOE                   : std_logic;
   signal s_dataDir 						  : std_logic;
   signal s_dataOE                    : std_logic;
   signal s_addrDir                   : std_logic;
   signal s_addrOE                    : std_logic;

  -- Local data & address
   signal s_locDataIn                 : unsigned(63 downto 0);        
   signal s_locDataOut                : unsigned(63 downto 0);
   signal s_locData                   : unsigned(63 downto 0); -- Local data
   signal s_locAddr, s_rel_locAddr    : unsigned(63 downto 0); -- Local address
   signal s_locAddr2e                 : unsigned(63 downto 0); -- for 2e transfers
   signal s_locAddrBeforeOffset       : unsigned(63 downto 0);
   signal s_phase1addr                : unsigned(63 downto 0); -- for 2e transfers
   signal s_phase2addr                : unsigned(63 downto 0); --
   signal s_phase3addr                : unsigned(63 downto 0); --
   signal s_addrOffset                : unsigned(17 downto 0); -- block transfers|
   signal s_CrCsrOffsetAddr           : unsigned(18 downto 0); -- CR/CSR address 
   signal s_DataShift                 : unsigned(5 downto 0);
   signal s_2eLatchAddr               : std_logic_vector(1 downto 0); -- for 2e transfers
   signal s_locDataSwap               : std_logic_vector(63 downto 0);
   signal s_locDataInSwap             : std_logic_vector(63 downto 0);
   signal s_locDataOutWb              : std_logic_vector(63 downto 0);
  -- Latched signals
   signal s_VMEaddrLatched            : unsigned(63 downto 1); --Latch on AS falling edge
   signal s_LWORDlatched              : std_logic;  -- Stores LWORD on falling edge of AS
   signal s_DSlatched                 : std_logic_vector(1 downto 0);  -- Stores DS
   signal s_AMlatched                 : std_logic_vector(5 downto 0); --Latch on AS f. edge 
   signal s_XAM                       : unsigned(7 downto 0);  -- Stores received XAM  
   signal s_RSTedge                   : std_logic;
  -- Type of data transfer (depending on VME_DS_n, VME_LWORD_n and VME_ADDR(1))

   signal s_typeOfDataTransfer        : t_typeOfDataTransfer;
   signal s_typeOfDataTransferSelect  : std_logic_vector(4 downto 0);   

  -- Addressing type (depending on VME_AM)

   signal s_addressingType            : t_addressingType;
   signal s_addressingTypeSelect      : std_logic_vector(5 downto 0);
   signal s_transferType              : t_transferType;	
   signal s_XAMtype                   : t_XAMtype;
   signal s_2eType                    : t_2eType;
   signal s_addrWidth                 : std_logic_vector(1 downto 0);    
  -- Main FSM signals 

   signal s_mainFSMstate              : t_mainFSMstates;
   signal s_FSM                       : t_FSM;
   signal s_dataToAddrBus             : std_logic;  -- (for D64) --> multiplexed transfer 
   signal s_dataToOutput              : std_logic;   -- Puts data to VME data bus
   signal s_mainDTACK                 : std_logic;       -- DTACK driving

   signal s_memAck                    : std_logic;  -- Memory acknowledge 
   signal s_memAckCSR                 : std_logic;  -- CR/CSR acknowledge
   signal s_memReq                    : std_logic;  -- Global memory request      
   signal s_VMEaddrLatch              : std_logic;  -- pulse on VME_AS_n_i f.edge
   signal s_DSlatch                   : std_logic;  -- Stores data strobes
   signal s_incrementAddr             : std_logic;  -- Increments local address 
   signal s_blockTransferLimit        : std_logic;  -- Block transfer limit
   signal s_mainFSMreset              : std_logic;  -- Resets main FSM on AS r. edge
   signal s_dataPhase                 : std_logic;  -- for A64 and multipl. transf.
   signal s_transferActive            : std_logic;  -- active VME transfer
   signal s_retry                     : std_logic;  -- RETRY signal
   signal s_berr                      : std_logic;  -- BERR signal
   signal s_berr_1                    : std_logic;  --                            
   signal s_berr_2                    : std_logic;  --    

  -- Access decode signals
   signal s_confAccess                : std_logic;  -- Asserted when CR or CSR is addressed
   signal s_cardSel                   : std_logic;  -- Asserted when WB memory is addressed  

  -- WishBone signals
   signal s_sel                       : unsigned(7 downto 0);  -- SEL WB signal
   signal s_nx_sel                    : std_logic_vector(7 downto 0);
   signal s_RW                        : std_logic;             -- RW WB signal                  
  
  -- 2e related signals
   signal s_beatCount                 : unsigned(8 downto 0);  -- for 2e modes
   signal s_cycleCount                : unsigned(7 downto 0);  -- Stores cycle count 
   signal s_DS1pulse                  : std_logic;  -- Pulse on DS1 edge               

  -- CR/CSR related signals
   signal s_CRaddressed               : std_logic;   -- CR is addressed
   signal s_CRAMaddressed             : std_logic;   -- CRAM is addressed
   signal s_CSRaddressed              : std_logic;   -- CSR space is addressed            
   signal s_CSRdata                   : unsigned(7 downto 0);  -- CSR data write/read
   signal s_CRdataIn                  : std_logic_vector(7 downto 0);  -- CR data bus
   signal s_CRAMdataIn                : std_logic_vector(7 downto 0);  -- CRAM data bus
   signal s_FUNC_ADEM                 : t_FUNC_32b_array_std;
   signal s_FUNC_AMCAP                : t_FUNC_64b_array_std;
   signal s_FUNC_XAMCAP               : t_FUNC_256b_array_std;

  -- CR image registers
   signal s_BEG_USER_CSR              : std_logic_vector(23 downto 0);
   signal s_END_USER_CSR              : std_logic_vector(23 downto 0);
   signal s_BEG_USER_CR               : std_logic_vector(23 downto 0);
   signal s_END_USER_CR               : std_logic_vector(23 downto 0);      
   signal s_BEG_CRAM                  : std_logic_vector(23 downto 0);
   signal s_END_CRAM                  : std_logic_vector(23 downto 0);
  -- Error signals
   signal s_BERRcondition             : std_logic;   -- Condition for asserting BERR 
   signal s_wberr1                    : std_logic;
   signal s_rty1                      : std_logic;                           
  -- Initialization signals
   signal s_initInProgress            : std_logic;  --The initialization is in progress
   signal s_initReadCounter           : unsigned(8 downto 0); -- Counts read operations
   signal s_initReadCounter1          : std_logic_vector(8 downto 0);
   signal s_CRaddr                    : unsigned(18 downto 0);

   signal s_is_d64                    : std_logic;
   signal s_base_addr                 : unsigned(63 downto 0);
   signal s_nx_base_addr              : std_logic_vector(63 downto 0);
   signal s_func_sel                  : std_logic_vector(7 downto 0);
   signal s_VMEdata64In               : unsigned(63 downto 0);             

  --flag FIFO: if '1' the FIFO is used                                      
   signal s_FIFO                      : std_logic;
   signal s_transfer_done_i           : std_logic;

  -- 
   signal s_counter                   : unsigned(31 downto 0); 
   signal s_countcyc                  : unsigned(9 downto 0); 
   signal s_BERR_out                  : std_logic;  
   signal s_errorflag                 : std_logic;
   signal s_resetflag                 : std_logic;        
   signal s_led1                      : std_logic;
   signal s_led2                      : std_logic;
	signal s_led3                      : std_logic;
   signal s_led4                      : std_logic;
	signal s_led5                      : std_logic;
   signal s_AckWithError              : std_logic;
   signal s_sw_reset                  : std_logic;
   signal s_decode                    : std_logic;
   signal s_AckWb                     : std_logic;
   signal s_err                       : std_logic;
   signal s_rty                       : std_logic;
  -- transfer rate signals:
   signal s_countertime               : unsigned(19 downto 0);
   signal s_time                      : std_logic_vector(39 downto 0);
   signal s_counterbytes              : unsigned(8 downto 0);
   signal s_bytes                     : std_logic_vector(12 downto 0);
   signal s_time_ns                   : unsigned(39 downto 0);     
   signal s_datawidth                 : unsigned(3 downto 0);
begin
  --
   s_FIFO   <= '0'; -- FIFO not used if '0'
   FifoMux  <= s_FIFO; 
  ---------
   s_is_d64 <= '1' when s_sel= "11111111" else '0'; --for the VME_ADDR_DIR_o |
  ---------	
   s_RW     <= VME_WRITE_n_i; 
   s_reset  <= not(VME_RST_n_i) or s_sw_reset; -- hw and sw reset
   reset_o  <= s_reset;   -- Asserted when high

   VME_GA_oversampled_o <= VME_GA_i;           
   -- the GA lines are connected to the CR_CSR_Space to initialize the BAR   | 
  -------------------------------------------------------------------------
  -- These output signals are connected to the buffers on the board 
  -- SN74VMEH22501A Function table:
  --   OEn | DIR | OUTPUT                 OEAB   |   OEBYn   |   OUTPUT
  --    H  |  X  |   Z                      L    |     H     |     Z
  --    L  |  H  | A to B                   H    |     H     |   A to B
  --    L  |  L  | B to A                   L    |     L     |   B to Y
  --                                        H    |     L     |A to B, B to Y |

   VME_DATA_DIR_o   <= s_dataDir;  
   VME_DATA_OE_N_o  <= s_dataOE; 
   VME_ADDR_DIR_o   <= s_addrDir;            
   VME_ADDR_OE_N_o  <= s_addrOE;           
   VME_DTACK_OE_o   <= s_dtackOE;                          --                |

  -- VME DTACK: 
   VME_DTACK_n_o    <= s_mainDTACK; 
  --------------------------ACCESS MODE DECODERS----------------------------
  -- Type of data transfer decoder
  -- VME64 ANSI/VITA 1-1994...Table 2-2 "Signal levels during data transfers"
  -- A2 is used to select the D64 type  (D64 --> MBLT and 2edge cycles)
  -- VME DATA --> BIG ENDIAN

   s_typeOfDataTransferSelect <= s_DSlatched & s_VMEaddrLatched(1) & 
                                 s_LWORDlatched & s_VMEaddrLatched(2);

  -- These 5 bits are not sufficient to descriminate the D32 and D64 data 
  -- transfer type; indeed the D32 access with A2 = '0' (eg 0x010)
  -- fall within D64 access --> The data transfer type have to be evaluated  
  -- jointly with the address type.
  -- Bytes position on VMEbus: 
  -- A24-A31 | A16-A23 | A08-A15 | A00-A07 | D24-D31 | D16-D23 | D08-D15 | D00-D07 
  --         |         |         |	       |         |         | BYTE(0) | 
  --         |         |         |	       |         |         |         | BYTE(1)
  --         |         |         |	       |         |         | BYTE(2) |
  --         |         |         |	       |         |         |         | BYTE(3)
  --         |         |         |	       |	        |         | BYTE(0) | BYTE(1)
  --         |         |         |	       |	        |         | BYTE(2) | BYTE(3)
  --         |	        |	      |	       |  BYTE(0)| BYTE(1) | BYTE(2) | BYTE(3)
  --  BYTE(0)| BYTE(1) | BYTE(2) | BYTE(3) |  BYTE(4)| BYTE(5) | BYTE(6) | BYTE(7) 
  
   process(clk_i)                                           
   begin
      if rising_edge(clk_i) then
         if (s_addressingType /= TWOedge) then                                           
            case s_typeOfDataTransferSelect is                                          
               when "01010" => s_typeOfDataTransfer <= D08_0; 
                               s_DataShift          <= b"001000";        
               when "01011" => s_typeOfDataTransfer <= D08_0; 
					                s_DataShift          <= b"001000";  
               when "10010" => s_typeOfDataTransfer <= D08_1; 
                               s_DataShift          <= b"000000";  
               when "10011" => s_typeOfDataTransfer <= D08_1; 
                               s_DataShift          <= b"000000";  
               when "01110" => s_typeOfDataTransfer <= D08_2; 
                               s_DataShift          <= b"001000";   
               when "01111" => s_typeOfDataTransfer <= D08_2; 
                               s_DataShift          <= b"001000";  
               when "10110" => s_typeOfDataTransfer <= D08_3; 
                               s_DataShift          <= b"000000";  
               when "10111" => s_typeOfDataTransfer <= D08_3; 
                               s_DataShift          <= b"000000";    
               when "00010" => s_typeOfDataTransfer <= D16_01; 
                               s_DataShift          <= b"000000"; 
               when "00011" => s_typeOfDataTransfer <= D16_01; 
                               s_DataShift          <= b"000000"; 
               when "00110" => s_typeOfDataTransfer <= D16_23; 
                               s_DataShift          <= b"000000"; 
               when "00111" => s_typeOfDataTransfer <= D16_23; 
                               s_DataShift          <= b"000000"; 
               when "00001" => s_typeOfDataTransfer <= D32; 
                               s_DataShift          <= b"000000";   
               when "00000" => s_typeOfDataTransfer <= D64; 
                               s_DataShift          <= b"000000";       
               when others =>  s_typeOfDataTransfer <= TypeError; 
                               s_DataShift          <= b"000000"; 
            end case;
         else  
            s_typeOfDataTransfer <= D64;
         end if;
      end if;
   end process;

  -- Address modifier decoder    
  -- Either the supervisor or user access mode are supported                 
   s_addressingTypeSelect <= s_AMlatched;

   with s_addressingTypeSelect select
      s_addressingType <= A24                     when c_A24_S_sup,
                          A24                     when c_A24_S,
                          A24_BLT                 when c_A24_BLT,
                          A24_BLT                 when c_A24_BLT_sup,
                          A24_MBLT                when c_A24_MBLT,
                          A24_MBLT                when c_A24_MBLT_sup,
                          CR_CSR                  when c_CR_CSR,
                          A16                     when c_A16,
                          A16                     when c_A16_sup,  
                          A32                     when c_A32,
                          A32                     when c_A32_sup,
                          A32_BLT                 when c_A32_BLT,
                          A32_BLT                 when c_A32_BLT_sup,
                          A32_MBLT                when c_A32_MBLT,
                          A32_MBLT                when c_A32_MBLT_sup,
                          A64                     when c_A64,
                          A64_BLT                 when c_A64_BLT, 
                          A64_MBLT                when c_A64_MBLT,
                          TWOedge                 when c_TWOedge,
                          AM_Error                when others;
  -- Transfer type decoder                                                  
   s_transferType <= SINGLE when s_addressingType = A24 or s_addressingType = CR_CSR or 
                                 s_addressingType = A16 or s_addressingType = A32 or 
                                 s_addressingType = A64      else
                     BLT    when s_addressingType = A24_BLT or s_addressingType = A32_BLT or 
                                 s_addressingType = A64_BLT  else
                     MBLT   when s_addressingType = A24_MBLT or s_addressingType = A32_MBLT or 
                                 s_addressingType = A64_MBLT else
                     TWOe   when s_addressingType = TWOedge  else     
                     error;

   s_datawidth <=    "0001" when s_typeOfDataTransfer = D08_0 or s_typeOfDataTransfer = D08_1 or 
                                 s_typeOfDataTransfer = D08_2 or s_typeOfDataTransfer = D08_3   else
                     "0010" when s_typeOfDataTransfer = D16_01 or s_typeOfDataTransfer = D16_23 else
                     "0100" when s_typeOfDataTransfer = D32 or (s_typeOfDataTransfer = D64 and 
                                 (s_transferType = SINGLE or  s_transferType = BLT))            else
                     "1000" when s_typeOfDataTransfer = D64                                     else
                     "1000";                                       


   s_addrWidth <=    "00" when s_addressingType = A16                                    else
                     "01" when s_addressingType = A24 or s_addressingType = A24_BLT or 
                               s_addressingType = A24_MBLT or s_addressingType = CR_CSR  else
                     "10" when s_addressingType = A32 or s_addressingType = A32_BLT or 
                               s_addressingType = A32_MBLT or (s_addressingType = TWOedge and 
                               (s_XAMtype = A32_2eVME or s_XAMtype = A32_2eSST))         else
                     "11";     -- for A64, A64 BLT, A64 MBLT, A64_2eVME, A64_2eSST
  -- uncomment for using 2e modes:
   --with s_XAM select                                            
   --   s_XAMtype <=   A32_2eVME when x"01",
   --                  A64_2eVME when x"02",
   --                  A32_2eSST when x"11",
   --                  A64_2eSST when x"12",
   --                  XAM_error when others;

   --s_2eType <=       TWOe_VME when s_XAMtype = A32_2eVME or s_XAMtype = A64_2eVME else
   --                  TWOe_SST;

-------------------------------------MAIN FSM--------------------------------|
   s_memReq         <= s_FSM.s_memReq;
   s_decode         <= s_FSM.s_decode;
   s_dtackOE        <= s_FSM.s_dtackOE;
   s_mainDTACK      <= s_FSM.s_mainDTACK;
   s_dataDir        <= s_FSM.s_dataDir;
   s_dataOE         <= s_FSM.s_dataOE;
   s_addrDir        <= s_FSM.s_addrDir;  
   s_addrOE         <= s_FSM.s_addrOE;
   s_DSlatch        <= s_FSM.s_DSlatch;
   s_incrementAddr  <= s_FSM.s_incrementAddr;
   s_dataPhase      <= s_FSM.s_dataPhase;
   s_dataToOutput   <= s_FSM.s_dataToOutput;
   s_dataToAddrBus  <= s_FSM.s_dataToAddrBus;
   s_transferActive <= s_FSM.s_transferActive;
   s_2eLatchAddr    <= s_FSM.s_2eLatchAddr;
   s_retry          <= s_FSM.s_retry;
   s_berr           <= s_FSM.s_berr;
   s_BERR_out       <= s_FSM.s_BERR_out;                        

   p_VMEmainFSM : process(clk_i)
   begin
      if rising_edge(clk_i) then
         if s_reset = '1' or s_mainFSMreset = '1' then -- FSM resetted after power up,
                                                       -- software reset, manually reset, 
                                                       -- on rising edge of AS.
            s_FSM             <=  c_FSM_default;
            s_mainFSMstate    <= IDLE;
         else
            case s_mainFSMstate is                            

               when IDLE =>
                  s_FSM  <=  c_FSM_default; 
                  -- During the Interrupt ack cycle the Slave can't be accessed
                  -- so if VME_IACK is asserted the FSM is blocked in IDLE state.
                  -- The VME_IACK signal is asserted by the Interrupt handler
                  -- during all the Interrupt cycle.
                  if s_VMEaddrLatch = '1' and VME_IACK_n_i = '1' then              
                     s_mainFSMstate <= DECODE_ACCESS; -- if AS fall. edge go in DECODE_ACCESS
                  else                                                                       
                     s_mainFSMstate <= IDLE;                         
                  end if;

               when DECODE_ACCESS =>                                            
                  -- check if this slave board is addressed and if it is, check the access mode
                  s_FSM           <=  c_FSM_default;
                  s_FSM.s_decode  <= '1';
                  s_FSM.s_DSlatch <= '1';		
                  -- uncomment for using 2e modes:						
                  --if s_addressingType = TWOedge then   -- start 2e transfer
                  --   s_mainFSMstate <= WAIT_FOR_DS_2e;
                  if s_confAccess = '1' or (s_cardSel = '1') then               
                     s_mainFSMstate <= WAIT_FOR_DS;
                  else
                     s_mainFSMstate <= DECODE_ACCESS;
                  end if;

               when WAIT_FOR_DS =>         -- wait until DS /= "11"             
                  s_FSM  <=  c_FSM_default; 
                  s_FSM.s_dtackOE        <= '1';
                  s_FSM.s_dataDir        <= VME_WRITE_n_i;
                  s_FSM.s_addrDir        <= (s_is_d64) and VME_WRITE_n_i;
                  s_FSM.s_DSlatch        <= '1';
                  s_FSM.s_dataPhase      <= s_dataPhase;
                  s_FSM.s_transferActive <= '1';

                  if VME_DS_n_i /= "11" then
                     s_mainFSMstate <= LATCH_DS;
                  else
                     s_mainFSMstate <= WAIT_FOR_DS;
                  end if;                                        

               when LATCH_DS =>                                             
                  -- this state is necessary indeed the VME master can assert the 
                  -- DS lines not at the same time
                  s_FSM                  <=  c_FSM_default;                                      
                  s_FSM.s_dtackOE        <= '1';
                  s_FSM.s_dataDir        <= VME_WRITE_n_i;
                  s_FSM.s_addrDir        <=  (s_is_d64) and VME_WRITE_n_i;
                  s_FSM.s_DSlatch        <= '1';
                  s_FSM.s_dataPhase      <= s_dataPhase;
                  s_FSM.s_transferActive <= '1';
                  s_mainFSMstate         <= CHECK_TRANSFER_TYPE;

               when CHECK_TRANSFER_TYPE =>                    
                  s_FSM                  <=  c_FSM_default;
                  s_FSM.s_dtackOE        <= '1';
                  s_FSM.s_dataDir        <= VME_WRITE_n_i;
                  s_FSM.s_addrDir        <=  (s_is_d64) and VME_WRITE_n_i;
                  s_FSM.s_dataPhase      <= s_dataPhase;
                  s_FSM.s_transferActive <= '1';
                  if (s_transferType = SINGLE or (s_transferType = BLT and 
                     VME_WRITE_n_i = '0') or (s_transferType = BLT and 
                     VME_WRITE_n_i = '1' and s_transfer_done_i = '1')) and 
                     s_addrWidth /= "11"                                                    then
                     s_mainFSMstate <= MEMORY_REQ;
                     s_FSM.s_memReq <= '1';
                  elsif (s_transferType = MBLT or s_addrWidth = "11") and s_dataPhase = '0' then
                     s_mainFSMstate <= DTACK_LOW;
                  elsif (s_transferType = MBLT or s_addrWidth = "11") and s_dataPhase = '1' then
                     s_mainFSMstate <= MEMORY_REQ;
                     s_FSM.s_memReq <= '1';                        
                  end if;

               when MEMORY_REQ =>                                             
                  -- To request the memory CR/CSR or WB memory it is sufficient to 
                  -- generate a pulse on s_memReq signal 
                  s_FSM                   <=  c_FSM_default;
                  s_FSM.s_dtackOE         <= '1';
                  s_FSM.s_dataDir         <= VME_WRITE_n_i;
                  s_FSM.s_addrDir         <=  (s_is_d64) and VME_WRITE_n_i;
                  s_FSM.s_dataPhase       <= s_dataPhase;
                  s_FSM.s_transferActive  <= '1';
                  if s_memAck = '1' and s_RW = '0'    then
                     s_mainFSMstate <= DTACK_LOW;                                
                  elsif s_memAck = '1' and s_RW = '1' then
                     if s_transferType = MBLT then
                        s_FSM.s_dataToAddrBus <= '1';
                     else
                        s_FSM.s_dataToOutput <= '1';
                     end if;
                     s_mainFSMstate <= DATA_TO_BUS;                            
                  else                                             
                     s_mainFSMstate <= MEMORY_REQ;                           
                  end if;

               when DATA_TO_BUS =>
                  s_FSM                  <=  c_FSM_default;
                  s_FSM.s_dtackOE        <= '1';
                  s_FSM.s_dataDir        <= VME_WRITE_n_i;
                  s_FSM.s_addrDir        <=  (s_is_d64) and VME_WRITE_n_i;
                  s_FSM.s_dataPhase      <= s_dataPhase;
                  s_FSM.s_transferActive <= '1';
                  s_FSM.s_dataToAddrBus  <= s_dataToAddrBus;
                  s_FSM.s_dataToOutput   <= s_dataToOutput;
                  s_mainFSMstate         <= DTACK_LOW;

               when DTACK_LOW =>         
                  s_FSM                  <=  c_FSM_default;
                  s_FSM.s_dtackOE        <= '1';
                  s_FSM.s_dataDir        <= VME_WRITE_n_i;
                  s_FSM.s_addrDir        <= (s_is_d64) and VME_WRITE_n_i;
                  s_FSM.s_dataPhase      <= s_dataPhase;
                  s_FSM.s_transferActive <= '1';
                  if s_BERRcondition = '0' then
                     s_FSM.s_mainDTACK <= '0';
                  else                                         
                     s_FSM.s_BERR_out <= '1';
                  end if;

                  if VME_DS_n_i = "11" then
                     s_mainFSMstate <= DECIDE_NEXT_CYCLE;
                  else
                     s_mainFSMstate <= DTACK_LOW;
                  end if;

               when DECIDE_NEXT_CYCLE =>
                  s_FSM                  <=  c_FSM_default;
                  s_FSM.s_dtackOE        <= '1';
                  s_FSM.s_dataDir        <= VME_WRITE_n_i;
                  s_FSM.s_addrDir        <=  (s_is_d64) and VME_WRITE_n_i;
                  s_FSM.s_dataPhase      <= s_dataPhase;
                  s_FSM.s_transferActive <= '1';
                  if (s_transferType = SINGLE and s_addrWidth /= "11") or 
                     (s_transferType = SINGLE and s_addrWidth = "11" and s_dataPhase = '1') then
                      s_mainFSMstate <= WAIT_FOR_DS;
                  elsif (s_transferType = BLT and s_addrWidth /= "11") or 
                        (s_transferType = BLT and s_addrWidth = "11" and s_dataPhase = '1') or 
                        (s_transferType = MBLT and s_dataPhase = '1')                       then
                      s_mainFSMstate <= INCREMENT_ADDR;              
                  elsif (s_transferType = MBLT or s_addrWidth = "11")and s_dataPhase = '0'  then
                      s_mainFSMstate <= SET_DATA_PHASE;
                  else s_mainFSMstate <= DECIDE_NEXT_CYCLE;
                  end if;                                  

               when INCREMENT_ADDR =>
                  s_FSM                  <=  c_FSM_default;
                  s_FSM.s_dtackOE        <= '1';
                  s_FSM.s_dataDir        <= VME_WRITE_n_i;
                  s_FSM.s_addrDir        <=  (s_is_d64) and VME_WRITE_n_i;
                  s_FSM.s_dataPhase      <= s_dataPhase;
                  s_FSM.s_transferActive <= '1';
                  s_FSM.s_incrementAddr  <= '1';
                  s_mainFSMstate         <= WAIT_FOR_DS;

               when SET_DATA_PHASE =>                              
                  s_FSM                  <=  c_FSM_default;
                  s_FSM.s_dtackOE        <= '1';
                  s_FSM.s_dataDir        <= VME_WRITE_n_i;
                  s_FSM.s_addrDir        <=  (s_is_d64) and VME_WRITE_n_i;
                  s_FSM.s_dataPhase      <= '1';
                  s_FSM.s_transferActive <= '1';
                  s_mainFSMstate         <= WAIT_FOR_DS;        
    -- uncomment for using 2e modes:
--               when WAIT_FOR_DS_2e =>
--                  s_FSM                <=  c_FSM_default;
--                  s_FSM.s_2eLatchAddr  <= "01";
--                  if VME_DS_n_i(0) = '0' then
--                     s_mainFSMstate <= ADDR_PHASE_1;
--                  end if;                                       
--
--               when ADDR_PHASE_1 =>
--                  s_FSM             <=  c_FSM_default;
--                  s_mainFSMstate    <= DECODE_ACCESS_2e;
--
--               when DECODE_ACCESS_2e =>
--                  s_FSM          <=  c_FSM_default;
--                  s_FSM.s_decode <= '1';
--                  if s_cardSel = '1' then  -- if module is selected, proceed with DTACK, 
--                                           -- else wait here until FSM reset by AS going high            
--                     s_mainFSMstate <= DTACK_PHASE_1;
--                  end if;
--
--               when DTACK_PHASE_1 =>
--                  s_FSM               <=  c_FSM_default;
--                  s_FSM.s_dtackOE     <= '1';
--                  s_FSM.s_mainDTACK   <= '0';
--                  s_FSM.s_berr        <= s_berr;
--                  if VME_DS_n_i(0) = '1' and s_berr = '0' then
--                     s_mainFSMstate <= ADDR_PHASE_2;
--                  end if;                                        
--
--               when ADDR_PHASE_2 =>
--                  s_FSM                   <=  c_FSM_default;
--                  s_FSM.s_dtackOE         <= '1';
--                  s_FSM.s_2eLatchAddr     <= "10";
--                  s_FSM.s_mainDTACK       <= '0';
--                  s_mainFSMstate          <= DTACK_PHASE_2;
--
--               when DTACK_PHASE_2 =>
--                  s_FSM            <=  c_FSM_default;
--                  s_FSM.s_dtackOE  <= '1';
--                  if VME_DS_n_i(0) = '0' then
--                     s_mainFSMstate <= ADDR_PHASE_3;
--                  end if;                                      
--
--               when ADDR_PHASE_3 =>
--                  s_FSM                   <=  c_FSM_default;
--                  s_FSM.s_dtackOE         <= '1';
--                  s_FSM.s_2eLatchAddr     <= "11";
--                  s_mainFSMstate          <= DTACK_PHASE_3;
--
--               when DTACK_PHASE_3 =>
--                  s_FSM               <=  c_FSM_default;
--                  s_FSM.s_dtackOE     <= '1';
--                  s_FSM.s_mainDTACK   <= '0';
--                  s_FSM.s_retry       <= s_retry;
--                  if s_RW = '0' and s_retry = '0' and s_2eType = TWOe_VME then
--                     s_mainFSMstate <= TWOeVME_WRITE;
--                  elsif s_RW = '1' and s_retry = '0' and s_2eType = TWOe_VME then
--                     s_mainFSMstate <= TWOeVME_READ;        
--            --   elsif s_2eType = TWOe_SST then			  -- not yet correct
--            --      s_mainFSMstate <= TWOe_FIFO_WAIT_READ;
--            --       s_memReq          <= '0';
--            --		 s_cyc             <= '0';
--            --   else                                     -- not yet correct
--            --       s_mainFSMstate <= TWOe_FIFO_WAIT_READ;
--            --      s_memReq          <= '0';
--            --		 s_cyc             <= '0';
--            --  end if;                                                                                    
--                  elsif VME_DS_n_i(0) = '1' or s_retry = '1' then
--                     s_mainFSMstate <= TWOe_RELEASE_DTACK;		  
--                  end if;
--
--               when TWOeVME_WRITE =>
--                  s_FSM              <=  c_FSM_default;
--                  s_FSM.s_dtackOE    <= '1';
--                  s_FSM.s_mainDTACK  <= s_mainDTACK;
--                  if s_DS1pulse = '1' and VME_DS_n_i(0) = '0'then
--                     s_mainFSMstate <= WAIT_WR_1;
--                     s_FSM.s_memReq <= '1';				 
--                  elsif VME_DS_n_i(0) = '1' then
--                     s_mainFSMstate <= TWOe_RELEASE_DTACK;
--                  end if;                                      
--
--               when WAIT_WR_1 =>
--                  s_FSM              <=  c_FSM_default;
--                  s_FSM.s_dtackOE    <= '1';
--                  s_FSM.s_mainDTACK  <= s_mainDTACK;
--                  s_mainFSMstate     <= WAIT_WR_2;    
--
--               when WAIT_WR_2 =>
--                  s_FSM             <=  c_FSM_default;
--                  s_FSM.s_dtackOE   <= '1';
--                  s_FSM.s_mainDTACK <= s_mainDTACK;
--                  s_mainFSMstate    <= WAIT_WB_ACK_WR;    
--
--               when WAIT_WB_ACK_WR =>
--                  s_FSM             <=  c_FSM_default;
--                  s_FSM.s_dtackOE   <= '1';
--                  s_FSM.s_mainDTACK <= s_mainDTACK;
--                  if s_AckWb = '1' then
--                     s_mainFSMstate <= TWOeVME_TOGGLE_WR;  
--                  end if;                                    
--
--               when TWOeVME_TOGGLE_WR =>
--                  s_FSM                  <=  c_FSM_default;
--                  s_FSM.s_dtackOE        <= '1';
--                  s_FSM.s_mainDTACK      <= not s_mainDTACK;
--                  s_FSM.s_incrementAddr  <= '1';
--                  s_mainFSMstate <= TWOeVME_WRITE;
--
--               when TWOeVME_READ =>
--                  s_FSM                  <=  c_FSM_default;
--                  s_FSM.s_dtackOE        <= '1';
--                  s_FSM.s_mainDTACK      <= s_mainDTACK;
--                  s_FSM.s_dataDir        <= '1';
--                  s_FSM.s_addrDir        <= s_is_d64;     
--                  if s_DS1pulse = '1' and VME_DS_n_i(0) = '0'then
--                     s_mainFSMstate <= TWOeVME_MREQ_RD;
--                     s_FSM.s_memReq <= '1'; 
--                  elsif VME_DS_n_i(0) = '1' then
--                     s_mainFSMstate <= TWOe_RELEASE_DTACK;
--                  end if;                              
--
--               when TWOeVME_MREQ_RD =>
--                  s_FSM              <=  c_FSM_default;
--                  s_FSM.s_dtackOE    <= '1';
--                  s_FSM.s_mainDTACK  <= s_mainDTACK;
--                  s_FSM.s_dataDir    <= '1';
--                  s_FSM.s_addrDir    <= s_is_d64;
--                  s_mainFSMstate     <= WAIT_WB_ACK_RD;
--
--               when WAIT_WB_ACK_RD =>
--                  s_FSM              <=  c_FSM_default;
--                  s_FSM.s_dtackOE    <= '1';
--                  s_FSM.s_mainDTACK  <= s_mainDTACK;
--                  s_FSM.s_dataDir    <= '1';
--                  s_FSM.s_addrDir    <= s_is_d64;
--                  if s_AckWb = '1' then
--                     s_mainFSMstate <= TWOeVME_INCR_ADDR;
--                  end if;	                              
--
--               when TWOeVME_INCR_ADDR =>
--                  s_FSM                   <=  c_FSM_default;
--                  s_FSM.s_dtackOE         <= '1';
--                  s_FSM.s_mainDTACK       <= s_mainDTACK;
--                  s_FSM.s_dataDir         <= '1';
--                  s_FSM.s_addrDir         <= s_is_d64;
--                  s_FSM.s_incrementAddr   <= '1';
--                  s_FSM.s_dataToAddrBus   <= '1';	
--                  s_mainFSMstate          <= TWOeVME_TOGGLE_RD;
--
--               when TWOeVME_TOGGLE_RD =>
--                  s_FSM               <=  c_FSM_default;
--                  s_FSM.s_dtackOE     <= '1';
--                  s_FSM.s_mainDTACK   <= not s_mainDTACK;
--                  s_FSM.s_dataDir     <= '1';
--                  s_FSM.s_addrDir     <= s_is_d64;
--                  s_mainFSMstate      <= TWOeVME_READ;
--
--               when TWOe_FIFO_WRITE =>                       
--                  s_FSM               <=  c_FSM_default;
--                  s_FSM.s_dtackOE     <= '1';
--                  s_FSM.s_mainDTACK   <= s_mainDTACK;
--                  if s_DS1pulse = '1' and s_2eType = TWOe_VME and 
--                     VME_DS_n_i(0) = '0'then
--                     s_FSM.s_memReq   <= '1';
--            -- elsif s_DS1pulse = '1' then --VME_DS_n_i(0) = '1' then
--            --   s_memReq          <= '1';
--            -- else
--            --   s_memReq          <= '0';	  
--                  end if;
--
--                  if s_DS1pulse = '1' and s_2eType = TWOe_VME  then
--                     s_mainFSMstate <= TWOe_TOGGLE_DTACK;
--                  elsif VME_DS_n_i(0) = '1' then
--                     s_mainFSMstate <= TWOe_RELEASE_DTACK;
--                  end if;
--
--               when TWOe_TOGGLE_DTACK =>                         
--                  s_FSM                 <=  c_FSM_default;
--                  s_FSM.s_dtackOE       <= '1';
--                  s_FSM.s_dataDir       <= s_dataDir;
--                  s_FSM.s_addrDir       <= s_addrDir;
--                  s_FSM.s_incrementAddr <= '1';
--                  if s_RW = '0' and  s_2eType = TWOe_SST then    
--                     s_mainFSMstate <= TWOe_FIFO_WRITE;
--                     s_FSM.s_mainDTACK <= not s_mainDTACK;
--                  elsif s_RW = '1' and  s_2eType = TWOe_SST then
--                     s_mainFSMstate <= TWOe_CHECK_BEAT;
--                     s_FSM.s_mainDTACK <= not s_mainDTACK;
--            --elsif s_RW = '0' then
--            -- s_mainFSMstate <= TWOe_FIFO_WRITE;	
--            -- s_mainDTACK       <= not s_mainDTACK;
--                  else				
--                     s_mainFSMstate <= TWOe_WAIT_FOR_DS1;
--                     s_FSM.s_mainDTACK <= not s_mainDTACK;
--                  end if;
--
--               when TWOe_WAIT_FOR_DS1 =>                  
--                  s_FSM                 <=  c_FSM_default;
--                  s_FSM.s_dtackOE       <= '1';
--                  s_FSM.s_dataDir       <= s_dataDir;
--                  s_FSM.s_addrDir       <= s_addrDir;
--                  s_FSM.s_mainDTACK     <= s_mainDTACK;
--                  s_FSM.s_dataToAddrBus <= '1';
--                  if (s_DS1pulse = '1' and s_2eType = TWOe_VME) or s_2eType = TWOe_SST then
--                     s_mainFSMstate <= TWOe_CHECK_BEAT;
--                  end if; 
--
--               when TWOe_FIFO_WAIT_READ =>
--                  s_FSM              <=  c_FSM_default;
--                  s_FSM.s_dtackOE    <= '1';
--                  s_FSM.s_dataDir    <= '1';
--                  s_FSM.s_addrDir    <= s_is_d64;
--                  s_FSM.s_mainDTACK  <= s_mainDTACK;
--                  s_FSM.s_memReq     <= not stall_i;
--            --           if readFIFOempty_i = '0' then  --and s_2eType=TWOe_SST then
--                  if stall_i = '0' then --and s_2eType=TWOe_SST then      
--                     s_mainFSMstate  <= TWOe_FIFO_READ;
--                  end if; 
--          --   s_memReq          <= not stall_i;  -- access to the wb_dma
--               when TWOe_FIFO_READ =>
--                  s_FSM                 <=  c_FSM_default;
--                  s_FSM.s_dtackOE       <= '1';
--                  s_FSM.s_dataDir       <= '1';
--                  s_FSM.s_addrDir       <= s_is_d64;
--                  s_FSM.s_mainDTACK     <= s_mainDTACK;
--                  s_FSM.s_dataToAddrBus <= s_AckWb;
--                  if s_AckWb = '1' then 
--                     s_mainFSMstate    <= TWOe_TOGGLE_DTACK;
--                  end if;
--
--               when TWOe_CHECK_BEAT =>                                  
--                  s_FSM               <=  c_FSM_default;
--                  s_FSM.s_dtackOE     <= '1';
--                  s_FSM.s_dataDir     <= '1';
--                  s_FSM.s_addrDir     <= s_is_d64;
--                  s_FSM.s_mainDTACK   <= s_mainDTACK; 
--                  s_mainFSMstate      <= TWOe_END_1;
--
--               when TWOe_RELEASE_DTACK =>  -- wait here the AS rising edge --> reset FSM
--                  s_FSM              <=  c_FSM_default;
--                  s_FSM.s_dtackOE    <= '1';
--                  s_mainFSMstate     <= TWOe_RELEASE_DTACK;
--
--               when TWOe_END_1 =>
--                  s_FSM              <=  c_FSM_default;
--                  s_FSM.s_dtackOE    <= '1';
--                  s_FSM.s_mainDTACK  <= s_mainDTACK;
--                  s_FSM.s_retry      <= '1';
--                  s_mainFSMstate     <= TWOe_END_2;
--
--               when TWOe_END_2 =>              
--                  s_FSM              <=  c_FSM_default;
--                  s_FSM.s_dtackOE    <= '1';
--                  s_FSM.s_mainDTACK  <= s_mainDTACK;
--                  s_FSM.s_retry      <= '1';
--                  s_FSM.s_berr       <= '1';
--                  if VME_DS_n_i = "11" then
--                     s_mainFSMstate <= TWOe_RELEASE_DTACK;
--                  end if;

               when others =>
                  s_FSM              <=  c_FSM_default;
                  s_mainFSMstate     <= IDLE;

            end case;
         end if;
      end if;
   end process;

  ------------------------- RETRY and ERROR drivers----------------------|

   p_RETRYdriver: process(clk_i)
   begin
      if rising_edge(clk_i) then
         if s_rty1='1' or s_retry ='1' then
            VME_RETRY_n_o    <= '0';   
            VME_RETRY_OE_o   <= '1';
         else
            VME_RETRY_n_o    <= '1';   
            VME_RETRY_OE_o   <= '0';
         end if;
      end if;
   end process;

  -- BERR driver 
  -- The slave assert the Error line when during the Decode access phase an error 
  -- condition is detected and the s_BERRcondition is asserted.
  -- When the FSM is in the DTACK_LOW state one of the VME_DTACK and VME_BERR line is asserted.
  -- The VME_BERR line can not be asserted by the slave at anytime, but only during 
  -- the DTACK_LOW state; this to avoid that one temporary error condition 
  -- during the decode access phase causes an undesired assertion of VME_BERR line.

   p_BERRdriver: process(clk_i)    
   begin
      if rising_edge(clk_i) then
         s_berr_1      <= s_berr;    
         s_berr_2      <= s_berr and s_berr_1;
         if (s_BERR_out = '1') then    
            VME_BERR_o <= '1';   -- The VME_BERR is asserted when '1' becouse 
                                 -- the buffers on the board invert the logic
         else
            VME_BERR_o <= '0';
         end if;
      end if;
   end process;

  -- When the VME_BERR line is asserted this process assert the error flag; This flag 
  -- acts as the BERR flag --> BIT SET REGISTER's bit 3 in the CSR space

   FlagError: process(clk_i)
   begin
      if rising_edge (clk_i) then
         if s_resetflag = '1' or s_reset = '1' then
            s_errorflag <= '0';
         elsif (s_BERR_out = '1') then    
            s_errorflag <= '1';   
         end if;
      end if;                     
   end process;

  -- This process detect an error condition and assert the s_BERRcondition signal
  -- If the VME master try to access with a not supported mode  the slave answer with an error.

   process(clk_i)
   begin	 
      if rising_edge(clk_i) then
         if s_reset = '1' then s_BERRcondition <= '0';
      else
         if s_initInProgress = '0' then
            if (s_CRAMaddressed = '1' and s_CRaddressed = '1') or (s_CRAMaddressed = '1' and 
                s_CSRaddressed = '1') or  (s_CRaddressed = '1' and s_confAccess = '1' and s_RW = '0')
               or (s_CSRaddressed = '1' and s_CRaddressed = '1') or ((s_transferType = error or 
               s_wberr1 = '1') and s_transferActive='1') or (s_typeOfDataTransfer = TypeError) or  
               (s_addressingType = AM_Error) or s_blockTransferLimit = '1' or 
               (s_transferType = BLT and (not(s_typeOfDataTransfer = D32 or 
               s_typeOfDataTransfer = D64))) or (s_transferType = MBLT and 
               s_typeOfDataTransfer /= D64)  then 

               s_BERRcondition <= '1';
            else
               s_BERRcondition <= '0';
            end if;
         end if;  
      end if;		 
   end if;
  end process;

  --generate the error condition if block transfer overlap the limit
  -- BLT --> block transfer limit = 256 bytes
  -- MBLT --> block transfer limit = 2048 bytes                         
  with s_transferType select
     s_blockTransferLimit <= s_addrOffset(8)   when BLT, 
                             s_addrOffset(11)  when MBLT, 
                             '0'               when others;  

  -- handler of wb err pulse
  process(clk_i)
  begin
   if rising_edge(clk_i) then
      if  s_mainFSMreset = '1' or s_reset = '1' then 
         s_wberr1 <= '0';
      elsif s_err = '1'  then
         s_wberr1 <= '1';
      end if;	
   end if;
  end process;

  -- handler of wb retry pulse                                        
  process(clk_i)
  begin
     if rising_edge(clk_i) then
        if  s_mainFSMreset = '1' or s_reset = '1' then 
            s_rty1 <= '0';
        elsif s_rty = '1' then
            s_rty1 <= '1';
        end if;	
    end if;
  end process;

  ---------------------------------------------------------------------|  
  --These two mux are inserted to provide the vme64x core of the MBLT access mode
  p_ADDRmux : process(clk_i)
  begin
     if rising_edge(clk_i) then
        if s_dataToAddrBus = '1' then   
           VME_ADDR_b_o    <=  s_locDataSwap(63 downto 33);                    
           VME_LWORD_n_b_o <= s_locDataSwap(32);                       
        end if;
     end if;
  end process;
  p_DATAmux : process(clk_i)
  begin
     if rising_edge(clk_i) then
        if s_dataToAddrBus = '1' or s_dataToOutput = '1' then
           if s_addressingType = CR_CSR then
              VME_DATA_b_o <=  std_logic_vector(s_locData(31 downto 0));
           else	  
              VME_DATA_b_o <=  s_locDataSwap(31 downto 0);                       
           end if;
        end if;
     end if;
  end process;
  ---------------------ADDRESS_HANDLER_PROCESS------------------------|
  --Local address & AM & 2e address phase latching
  s_VMEaddrInput <= unsigned(VME_ADDR_b_i);
  s_LWORDinput   <= VME_LWORD_n_b_i;
  s_VMEdataInput <= unsigned(VME_DATA_b_i);
  p_addrLatching : process(clk_i)  
  begin
     if rising_edge(clk_i) then
        if s_reset = '1' then
           s_VMEaddrLatched <= (others => '0');
           s_LWORDlatched   <= '0';
           s_AMlatched      <= (others => '0');
        else
           if s_VMEaddrLatch = '1' then  -- Latching on falling edge of VME_AS_n_i
              s_VMEaddrLatched <= s_VMEdataInput & s_VMEaddrInput;
              s_LWORDlatched   <= s_LWORDinput;
              s_AMlatched      <= VME_AM_i;
           else
              s_VMEaddrLatched <= s_VMEaddrLatched;
              s_LWORDlatched   <= s_LWORDlatched;
              s_AMlatched      <= s_AMlatched;
           end if;
        end if;
     end if;
  end process;                     
-- uncomment for using 2e modes:
--  p_2eAddrLatch : process(clk_i)
--  begin
--     if rising_edge(clk_i) then
--        if s_reset = '1' or s_mainFSMreset = '1' then
--           s_phase1addr <= (others => '0');
--           s_phase2addr <= (others => '0');
--           s_phase3addr <= (others => '0');
--        else
--           case s_2eLatchAddr is
--              when "01" => 
--                 s_phase1addr <= s_VMEdataInput & s_VMEaddrInput & s_LWORDinput;
--                 s_phase2addr <= s_phase2addr;
--                 s_phase3addr <= s_phase3addr;
--              when "10" => 
--                 s_phase2addr <= s_VMEdataInput & s_VMEaddrInput & s_LWORDinput;
--                 s_phase1addr <= s_phase1addr;
--                 s_phase3addr <= s_phase3addr;
--              when "11" => 
--                 s_phase3addr <= s_VMEdataInput & s_VMEaddrInput & s_LWORDinput;
--                 s_phase1addr <= s_phase1addr;
--                 s_phase2addr <= s_phase2addr;
--              when others => 
--                 s_phase1addr <= s_phase1addr;
--                 s_phase2addr <= s_phase2addr;
--                 s_phase3addr <= s_phase3addr;
--           end case;
--      end if;
--   end if;
--  end process;
--   s_XAM  <= s_phase1addr(7 downto 0);
    -- Local address mapping                                         

   s_locAddrBeforeOffset(63 downto 1) <= x"000000000000" & s_VMEaddrLatched(15 downto 1)
                                         when  s_addrWidth = "00" else
                                         x"0000000000" & s_VMEaddrLatched(23 downto 1) 
                                         when s_addrWidth = "01" else
                                         x"00000000" & s_VMEaddrLatched(31 downto 1)  
                                         when s_addrWidth = "10" else
   s_VMEaddrLatched(63 downto 1);

   s_locAddrBeforeOffset(0) <= '0' when (s_DSlatched(1) = '0' and s_DSlatched(0) = '1') else
                               '1' when (s_DSlatched(1) = '1' and s_DSlatched(0) = '0') else
                               '0';

   s_locAddr2e <= s_phase1addr(63 downto 8) & s_phase2addr(7 downto 0);
  -- This process generates the s_locAddr that is used during the access decode process;
  -- If the board is addressed the VME_Access_Decode component generates the s_base_addr 
  -- The s_rel_locAddr is used by the VME_WB_master to address the WB memory
  process(clk_i)
  begin
    if rising_edge(clk_i) then
       if s_addressingType = TWOedge then
          s_rel_locAddr <= s_locAddr2e + s_addrOffset-s_base_addr;
          s_locAddr <= s_locAddr2e; 
       elsif s_addressingType = CR_CSR then           
          s_locAddr <= s_locAddrBeforeOffset;	 	
       else
          s_rel_locAddr <= s_locAddrBeforeOffset + s_addrOffset-s_base_addr;
          s_locAddr <= s_locAddrBeforeOffset;
       end if;
    end if;
  end process;
  -- Local address incrementing                                       
  -- This process generates the s_addrOffset 
  -- The s_addrOffset is /= 0 during BLT, MBLT and 2e access modes, when 
  -- the vme64x core increments the address every cycle
  p_addrIncrementing : process(clk_i)
  begin
    if rising_edge(clk_i) then
       if s_reset = '1' or s_mainFSMreset = '1' then
          s_addrOffset <= (others => '0');
       elsif s_incrementAddr = '1' then  
          if s_addressingType = TWOedge then
             s_addrOffset <= s_addrOffset + 8;   -- the TWOedge access is D64
          else	  
              if s_typeOfDataTransfer = D08_0 or s_typeOfDataTransfer = D08_1 or 
                 s_typeOfDataTransfer = D08_2 or s_typeOfDataTransfer = D08_3 then    
                 s_addrOffset <= s_addrOffset + 1;
              elsif s_typeOfDataTransfer = D16_01 or s_typeOfDataTransfer = D16_23 then
                 s_addrOffset <= s_addrOffset + 2;
              elsif s_typeOfDataTransfer = D64 then
                  if s_transferType = MBLT then
                     s_addrOffset <= s_addrOffset + 8;  
                  else				  
                     s_addrOffset <= s_addrOffset + 4; --BLT D32
                  end if;	  
              elsif s_typeOfDataTransfer = D32 then	--BLT D32     
                 s_addrOffset <= s_addrOffset + 4;
              else
                 s_addrOffset <= s_addrOffset;    
              end if;  
         end if;		
      else 
         s_addrOffset <= s_addrOffset;	
      end if;
    end if;
  end process;            

   s_CrCsrOffsetAddr <= "00"&s_locAddr(18 downto 2) when s_mainFSMreset = '0' else
                        (others => '0');   

   s_CRaddr <= (s_CrCsrOffsetAddr) when s_initInProgress = '0' else
               (resize(s_initReadCounter, s_CRaddr'length));  

   CRaddr_o   <= std_logic_vector(s_CRaddr(11 downto 0));
   CRAMaddr_o <= std_logic_vector(s_CrCsrOffsetAddr - unsigned(s_BEG_CRAM(18 downto 0)));

  --------------------DATA HANDLER PROCESS---------------------------- |  
  -- Data strobe latching
  p_DSlatching : process(clk_i)
  begin
    if rising_edge(clk_i) then
       if s_DSlatch = '1' then
          s_DSlatched <= VME_DS_n_i;
       else
          s_DSlatched <= s_DSlatched;
       end if;
    end if;
  end process;

   s_VMEdata64In(63 downto 33) <= s_VMEaddrInput(31 downto 1);
   s_VMEdata64In(32) <= (s_LWORDinput);
   s_VMEdata64In(31 downto 0) <=  s_VMEdataInput(31 downto 0);

  process(clk_i)
  begin
    if rising_edge(clk_i) then
       s_locDataIn  <= unsigned(s_VMEdata64In) srl to_integer(unsigned(s_DataShift));   
    end if;
  end process;                                     

   CSRData_o <= std_logic_vector(s_locDataIn(7 downto 0));

  process(clk_i)
  begin
     if rising_edge(clk_i) then
        CRAMdata_o <= std_logic_vector(s_locDataIn(7 downto 0));
        if (s_confAccess = '1' and s_CRAMaddressed = '1' and s_memReq = '1' and 
           s_RW = '0' and (s_typeOfDataTransfer = D08_3 or s_typeOfDataTransfer = D32 or 
           s_typeOfDataTransfer = D16_23 or (s_typeOfDataTransfer = D64 and 
           s_transferType /= MBLT))) then
           
              CRAMwea_o  <= '1';
        else 
              CRAMwea_o  <= '0';
        end if;
     end if;	 
  end process;                           
  --swap the data during read or write operation
  --sel= 00 --> No swap
  --sel= 01 --> Swap Byte  eg: 01234567 became 10325476
  --sel= 10 --> Swap Word  eg: 01234567 became 23016745
  --sel= 11 --> Swap Word+ Swap Byte eg: 01234567 became 32107654
  swapper_write: VME_swapper PORT MAP(
                                      d_i => std_logic_vector(s_locDataIn),
                                      sel => MBLT_Endian_i,
                                      d_o => s_locDataInSwap
                                    );	  

  swapper_read: VME_swapper PORT MAP(
                                     d_i => std_logic_vector(s_locData),
                                     sel => MBLT_Endian_i,
                                     d_o => s_locDataSwap
                                   );	  

  s_locDataOut <=   unsigned(s_locDataOutWb) when s_cardSel = '1' else
                    resize(s_CSRdata, s_locDataOut'length) when 
                       s_confAccess = '1' and s_CSRaddressed = '1' and 
                       s_CRAMaddressed = '0' and s_CRaddressed = '0' and 
                       (s_typeOfDataTransfer = D08_3 or s_typeOfDataTransfer = D32 or 
                       s_typeOfDataTransfer = D16_23 or (s_typeOfDataTransfer = D64 and 
                       s_transferType /= MBLT)) else
                    resize(unsigned(s_CRdataIn), s_locDataOut'length) when 
                       s_confAccess = '1' and s_CRaddressed = '1' and 
                       s_CRAMaddressed = '0' and s_CSRaddressed = '0' and 
                       (s_typeOfDataTransfer = D08_3 or s_typeOfDataTransfer = D32 or 
                       s_typeOfDataTransfer = D16_23 or (s_typeOfDataTransfer = D64 and 
                       s_transferType /= MBLT)) else
                    resize(unsigned(s_CRAMdataIn), s_locDataOut'length) when 
                       s_confAccess = '1' and s_CRAMaddressed = '1' and 
                       s_CRaddressed = '0' and s_CSRaddressed = '0'  and 
                       (s_typeOfDataTransfer = D08_3 or s_typeOfDataTransfer = D32 or 
                       s_typeOfDataTransfer = D16_23 or (s_typeOfDataTransfer = D64 and 
                       s_transferType /= MBLT)) else
                    (others => '0');   
  
  s_locData(63 downto 0) <= s_locDataOut(63 downto 0) sll to_integer(unsigned(s_DataShift));
  s_CSRdata <= unsigned(CSRData_i);
  -------------------------BEAT COUNT--------------------------------|

  
  -- 2eSST:
  -- The Cycle Count informs the slave in advance of the amount of data that 
  -- it is requested to receive in a write transaction or the amount of data 
  -- it is to supply in a read request. The cycle count value sent is the beat count 
  -- divided by two. There are two data beats in each cycle
  -- 2eVME:
  -- Rule 11.8:
  -- The beat count shall be sent in A[15:8] during the second address phase. 
  -- The value is the number of beats divided by two.
  s_cycleCount <= unsigned(s_phase2addr(15 downto 8)); 
  -- The Beat Count information is important if the FIFO is used; 
  -- during 2e access the Master send this information, during
  -- BLT and MBLT access the Beat Count is equal to the block transfer limit.
  process(s_cycleCount,s_beatCount,s_XAMtype, s_transferType, s_typeOfDataTransfer)
  begin                            --                                |
    if ((s_XAMtype = A32_2eVME) or (s_XAMtype = A64_2eVME) or (s_XAMtype = A32_2eSST) 
       or (s_XAMtype = A64_2eSST))  then 
          s_beatCount <= (resize(s_cycleCount*2, s_beatCount'length));
    elsif s_transferType = SINGLE then 
          s_beatCount <= (to_unsigned(1, s_beatCount'length));
    elsif s_transferType = BLT then	 
              --Rule 2.12a VME64std
          if (s_typeOfDataTransfer = D08_0 or s_typeOfDataTransfer = D08_1 or 
             s_typeOfDataTransfer = D08_2 or s_typeOfDataTransfer = D08_3)       then
               s_beatCount <= (to_unsigned(255, s_beatCount'length));
          elsif (s_typeOfDataTransfer = D16_01 or s_typeOfDataTransfer = D16_23) then
               s_beatCount <= (to_unsigned(127, s_beatCount'length));
          else 	
               s_beatCount <= (to_unsigned(31, s_beatCount'length));  
          --32 not 64 becouse the fifo read from wb 64 bit (not 32) every cycle.
          end if;	
    elsif s_transferType =	MBLT and s_FIFO = '1' then   --  Rule 2.78 VME64std
          s_beatCount <= (to_unsigned(255, s_beatCount'length));
    else
          s_beatCount <= (to_unsigned(1, s_beatCount'length));   
    end if;  
end process;       
       
  ---------------------MEMORY MAPPING--------------------------------
  -- WB bus width = 64-bits
  -- Granularity = byte
  -- WB bus --> BIG ENDIAN 
  p_memoryMapping : process(clk_i)
  begin
     if rising_edge(clk_i) then
        if s_transferType = TWOe then
           s_nx_sel                            <= "11111111";
        else	
           case s_typeOfDataTransfer is
              when D08_0 =>
                 if s_rel_locAddr(2) = '0' then
                    s_nx_sel                   <= "10000000";
                 else
                    s_nx_sel                   <= "00001000";
                 end if;		
              when D08_1 =>
                 if s_rel_locAddr(2) = '0' then
                    s_nx_sel                   <= "01000000";
                 else
                    s_nx_sel                   <= "00000100";
                 end if;			       
              when D08_2 =>
                 if s_rel_locAddr(2) = '0' then
                    s_nx_sel                   <= "00100000";
                 else
                    s_nx_sel                   <= "00000010";
                 end if;			   	
              when D08_3 =>
                 if s_rel_locAddr(2) = '0' then
                    s_nx_sel                   <= "00010000";
                 else
                    s_nx_sel                   <= "00000001";
                 end if;
              when D16_01 =>                 
                 if s_rel_locAddr(2) = '0' then
                    s_nx_sel                   <= "11000000";
                 else
                    s_nx_sel                   <= "00001100";
                 end if;
              when D16_23 =>                 
                 if s_rel_locAddr(2) = '0' then
                    s_nx_sel                   <= "00110000";
                 else
                    s_nx_sel                   <= "00000011";
                 end if;	  
              when D64 =>     
                 case s_transferType is
                    when MBLT =>            -- D64                    |
                       s_nx_sel                <= "11111111";
                    when others =>          -- D32  BLT or SINGLE
                       if s_rel_locAddr(2) = '0' then
                          s_nx_sel             <= "11110000";
                       else
                          s_nx_sel             <= "00001111";
                       end if;	
                 end case;
              when D32 =>   
                 if s_rel_locAddr(2) = '1' then
                    s_nx_sel                   <= "00001111";
                 else
                    s_nx_sel                   <= "11110000";			  
                 end if;	
              when others =>
                 s_nx_sel                      <= "00000000";   
           end case;
        end if;
     end if;
  end process;
  s_sel <= unsigned(s_nx_sel);
--------------------------WB MASTER-----------------------------------|
--This component acts as WB master for single read/write PIPELINED mode.
--The data and address lines are shifted inside this component.
  Inst_Wb_master: VME_Wb_master PORT MAP(
                                         s_memReq        => s_memReq,
                                         clk_i           => clk_i,
                                         s_cardSel       => s_cardSel,
                                         s_reset         => s_reset,
                                         s_mainFSMreset  => s_mainFSMreset,
                                         s_BERRcondition => s_BERRcondition,
                                         s_sel           => std_logic_vector(s_sel),
                                         s_beatCount     => std_logic_vector(s_beatCount),
                                         s_locDataInSwap => s_locDataInSwap,
                                         s_locDataOut    => s_locDataOutWb,
                                         s_rel_locAddr   => std_logic_vector(s_rel_locAddr),
                                         s_AckWithError  => s_AckWithError,
                                         memAckWb        => s_AckWb,
                                         err             => s_err,
                                         rty             => s_rty,
                                         s_RW            => s_RW,
                                         psize_o         => psize_o,
                                         stall_i         => stall_i,
                                         rty_i           => rty_i,
                                         err_i           => err_i,
                                         cyc_o           => cyc_o,
                                         memReq_o        => memReq_o,
                                         WBdata_o        => wbData_o,
                                         wbData_i        => wbData_i,
                                         locAddr_o       => locAddr_o,
                                         memAckWB_i      => memAckWB_i,
                                         WbSel_o         => wbSel_o,
                                         RW_o            => RW_o
                                        );
--------------------------DECODER-------------------------------------|
  -- DECODER: This component check if the board is addressed; if the CR/CSR 
  --space is addressed the Confaccess is asserted
  -- If the Wb memory is addressed the CardSel is asserted.
  Inst_Access_Decode: VME_Access_Decode PORT MAP(
                                                 clk_i          => clk_i,
                                                 s_reset        => s_reset,
                                                 s_mainFSMreset => s_mainFSMreset,
                                                 s_decode       => s_decode,
                                                 ModuleEnable   => ModuleEnable,
                                                 InitInProgress => s_initInProgress,
                                                 Addr           => std_logic_vector(s_locAddr),
                                                 Ader0          => Ader0,
                                                 Ader1          => Ader1,
                                                 Ader2          => Ader2,
                                                 Ader3          => Ader3,
                                                 Ader4          => Ader4,
                                                 Ader5          => Ader5,
                                                 Ader6          => Ader6,
                                                 Ader7          => Ader7,
                                                 Adem0          => s_FUNC_ADEM(0),
                                                 Adem1          => s_FUNC_ADEM(1),
                                                 Adem2          => s_FUNC_ADEM(2),
                                                 Adem3          => s_FUNC_ADEM(3),
                                                 Adem4          => s_FUNC_ADEM(4),
                                                 Adem5          => s_FUNC_ADEM(5),
                                                 Adem6          => s_FUNC_ADEM(6),
                                                 Adem7          => s_FUNC_ADEM(7),
                                                 AmCap0         => s_FUNC_AMCAP(0),
                                                 AmCap1         => s_FUNC_AMCAP(1),
                                                 AmCap2         => s_FUNC_AMCAP(2),
                                                 AmCap3         => s_FUNC_AMCAP(3),
                                                 AmCap4         => s_FUNC_AMCAP(4),
                                                 AmCap5         => s_FUNC_AMCAP(5),
                                                 AmCap6         => s_FUNC_AMCAP(6),
                                                 AmCap7         => s_FUNC_AMCAP(7),
                                                 XAmCap0        => s_FUNC_XAMCAP(0),
                                                 XAmCap1        => s_FUNC_XAMCAP(1),
                                                 XAmCap2        => s_FUNC_XAMCAP(2),
                                                 XAmCap3        => s_FUNC_XAMCAP(3),
                                                 XAmCap4        => s_FUNC_XAMCAP(4),
                                                 XAmCap5        => s_FUNC_XAMCAP(5),
                                                 XAmCap6        => s_FUNC_XAMCAP(6),
                                                 XAmCap7        => s_FUNC_XAMCAP(7),
                                                 Am             => s_AMlatched,
                                                 XAm            => std_logic_vector(s_XAM),
                                                 BAR            => BAR_i,
                                                 AddrWidth      => s_addrWidth,
                                                 Funct_Sel      => s_func_sel,
                                                 Base_Addr      => s_nx_base_addr,
                                                 Confaccess     => s_confAccess,
                                                 CardSel        => s_cardSel
                                                );
  s_base_addr <= unsigned(s_nx_base_addr);

  -- CR/CSR addressing 
  s_CSRaddressed  <= '1' when (s_locAddr(18 downto 0) <= x"7FFFF" and 
                      s_locAddr(18 downto 0) >= x"7FC00") xor 
                      (s_locAddr(18 downto 0) >= unsigned(s_BEG_USER_CSR(18 downto 0)) and 
                      s_locAddr(18 downto 0) <= unsigned(s_END_USER_CSR(18 downto 0)) and 
                      unsigned(s_BEG_USER_CSR) < unsigned(s_END_USER_CSR)) else '0';

  s_CRaddressed   <= '1' when (s_locAddr(18 downto 0) <= x"00FFF" and 
                      s_locAddr(18 downto 0) >= x"00000") xor 
                      (s_locAddr(18 downto 0) >= unsigned(s_BEG_USER_CR(18 downto 0)) and 
                      s_locAddr(18 downto 0) <= unsigned(s_END_USER_CR(18 downto 0)) and 
                      unsigned(s_BEG_USER_CR) < unsigned(s_END_USER_CR))     else '0';

  s_CRAMaddressed <= '1' when (s_locAddr(18 downto 0) >= unsigned(s_BEG_CRAM(18 downto 0)) and 
                     s_locAddr(18 downto 0) <= unsigned(s_END_CRAM(18 downto 0)) and  
                     unsigned(s_BEG_CRAM) < unsigned(s_END_CRAM)) else '0';

  --------------------------ACKNOWLEDGE---------------------------------------|
  -- The signal s_memAck is used as condition to pass from the MEMORY_REQ to DATA_TO_BUS 
  -- or DTACK_LOW state ,so is necessary assert s_memACk also if there is an error.

  s_memAck <= s_memAckCSR or s_AckWb or s_AckWithError or s_err;

  -- CR/CSR memory acknowledge

  p_memAckCSR : process(clk_i)
  begin
     if rising_edge(clk_i) then
        if s_reset = '1' then
           s_memAckCSR <= '0';
        else
           if s_memReq = '1' and s_confAccess = '1' then
              s_memAckCSR <= '1';
           else
              s_memAckCSR <= '0';
           end if;
        end if;
     end if;
  end process;

  -----------------------CR/CSR IN/OUT----------------------------------------|

  en_wr_CSR <= '1' when ((s_typeOfDataTransfer = D08_3 or s_typeOfDataTransfer = D32 or 
                s_typeOfDataTransfer = D16_23 or (s_typeOfDataTransfer = D64 and 
                s_transferType /= MBLT)) and s_memReq = '1' and 
                s_confAccess = '1' and s_RW = '0') else '0';

  CrCsrOffsetAddr <= std_logic_vector(s_CrCsrOffsetAddr);

  err_flag_o <= s_errorflag;
  
  s_resetflag <= reset_flag_i;
  -- Software reset: the VME Master assert the BIT SET REGISTER's bit 7. The reset will be 
  -- effective the next AS rising edge at the end of the write operation in this register.

  process(clk_i)
  begin
     if rising_edge(clk_i) then
        if s_mainFSMreset = '1' then 
           s_sw_reset <= Sw_Reset;
        else 
           s_sw_reset <= '0';      
        end if;	
     end if;	
  end process;

-- The following process are used to calculate the duration in ns of the 
-- transfer (time between the As falling edge and the AS rising edge) and
-- the number of bytes transferred. 
--  
  process(clk_i)
  begin
     if rising_edge(clk_i) then
        if VME_RST_n_i = '0' or s_mainFSMreset = '1' then 
           s_countertime <= (others => '0');
        elsif  VME_AS_n_i = '0' then
           s_countertime <= s_countertime + 1;
        end if;	
  end if;
  end process;

  process(clk_i)
  begin
     if rising_edge(clk_i) then
        if s_mainFSMreset = '1' and s_cardSel = '1' then
           s_time <= std_logic_vector(s_countertime * unsigned(clk_period));
        end if;	
     end if;
  end process;                                                             

  process(clk_i)
  begin
     if rising_edge(clk_i) then
        if VME_RST_n_i = '0' or s_mainFSMreset = '1' then 
           s_counterbytes <= (others => '0');
        elsif  s_memReq = '1' and s_cardSel = '1' then
           s_counterbytes <= s_counterbytes + 1;
        end if;	
     end if;
  end process;

  process(clk_i)
  begin
     if rising_edge(clk_i) then
        if s_mainFSMreset = '1' and s_cardSel = '1' then
           s_bytes <= std_logic_vector(unsigned(s_counterbytes * s_datawidth));
        end if;	
     end if;
  end process;
  numBytes <= s_bytes;
  transfTime <= s_time;

---------------------------INITIALIZATION-------------------------------------|  
  -- Initialization procedure                
  -- Read important CR data (like FUNC_ADEMs etc.) and store it locally
  s_initReadCounter <= unsigned(s_initReadCounter1);
  Inst_VME_Init: VME_Init PORT MAP(
                                   clk_i          => clk_i,
                                   RSTedge        => s_RSTedge,
                                   CRAddr         => std_logic_vector(s_CRaddr),
                                   CRdata_i       => CRdata_i,
                                   InitReadCount  => s_initReadCounter1,
                                   InitInProgress => s_initInProgress,
                                   BEG_USR_CR_o   => s_BEG_USER_CR,
                                   END_USR_CR_o   => s_END_USER_CR,
                                   BEG_USR_CSR_o  => s_BEG_USER_CSR,
                                   END_USR_CSR_o  => s_END_USER_CSR,
                                   BEG_CRAM_o     => s_BEG_CRAM,
                                   END_CRAM_o     => s_END_CRAM,
                                   FUNC0_ADEM_o   => s_FUNC_ADEM(0),
                                   FUNC1_ADEM_o   => s_FUNC_ADEM(1),
                                   FUNC2_ADEM_o   => s_FUNC_ADEM(2),
                                   FUNC3_ADEM_o   => s_FUNC_ADEM(3),
                                   FUNC4_ADEM_o   => s_FUNC_ADEM(4),
                                   FUNC5_ADEM_o   => s_FUNC_ADEM(5),
                                   FUNC6_ADEM_o   => s_FUNC_ADEM(6),
                                   FUNC7_ADEM_o   => s_FUNC_ADEM(7),
                                   FUNC0_AMCAP_o  => s_FUNC_AMCAP(0),
                                   FUNC1_AMCAP_o  => s_FUNC_AMCAP(1),
                                   FUNC2_AMCAP_o  => s_FUNC_AMCAP(2),
                                   FUNC3_AMCAP_o  => s_FUNC_AMCAP(3),
                                   FUNC4_AMCAP_o  => s_FUNC_AMCAP(4),
                                   FUNC5_AMCAP_o  => s_FUNC_AMCAP(5),
                                   FUNC6_AMCAP_o  => s_FUNC_AMCAP(6),
                                   FUNC7_AMCAP_o  => s_FUNC_AMCAP(7),
                                   FUNC0_XAMCAP_o => s_FUNC_XAMCAP(0),
                                   FUNC1_XAMCAP_o => s_FUNC_XAMCAP(1),
                                   FUNC2_XAMCAP_o => s_FUNC_XAMCAP(2),
                                   FUNC3_XAMCAP_o => s_FUNC_XAMCAP(3),
                                   FUNC4_XAMCAP_o => s_FUNC_XAMCAP(4),
                                   FUNC5_XAMCAP_o => s_FUNC_XAMCAP(5),
                                   FUNC6_XAMCAP_o => s_FUNC_XAMCAP(6),
                                   FUNC7_XAMCAP_o => s_FUNC_XAMCAP(7) 
                                  );                                 

  ---------------------METASTABILITY-----------------------------------------
  -- Input oversampling & edge detection; oversampling the input data is necessary to avoid 
  -- metastability problems. With 3 samples the probability of metastability problem will 
  -- be very low but of course the transfer rate will be slow down a little.

  ASfallingEdge : FallingEdgeDetection
  port map (
             sig_i      => VME_AS_n_i,
             clk_i      => clk_i,
             FallEdge_o => s_VMEaddrLatch
          ); 	

  RSTfallingEdge : RisEdgeDetection
  port map (
              sig_i      => s_reset,
              clk_i      => clk_i,
              RisEdge_o  => s_RSTedge
          );

  ASrisingEdge : RisEdgeDetection
  port map (
              sig_i     => VME_AS_n_i,
              clk_i     => clk_i,
              RisEdge_o => s_mainFSMreset
          ); 
  -- for 2e modes:
  DS1EdgeDetect : EdgeDetection
  port map (
              sig_i     => VME_DS_n_i(1),
              clk_i     => clk_i,
              sigEdge_o => s_DS1pulse
          );

  CRinputSample : DoubleRegInputSample
  generic map(
               width => 8
            )
  port map(
             reg_i => CRdata_i,      
             reg_o => s_CRdataIn,
             clk_i => clk_i
        );

  CRAMinputSample : DoubleRegInputSample
  generic map(
              width => 8
           )
  port map(
             reg_i => CRAMdata_i,
             reg_o => s_CRAMdataIn,
             clk_i => clk_i
         );

  

 ---------------------------Output for FIFO.vhd-------------------------------------|

  VMEtoWB <= '1' when (s_cardSel = '1' and (s_transferType = BLT or s_transferType = MBLT) and 
                      VME_WRITE_n_i = '0' and VME_DS_n_i /= "11") else '0';
  WBtoVME <= '1' when (s_cardSel = '1' and (s_transferType = BLT or s_transferType = MBLT) and 
                      VME_WRITE_n_i = '1' and VME_DS_n_i /= "11") else '0';
  transfer_done_o <= s_mainFSMreset;
  ------------------------------LEDS------------------------------------------------|
   leds(6) <= not s_transferActive;
   leds(2) <= s_led2;   
   leds(7) <= s_counter(25);
   leds(5) <= s_led5;
   leds(0) <= not(s_func_sel(0));                
   leds(1) <= s_led1;
   leds(3) <= s_led3; 
   leds(4) <= s_led4; 

 -------------------------------------------------------------------------------------------  
 -- This process implements a simple 32 bit counter. If the bitstream file has been downloaded
 -- correctly and the clock is working properly you can see a led flash on the board.
  process(clk_i)
  begin
     if rising_edge(clk_i) then
        if VME_RST_n_i = '0' then 
           s_counter <= (others => '0');
        else 
           s_counter <= s_counter + 1;
        end if;	
    end if;
  end process;

--------------------------------------------------------------------------------------
   s_transfer_done_i <= transfer_done_i when s_FIFO = '1' else '1';

process(clk_i)
  begin
     if rising_edge(clk_i) then
        if  s_reset = '1' then 
            s_led1 <= '1';  -- off
				s_led2 <= '1';
				s_led3 <= '1';
				s_led4 <= '1';
				s_led5 <= '1';
        else 
            s_led1 <= s_DSlatched(1);  
				s_led2 <= s_DSlatched(0);
				s_led3 <= s_VMEaddrLatched(1);
				s_led4 <= s_LWORDlatched;
				s_led5 <= s_VMEaddrLatched(2);		      
        end if;	
    end if;
  end process;
 	

     end RTL;
