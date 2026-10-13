module i2c_scl(
	input clk,
	output reg scl = 1,
	output reg tick = 0,
	output wire scl_bus);

reg [8:0]count = 0;

assign scl_bus = (scl == 1'b0) ? 1'b0 : 1'bz; 

always @(posedge clk) begin
	if (count == 499) begin	
		tick <=1;
		count <= 0;
		scl <= ~scl;
	end
	else begin
		count<= count +1;
       		tick <= 0;
	end
end

endmodule