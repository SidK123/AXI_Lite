module AXI_Integration_tb ();

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

  AXI_Lite_Slave SLAVE( 
    .aclk (clock),
    .aresetn (reset_n), 
    .*
  );

  AXI_Lite_Master MASTER( 
    .aclk (clock),
    .aresetn (reset_n), 
    .*
  );

  task initialize_register_file();
    for (int i = 0; i < 32; i++) begin
      register_file[i] = 32'd0;
    end
  endtask

  task automatic delay(int n, string signal_delay = "GENERIC_DELAY"); 
    $display("Delaying signal %s for %d cycles", signal_delay, n); 
    for(int i = 0; i < n; i++) begin
      @(posedge clock);
    end
  endtask

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
    register_file[address] = write_data;
    rw_enable = 1'b1;
    rw_transaction = 1'b0;
    @(posedge clock);
    rw_enable = 1'b0;
    rw_transaction = 1'b0;
  endtask

  property read_data_check();
    @(posedge clock) (rvalid |-> (rdata == register_file[address]));
  endproperty

  checking_read_data: assert property(read_data_check()) else $display("Expected data was %h, actual data was %h.", register_file[address], rdata);

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
    for (int i = 0; i < 10; i++) begin
      initiate_write_transaction();
      delay(20);
      initiate_read_transaction();
      delay(20);
    end
    $finish;
  end

endmodule : AXI_Integration_tb