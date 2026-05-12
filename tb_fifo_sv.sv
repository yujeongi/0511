`timescale 1ns / 1ps

module tb_fifo_sv ();

    parameter DEPTH = 16;

    reg        clk;
    reg        rst;
    reg  [7:0] push_data;
    reg        push;
    reg        pop;
    wire [7:0] pop_data;
    wire       full;
    wire       empty;

    //random verification
    reg  [7:0] compare_data[0:(DEPTH-1)];  //expected data
    reg [$clog2(DEPTH)-1:0] push_cnt, pop_cnt; //integer면 pop_cnt가 계속 변하는데 이러면 x

    fifo_sv dut (
    .clk(clk),
    .rst(rst),
    .push(push),
    .pop(pop),
    .push_data(push_data),
    .pop_data(pop_data),
    .full(full),
    .empty(empty)
);

    always #5 clk = ~clk;

    integer i;

    initial begin
        clk = 0;
        rst = 1;
        push_data = 0;
        push = 0;
        pop = 0;
        //reset
        #10;
        rst = 0;

        @(posedge clk);
        #1;

        //push only
        for (i = 0; i < DEPTH + 1; i = i + 1) begin
            push = 1;
            push_data = i;
            #10;
        end

        //pop only
        push=0; //이게 빠졌잖아!!!!
        for (i = 0; i < DEPTH + 1; i = i + 1) begin
            pop = 1;
            #10;
        end

        //push pop
        push = 1;
        pop = 0;
        push_data = 8'h30;
        #10;
        for (i = 0; i < DEPTH + 1; i = i + 1) begin
            pop = 1;
            push_data = i + 8'h30;
            //push_data = i;
            #10;
        end

        //empty fifo for random test
        pop  = 1;
        push = 0;
        #20;
        pop  = 0;
        push = 0;

        #20;

        //random test
        push_cnt = 0;
        pop_cnt  = 0;


        // syncronize for drive signal
        @(posedge clk); // first vector = stimulus drive 동기

        for (i = 0; i < 256; i = i + 1) begin
            #1; // for drive time
            
            //randomize
            push = $random % 2;
            pop = $random % 2;
            push_data = $random % 256;  //8bit
            //compare data saving
            if (!full && push) begin
                compare_data[push_cnt] = push_data;
                push_cnt = push_cnt + 1;
            end

            @(negedge clk);//
           // #6; //drive하는 시점을 맞춰야함.
            

            if (!empty && pop) begin
                // compare
                if (pop_data == compare_data[pop_cnt]) begin
                    $display("%t: pass: pop_data = %h, compare data = %h", $time, pop_data, compare_data[pop_cnt]);
                end
                else begin
                    $display("%t: fail: pop_data = %h, compare data = %h", $time, pop_data, compare_data[pop_cnt]);
                end
                pop_cnt = pop_cnt + 1;
            end
            //#10;  //drive time
            @(posedge clk); // for drive time
        end


        #100;
        $stop;
    end

endmodule
