// `default_nettype none

module Register_File ( 
  input  logic clk, reset_n,
  input  logic we, re,
  input  logic [4:0] addr,
  input  logic [31:0] write_data, 
  output logic [31:0] read_data
); 

  logic [31:0] rf [31:0];

  assign read_data = re ? rf[addr] : 32'd0;

  always_ff @(posedge clk, negedge reset_n) begin
    if (~reset_n) begin
      for (int i = 0; i < 32; i++) begin
        rf[i] <= 32'd0; 
      end
    end else if (we) begin
	    rf[addr] <= write_data;
    end
  end

endmodule : Register_File

module AXI_Lite_Slave( 
  input  logic aclk, aresetn,
  //Read address channel signals
  input  logic [4:0] araddr, // Read address.
  // input  logic [3:0] arcache, // Memory type for data.
  input  logic [2:0] arprot,  // Protection type for data.
  input  logic arvalid,       // Read address valid. Master asserts this signal when the read address and control signals are valid.
  output logic arready,       // Read address ready, and slave asserts this signal when it can accept the read address and control signals.
  //Read data channel signals
  output logic [31:0] rdata,  // Read data.
  output logic [1:0] rresp,   // rresp is the read response, indicates the status of the transfer. 
  output logic rvalid,        // Slave asserts rvalid when the read data is ready
  input  logic rready,        // Master asserts this signal when it can accept the read data and response.
  //Write address channel signals
  input  logic [4:0] awaddr, // Write address.
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
  output logic [1:0] bresp,  // Status of the write transaction.
  output logic bvalid, 	     // Write response from slave is valid.
  input  logic bready        // Response is ready, asserted whenever master is ready to accept a write response.
);

  logic rf_we;
  logic rf_re;

  logic read_addr_register_en;
  logic write_addr_register_en;
  logic [4:0] addr_register;

  logic write_data_register_en;
  logic [31:0] write_data_register;
  
  always_ff @(posedge aclk, negedge aresetn) begin
    if (~aresetn) begin 
      addr_register <= 32'd0;
    end else if (read_addr_register_en) begin
      addr_register <= araddr;
    end else if (write_addr_register_en) begin
      addr_register <= awaddr;
    end
  end

  always_ff @(posedge aclk, negedge aresetn) begin
    if (~aresetn) begin 
      write_data_register <= 32'd0;
    end else if (write_data_register_en) begin
      write_data_register <= wdata;
    end
  end

  Register_File rf (
    .clk(aclk), 
	  .reset_n(aresetn), 
		.we(rf_we),
		.re(rf_re),
		.addr(addr_register),
		.write_data(write_data_register),
		.read_data(rdata)
	);
  
  enum logic [3:0] { IDLE, READ_ADDR_READY, WRITE_ADDR_READY_1, WRITE_DATA_READY_1, WRITE_READY_1} currState, nextState;

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
    write_addr_register_en = 1'b0;
    read_addr_register_en = 1'b0;
    rvalid  = 1'b0;
    awready = 1'b0;
    wready  = 1'b0;
    write_data_register_en = 1'b0;
    bvalid = 1'b0;
    arready = 1'b0;
    case (currState) 
      IDLE: begin 
        arready = 1'b1;
        awready = 1'b1;
        wready  = 1'b1;
        if (arvalid && rready) begin 
          nextState = READ_ADDR_READY; 
          read_addr_register_en = 1'b1;
        end else if (awvalid && ~wvalid && bready) begin
          nextState = WRITE_ADDR_READY_1;
          write_addr_register_en = 1'b1;
        end else if (wvalid && ~awvalid && bready) begin
          nextState = WRITE_DATA_READY_1;
          write_data_register_en = 1'b1;
        end else if (awvalid && wvalid && bready) begin
          nextState = WRITE_READY_1;
          write_data_register_en = 1'b1;
          write_addr_register_en = 1'b1;
        end else begin
          nextState = IDLE;
        end
      end 
      READ_ADDR_READY: begin
        nextState = IDLE;
        rf_re = 1'b1;
        rvalid = 1'b1;
      end	
      WRITE_ADDR_READY_1: begin
        nextState = wvalid ? WRITE_READY_1 : WRITE_ADDR_READY_1;
        wready = 1'b1;
        write_data_register_en = wvalid;
      end
      WRITE_DATA_READY_1: begin
        nextState = awvalid ? WRITE_READY_1 : WRITE_DATA_READY_1;
        awready = 1'b1;
        write_addr_register_en = awvalid;
      end
      WRITE_READY_1: begin
        nextState = IDLE;
        rf_we = 1'b1;
        bvalid = 1'b1;
      end
      default: begin
        nextState = IDLE;
        rf_we = 1'b0;
        rf_re = 1'b0;
        nextState = IDLE;
        write_addr_register_en = 1'b0;
        read_addr_register_en = 1'b0;
        rvalid  = 1'b0;
        awready = 1'b0;
        wready  = 1'b0;
        write_data_register_en = 1'b0;
        bvalid = 1'b0;
        arready = 1'b0;
      end
    endcase
  end

endmodule : AXI_Lite_Slave 

module AXI_Lite_Master(
  input logic aclk, aresetn,
  input logic rw_transaction, rw_enable,
  input logic [31:0]  write_data,
  input logic [4:0] address,
  output logic [31:0] read_data,
  output logic [4:0] araddr, 
  output logic [2:0] arprot,
  output logic arvalid,
  input logic arready,
  input logic [31:0] rdata,
  input logic [1:0] rresp,
  input logic rvalid,
  output logic rready,
  output logic [4:0] awaddr,
  output logic [2:0] awprot,
  output logic awvalid,
  input logic awready,
  output logic wvalid,
  output logic [31:0] wdata, 
  output logic [3:0] wstrb,
  input logic wready,
  input logic [1:0] bresp,
  input logic bvalid,
  output logic bready
);

  logic rdata_load;
  logic [31:0] r_write_data;
  logic [4:0]  r_addr;
  logic [31:0] r_read_data;

  always_ff @(posedge aclk, negedge aresetn) begin
    if (~aresetn) begin
      r_read_data <= '0;
    end else if (rvalid) begin
      r_read_data <= rdata; 
    end
  end

  always_ff @(posedge aclk, negedge aresetn) begin
    if (~aresetn) begin 
      r_write_data <= '0;
    end else if (rw_enable && ~rw_transaction) begin
      r_write_data <= write_data;
    end
  end

  always_ff @(posedge aclk, negedge aresetn) begin
    if (~aresetn) begin 
      r_addr <= '0;
    end else if (rw_enable) begin
      r_addr <= address;
    end
  end

  assign read_data = r_read_data; 
  assign wdata = r_write_data;
  assign awaddr = r_addr;
  assign araddr = r_addr; 

  enum logic [2:0] {IDLE, READ_1, READ_2, WRITE_1, WRITE_READY, WRITE_DATA_READY, WRITE_ADDR_READY} currState, nextState;

  always_ff @(posedge aclk, negedge aresetn) begin
    if (~aresetn) begin
      currState <= IDLE; 
    end else begin
      currState <= nextState;
    end
  end 

  always_comb begin
    arprot = 3'd0; 
    arvalid = 1'b0; 
    rready = 1'b0;
    awprot = 3'd0;
    awvalid = 1'b0;
    wvalid = 1'b0;
    wstrb = 4'd0;
    bready = 1'b0;
    rdata_load = 1'b0;
    case (currState) 
      IDLE: begin
        if (rw_enable) begin
          nextState = rw_transaction ? (READ_1) : (WRITE_1);
        end else begin
          nextState = IDLE;
        end 
      end
      READ_1: begin
        arvalid = 1'b1;
        rready  = 1'b1;
        nextState = arready ? READ_2 : READ_1;
      end 
      READ_2: begin
        rready = 1'b1;
        nextState = rvalid ? IDLE : READ_2;
        rdata_load = rvalid;
      end
      WRITE_1: begin
        awvalid = 1'b1;
        wvalid = 1'b1;
        bready = 1'b1;
        if (awready && wready) begin
          nextState = WRITE_READY;
        end else if (awready) begin
          nextState = WRITE_ADDR_READY;
        end else if (wready) begin
          nextState = WRITE_DATA_READY;
        end else begin
          nextState = WRITE_1;
        end
      end
      WRITE_ADDR_READY: begin
        wvalid = 1'b1;
        bready = 1'b1;
        nextState = wready ? WRITE_READY : WRITE_ADDR_READY; 
      end
      WRITE_DATA_READY: begin
        awvalid = 1'b1;
        bready = 1'b1;
        nextState = awready ? WRITE_READY : WRITE_DATA_READY; 
      end 
      WRITE_READY: begin
        nextState = bvalid ? IDLE : WRITE_READY;  
      end
    endcase
  end

endmodule : AXI_Lite_Master
