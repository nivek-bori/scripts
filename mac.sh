#!/bin/bash

# Enhanced logging
export PS4='+ $(date "+%H:%M:%S") [${BASH_SOURCE##*/}:${LINENO}] '

printf "Note: There is a ~2 day cooldown on changing the MAC address of your device"
sleep 5
printf "\n"

# Loggin wifi port for user
set -x # ---logging
networksetup -listallhardwareports
set +x # ---logging
printf "\n"

# Getting port location
printf "Enter the en{digit} of the Hardware Port of your Wifi (e.g., \"en0\" or \"en1\"): "
read port
printf "\n"

# Chechking user input is valid
if [[ "$port" =~ ^en[0-2]$ ]]; then
  echo "Valid interface: [$port]"
  printf "\n \n"
else
  printf "Invalid input. Please enter valid en{digit} (e.g., \"en0\" or \"en1\")\n"
  exit 1
fi

# Generate a random MAC address (starts with 02 for local use)
set -x # ---logging
mac=$(printf '02:%02x:%02x:%02x:%02x:%02x\n' \
  $((RANDOM%256)) $((RANDOM%256)) $((RANDOM%256)) \
  $((RANDOM%256)) $((RANDOM%256)))
set +x # ---logging
# Print the generated MAC
echo "Generated MAC: [$mac]"
printf "\n \n"

printf "Please enter your password whenever prompted\n\n"

# Disabling the address
printf "DISABLING THE ADDRESS\n"
set -x # ---logging
sudo networksetup -setairportpower "$port" off
sudo ifconfig "$port" down
sleep 5
set +x # ---logging
printf "Current Ether: "
ifconfig "$port" | grep ether
printf "\n \n"

# Changing mac address
printf "CHANGING THE ADDRESS TO $mac\n"
set -x # ---logging

set +x # ---logging
sleep 5
printf "\n \n"

# Enabling the address
printf "ENABLING THE ADDRESS\n"
set -x # ---logging
sudo networksetup -setairportpower "$port" on
sudo ifconfig "$port" up
sleep 5
set +x # ---logging
printf "Current Ether: "
ifconfig "$port" | grep ether
printf "\n \n"

# Resetting network
printf "RESETTING THE NETWORK\n"
set -x # ---logging
sudo networksetup -setnetworkserviceenabled Wi-Fi off
sleep 5
sudo networksetup -setnetworkserviceenabled Wi-Fi on
sleep 5
set +x  # ---logging
printf "Current Ether: "
ifconfig "$port" | grep ether
printf "\n"