find . -type f \( -name "*.tcl" -o -name "*.sv" -o -name "*.v" -o -name "*.f" -o -name "*.txt" \) \
  -exec vim -c "set ff=unix" -c "wq" {} \;
