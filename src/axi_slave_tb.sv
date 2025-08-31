`default_nettype none


module AXI_Lite_Slave_tb (); 

  logic clock, reset_n;
  logic [31:0] araddr;
  logic [3:0] arcache;
  logic [2:0] arprot;
  logic arvalid;
  logic arready;   
  logic [31:0] rdata;
  logic [1:0] rresp; 
  logic rready;      
  logic rvalid;
  logic [31:0] awaddr;
  logic [3:0] awcache;
  logic [2:0] awprot; 
  logic awvalid;     
  logic awready;     
  logic wvalid;
  logic [31:0] wdata; 
  logic [3:0] wstrb;  
  logic wready;      
  logic [1:0] bresp;        
  logic bvalid;       
  logic bready;       

  AXI_Lite_Slave DUT( 
    .aclk (clock),
    .aresetn (reset_n), 
    .*
  );

  class write_pkt;
    rand logic [31:0] w_data;
    rand logic [31:0] w_reg; 
  endclass 

  write_pkt pkt = new;

  task read_register_file();
    araddr  = pkt.w_reg;
    arvalid = 1'b1;
    rready  = 1'b1;
    @(posedge clock);
    #1 arvalid = 1'b0;
    assert(rdata == pkt.w_data);
    assert(rvalid);
    @(posedge clock);
    #1 rready = 1'b0;
    assert(rvalid == 1'b0);
  endtask

  property arready_high_check();
    @(posedge clock) (arvalid & rready) |-> arready;
  endproperty

  property rd_deassert_check();
    @(posedge clock) (arready & arvalid) |=> (~arready & ~arvalid);
  endproperty

  task write_register_file_addr_data_simul();
    @(posedge clock);
    #1;
    pkt.randomize();
    awaddr  = pkt.w_reg;
    wdata   = pkt.w_data;
    awvalid = 1'b1;
    wvalid  = 1'b1;
    bready  = 1'b1;
    @(posedge clock);
    #1 awvalid = 1'b0;
    wvalid  = 1'b0;
    @(posedge clock);
    #1 bready  = 1'b0;
  endtask

  property aw_valid_check();
    @(posedge clock) (awvalid & bready) |-> awready;
  endproperty

  property w_valid_check();
    @(posedge clock)(wvalid & bready) |-> wready;
  endproperty

  property ready_deassert();
    @(posedge clock) (awready && wready && wvalid && awvalid) |=> (~awready & ~wready);
  endproperty

  checking_aw_valid: assert property(aw_valid_check());
  checking_w_valid: assert property(w_valid_check());
  checking_ready_deass: assert property(ready_deassert());

  initial begin
    clock = 0;
    forever #5 clock = ~clock;
  end

  initial begin
    reset_n = 1'b1;
    #1 reset_n = 1'b0;
    #1 reset_n = 1'b1;
    @(posedge clock);
    write_register_file_addr_data_simul();
    @(posedge clock);
    @(posedge clock);
    @(posedge clock);
    read_register_file(); 
    $finish;
  end


endmodule : AXI_Lite_Slave_tb 
