// Six active-low LEDs on the Tang Nano 20K (balls 15, 16, 17, 18, 19, 20).
// The RISC-V core writes `pattern` and `enable` through a LiteX CSR.
// enable = 0 rotates one LED. enable = 1 holds `pattern` (1 = LED on).

module kyma_leds #(
    parameter integer CLK_HZ = 48_000_000
) (
    input  wire       clk,
    input  wire       rst,
    input  wire [5:0] pattern,
    input  wire       enable,
    output reg  [5:0] leds_n
);
    localparam integer STEP_HZ = 4;
    localparam integer DIV = (CLK_HZ / STEP_HZ) > 0 ? (CLK_HZ / STEP_HZ) : 1;

    reg [31:0] count = 0;
    reg [5:0]  walk  = 6'b000001;

    always @(posedge clk) begin
        if (rst) begin
            count  <= 0;
            walk   <= 6'b000001;
            leds_n <= 6'b111110;
        end else if (enable) begin
            leds_n <= ~pattern;
        end else if (count == DIV - 1) begin
            count  <= 0;
            walk   <= {walk[4:0], walk[5]};
            leds_n <= ~{walk[4:0], walk[5]};
        end else begin
            count <= count + 1;
        end
    end
endmodule
