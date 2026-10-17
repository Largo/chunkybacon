# Last in manifest.txt: the simulator's files are loaded, the host is the
# worker's (picoruby_lab.rb requires them on the first run with a board).
PicoSim.host = PicoSim::HostJS.new
