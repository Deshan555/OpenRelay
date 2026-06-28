#!/bin/bash

# Expose backend port 8000 to the public via ngrok
PORT=8000

echo "=========================================================="
echo " Starting ngrok tunnel on port $PORT..."
echo "=========================================================="
echo "Once started, look for the 'Forwarding' URL in the terminal."
echo "Example: https://xxxx-xx-xx-xx-xx.ngrok-free.app"
echo ""
echo "Copy that URL and paste it into the Setup Screen in your"
echo "OpenRelay Android mobile application."
echo "=========================================================="
echo ""

ngrok http $PORT
