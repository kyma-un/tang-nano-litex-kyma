// Standalone blinky for the Sipeed Tang Nano 20K.
// Clock: 27 MHz oscillator, ball 4.
// LEDs: active-low, balls 15 16 17 18 19 20.
// Constraints live in constraints/tangnano20k.cst.
// The same balls are described for LiteX in tang_nano_kyma/platform.py.

module blinky (
    input  wire       clk27,
    output reg  [5:0] led_n
);
    localparam integer CLK_HZ = 27_000_000;
    localparam integer DIV = CLK_HZ / 4;

    reg [31:0] count = 0;
    reg [5:0]  walk  = 6'b000001;

    always @(posedge clk27) begin
        if (count == DIV - 1) begin
            count <= 0;
            walk  <= {walk[4:0], walk[5]};
        end else begin
            count <= count + 1;
        end
        led_n <= ~walk;
    end
endmodule
