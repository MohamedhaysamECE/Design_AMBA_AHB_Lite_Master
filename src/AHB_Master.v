`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 19.07.2025 09:19:12
// Design Name: 
// Module Name: AHB_Master
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


module AHB_Master(
//global signals 
input clk,
input Hresetn,

//signals of transaction from processor 
input trans_valid,
input [31:0] T_addr, 
input [2:0] T_burst, 
input [2:0] T_size,
input T_WR, //read T_WR=0 , write T_WR= 1
input [31:0] T_Dwrite,

//signals from slave 
input Hready,
input Hresp,
input [31:0]HRdata,

//output signals
output reg [31:0]    Haddr,
output reg           Hwrite,
output reg [2:0]     Hsize,
output reg [2:0]     Hburst,
output reg [1:0]     Htrans,
output reg [31:0]    HWdata,
output reg           HREADY //output ready signal to slave
    );

reg first_transfer; //flag to indicate if this is the first transfer in a burst

// Safe size limiter
wire [2:0] safe_size;
assign safe_size = (T_size <= 3'b010) ? T_size : 3'b010;

// Safe burst limiter
wire [2:0] safe_burst;
assign safe_burst = ((T_burst == 3'b000) || (T_burst == 3'b001)) ? T_burst : 3'b000;

//state machine states
reg [2:0] pre_state,next_state;

localparam IDLE = 3'b000,
           address_phase = 3'b001,
           data_phase = 3'b010,
           wait_state = 3'b011,
           busy_state = 3'b100,   //to hold data when master is busy
           error_state1 = 3'b101,   // cycle 1 of error
           error_state2 = 3'b110;   // cycle 2 of error


//present state logic
always @(posedge clk or negedge Hresetn) begin
    if (!Hresetn)
        pre_state <= IDLE;
    else
        pre_state <= next_state;

end


//next state logic
always @(*) begin
    case (pre_state)
        IDLE: begin
            if (trans_valid) begin
                next_state = address_phase;
            end else begin
                next_state = IDLE;
            end
        end
        
        address_phase: begin
            next_state = (!trans_valid && safe_burst == 3'b001) ? busy_state : data_phase;//go to busy state when trans_valid =0 and transfer to data phase when trans_valid =1
        end
        busy_state: begin
            next_state = trans_valid ? data_phase : busy_state;
            end
        data_phase: begin
                if (Hresp)
                    next_state = error_state1;
                else if (!Hready)
                    next_state = wait_state;
                else
                    next_state = address_phase;    
        end      

        wait_state: begin
                next_state = (Hready) ? address_phase : wait_state;
        end

        error_state1: begin
            next_state = Hready ? error_state2 : error_state1;
        end
        
        error_state2: begin
            next_state = (!trans_valid) ? IDLE : address_phase;
        end

        default:begin 
            next_state = IDLE; 
        end
    endcase
end


// output signals related to each state
// moore machine output depend on state only
    always @(pre_state) begin
            case (pre_state)
                IDLE: begin
                    Haddr   = 32'd0;
                    Hwrite  = 1'd0;
                    Hsize   = 3'd0;
                    Hburst  = 3'd0;
                    Htrans  = 2'b00; // IDLE
                    HWdata  = 32'd0;
                    first_transfer = 1'b1;
                    HREADY  = 1'b0; 
                end

                address_phase: begin
                    Hwrite  = T_WR;
                    Hsize   = safe_size;
                    Hburst  = safe_burst;
                    HREADY  = 1'b1; // Indicate that master is ready to start the transaction
                    // Warn if size is unsupported
                    if (T_size > 3'b010) begin
                        $display("Warning: Unsupported HSIZE %b at time %t. Using default = 4 Bytes (Word)", T_size, $time);
                    end

                    // Warn if burst type is unsupported
                    if (T_burst != 3'b000 && T_burst != 3'b001) begin
                        $display("Warning: Unsupported HBURST = %b at time %t. Defaulting to SINGLE (3'b000)", T_burst, $time);
                    end
                    
                    //assign the Htrans depending on type of burst
                        if (safe_burst == 3'b001) begin
                            if (!trans_valid)
                                Htrans = 2'b01; // BUSY
                            else if (first_transfer)
                                Htrans = 2'b10; // NONSEQ
                            else
                                Htrans = 2'b11; // SEQ
                        end else begin
                            Htrans = 2'b10; // NONSEQ for SINGLE
                        end

                    
                    //increment the address based on burst type and size
                    if (safe_burst == 3'b000) begin
                        Haddr = T_addr;          // SINGLE burst ? always T_addr
                        first_transfer = 1'b1;   // reset flag
                    end else begin
                        if (first_transfer) begin
                            Haddr = T_addr;      // first beat of INCR burst
                            first_transfer = 1'b0;
                        end else begin
                            Haddr = Haddr + (1 << safe_size); //if hsize =000 so beat = 1byte so address incr by 1
                                                               //if hsize =001 so beat = 2byte so address incr by 2
                                                               //if hsize =010 so beat = 4byte so address incr by 4 
                        end
                    end

                    end
                busy_state: begin
                    HREADY = 1'b0;
                    // no changes to signals during BUSY hold
                end    

                data_phase: begin
                    HREADY = 1'b1;
                    if (T_WR) 
                         HWdata = T_Dwrite; // write operation
                    else
                        $display("Received Data: %h", HRdata); // read operation
                end

                wait_state: begin
                    // Maintain the current signals
                    HREADY = 1'b1; 
                    Haddr  = Haddr;
                    Hwrite = Hwrite;
                    Hsize  = Hsize;
                    Hburst = Hburst;
                    Htrans = Htrans;
                    HWdata = HWdata;
                end

                error_state1: begin
                     HREADY = 1'b0;
                 end

                error_state2: begin
                    Htrans = 2'b00;
                    Hwrite = 1'd0;
                    Hsize = 3'd0;
                    Hburst = 3'd0;
                    HWdata = 32'd0;
                    first_transfer = 1'b0;
                    HREADY = 1'b0;
                end

                default: begin
                    Haddr   = 32'd0;
                    Hwrite  = 1'd0;
                    Hsize   = 3'd0;
                    Hburst  = 3'd0;
                    Htrans  = 2'b00; // IDLE
                    HWdata  = 32'd0;
                    HREADY  = 1'b0;     
                end

            endcase
        end
endmodule
