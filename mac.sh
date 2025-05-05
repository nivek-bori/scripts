#!/bin/bash

# Loggin wifi port for user
networksetup -listallhardwareports
printf "\n"

# Getting port location
printf "Enter the en{digit} of your wifi (e.g., \"en0\" or \"en1\": "
read port
printf "\n"

# Chechking user input is valid
if [[ "$port" =~ ^en[0-2]$ ]]; then
  echo "Valid interface: [$port]\n"
else
  printf "Invalid input. Please enter valid en{digit} (e.g., \"en0\" or \"en1\")\n"
  exit 1
fi


# Generate a random MAC address (starts with 02 for local use)
mac=$(printf '02:%02x:%02x:%02x:%02x:%02x\n' \
  $((RANDOM%256)) $((RANDOM%256)) $((RANDOM%256)) \
  $((RANDOM%256)) $((RANDOM%256)))

# Print the generated MAC
echo "Generated MAC: [$mac]\n"

printf "Please enter your password whenever prompted\n\n"

# Disabling the address
sudo networksetup -setairportpower "$port" off
sudo ifconfig "$port" down
ifconfig "$port"

# Changing mac address
sudo ifconfig "$port" ether "$mac"

# Enabling the address
sudo networksetup -setairportpower "$port" on
sudo ifconfig "$port" up
ifconfig "$port"

echo "\nSuccessfully changed mac address to: [$mac]"
