#!/bin/bash

# List of TCP ports to allow
tcp_ports=(47984 47989 48010)

# List of UDP ports to allow
udp_ports=(5353 47998 47999 48000 48002 48010)

# Check if UFW is installed and active
ufw status >/dev/null 2>&1
if [ $? -ne 0 ]; then
	echo "UFW does not seem to be installed or active. Please install and/or enable it."
	exit 1
fi

# Allow TCP ports
for port in "${tcp_ports[@]}"; do
	echo "Allowing TCP port $port..."
	ufw allow $port/tcp
done

# Allow UDP ports
for port in "${udp_ports[@]}"; do
	echo "Allowing UDP port $port..."
	ufw allow $port/udp
done

echo "Operation completed. The specified TCP and UDP ports have been allowed through UFW."
