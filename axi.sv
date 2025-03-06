// `default_nettype none

module Register_File ( 
  input  logic clk, reset_n,
  input  logic we, re,
  input  logic [3:0] addr,
  input  logic [31:0] write_data, 
  output logic [31:0] read_data
); 

  logic [31:0] rf [15:0];

  assign read_data = re ? rf[addr] : 32'd0;

  always_ff @(posedge clk, negedge reset_n) begin
    if (~reset_n) begin
      for (int i = 0; i < 16; i++) begin
        rf[i] <= 32'd0; 
      end
    end else if (we) begin
	rf[addr] <= write_data;
    end
  end

endmodule : Register_File

module AXI_Lite_Interface ( 
  input  logic aclk, aresetn,
  //Read address channel signals
  input  logic [31:0] araddr, // Read address.
  // input  logic [3:0] arcache, // Memory type for data.
  input  logic [2:0] arprot,  // Protection type for data.
  input  logic arvalid,       // Read address valid. Master asserts this signal when the read address and control signals are valid.
  output logic arready,       // Read address ready, and slave asserts this signal when it can accept the read address and control signals.
  //Read data channel signals
  output logic [31:0] rdata,  // Read data.
  output logic [1:0] rresp, // rresp is the read response, indicates the status of the transfer. 
  output logic rvalid, // Slave asserts rvalid when the read data is ready
  input  logic rready,        // Master asserts this signal when it can accept the read data and response.
  //Write address channel signals
  input  logic [31:0] awaddr, // Write address.
  // input  logic [3:0] awcache, // Memory type for data.
  input  logic [2:0] awprot,  // Protection type for data.
  input  logic  awvalid,      // Master asserts this signal when write address and other control signals are ready.
  output logic  awready,      // Asserted when slave is ready to accept write address and other control signals.
  //Write data channel signals
  input  logic wvalid,
  input  logic [31:0] wdata, // Write data.
  input  logic [3:0] wstrb,  // Write strobes, indicates which bytes of the write data are valid.
  output logic  wready,      // Asserted when slave is ready to accept write data and other control signals.
  //Write response channel
  output logic [1:0] bresp,        // Status of the write transaction.
  output logic bvalid, 	     // Write response from slave is valid.
  input  logic bready        // Response is ready, asserted whenever master is ready to accept a write response.
);

  logic rf_we;
  logic rf_re;

  logic r_addr_register_en;
  logic w_addr_register_en;
  logic [31:0] addr_register;

  logic w_data_register_en;
  logic [31:0] w_data_register;
  
  always_ff @(posedge aclk, negedge aresetn) begin
    if (~aresetn) begin 
      addr_register <= 32'd0;
    end else if (r_addr_register_en) begin
      addr_register <= araddr;
    end else if (w_addr_register_en) begin
      addr_register <= awaddr;
    end
  end

  always_ff @(posedge aclk, negedge aresetn) begin
    if (~aresetn) begin 
      w_data_register <= 32'd0;
    end else if (w_data_register_en) begin
      w_data_register <= wdata;
    end
  end

  Register_File rf (.clk(aclk), 
	            .reset_n(aresetn), 
		    .we(rf_we),
		    .re(rf_re),
		    .addr(addr_register[3:0]),
		    .write_data(w_data_register),
		    .read_data(rdata)
		    );
  
  enum logic [3:0] { IDLE, READ_ADDR_READY, WRITE_ADDR_READY_1, WRITE_DATA_READY_1, WRITE_READY_1, WRITE_READY_2 } currState, nextState;

  always_ff @(posedge aclk, negedge aresetn) begin 
    if (~aresetn) begin
      currState <= IDLE;
    end else begin
      currState <= nextState;
    end 
  end 

  always_comb begin
    rf_we = 1'b0;
    rf_re = 1'b0;
    nextState = IDLE;
    w_addr_register_en = 1'b0;
    r_addr_register_en = 1'b0;
    rvalid  = 1'b0;
    awready = 1'b0;
    wready  = 1'b0;
    w_data_register_en = 1'b0;
    bvalid = 1'b0;
    arready = 1'b0;
    case (currState) 
      IDLE: begin 
        if (arvalid && rready) begin 
          nextState = READ_ADDR_READY; 
          r_addr_register_en = 1'b1;
          arready = 1'b0;
        end else if (awvalid && ~wvalid && bready) begin
          nextState = WRITE_ADDR_READY_1;
          w_addr_register_en = 1'b1;
          w_data_register_en = 1'b0;
          awready = 1'b1;
          bvalid  = 1'b0;
        end else if (wvalid && ~awvalid && bready) begin
          nextState = WRITE_DATA_READY_1;
          w_data_register_en = 1'b1;
          w_addr_register_en = 1'b0;
          wready = 1'b1;
          bvalid = 1'b0;
        end else if (awvalid && wvalid && bready) begin
          nextState = WRITE_READY_1;
          w_data_register_en = 1'b1;
          w_addr_register_en = 1'b1;
          awready = 1'b1;
          wready  = 1'b1;
          bvalid  = 1'b0;
        end else begin
          nextState = IDLE;
        end
      end 
      READ_ADDR_READY: begin
        nextState = IDLE;
        rf_re = 1'b1;
        r_addr_register_en = 1'b0;
        rvalid = 1'b1;
      end	
      WRITE_ADDR_READY_1: begin
        nextState = wvalid ? WRITE_READY_1 : WRITE_ADDR_READY_1;
        wready = wvalid;
        w_data_register_en = wvalid;
        w_addr_register_en = 1'b0;
        bvalid = 1'b0;
      end
      WRITE_DATA_READY_1: begin
        nextState = awvalid ? WRITE_READY_1 : WRITE_DATA_READY_1;
        awready = awvalid;
        w_data_register_en = 1'b0;
        w_addr_register_en = awvalid;
        bvalid = 1'b0;
      end
      WRITE_READY_1: begin
        nextState = WRITE_READY_2;
        rf_we = 1'b1;
        awready = 1'b0;
        wready = 1'b0;
        w_data_register_en = 1'b0;
        w_addr_register_en = 1'b0;
        bvalid = 1'b0; 
      end
      WRITE_READY_2: begin
        nextState = IDLE;
        rf_we = 1'b0;
        w_data_register_en = 1'b0;
        bvalid = 1'b1; 
      end
      default: begin
        nextState = IDLE;
        rf_we = 1'b0;
        rf_re = 1'b0;
        nextState = IDLE;
        w_addr_register_en = 1'b0;
        r_addr_register_en = 1'b0;
        rvalid  = 1'b0;
        awready = 1'b0;
        wready  = 1'b0;
        w_data_register_en = 1'b0;
        bvalid = 1'b0;
        arready = 1'b0;
      end
    endcase
  end

endmodule : AXI_Lite_Interface
