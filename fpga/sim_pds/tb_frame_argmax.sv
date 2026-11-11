`timescale 1ns / 1ps
// Self-checking TB for frame_argmax: drives three frames and compares
// the latched result against the expected argmax.
module tb_frame_argmax;

    reg clk = 0;
    reg rst_n = 0;
    reg in_valid = 0;
    reg [31:0] in_packet = 0;
    reg frame_done = 0;
    wire out_valid;
    wire [31:0] out_packet;
    wire [15:0] det_count;

    integer errors = 0;

    frame_argmax #(.CONF_THRESH(8'd50)) dut (
        .clk(clk), .rst_n(rst_n),
        .in_valid(in_valid), .in_packet(in_packet), .frame_done(frame_done),
        .out_valid(out_valid), .out_packet(out_packet), .det_count(det_count)
    );

    always #5 clk = ~clk;

    task send(input [7:0] cls, input [7:0] x, input [7:0] y, input [7:0] conf);
        begin
            @(negedge clk); in_valid = 1; in_packet = {cls, x, y, conf};
            @(negedge clk); in_valid = 0;
        end
    endtask

    task end_frame;
        begin
            @(negedge clk); frame_done = 1;
            @(negedge clk); frame_done = 0;
            #1;   // sample after the negedge, before the next posedge clears out_valid
        end
    endtask

    initial begin
        repeat (3) @(negedge clk);
        rst_n = 1;
        repeat (2) @(negedge clk);

        // frame 1: two packets above threshold, second is stronger
        send(8'd1, 8'd10, 8'd20, 8'd60);
        send(8'd2, 8'd11, 8'd21, 8'd90);
        send(8'd3, 8'd12, 8'd22, 8'd10);   // below threshold
        end_frame;
        if (out_valid !== 1'b1) begin $display("FAIL f1 valid"); errors = errors + 1; end
        if (det_count !== 16'd2) begin $display("FAIL f1 count=%0d", det_count); errors = errors + 1; end
        if (out_packet !== {8'd2, 8'd11, 8'd21, 8'd90}) begin
            $display("FAIL f1 packet=%h", out_packet); errors = errors + 1; end

        // frame 2: nothing above threshold
        send(8'd1, 8'd1, 8'd2, 8'd7);
        end_frame;
        if (out_valid !== 1'b0) begin $display("FAIL f2 valid"); errors = errors + 1; end
        if (det_count !== 16'd0) begin $display("FAIL f2 count=%0d", det_count); errors = errors + 1; end

        // frame 3: tie -> first wins
        send(8'd1, 8'd5, 8'd5, 8'd70);
        send(8'd2, 8'd6, 8'd6, 8'd70);
        end_frame;
        if (out_packet !== {8'd1, 8'd5, 8'd5, 8'd70}) begin
            $display("FAIL f3 tie packet=%h", out_packet); errors = errors + 1; end

        if (errors == 0) $display("frame_argmax: PASSED");
        else             $display("frame_argmax: %0d FAILURES", errors);
        $finish;
    end

    initial begin #10000; $display("TIMEOUT"); $finish; end
endmodule
