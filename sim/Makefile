compVsys:
	iverilog -g2012 -f ../flist/video_sys.f -s video_sys_top -o video_sys_top.vvp
compV:
	vcs  -full64 -sverilog -f ../flist/video_sys.f
compM:
	vcs  -full64 -sverilog -f ../flist/MMA.f -l comp.log
clr:
	rm -rf *csrc ./*.daidir $(simv_name) *simv* DVE* ucli* *.vpd *.vdb *.log *.fsdb *novas* *.dat *Log  *conf
