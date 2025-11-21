+incdir+.
+incdir+./interface
+incdir+./env
+incdir+./test
+incdir+./uvc/nice

// Compile interface first
./interface/nice_if.sv

// Compile UVC package
./uvc/nice/ai_nice_pkg.sv

// Compile environment package
./env/ai_env_pkg.sv

// Compile test package
./test/ai_test_pkg.sv

// Compile DUT
-f flist/dut.f

// Compile testbench top
./tb/top_tb.sv
