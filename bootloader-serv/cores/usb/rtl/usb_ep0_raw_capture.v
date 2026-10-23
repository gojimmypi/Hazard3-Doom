/* ULX5M SERV diagnostic: freeze the first unacknowledged EP0 DATA response.
 * Captures 48 MHz GateMate IDDR pairs, not analog pad voltages. Read-only
 * memory from the CPU; arming is explicit through a separate CSR write.
 */
`default_nettype none
module usb_ep0_raw_capture #(
    parameter integer FREE_RUNNING_READ = 0
)(
    input wire clk,
    input wire rst,
    input wire arm,
    input wire tx_data_pending,
    input wire tx_en,
    input wire tx_en_pad_d,
    input wire rx_hold,
    input wire [1:0] raw_dp,
    input wire [1:0] raw_dn,
    input wire rx_change,
    input wire rx_sync,
    input wire ack_valid,
    input wire ack_timeout,
    input wire rd_en,
    input wire [6:0] rd_addr,
    output reg [15:0] rd_data,
    output wire [15:0] status,
    output wire [15:0] sample_count
);
    // Each 16-bit RAM word stores two consecutive 48 MHz samples.
    // Byte bits: [7:6]=D+ IDDR Q1:Q0, [5:4]=D- IDDR Q1:Q0,
    // [3]=filtered change, [2]=RX SYNC, [1]=registered TX OE,
    // [0]=RX hold. Low byte is the earlier cycle.
    reg [15:0] ram [0:127];
    reg tx_en_prev;
    reg watching;
    reg recording;
    reg frozen;
    reg [8:0] count;
    reg [7:0] first_sample;
    wire [7:0] sample = {raw_dp, raw_dn, rx_change,
                         rx_sync, tx_en_pad_d, rx_hold};
    wire start = tx_en_prev && !tx_en && tx_data_pending &&
                 !watching && !frozen;

    assign status = {12'b0, frozen, recording, watching, !frozen};
    assign sample_count = {7'b0, count};

    // Optional always-clocked RAM read eliminates the bus-derived read
    // enable from the critical path. Only the BTN2 build opts into this;
    // CSR read latency and the capture write path are unchanged.
    generate if (FREE_RUNNING_READ) begin : g_free_read
        always @(posedge clk)
            rd_data <= ram[rd_addr];
    end else begin : g_gated_read
        always @(posedge clk)
            if (rd_en)
                rd_data <= ram[rd_addr];
    end endgenerate

    always @(posedge clk) begin
        if (rst) begin
            tx_en_prev <= 1'b0;
            watching <= 1'b0;
            recording <= 1'b0;
            frozen <= 1'b0;
            count <= 0;
            first_sample <= 0;
        end else begin
            tx_en_prev <= tx_en;
            if (arm) begin
                watching <= 1'b0;
                recording <= 1'b0;
                frozen <= 1'b0;
                count <= 0;
            end else if (start) begin
                watching <= 1'b1;
                recording <= 1'b1;
                count <= 0;
            end else if (watching) begin
                if (recording) begin
                    if (!count[0])
                        first_sample <= sample;
                    else
                        ram[count[7:1]] <= {sample, first_sample};
                    count <= count + 1'b1;
                    if (count == 9'd255)
                        recording <= 1'b0;
                end
                if (ack_timeout) begin
                    // Preserve a final odd sample; count indicates validity.
                    if (recording && count[0])
                        ram[count[7:1]] <= {8'h00, first_sample};
                    watching <= 1'b0;
                    recording <= 1'b0;
                    frozen <= 1'b1;
                end else if (ack_valid) begin
                    // Discard an acknowledged packet, retry on next DATA.
                    watching <= 1'b0;
                    recording <= 1'b0;
                    count <= 0;
                end
            end
        end
    end
endmodule
`default_nettype wire
