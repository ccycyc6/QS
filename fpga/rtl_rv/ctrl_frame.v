//=============================================================================
// ScreenSense - controller frame packer (track A, pre-sensor)
//-----------------------------------------------------------------------------
// Reads a simple parallel sensor bus and emits one 12-byte frame at ~100 Hz:
//
//   [0] A5  [1] 5A  [2] seq  [3] jx  [4] jy
//   [5] ax_hi [6] ax_lo  [7] ay_hi [8] ay_lo  [9] az_hi [10] az_lo
//   [11] buttons_lo
//
// Until a real IMU exists, DEMO=1 drives the bus from internal generators so
// the whole path (IC -> UART -> PC) can be exercised end to end.
//=============================================================================
`timescale 1ns / 1ps

module ctrl_frame #(
    parameter integer CLK_HZ    = 74_250_000,
    parameter integer PERIOD_MS = 10,
    parameter integer DEMO      = 1
) (
    input  wire               clk,
    input  wire               rst_n,
    // sensor bus (tie off / ignore when DEMO=1)
    input  wire signed [15:0] s_ax,
    input  wire signed [15:0] s_ay,
    input  wire signed [15:0] s_az,
    input  wire        [15:0] s_btn,
    // uart
    output reg                uart_start,
    output reg  [7:0]         uart_data,
    input  wire               uart_busy,
    // observation
    output reg                frame_pulse
);

    localparam integer PERIOD = 74_250 * PERIOD_MS;   // clocks

    reg [31:0] tick;
    reg [15:0] seq;
    reg [3:0]  idx;
    reg        sending;

    // ---- demo generators -------------------------------------------------
    reg [19:0] demo_cnt;
    reg [15:0] d_ax, d_ay, d_az;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            demo_cnt <= 20'd0;
            d_ax <= 16'd0; d_ay <= 16'd0; d_az <= 16'd0;
        end else begin
            demo_cnt <= demo_cnt + 20'd1;
            d_ax <= {4'd0, demo_cnt[19:8]};
            d_ay <= {4'd0, ~demo_cnt[19:8]};
            d_az <= 16'h0400;
        end
    end

    wire [15:0] v_ax = (DEMO != 0) ? d_ax : $unsigned(s_ax);
    wire [15:0] v_ay = (DEMO != 0) ? d_ay : $unsigned(s_ay);
    wire [15:0] v_az = (DEMO != 0) ? d_az : $unsigned(s_az);
    wire [15:0] v_btn = (DEMO != 0) ? 16'h0000 : s_btn;

    // ---- frame byte mux --------------------------------------------------
    reg [7:0] byte_sel;

    always @(*) begin
        case (idx)
            4'd0:  byte_sel = 8'hA5;
            4'd1:  byte_sel = 8'h5A;
            4'd2:  byte_sel = seq[7:0];
            4'd3:  byte_sel = 8'd0;
            4'd4:  byte_sel = 8'd0;
            4'd5:  byte_sel = v_ax[15:8];
            4'd6:  byte_sel = v_ax[7:0];
            4'd7:  byte_sel = v_ay[15:8];
            4'd8:  byte_sel = v_ay[7:0];
            4'd9:  byte_sel = v_az[15:8];
            4'd10: byte_sel = v_az[7:0];
            default: byte_sel = v_btn[7:0];
        endcase
    end

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            tick        <= 32'd0;
            seq         <= 16'd0;
            idx         <= 4'd0;
            sending     <= 1'b0;
            uart_start  <= 1'b0;
            uart_data   <= 8'd0;
            frame_pulse <= 1'b0;
        end else begin
            uart_start  <= 1'b0;
            frame_pulse <= 1'b0;

            if (!sending) begin
                tick <= tick + 32'd1;
                if (tick >= PERIOD) begin
                    tick    <= 32'd0;
                    sending <= 1'b1;
                    idx     <= 4'd0;
                    seq     <= seq + 16'd1;
                end
            end else if (!uart_busy) begin
                uart_start <= 1'b1;
                uart_data  <= byte_sel;
                if (idx == 4'd11) begin
                    sending     <= 1'b0;
                    frame_pulse <= 1'b1;
                end else begin
                    idx <= idx + 4'd1;
                end
            end
        end
    end

endmodule
