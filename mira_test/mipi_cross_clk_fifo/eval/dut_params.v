localparam WADDR_DEPTH = 64;
localparam WDATA_WIDTH = 34;
localparam RADDR_DEPTH = 64;
localparam RDATA_WIDTH = 34;
localparam FIFO_CONTROLLER = "HARD_IP";
localparam FWFT = 0;
localparam FORCE_FAST_CONTROLLER = 1;
localparam IMPLEMENTATION = "EBR";
localparam WADDR_WIDTH = 6;
localparam RADDR_WIDTH = 6;
localparam REGMODE = "reg";
localparam OREG_IMPLEMENTATION = "LUT";
localparam RESETMODE = "async";
localparam ENABLE_ALMOST_FULL_FLAG = "FALSE";
localparam ALMOST_FULL_ASSERTION = "static-single";
localparam ALMOST_FULL_ASSERT_LVL = 63;
localparam ALMOST_FULL_DEASSERT_LVL = 62;
localparam ENABLE_ALMOST_EMPTY_FLAG = "FALSE";
localparam ALMOST_EMPTY_ASSERTION = "static-single";
localparam ALMOST_EMPTY_ASSERT_LVL = 1;
localparam ALMOST_EMPTY_DEASSERT_LVL = 2;
localparam ENABLE_DATA_COUNT_WR = "FALSE";
localparam ENABLE_DATA_COUNT_RD = "FALSE";
localparam FAMILY = "LIFCL";
`define je5d00
`define LIFCL
`define LIFCL_40
