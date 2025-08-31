// `default_nettype none

module top (
    input  logic CLOCK_100,
    input  logic [3:0] BTN, 
    input  logic [15:0] SW,
    output logic [15:0] LD
);

    logic clock, reset_n;
    logic [31:0] araddr;
    logic [3:0] arcache;
    logic [2:0] arprot;
    logic arvalid;
    logic arready;   
    logic [31:0] rdata;
    logic [1:0] rresp; 
    logic rvalid;
    logic rready;      
    logic [31:0] awaddr;
    logic [3:0] awcache;
    logic [2:0] awprot; 
    logic  awvalid;     
    logic  awready;     
    logic wvalid;
    logic [31:0] wdata; 
    logic [3:0] wstrb;  
    logic  wready;      
    logic [1:0] bresp;        
    logic bvalid;       
    logic bready;       

    logic [31:0] LD_r_data;

    assign reset_n = SW[0];
    assign clock   = CLOCK_100;

    always_ff @(posedge clock) begin
        if (~reset_n) begin
            LD_r_data <= 32'hFFFF;
        end else if (rvalid) begin
            LD_r_data <= rdata;
        end 
    end 

    assign LD = SW[1] ? LD_r_data[31:16] : LD_r_data [15:0];

    jtag_axi_0 JTAG_to_AXI (
        .aclk (clock),
        .aresetn (reset_n),  
        .m_axi_awaddr (awaddr),
        .m_axi_awprot (awprot),
        .m_axi_awvalid (awvalid),
        .m_axi_awready (awready),
        .m_axi_wdata (wdata),
        .m_axi_wstrb (wstrb),
        .m_axi_wvalid (wvalid),
        .m_axi_wready (wready),
        .m_axi_bresp (bresp),
        .m_axi_bvalid (bvalid),
        .m_axi_bready (bready),
        .m_axi_araddr (araddr),
        .m_axi_arprot (arprot),
        .m_axi_arvalid (arvalid),
        .m_axi_arready (arready),
        .m_axi_rdata (rdata),
        .m_axi_rresp (rresp),
        .m_axi_rvalid (rvalid),
        .m_axi_rready (rready)
    );

    AXI_Lite_Interface AXI_Slave (
        .aclk (clock),
        .aresetn (reset_n),
        .*
    );

endmodule : top