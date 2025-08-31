`default_nettype none


module AXI_Lite_Master_tb(); 

  logic clock, reset_n;
  logic rw_transaction, rw_enable;
  logic [31:0] write_data, read_data;
  logic [4:0] address;
  logic [4:0] araddr;
  logic [3:0] arcache;
  logic [2:0] arprot;
  logic arvalid;
  logic arready;   
  logic [31:0] rdata;
  logic [1:0] rresp; 
  logic rready;      
  logic rvalid;
  logic [4:0] awaddr;
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

  logic [31:0] register_file [31:0];

  AXI_Lite_Master DUT( 
    .aclk (clock),
    .aresetn (reset_n), 
    .*
  );

  class write_pkt;
    rand logic [31:0] w_data;
    rand logic [31:0] w_reg; 
  endclass 

  write_pkt pkt = new;

  task initialize_register_file();
    for (int i = 0; i < 32; i++) begin
      register_file[i] = 32'd0;
    end
  endtask

  task automatic delay(int n, string signal_delay); 
    $display("Delaying signal %s for %d cycles", signal_delay, n); 
    for(int i = 0; i < n; i++) begin
      @(posedge clock);
    end
  endtask

  task cleanup();
    rw_enable = 1'b0;
    rw_transaction = 1'b0;
    arready = 1'b0;
    awready = 1'b0;
    wready = 1'b0;
    bvalid = 1'b0;
  endtask;

  task initiate_read_transaction();
    address = $random();
    $display("Reading from address %h.", address);
    rw_enable = 1'b1;
    rw_transaction = 1'b1;
    @(posedge clock);
    rw_enable = 1'b0;
    rw_transaction = 1'b0;
  endtask

  task initiate_write_transaction();
    write_data = $random();
    address = $random();
    $display("Writing data %h to address %h.", write_data, address);
    register_file[address] = wdata;
    rw_enable = 1'b1;
    rw_transaction = 1'b0;
    @(posedge clock);
    rw_enable = 1'b0;
    rw_transaction = 1'b0;
  endtask

  task read_transaction();
    string arready_str = "ARREADY";
    int arready_delay = $urandom_range(1, 25);
    initiate_read_transaction();
    #1; // Scheduling race in NBA update of state and active region assertion checking, so require an extra timestep.
    assert(arvalid);
    assert(rready);
    delay(arready_delay, arready_str);
    arready = 1'b1;
    @(posedge clock);
    arready = 1'b0;
    assert(rready); 
    rdata = register_file[address];
    rvalid = 1'b1;
    @(posedge clock);
    #1;
    assert(read_data == register_file[address]) else $display("Expected data was: %h, Actual Data Was: %h", register_file[address], read_data);
  endtask

  task write_transaction();
    string awready_str = "AWREADY";
    string wready_str = "WREADY";
    int awready_delay = $urandom_range(1, 25); 
    int wready_delay  = $urandom_range(1, 25);
    awready = 1'b0;
    wready = 1'b0;
    bvalid = 1'b0; 
    initiate_write_transaction();
    fork 
      begin
        delay(awready_delay, awready_str);
        awready = 1'b1;
      end
      begin
        delay(wready_delay, wready_str); 
        wready = 1'b1;
      end
    join
    @(posedge clock);
    bvalid = 1'b1;
    @(posedge clock);
  endtask

  initial begin
    clock = 0;
    forever #5 clock = ~clock;
  end

  initial begin
    reset_n = 1'b1;
    #1 reset_n = 1'b0;
    #1 reset_n = 1'b1;
    initialize_register_file();
    @(posedge clock);
    cleanup();
    @(posedge clock);
    for (int i = 0; i < 100; i++) begin
      write_transaction(); 
    end
    @(posedge clock);
    cleanup();
    @(posedge clock);
    for (int i = 0; i < 100; i++) begin
      read_transaction();
    end
    @(posedge clock);
    $finish;
  end


endmodule : AXI_Lite_Master_tb 
