`timescale 1ns / 1ps

module fifo_sv (
    input  logic       clk,
    input  logic       rst,
    input  logic       push,
    input  logic       pop,
    input  logic [7:0] push_data,
    output logic [7:0] pop_data,
    output logic       full,
    output logic       empty
);

    logic [3:0] wptr, rptr;

    control_unit U_CNT_UNIT (  //instance
        .*,
        .wptr(wptr),
        .rptr(rptr)
    );

    reg_file U_REG_FILE (
        .*,
        .wdata(push_data),
        .waddr(wptr),
        .raddr(rptr),
        .we   (push & (~full)),
        .rdata(pop_data)
    );

endmodule

module control_unit (
    input  logic       clk,
    input  logic       rst,
    input  logic       push,
    input  logic       pop,
    output logic       full,
    output logic       empty,
    output logic [3:0] wptr,
    output logic [3:0] rptr
);
    logic full_reg, full_next;
    logic empty_reg, empty_next;
    logic [3:0] wptr_reg, wptr_next;
    logic [3:0] rptr_reg, rptr_next;

    assign wptr  = wptr_reg;
    assign rptr  = rptr_reg;
    assign full  = full_reg;
    assign empty = empty_reg;

    always_ff @(posedge clk, posedge rst) begin
        if (rst) begin
            full_reg  <= 0;
            empty_reg <= 0;
            wptr_reg  <= 0;
            rptr_reg  <= 0;
        end else begin
            full_reg  <= full_next;
            empty_reg <= empty_next;
            wptr_reg  <= wptr_next;
            rptr_reg  <= rptr_next;
        end
    end

    always_comb begin
        full_next  = full_reg;
        empty_next = empty_reg;
        wptr_next  = wptr_reg;
        rptr_next  = rptr_reg;
        case ({
            push, pop
        })
            2'b10: begin  // push only
                if (!full_reg) begin
                    wptr_next  = wptr_reg;
                    empty_next = 0;
                    if (wptr_next == rptr_reg) full_next = 1;
                end
            end
            2'b01: begin
                if (!empty_reg) begin
                    rptr_next = rptr_reg + 1;
                    full_next = 0;
                    if (rptr_next == wptr_reg) empty_next = 0;
                end
            end
            2'b11: begin
                if (full_reg) begin
                    rptr_next = rptr_reg + 1;
                    full_next = 0;
                end else if (empty_reg) begin
                    wptr_next  = wptr_reg + 1;
                    empty_next = 0;
                end else begin
                    wptr_next = wptr_reg + 1;
                    rptr_next = rptr_reg + 1;
                end
            end
        endcase
    end
    /*        if (push & pop) begin
            if (full) begin  // pop only
                rptr_next = rptr_reg + 1;
                full_next = 0;
            end else if (empty) begin  // push only
                wptr_next  = wptr_reg + 1;
                empty_next = 0;
            end else begin
                rptr_next = rptr_reg + 1;
                wptr_next = wptr_reg + 1;
            end
        end else if (pop) begin
            if (!empty_reg) begin
                rptr_next = rptr_reg + 1;
                if (rptr_next == wptr_reg) begin
                    empty_next = 1;
                end
            end
        end else if (push) begin
            if (!full_reg) begin
                wptr_next = wptr_reg + 1;
                if (wptr_next == rptr_reg) begin
                    full_next = 1;
                end
            end
        end
    end
*/
endmodule

module reg_file (
    input  logic       clk,
    input  logic [7:0] wdata,
    input  logic [3:0] waddr,
    input  logic [3:0] raddr,
    input  logic       we,
    output logic [7:0] rdata
);

    logic [7:0] reg_file[0:15];  //4bit

    always_ff @(posedge clk) begin
        if (we) begin
            reg_file[waddr] <= wdata;
        end
    end

    assign rdata = reg_file[raddr]; // pop은 we의 조건x, pop신호가 아니라 raddr가 바뀌면 rdata 변하게끔.

endmodule
