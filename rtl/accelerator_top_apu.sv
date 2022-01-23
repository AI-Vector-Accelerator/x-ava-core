//Top file for ava adaptor for X-IF interface
import accelerator_pkg::*;


module xava(
    input logic              clk_i,
    input logic              rst_ni,
    if_xif.coproc_compressed xif_compressed, //unused
    if_xif.coproc_issue      xif_issue, //issue_valid, issue_ready, req and resp pkt
    if_xif.coproc_commit     xif_commit, //commit_valid, commit pkt
    if_xif.coproc_mem        xif_mem, //mem_valid, mem_ready, req and resp pkt
    if_xif.coproc_mem_result xif_mem_result, //output mem_result_valid, output mem_result, mem result sent to
    if_xif.coproc_result     xif_result, //result_valid, result_ready, result pkt

    // vector memory interface
    output logic                  data_req_o,
    input  logic                  data_gnt_i,
    input  logic                  data_rvalid_i,
    //input  logic                  data_err_i,
    input  logic [31:0]           data_rdata_i,
    output logic [31:0]           data_addr_o,
    output logic                  data_we_o,
    output logic [3:0]            data_be_o,
    output logic [31:0]           data_wdata_o,

    output logic core_halt_o

    );

    //Instantiate accelerator top and adaptor
    wire  [31:0] apu_result;
    wire  [4:0]  apu_flags_o;
    wire          apu_gnt;
    wire         apu_rvalid;

    wire         apu_req;
    wire  [2:0][31:0] apu_operands_i;
    wire  [5:0]  apu_op;
    wire  [14:0] apu_flags_i;

    //Commented as signals are directly exposed to top 
    //wire         data_req_o;
    //wire         data_gnt_i;
    //wire         data_rvalid_i;
    //wire         data_we_o;
    //wire  [3:0]  data_be_o;
    //wire  [31:0] data_addr_o;
    //wire  [31:0] data_wdata_o;
    //wire  [31:0] data_rdata_i;
    //wire         core_halt_o;


    accelerator_top acctop0(
            .apu_result         (apu_result),
            .apu_flags_o        (apu_flag_o), //nothing returned to interface/cpu, maybe use for something else?
            .apu_gnt            (apu_gnt), //WAIT state in decoder, when gnt = 1 apu_operands_o, apu_op_o, apu_flags_o may change next cycle
            .apu_rvalid         (apu_rvalid),
            .clk                (clk_i),
            .n_reset            (rst_ni),
            .apu_req            (apu_req), // && xif_issue.issue_ready), //ready for new instructions (revisit)
            .apu_operands_i     (apu_operands_i), //this contains the funct3, major_opcode, funct6, source1, source2, destination fields
            //...of type wire [2:0][31:0];
            .apu_op             (apu_op), //this tells the core what apu op is required but not used within ava...
            .apu_flags_i        (apu_flags_i), //again this is meant to pass in flags, just stored and not used

            //VLSU signals
            .data_req_o         (data_req_o), //vlsu signal for in LOAD_CYCLE and STORE_CYCLE in vlsu (request)
            .data_gnt_i         (data_gnt_i), //vlsu signal, not used anywhere... (generate)
            .data_rvalid_i      (data_rvalid_i), //vlsu signal for in LOAD_WAIT and STORE_WAIT (result valid)
            .data_we_o          (data_we_o), //vlsu signal for in STORE_CYCLE (write enable?)
            .data_be_o          (data_be_o), //vlsu signal, (byte enable?)
            //= vlsu_store_i ? store_cycle_be : 4'b1111; in vlsu
            .data_addr_o        (data_addr_o), //vlsu signal, data address output
            //= vlsu_store_i ? ({cycle_addr[31:2], 2'd0} + (store_cycles_cnt << 2)) : {cycle_addr[31:2], 2'd0};
            .data_wdata_o       (data_wdata_o), //vlsu signal, (write data out), set to 0...
            .data_rdata_i       (data_rdata_i), //vlsu signal, (read data in), written to temporary reg and split into words 32bits -> 4x8bits

            //Core halt signal
            .core_halt_o        (core_halt_o)  //core halt to stop main core?
        );

    //Pack the x interface
    //assign input output

    //COMPRESSED INTERFACE - NOT USED
    assign xif_compressed.compressed_ready = '0;
    assign xif_compressed.compressed_resp  = '0;

    //ISSUE INTERFACE
    assign apu_req = xif_issue.issue_valid;
    assign apu_operands_i [0] = xif_issue.issue_req.instr; //Contains instr
    assign apu_operands_i [1] = xif_issue.issue_req.rs[0]; //register operand 1
    assign apu_operands_i [2] = xif_issue.issue_req.rs[1]; //register operand 2
    assign xif_issue.issue_ready = apu_gnt;
    assign xif_issue.issue_resp.accept = '1; //Is copro accepted by processor?
    //assign xif_issue.issue_resp.writeback = apu_rvalid; //Will copro writeback?
    //assign xif_issue.issue_resp.writeback = (!acctop0.vec_reg_write && (acctop0.vdec0.state == 0));

    assign xif_issue.issue_resp.writeback = (xif_issue.issue_req.instr[31:26] == 6'b010000); 
    //(!acctop0.vec_reg_write && (acctop0.vdec0.state == 0));


    //COMMIT INTERFACE
    //assign ?? = xif_commit.commit_valid & ~xif_commit.commit_kill;
    //assign ?? = xif_commit.commit_valid & xif_commit.commit_kill;


    logic [31:0] temp_apu_result;
    logic temp_apu_rvalid;
    logic [31:0] temp_apu_result2;
    logic temp_apu_rvalid2;
    logic [1:0] stall;
    always_ff @(posedge clk_i, negedge rst_ni) //stall ava output for result to be written back
    if(~rst_ni)
    begin
	stall <= 0;
        temp_apu_result <= '0;
	temp_apu_rvalid <= '0;
    end
    else begin
            temp_apu_result <= apu_result;
            temp_apu_rvalid <= apu_rvalid;

            //temp_apu_result <= temp_apu_result2;
            //temp_apu_rvalid <= temp_apu_rvalid2;
    end
    //else if (temp_apu_rvalid2 == 1)
	 //   stall <= 1;
    //else begin
//	    temp_apu_result2 = apu_result;
//          temp_apu_rvalid2 = apu_rvalid;
//    end
    
    

    //RESULT INTERFACE
    assign xif_result.result_valid = (temp_apu_rvalid);
    //assign xif_result.result_valid = (apu_rvalid || !result_ready);

    assign xif_result.result.id = '0;
    //assign xif_result.result.data = apu_result;
    assign xif_result.result.data = temp_apu_result;
    assign xif_result.result.rd = xif_issue.issue_req.instr[11:7]; //unimplemented as of 22/01/22
    //assign xif_result.result.rd = '0;
    assign xif_result.result.we = temp_apu_rvalid; //unimplemented as of 22/01/22
    assign xif_result.result.float = '0;
    assign xif_result.result.exc = '0;
    assign xif_result.result.exccode = '0;

endmodule
