function port_3000() {
  lsof -wni tcp:3000
}

# Kills whatever is running on port 3000
function kill_3000() {
  kill -9 $(lsof -i :3000 -t)
}
