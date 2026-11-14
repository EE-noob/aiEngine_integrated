puts "XILINX_VIVADO=$::env(XILINX_VIVADO)"
puts "FAMILY_DIR=[file exists $::env(XILINX_VIVADO)/data/parts/xilinx/virtexuplus/devint/virtexuplus/xcvu3p]"
puts "FAMILY_FILES=[llength [glob -nocomplain $::env(XILINX_VIVADO)/data/parts/xilinx/virtexuplus/devint/virtexuplus/xcvu3p/*]]"
puts "VU3P_PART=[get_parts -quiet xcvu3p-ffvc1517-2-i]"
puts "VU3P_MATCHES=[get_parts -quiet -filter {NAME =~ *xcvu3p*}]"
exit
