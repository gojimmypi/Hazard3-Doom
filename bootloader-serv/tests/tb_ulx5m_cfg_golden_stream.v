`timescale 1ns/1ps
`default_nettype none
/* Simulation only: exercise model with each byte of verified seed-147 .bit.
 * format_verified/policy_authorized are MOCKED HIGH for data-path coverage.
 * No CC_CFG_CTRL instance, flash/JTAG access or application boot is present.
 */
module tb_ulx5m_cfg_golden_stream;
    localparam integer IMAGE_BYTES = 414867;
    reg clk = 1'b0;
    always #10 clk = ~clk;
    reg rst = 1'b1;
    reg start = 1'b0;
    reg [7:0] read_data = 8'd0;
    reg read_valid = 1'b0;
    wire read_request, cfg_en, cfg_valid, cfg_recfg;
    wire busy, done, failed, usb_quiesce;
    wire [7:0] cfg_data;
    reg [7:0] image_data [0:IMAGE_BYTES - 1];
    reg [1023:0] hex_filename;
    integer offered = 0;
    integer observed = 0;
    integer cycle = 0;
    integer first_en = -1;
    integer last_valid = -1;
    reg prev_en = 1'b0;
    reg en_ended = 1'b0;

    ulx5m_cfg_handoff_model #(
        .READ_TIMEOUT(16), .MAX_BYTES(32'd414867)
    ) dut (
        .clk(clk), .rst(rst), .start(start),
        .mode_valid(1'b1), .dfu_selected(1'b0),
        .integrity_ok(1'b1), .format_verified(1'b1),
        .policy_authorized(1'b1), .spi_exclusive(1'b1),
        .image_bytes(32'd414867),
        .read_data(read_data), .read_valid(read_valid),
        .read_error(1'b0), .read_request(read_request),
        .cfg_data_model(cfg_data), .cfg_en_model(cfg_en),
        .cfg_valid_model(cfg_valid), .cfg_recfg_model(cfg_recfg),
        .busy(busy), .done(done), .failed(failed),
        .usb_quiesce_model(usb_quiesce)
    );

    /* Mock read-only flash: one byte on request, never a write or command. */
    always @(negedge clk) begin
        if (!rst && read_request && offered < IMAGE_BYTES) begin
            read_data = image_data[offered];
            read_valid = 1'b1;
            offered = offered + 1;
        end else begin
            read_valid = 1'b0;
        end
    end

    always @(negedge clk) begin
        cycle = cycle + 1;
        if (!rst) begin
            if (cfg_en && !prev_en)
                first_en = cycle;
            if (cfg_valid) begin
                if (!cfg_en || !cfg_recfg)
                    $fatal(1, "VALID without EN and RECFG");
                if (first_en < 0 || (observed == 0 && cycle - first_en < 3))
                    $fatal(1, "EN lead time too short");
                if (last_valid >= 0 && cycle - last_valid < 2)
                    $fatal(1, "Missing interbyte gap");
                if (observed >= IMAGE_BYTES || cfg_data !== image_data[observed])
                    $fatal(1, "Byte mismatch at offset 0x%08x", observed);
                observed = observed + 1;
                last_valid = cycle;
            end
            if (!cfg_en && prev_en) begin
                en_ended = 1'b1;
                if (!done || observed != IMAGE_BYTES ||
                    last_valid < 0 || cycle - last_valid < 8)
                    $fatal(1, "EN fell early or before all bytes");
            end
            if (failed)
                $fatal(1, "Model failed at byte %0d", observed);
            prev_en = cfg_en;
        end
    end

    initial begin
        /* The hex file is generated in a temporary directory by Python. */
        if (!$value$plusargs("IMAGE_HEX=%s", hex_filename))
            $fatal(1, "+IMAGE_HEX=FILE required");
        $readmemh(hex_filename, image_data);
        repeat (5) @(negedge clk);
        rst = 1'b0;
        @(negedge clk);
        start = 1'b1;
        @(negedge clk);
        start = 1'b0;
        wait (done);
        repeat (2) @(negedge clk);
        #1;
        if (offered != IMAGE_BYTES || observed != IMAGE_BYTES || !en_ended ||
            cfg_en || cfg_valid || read_request || failed || !usb_quiesce)
            $fatal(1, "Missing bytes or wrong model final state");
        $display("[PASS] Golden seed-147 .bit: %0d/%0d bytes compared in order", observed, IMAGE_BYTES);
        $display("[PASS] Golden stream model: EN lead, gaps, tail, RECFG");
        $display("[NOTE] Byte pacing only; configuration format/handoff/recovery NOT validated");
        $finish;
    end

    initial begin
        #100000000;
        $fatal(1, "Golden-stream model timeout");
    end
endmodule
`default_nettype wire
