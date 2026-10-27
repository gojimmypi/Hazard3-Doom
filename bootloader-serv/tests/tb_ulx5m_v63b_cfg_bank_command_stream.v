`timescale 1ns/1ps
`default_nettype none
/* Synthetic 11,22,33 vector tests timing only -- NOT GateMate opcodes. */
module tb_ulx5m_v63b_cfg_bank_command_stream;
    reg clk = 0;
    always #5 clk = ~clk;
    reg rst = 1;
    reg request = 0;
    reg normal_mode = 0;
    reg spi_released = 0;

    wire stream_clk, stream_en, stream_valid, stream_busy, stream_done;
    wire stream_blocked;
    wire [7:0] stream_data;
    ulx5m_cfg_bank_command_stream #(
        .COMMAND_LEN(3), .COMMAND_BYTES(512'h332211)
    ) dut (
        .clk(clk), .rst(rst), .request(request),
        .normal_mode(normal_mode), .spi_released(spi_released),
        .cfg_clk(stream_clk), .cfg_en(stream_en), .cfg_valid(stream_valid),
        .cfg_data(stream_data), .busy(stream_busy),
        .done(stream_done), .blocked(stream_blocked)
    );

    wire disabled_en, disabled_valid, disabled_done, disabled_blocked;
    wire [7:0] disabled_data;
    ulx5m_cfg_bank_command_stream default_off (
        .clk(clk), .rst(rst), .request(request),
        .normal_mode(normal_mode), .spi_released(spi_released),
        .cfg_clk(), .cfg_en(disabled_en), .cfg_valid(disabled_valid),
        .cfg_data(disabled_data), .busy(),
        .done(disabled_done), .blocked(disabled_blocked)
    );

    integer lead = 0;
    integer gaps = 0;
    integer tail = 0;
    integer sent = 0;
    integer prev_valid = 0;
    integer prev_en = 0;
    reg monitor = 0;

    always @(posedge clk) begin
        if (disabled_en || disabled_valid || disabled_done || disabled_data != 0)
            $fatal(1, "Default-off helper generated configuration activity");
        if (monitor) begin
            if (stream_valid) begin
                if (!stream_en || !normal_mode || !spi_released)
                    $fatal(1, "VALID without exclusive safe mode");
                if (sent == 0 && lead < 3)
                    $fatal(1, "EN lead was shorter than 3 clocks");
                if (sent > 0 && gaps < 1)
                    $fatal(1, "No idle cycle between successive bytes");
                case (sent)
                    0: if (stream_data !== 8'h11) $fatal(1, "Wrong byte 0");
                    1: if (stream_data !== 8'h22) $fatal(1, "Wrong byte 1");
                    2: if (stream_data !== 8'h33) $fatal(1, "Wrong byte 2");
                    default: $fatal(1, "Too many bytes");
                endcase
                sent = sent + 1;
                gaps = 0;
            end else if (stream_en && sent == 0) begin
                lead = lead + 1;
            end else if (stream_en && sent < 3) begin
                gaps = gaps + 1;
            end else if (stream_en && sent == 3) begin
                tail = tail + 1;
            end
            if (stream_done && (sent != 3 || tail < 8 || stream_en))
                $fatal(1, "Stream completed with bad 8-clock EN tail");
            prev_valid = stream_valid;
            prev_en = stream_en;
        end
    end

    task reset_all;
        begin
            @(negedge clk); rst = 1;
            request = 0; monitor = 0;
            repeat (3) @(negedge clk);
            rst = 0;
            repeat (2) @(negedge clk);
        end
    endtask

    task start;
        begin
            @(negedge clk); request = 1;
            @(negedge clk); request = 0;
        end
    endtask

    initial begin
        reset_all();
        // A DFU request cannot enter the byte streamer.
        normal_mode = 0; spi_released = 1;
        start();
        repeat (3) @(negedge clk);
        if (!stream_blocked || stream_en || stream_done)
            $fatal(1, "DFU selection failed to block stream");

        reset_all();
        // Active flash drivers cannot coexist with the config streamer.
        normal_mode = 1; spi_released = 0;
        start();
        repeat (3) @(negedge clk);
        if (!stream_blocked || stream_en || stream_done)
            $fatal(1, "SPI not released but stream active");

        reset_all();
        normal_mode = 1; spi_released = 1;
        lead = 0; gaps = 0; tail = 0; sent = 0;
        monitor = 1;
        start();
        repeat (24) @(negedge clk);
        if (!stream_done || stream_blocked || sent != 3 || tail < 8)
            $fatal(1, "Synthetic 3-byte stream failed");
        if (!disabled_blocked || disabled_en)
            $fatal(1, "Default disabled image did not fail closed");

        reset_all();
        normal_mode = 1; spi_released = 1;
        start();
        repeat (4) @(negedge clk);
        spi_released = 0;
        repeat (3) @(negedge clk);
        if (!stream_blocked || stream_done || stream_en)
            $fatal(1, "SPI release withdrawal did not abort");

        $display("[PASS] v63b synthetic CC_CFG_CTRL timing, 4 scenarios; NO VENDOR COMMAND");
        $finish;
    end
endmodule
`default_nettype wire
