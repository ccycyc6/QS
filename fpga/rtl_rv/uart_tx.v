//=============================================================================
// ScreenSense - minimal 8N1 UART transmitter
//-----------------------------------------------------------------------------
// 115200 baud at 74.25 MHz -> 644 clocks per bit (rounded).
// Handshake: pulse start with data, wait for busy to fall.
//=============================================================================
`timescale 1ns / 1ps

module uart_tx #(
    parameter integer CLK_HZ = 74_250_000,
    parameter integer BAUD   = 115200
) (
    input  wire       clk,
    input  wire       rst_n,
    input  wire       start,
    input  wire [7:0] data,
    output reg        busy,
    output reg        tx
);

    localparam integer DIV = CLK_HZ / BAUD;   // 644 @ 74.25 MHz

    reg [9:0]  shifter;      // {stop, data[7:0], start}
    reg [9:0]  bit_cnt;
    reg [15:0] div_cnt;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            tx      <= 1'b1;
            busy    <= 1'b0;
            shifter <= 10'h3FF;
            bit_cnt <= 10'd0;
            div_cnt <= 16'd0;
        end else if (!busy) begin
            tx <= 1'b1;
            if (start) begin
                shifter <= {1'b1, data, 1'b0};
                busy    <= 1'b1;
                bit_cnt <= 10'd0;
                div_cnt <= 16'd0;
                tx      <= 1'b0;          // start bit
            end
        end else begin
            if (div_cnt == DIV - 1) begin
                div_cnt <= 16'd0;
                if (bit_cnt == 10'd9) begin
                    busy <= 1'b0;
                    tx   <= 1'b1;
                end else begin
                    bit_cnt <= bit_cnt + 10'd1;
                    tx      <= shifter[0];
                    shifter <= {1'b1, shifter[9:1]};
                end
            end else begin
                div_cnt <= div_cnt + 16'd1;
            end
        end
    end

endmodule
