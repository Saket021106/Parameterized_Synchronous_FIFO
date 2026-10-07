module sync_fifo #(
    parameter DATA_WIDTH = 8,
    parameter REGS = 8
)(
    input logic clk,
    input logic rst,

    input logic [DATA_WIDTH - 1:0] data_in,

    input logic wr_en,
    input logic rd_en,

    output logic [DATA_WIDTH - 1:0] data_out,

    output logic full,
    output logic empty
);

    logic [DATA_WIDTH - 1:0] data [0:REGS - 1];

    logic [$clog2(REGS) - 1:0] write_ptr;
    logic [$clog2(REGS) - 1:0] read_ptr;

    logic [$clog2(REGS):0] count;

    assign full = (count == REGS);
    assign empty = (count == '0);

    always_ff @(posedge clk) begin : fifo

        if (rst) begin
            write_ptr <= '0;
            read_ptr <= '0;
            count <= '0;
            data_out <= '0;
        end

        else begin

            if (wr_en && !full) begin

                data[write_ptr] <= data_in;

                if (write_ptr == REGS - 1)
                    write_ptr <= '0;
                else
                    write_ptr <= write_ptr + 1'b1;

            end

            if (rd_en && !empty) begin

                data_out <= data[read_ptr];

                if (read_ptr == REGS - 1)
                    read_ptr <= '0;
                else
                    read_ptr <= read_ptr + 1'b1;

            end

            if ((wr_en && !full) && (!rd_en || empty))
                count <= count + 1'b1;

            else if ((rd_en && !empty) && (!wr_en || full))
                count <= count - 1'b1;

        end

    end

endmodule
