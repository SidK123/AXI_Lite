module ChipInterface(
    input logic [7:0] SW,
    input logic CLOCK_100,
    output logic [7:0] LD
);

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

  assign rw_transaction = SW[0];
  assign rw_enable      = SW[6];
  assign address = SW[5:1];
  assign write_data = 32'hDEADBEEF;
  assign LD[7:0] = read_data[7:0]; 

  AXI_Lite_Slave SLAVE( 
    .aclk (CLOCK_100),
    .aresetn (~SW[7]), 
    .*
  );

  AXI_Lite_Master MASTER( 
    .aclk (CLOCK_100),
    .aresetn (~SW[7]), 
    .*
  );
endmodule : ChipInterface