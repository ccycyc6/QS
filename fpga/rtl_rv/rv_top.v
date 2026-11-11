//=============================================================================
// ScreenSense - RISC-V control-plane subsystem (track B, option 2)
//-----------------------------------------------------------------------------
// Wraps the ARES 5-stage core (student_top) with:
//   * a power-on reset stretcher on the shared clock (no new clock domain),
//   * all unused SoC ports tied off,
//   * one observable output so the core cannot be trimmed by synthesis.
//
// ARES sources are NOT modified.  The whole subsystem is instantiated from
// hdmi_loop.sv only when WITH_RV is defined (see rtl_pds/rv_cfg.vh).
//
// Clock: the caller passes pixclk_video (74.25 MHz).  The core is designed for
// 100 MHz, so 74.25 is a safe derating -- and reusing an existing clock avoids
// adding a PLL output and a new BKCL/BUFG tree.
//=============================================================================
`timescale 1ns / 1ps

module rv_top (
    input  wire clk,        // pixclk_video, 74.25 MHz
    input  wire rst_n,      // asynchronous reset, active low
    output wire led,        // observable heartbeat (goes to led_int)
    output wire uart_tx     // SoC UART TX (idle high)
);

    // ---- power-on reset stretcher: 512 clocks (~7 us) ----
    reg [8:0] rst_cnt;
    reg       core_rst;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            rst_cnt  <= 9'd0;
            core_rst <= 1'b1;
        end else if (rst_cnt != 9'h1FF) begin
            rst_cnt  <= rst_cnt + 9'd1;
            core_rst <= 1'b1;
        end else begin
            core_rst <= 1'b0;
        end
    end

    // ---- SoC outputs ----
    wire [31:0] virtual_led;
    wire [39:0] virtual_seg;
    wire        retire_valid;
    wire [31:0] retire_pc;
    wire [31:0] retire_pc_next;
    wire        retire_rd_wen;
    wire [4:0]  retire_rd;
    wire [31:0] retire_wdata;
    wire        retire_is_ebreak;
    wire [7:0]  uart_tx_data;
    wire        uart_tx_start;

    student_top #(
        // Keep the mainline single-hart profile; shrink only the data RAM.
        .EXTERNAL_IROM (0),
        .USE_ICACHE    (1),
        .DRAM_AW       (12),                  // 4 KiB data RAM (was 256 KiB)
        .DRAM_INIT_FILE("build/pipeline/dram.hex")
    ) u_soc (
        .w_cpu_clk     (clk),
        .w_clk_50Mhz   (clk),
        .w_clk_rst     (core_rst),
        .virtual_key   (8'd0),
        .virtual_sw    (64'd0),
        .uart_rx_data  (8'd0),
        .uart_rx_ready (1'b0),
        .uart_tx_busy  (1'b0),
        .uart_tx_data  (uart_tx_data),
        .uart_tx_start (uart_tx_start),
        .virtual_led   (virtual_led),
        .virtual_seg   (virtual_seg),
        .retire_valid  (retire_valid),
        .retire_pc     (retire_pc),
        .retire_pc_next(retire_pc_next),
        .retire_rd_wen (retire_rd_wen),
        .retire_rd     (retire_rd),
        .retire_wdata  (retire_wdata),
        .retire_is_ebreak(retire_is_ebreak),
        .irom_req_valid(),
        .irom_req_addr (),
        .irom_req_ready(1'b0),
        .irom_rsp_valid(1'b0),
        .irom_rsp_data (32'd0),
        .irom_rsp_ready(),
        .irom_flush    (),
        .shared_rdata  (32'd0),
        .shared_req_valid(),
        .shared_req_write(),
        .shared_req_addr (),
        .shared_req_wdata(),
        .shared_req_wstrb()
    );

    // Observable: any of these toggling keeps the core alive through synthesis.
    assign led     = virtual_led[0] ^ retire_valid ^ retire_pc[2] ^ uart_tx_start;
    assign uart_tx = 1'b1;   // the UART module lives in the caller; left idle

endmodule
