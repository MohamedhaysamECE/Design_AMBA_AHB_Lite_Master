`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 26.07.2025 14:30:38
// Design Name: 
// Module Name: master_tb
// Project Name: 
// Target Devices: 
// Tool Versions: 
// Description: 
// 
// Dependencies: 
// 
// Revision:
// Revision 0.01 - File Created
// Additional Comments:
// 
//////////////////////////////////////////////////////////////////////////////////



module Master_tb;
  // Clock and reset
  reg clk;
  reg Hresetn;

  // Inputs to Master
  reg trans_valid;
  reg [31:0] T_addr;
  reg [2:0]  T_burst;
  reg [2:0]  T_size;
  reg        T_WR;
  reg [31:0] T_Dwrite;

  // Slave response
  reg Hready;
  reg Hresp;
  reg [31:0] HRdata;

  // Outputs from Master
  wire [31:0] Haddr;
  wire        Hwrite;
  wire [2:0]  Hsize;
  wire [2:0]  Hburst;
  wire [1:0]  Htrans;
  wire [31:0] HWdata;
  wire        HREADY;

  // Instantiate the AHB_Master
  AHB_Master M1 (
    .clk(clk),
    .Hresetn(Hresetn),
    .trans_valid(trans_valid),
    .T_addr(T_addr),
    .T_burst(T_burst),
    .T_size(T_size),
    .T_WR(T_WR),
    .T_Dwrite(T_Dwrite),
    .Hready(Hready),
    .Hresp(Hresp),
    .HRdata(HRdata),
    .Haddr(Haddr),
    .Hwrite(Hwrite),
    .Hsize(Hsize),
    .Hburst(Hburst),
    .Htrans(Htrans),
    .HWdata(HWdata),
    .HREADY(HREADY));

  // Clock generation
  always #5 clk = ~clk; //frequency 100 MHZ 

  // Task to send a transaction
  task send_transaction(
    input [31:0] addr,
    input [2:0] burst,
    input [2:0] size,
    input wr,
    input [31:0] data
  );
  begin
    @(posedge clk);
    T_addr      <= addr;
    T_burst     <= burst;
    T_size      <= size;
    T_WR        <= wr;
    T_Dwrite    <= data;
   // @(posedge clk);
  //  trans_valid <= 0;
  end
  endtask

  initial begin
    // Initialize signals
    clk = 0;
    Hresetn = 0;
    trans_valid = 0;
    T_addr = 0;
    T_burst = 0;
    T_size = 0;
    T_WR = 0;
    T_Dwrite = 0;
    Hready = 1;
    Hresp = 0;
    HRdata = 32'hDEADBEEF;

    // Apply reset
    #20; Hresetn = 1;
    trans_valid = 1;
      // 1. Single burst with sizes 1, 2, 4 bytes
    $display("\n--- SINGLE BURST with SIZES 1, 2, 4 Bytes ---");
    trans_valid = 1;
    send_transaction(32'h1000_0000, 3'b000, 3'b000, 1, 32'hA1); // 1 byte
    repeat (3) @(posedge clk);
    send_transaction(32'h2000_0000, 3'b000, 3'b001, 0, 32'hA2); // 2 bytes with read operation 
    repeat (3) @(posedge clk);
    send_transaction(32'h3000_0000, 3'b000, 3'b010, 1, 32'hA3); // 4 bytes
    repeat (3) @(posedge clk);

    // 2. Single burst with unsupported size > 010
    $display("\n--- SINGLE BURST with UNSUPPORTED SIZE > 010 ---");
    send_transaction(32'h1000_0010, 3'b000, 3'b011, 1, 32'hBEEF_BEEF);
    repeat (3) @(posedge clk);

    // 3. INCR burst with 4-byte size, no wait
    $display("\n--- INCR BURST 4-byte size without WAIT ---");
    send_transaction(32'h2000_0000, 3'b001, 3'b010, 1, 32'hC1);
    repeat (2) @(posedge clk);
    send_transaction(32'h0000_0000, 3'b001, 3'b010, 1, 32'hC2);
    repeat (2) @(posedge clk);
    send_transaction(32'h0000_0000, 3'b001, 3'b010, 1, 32'hC3);
    repeat (3) @(posedge clk);

    // 4. INCR burst with wait state
    $display("\n--- INCR BURST with WAIT STATE ---");
    send_transaction(32'h2100_0000, 3'b001, 3'b010, 1, 32'hD1);
    repeat (1) @(posedge clk);
    Hready = 0; repeat(2) @(posedge clk); Hready = 1;
    send_transaction(32'h0000_0000, 3'b001, 3'b010, 1, 32'hD2);
    repeat (3) @(posedge clk);

    // 5. INCR burst with BUSY master
    $display("\n--- INCR BURST with BUSY MASTER ---");
    send_transaction(32'h0000_0000, 3'b001, 3'b010, 1, 32'hD2);
    repeat (2) @(posedge clk);
    trans_valid = 0;
    repeat (2) @(posedge clk);
    trans_valid = 1;
    send_transaction(32'h2200_0000, 3'b001, 3'b010, 1, 32'hE1);
    repeat (3) @(posedge clk);

    // 6. Unsupported burst type
    $display("\n--- UNSUPPORTED BURST TYPE ---");
    send_transaction(32'h2300_0000, 3'b011, 3'b010, 1, 32'hF1);
    repeat (3) @(posedge clk);
    // ---------------------------
    // 7. ERROR and master CONTINUES burst
    // ---------------------------
    $display("\n--- ERROR: CONTINUE BURST ---");
    send_transaction(32'h3000_0000, 3'b001, 3'b010, 1, 32'hE001);
    repeat (4) @(posedge clk);
    Hready = 0; Hresp = 1; // simulate ERROR (cycle 1 of error)
    repeat (2) @(posedge clk);
    Hready = 1;  // cycle 2 of error (end error response)
    repeat (2) @(posedge clk);
    Hresp = 0;             // back to OKAY
    send_transaction(32'h0000_0000, 3'b001, 3'b010, 1, 32'hE002);
    repeat (3) @(posedge clk);
    // ---------------------------
    // 8. ERROR and master CANCELS burst
    // ---------------------------
    $display("\n--- ERROR: CANCEL BURST ---");
    send_transaction(32'h4000_0000, 3'b001, 3'b010, 1, 32'hC001);
    repeat (1) @(posedge clk);
    Hready = 0; Hresp = 1; // simulate ERROR (cycle 1)
    repeat (1) @(posedge clk);
    Hready = 1; Hresp = 1; // cycle 2 (ERROR ends)
    repeat (1) @(posedge clk);
    Hresp = 0;

    trans_valid = 0; // cancel burst
    repeat (1) @(posedge clk);
    trans_valid = 1; // start new transaction
    send_transaction(32'h5000_0000, 3'b000, 3'b010, 1, 32'hC002); // new SINGLE transaction
    repeat (3) @(posedge clk);
    $finish;
  end

endmodule
