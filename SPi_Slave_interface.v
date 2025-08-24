module SPI_Slave(
    input MOSI,
    input SS_n,
    input clk,
    input rst_n,
    input tx_valid,
    input [7:0] tx_data,
    output reg MISO,
    output reg rx_valid,
    output reg [9:0] rx_data
);

    // FSM States
    parameter IDLE      = 3'b000;
    parameter CHK_CMD   = 3'b001;
    parameter WRITE     = 3'b010;
    parameter READ_ADD  = 3'b011;
    parameter READ_DATA = 3'b100;

    reg [2:0] cs, ns;
    reg ADDRESS_read;
    reg [3:0] counter_up;
    reg [3:0] counter_down;
    reg [9:0] shift_reg_parallel;

    // Sequential: State Transition
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n)
            cs <= IDLE;
        else
            cs <= ns;
    end

    // Combinational: Next State Logic
    always @(*) begin
        ns = IDLE;
        case (cs)
            IDLE: begin
                if (SS_n)
                    ns = IDLE;
                else
                    ns = CHK_CMD;
            end

            CHK_CMD: begin
                if (!SS_n && !MOSI)
                    ns = WRITE;
                else if (!SS_n && MOSI) begin
                    case (ADDRESS_read)
                        1'b0, 1'bx: ns = READ_ADD;
                        1'b1:       ns = READ_DATA;
                    endcase
                end
            end

            WRITE: begin
                ns = (SS_n == 0) ? WRITE : IDLE;
            end

            READ_ADD: begin
                ns = (SS_n == 0) ? READ_ADD : IDLE;
            end

            READ_DATA: begin
                ns = (SS_n == 0) ? READ_DATA : IDLE;
            end

            default: ns = IDLE;
        endcase
    end

    // Sequential: Register and Output Logic
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            rx_valid <= 0;
            counter_up <= 0;
            counter_down <= 0;
            shift_reg_parallel <= 0;
            rx_data <= 0;
            ADDRESS_read <= 0;
            MISO <= 0;
        end else begin
            case (cs)
                IDLE: begin
                    rx_valid <= 0;
                end

                CHK_CMD: begin
                    counter_up <= 0;
                    counter_down <= 0;
                    shift_reg_parallel <= 0;
                    rx_valid <= 0;
                end

                WRITE: begin
                    shift_reg_parallel[9 - counter_up] <= MOSI;
                    counter_up <= counter_up + 1;
                    if (counter_up == 4'd9) begin
                        rx_data <= shift_reg_parallel;
                        rx_valid <= 1;
                        counter_up <= 0;
                    end
                end

                READ_ADD: begin
                    shift_reg_parallel[9 - counter_up] <= MOSI;
                    counter_up <= counter_up + 1;
                    if (counter_up == 4'd9) begin
                        rx_data <= shift_reg_parallel;
                        rx_valid <= 1;
                        counter_up <= 0;
                        ADDRESS_read <= 1;
                    end
                end

                READ_DATA: begin
                    MISO <= tx_data[7 - counter_down];
                    counter_down <= counter_down + 1;
                    if (counter_down == 4'd7) begin
                        counter_down <= 0;
                        ADDRESS_read <= 0;
                    end
                end
            endcase
        end
    end

endmodule
