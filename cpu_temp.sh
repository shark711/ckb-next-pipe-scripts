#!/bin/bash

PIPE="/tmp/ckbpipe000"

CHECK_EVERY=5 # Check temperature every X seconds
CORE_TEMP='Tctl:'

LOW_TEMP=30  #Cyan at 30'C
IDLE_TEMP=40 #Green at 40'C
HIGH_TEMP=65 #Yellow at 65'C
HOT_TEMP=80  #Red at 80'C

# Function to write to pipe with timeout
# if ckn-next is not actively listening to the pipe, writing to the pipe take forever, creating a write_to_pipe() function with a timeout to avoid this from hanging, can copy and paste this for other projects, not reusing exeisting variables
write_to_pipe() {
    local pipe="$1"
    local data="$2"
    local timeout="$3"
    local pid

    # Check if pipe is open for writing
    if [ ! -w "$pipe" ]; then
        echo "Pipe $pipe not open for writing"
        return 1
    fi

    # Write data to pipe in the background
    echo "$data" > "$pipe" &
    pid=$!

    # Wait for the background process or timeout
    (sleep "$timeout"; kill -9 "$pid" 2>/dev/null) & wait "$pid" 2>/dev/null
}

while true; do
   # Initialize RGB_COLOR variable, and set it to transparent black
   RGB_COLOR='00000000'

   # Use `sensors` command to get temperature readings, grep for lines starting with $CORE_TEMP, which in my case is 'Tctl:'
   # Use sed to clean up the output and extract the temperature value
   #cpu_temp=$(sensors | grep "^Tctl:" | sed 's/^Tctl:[[:space:]]*+//' | sed 's/°C.*$//')
   cpu_temp=$(sensors | grep "^$CORE_TEMP" | sed "s/^$CORE_TEMP[[:space:]]*+//" | sed 's/°C.*$//')

   
   # Print current temperature
   #DEBUG echo "Current CPU Temperature: $cpu_temp°C"
   
   

   # Check temperature against thresholds and set RGB_COLOR accordingly
   if (( $(echo "$cpu_temp <= $LOW_TEMP" | bc -l) )); then
       # Temperature is below or equal to LOW_TEMP
       RGB_COLOR='00FFFFFF' # Cyan
   elif (( $(echo "$cpu_temp >= $LOW_TEMP && $cpu_temp < $IDLE_TEMP" | bc -l) )); then
       # Temperature is between LOW_TEMP and IDLE_TEMP
       # Scale color from CYAN (#00FFFFFF) to GREEN (#00FF00FF)
       scaled_temp=$(echo "scale=2; ($cpu_temp - $LOW_TEMP) / ($IDLE_TEMP - $LOW_TEMP)" | bc -l)
       green_value=$(echo "255 * $scaled_temp" | bc -l)
       green_int=$(printf "%.0f" "$green_value")
       RGB_COLOR=$(printf "%02x%02x%02x" 0 \
                   $green_int \
                   $(printf "%.0f" "$(echo "255 - $green_value" | bc -l)"))
       RGB_COLOR="${RGB_COLOR^^}FF" # Append alpha channel (fully opaque)
   elif (( $(echo "$cpu_temp >= $IDLE_TEMP && $cpu_temp < $HIGH_TEMP" | bc -l) )); then
       # Temperature is between IDLE_TEMP and HIGH_TEMP
       # Scale color from GREEN (#00FF00FF) to YELLOW (#FFFF00FF)
       scaled_temp=$(echo "scale=2; ($cpu_temp - $IDLE_TEMP) / ($HIGH_TEMP - $IDLE_TEMP)" | bc -l)
       red_value=$(echo "255 * $scaled_temp" | bc -l)
       red_int=$(printf "%.0f" "$red_value")
       RGB_COLOR=$(printf "%02x%02x%02x" \
                   $red_int \
                   255 \
                   0)
       RGB_COLOR="${RGB_COLOR^^}FF" # Append alpha channel (fully opaque)
   elif (( $(echo "$cpu_temp >= $HIGH_TEMP && $cpu_temp < $HOT_TEMP" | bc -l) )); then
       # Temperature is between HIGH_TEMP and HOT_TEMP
       # Scale color from YELLOW (#FFFF00FF) to RED (#FF0000FF)
       scaled_temp=$(echo "scale=2; ($cpu_temp - $HIGH_TEMP) / ($HOT_TEMP - $HIGH_TEMP)" | bc -l)
       green_value=$(echo "255 * (1 - $scaled_temp)" | bc -l)
       green_int=$(printf "%.0f" "$green_value")
       RGB_COLOR=$(printf "%02x%02x%02x" \
                   255 \
                   $green_int \
                   0)
       RGB_COLOR="${RGB_COLOR^^}FF" # Append alpha channel (fully opaque)
   elif (( $(echo "$cpu_temp >= $HOT_TEMP" | bc -l) )); then
       # Temperature is HOT_TEMP or higher
       RGB_COLOR='FF0000FF' # Red
   fi
   
   write_to_pipe "$PIPE" "rgb $RGB_COLOR" 0.5

   # Sleep for CHECK_EVERY seconds
   sleep $CHECK_EVERY
done
