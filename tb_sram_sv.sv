`timescale 1ns / 1ps

interface ram_interface;
    logic       clk;
    logic [7:0] addr;
    logic [7:0] wdata;
    logic       we;
    logic [7:0] rdata;
endinterface

class transaction;
    rand bit [7:0] addr;
    rand bit [7:0] wdata;
    rand bit       we;
    bit      [7:0] rdata;

    constraint addr_range {addr < 10;}

    function debug_print(string name);
        $display("%t : [%s] addr = %d, wdata = %d, we = %d, rdata = %d", $time,
                 name, addr, wdata, we, rdata);
    endfunction
endclass

class generator;
    transaction tr;
    mailbox #(transaction) gen2drv_mbox;
    event event_gen_next;
    function new(mailbox#(transaction) gen2drv_mbox, event event_gen_next);
        this.gen2drv_mbox   = gen2drv_mbox;
        this.event_gen_next = event_gen_next;
    endfunction
    task run(int count);
        repeat (count) begin  // for fork join_any
            tr = new;

            // assertion
            assert (tr.randomize())  // 발생하지 않으면
            else $error("[GEN] tr.randomize() error!");

            gen2drv_mbox.put(tr);
            tr.debug_print("GEN");
            @(event_gen_next);
        end
    endtask
endclass

class driver;
    transaction tr;
    mailbox #(transaction) gen2drv_mbox;
    virtual ram_interface ram_vif;
    function new(mailbox#(transaction) gen2drv_mbox,
                 virtual ram_interface ram_vif);
        this.gen2drv_mbox = gen2drv_mbox;
        this.ram_vif      = ram_vif;
    endfunction

    task preset();
        ram_vif.addr  = 0;
        ram_vif.wdata = 0;
        ram_vif.we    = 0;
        @(posedge ram_vif.clk);
    endtask

    task run();
        forever begin
            gen2drv_mbox.get(tr);
            tr.debug_print("DRV");
            @(posedge ram_vif.clk);
            #1;
            ram_vif.addr  = tr.addr;
            ram_vif.wdata = tr.wdata;
            ram_vif.we    = tr.we;
        end
    endtask
endclass

class monitor;
    transaction tr;
    mailbox #(transaction) mon2scb_mbox;
    virtual ram_interface ram_vif;
    function new(mailbox#(transaction) mon2scb_mbox,
                 virtual ram_interface ram_vif);
        this.mon2scb_mbox = mon2scb_mbox;
        this.ram_vif = ram_vif;
    endfunction
    task run();
        forever begin
            @(posedge ram_vif.clk);
            //#1;  // 시뮬레이터 상에서 값이 반영되도록 wait. 시뮬레이터는 상승엣지 이후에 반영.
            tr       = new;
            tr.addr  = ram_vif.addr;
            tr.wdata = ram_vif.wdata;
            tr.we    = ram_vif.we;
            tr.rdata = ram_vif.rdata;
            mon2scb_mbox.put(tr);
            tr.debug_print("MON");
        end
    endtask
endclass

class scoreboard;
    transaction tr;
    mailbox #(transaction) mon2scb_mbox;
    event event_gen_next;
    int total_cnt = 0, pass_cnt = 0, fail_cnt = 0;

    byte mem[256];  //byte니까 2상태

    function new(mailbox#(transaction) mon2scb_mbox, event event_gen_next);
        this.mon2scb_mbox   = mon2scb_mbox;
        this.event_gen_next = event_gen_next;
    endfunction
    task run();
        forever begin
            mon2scb_mbox.get(tr);
            tr.debug_print("SCB");
            total_cnt++;
            //pass fail
            if (tr.we) begin  // write senario
                mem[tr.addr] = tr.wdata;
            end else begin  // read senario
                if (tr.rdata == mem[tr.addr]) begin
                    pass_cnt++;
                    $display("%t : PASS", $time);
                end else begin
                    fail_cnt++;
                    $display(
                        "%t : FAIL addr = %d, rdata = %d, compare data = %d",
                        $time, tr.addr, tr.rdata, mem[tr.addr]);
                end
            end
            ->event_gen_next;
        end
    endtask
endclass

class environment;
    generator gen;
    driver drv;
    monitor mon;
    scoreboard scb;
    mailbox #(transaction) gen2drv_mbox;
    mailbox #(transaction) mon2scb_mbox;
    virtual ram_interface ram_vif;
    event event_gen_next;
    function new(virtual ram_interface ram_vif);
        gen2drv_mbox = new;
        mon2scb_mbox = new;
        gen = new(gen2drv_mbox, event_gen_next);
        drv = new(gen2drv_mbox, ram_vif);
        mon = new(mon2scb_mbox, ram_vif);
        scb = new(mon2scb_mbox, event_gen_next);
    endfunction
    task run();
        //ram interface initial
        drv.preset();
        fork
            gen.run(20);
            drv.run();
            mon.run();
            scb.run();
        join_any
        #10;
        $display("env run task end");
        $display("__________________________");
        $display("** SRAM IP Verification **");
        $display("**** TOTAL test num = %2d **", scb.total_cnt);
        $display("**** PASS test num = %2d **", scb.pass_cnt);
        $display("**** FAIL test num = %2d **", scb.fail_cnt);
        $display("__________________________");
        $stop;
    endtask
endclass


module tb_sram_sv ();
    ram_interface ram_if ();
    environment env;
    sram dut (
        .clk  (ram_if.clk),
        .addr (ram_if.addr),
        .wdata(ram_if.wdata),
        .we   (ram_if.we),
        .rdata(ram_if.rdata)
    );

    always #5 ram_if.clk = ~ram_if.clk;

    initial begin
        ram_if.clk = 0;
        env = new(ram_if);
        env.run();
    end
endmodule
