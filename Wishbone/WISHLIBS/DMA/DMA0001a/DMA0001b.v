//----------------------------------------------------------------------
//-- Module name:     DMA0001b.v
//--
//-- Description:     A very simple 32-bit DMA unit.  For more infor-
//--                  mation, please refer to the WISHBONE Public Domain
//--                  Library Technical Reference Manual.
//--
//-- History:         Project rewritten:          JZ
//-- History:         Project complete:           SEP 19, 2001
//--                                              WD Peterson
//--                                              Silicore Corporation
//----------------------------------------------------------------------

module DMA0001b (
  //-- WISHBONE Signals

  input          ACK_I,
  output  [4:0]  ADR_O,
  input          CLK_I,
  output         CYC_O,
  input  [31:0]  DAT_I,
  output [31:0]  DAT_O,
  input          RST_I,
  output         SEL_O,
  output         STB_O,
  output         WE_O,

   //-- NON-WISHBONE Signals

  input          DMODE,
  input   [1:0]  IA,
  input  [31:0]  ID
);

  wire         INC;    
  wire         INP;    
  wire         TC;     
  reg          WE;     
  reg          SAS;    
  reg    [4:0] LADR_O; 
  reg   [31:0] LBDAT;  
  reg   [31:0] LDAT_O; 

  //------------------------------------------------------------------
  //-- CONTROL STATE MACHINE
  //
  // DMA initiates a SINGLE WRITE cycle beginning at the [CLK_I] rising
  // edge immediately after the reset input [RST_I] is negated. After the write cycle is
  // completed, the DMA initiates a SINGLE READ cycle. The write / read cycles repeat
  // indefinitely. Note there is a one-cycle read/write toggle overhead.
  //
  //    ___     ___     ___     ___     ___     ___     ___     ___  
  //   |   |   |   |   |   |   |   |   |   |   |   |   |   |   |   |
  //---+   +---+   +---+   +---+   +---+   +---+   +---+   +---+   +---  (CLK)
  //
  //  Read cyc              write cyc                     read cyc
  //----------+        +----------\\ ----------+        +-------\\-----  (SAS)
  //          |________|                       |________| 
  //
  //
  //------------------------------------------------------------------
  always @ (posedge CLK_I) begin

    // 
    // Note SAS is tied to STB_O and CYC_O, which meets RULE 3.25
    //
    // Set SAS to low when a bus cycle is complete (INP = 1)
    // Set SAS to high when a bus cycle is not complete (INP = 0)
    SAS <= ~RST_I & ~(SAS & INP);  
                                   
    // Togge WE (read <-> write) when a bus cycle is complete (SAS = 0)
    // Keep WE when a bus cycle is not complete (SAS = 1)
    WE  <= ~RST_I & ~(WE ^ SAS);   
  end

  //------------------------------------------------------------------
  //-- MODE CONTROL
  //
  // Single READ/WRITE if DMODE = 0 
  // Block READ/WRITE if DMODE = 1
  //
  // INP is asserted when ACK is asserted in the single-cycle mode 
  // INP is asserted when the number of counts is 7 in the block-cycle mode 
  //------------------------------------------------------------------
  assign INP = ( ~DMODE & INC ) | ( DMODE & TC );

  //------------------------------------------------------------------
  //-- Generate the terminal count (carry forward) logic from the
  //-- counter.
  //------------------------------------------------------------------

  assign TC = LADR_O[2] & LADR_O[1] & LADR_O[0];

  //------------------------------------------------------------------
  //-- INC gate.
  //------------------------------------------------------------------

  assign INC = ACK_I & SAS;

  //------------------------------------------------------------------
  //-- IDREG (Input Data REGister).
  //------------------------------------------------------------------

  always @ (posedge CLK_I) begin
    if (RST_I)
      LBDAT <= 32'b0;
    else if( INC & ~WE ) // at address increment and asserted read 
      LBDAT <= DAT_I;
  end

  //------------------------------------------------------------------
  //-- ODREG (Output Data REGister).
  //------------------------------------------------------------------

  always @ (posedge CLK_I) begin
    if (RST_I)
      LDAT_O <= ID;
    else if (INC & ~WE)
      LDAT_O <= LBDAT;
  end


  //------------------------------------------------------------------
  //-- AREG (Address REGister) 
  //
  // The highest two address bits generated by the DMA are latched in 
  // response to a reset. This allows each DMA (in a benchmarking system)
  // to target a unique SLAVE. The lower three address bits are generated
  // by a counter that counts from 0x0 to 0x7, and rolls over from 0x7 to 0x0.
  // 
  // After each bus cycle (READ or WRITE) is completed, 
  // the DMA increments its address
  //------------------------------------------------------------------
  always @ (posedge CLK_I) begin
    if (RST_I)
      LADR_O[2:0] <= 3'b0;
    else if (INC)
      LADR_O[2:0] <= LADR_O[2:0] + 3'b1;
  end

  always @ (posedge CLK_I) begin
    if (RST_I)
      LADR_O[4:3] <= IA;
    else 
      LADR_O[4:3] <= LADR_O[4:3];
  end

  //------------------------------------------------------------------
  //-- Make the outputs visible to the outside world.  Also connect
  //-- up some of the miscellaneous signals.
  //------------------------------------------------------------------

  assign ADR_O = LADR_O;
  assign CYC_O = SAS;
  assign DAT_O = LDAT_O;
  assign SEL_O = 1'b1;
  assign STB_O = SAS;
  assign WE_O  = WE;



endmodule 

