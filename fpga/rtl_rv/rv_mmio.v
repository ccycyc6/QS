//=============================================================================
// ScreenSense - RISC-V <-> vision register bridge (option B, 'small scheduler')
//-----------------------------------------------------------------------------
// The core reaches this block through the SoC's shared uncached MMIO window
// (addr[31:8] == 24'hA000F0), which needs no ARES source change.
//
// Address map (word offsets inside 0xA000F0xx):
//   0x00  R   last detection packet  {cls[31:24], x[23:16], y[15:8], conf[7:0]}
//   0x04  R   sequence number of that packet (increments per new detection)
//   0x08  R   {15'b0, valid_sticky} - high once any detection was seen
//   0x0C  R   detection count of the last frame
//   0x10  RW  control: bit0 = gate_enable (written by the CPU)
//   0x14  RW  reserved (threshold knob)
//
// Clocking: the vision side runs on clk_vis (clk_pe, 148.5 MHz), the CPU side on
// clk_cpu (pixclk_video, 74.25 MHz).  Data crosses with a toggle handshake
// (payload held stable while the toggle crosses); the gate bit crosses with a
// 2-flop synchroniser because it is quasi-static.
//=============================================================================
`timescale 1ns / 1ps

module rv_mmio (
    // ---- CPU side: clk_cpu ----
    input  wire        clk_cpu,
    input  wire        rst_n_cpu,
    input  wire        sh_valid,
    input  wire        sh_write,
    input  wire [31:0] sh_addr,
    input  wire [31:0] sh_wdata,
    input  wire [3:0]  sh_wstrb,
    output wire [31:0] sh_rdata,

    // ---- vision side: clk_vis ----
    input  wire        clk_vis,
    input  wire        rst_n_vis,
    input  wire        tgt_valid,
    input  wire [31:0] tgt_packet,
    input  wire [15:0] det_count,

    // ---- gate back to the vision pipeline ----
    output wire        gate_o
);

    // ================= vision side: capture + toggle ===================
    reg [31:0] v_pkt;
    reg [15:0] v_cnt;
    reg        v_tog;

    always @(posedge clk_vis or negedge rst_n_vis) begin
        if (!rst_n_vis) begin
            v_pkt <= 32'd0;
            v_cnt <= 16'd0;
            v_tog <= 1'b0;
        end else if (tgt_valid) begin
            v_pkt <= tgt_packet;
            v_cnt <= det_count;
            v_tog <= ~v_tog;
        end
    end

    // ================= CPU side: synchronise the toggle ================
    reg [2:0] tog_sync;
    always @(posedge clk_cpu or negedge rst_n_cpu) begin
        if (!rst_n_cpu) tog_sync <= 3'd0;
        else            tog_sync <= {tog_sync[1:0], v_tog};
    end
    wire pkt_edge = tog_sync[1] ^ tog_sync[2];

    reg [31:0] pkt_reg;
    reg [15:0] seq_reg;
    reg [15:0] cnt_reg;
    reg        valid_reg;

    always @(posedge clk_cpu or negedge rst_n_cpu) begin
        if (!rst_n_cpu) begin
            pkt_reg   <= 32'd0;
            seq_reg   <= 16'd0;
            cnt_reg   <= 16'd0;
            valid_reg <= 1'b0;
        end else if (pkt_edge) begin
            pkt_reg   <= v_pkt;          // payload is stable, toggle already crossed
            cnt_reg   <= v_cnt;
            seq_reg   <= seq_reg + 16'd1;
            valid_reg <= 1'b1;
        end
    end

    // ================= CPU side: control registers =====================
    reg [31:0] ctrl_reg;
    reg [31:0] thresh_reg;

    always @(posedge clk_cpu or negedge rst_n_cpu) begin
        if (!rst_n_cpu) begin
            ctrl_reg   <= 32'd0;
            thresh_reg <= 32'd0;
        end else if (sh_valid && sh_write) begin
            case (sh_addr[7:2])
                6'h04: ctrl_reg   <= sh_wdata;
                6'h05: thresh_reg <= sh_wdata;
                default: ;
            endcase
        end
    end

    assign sh_rdata = (sh_addr[7:2] == 6'h00) ? pkt_reg            :
                      (sh_addr[7:2] == 6'h01) ? {16'd0, seq_reg}    :
                      (sh_addr[7:2] == 6'h02) ? {31'd0, valid_reg}  :
                      (sh_addr[7:2] == 6'h03) ? {16'd0, cnt_reg}    :
                      (sh_addr[7:2] == 6'h04) ? ctrl_reg            :
                      (sh_addr[7:2] == 6'h05) ? thresh_reg          :
                      32'd0;

    // ================= gate: CPU -> vision (quasi-static) ===============
    wire gate_cpu = ctrl_reg[0];
    reg [1:0] gate_sync;
    always @(posedge clk_vis or negedge rst_n_vis) begin
        if (!rst_n_vis) gate_sync <= 2'b00;
        else            gate_sync <= {gate_sync[0], gate_cpu};
    end
    assign gate_o = gate_sync[1];

endmodule
