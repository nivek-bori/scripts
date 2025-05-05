#!/bin/bash

# Loggin wifi port for user
networksetup -listallhardwareports

# Getting port location
echo 'Enter the en{digit} of your wifi (e.g., \"en0\" or \"en1\": '
read port

# Chechking user input is valid
if [[ "$port" =~ ^en[0-2]$ ]]; then
  echo "Valid interface: $port"
else
  echo 'Invalid input. Please enter en{digit} (e.g., \"en0\" or \"en1\": .'
  exit 1
fi


# Generate a random MAC address (starts with 02 for local use)
mac=$(printf '02:%02x:%02x:%02x:%02x:%02x\n' \
  $((RANDOM%256)) $((RANDOM%256)) $((RANDOM%256)) \
  $((RANDOM%256)) $((RANDOM%256)))

# Print the generated MAC
echo "Generated MAC: $mac"

# Bring interface down, assign MAC, then bring up (replace 'en0' as needed)
networksetup -setairportpower "$port" off
sudo ifconfig "$port" down
sudo ifconfig "$port" ether "$mac"
sudo ifconfig "$port" up

echo "Successfully changed mac address to: $mac"
