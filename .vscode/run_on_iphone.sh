#!/bin/bash

# Kill any existing Flutter processes
echo "Stopping any existing Flutter processes..."
pkill -f flutter || true

# Get list of available iOS devices
echo "Available iOS devices:"
flutter devices | grep "ios" | grep -v "Not found" | awk '{print NR ". " $0}'

# Specify your iPhone device name when prompted, or default to the first iOS device
read -p "Enter your iPhone device name or press Enter to use the first one: " device_name

if [ -z "$device_name" ]; then
  device_id=$(flutter devices | grep "ios" | grep -v "Not found" | head -n 1 | awk '{print $2}')
  device_id=${device_id//[()]/}
else
  device_id=$device_name
fi

# Run on selected device
echo "Running on device: $device_id"
# Use program instead of target for better compatibility
flutter run -d "$device_id" --no-pub lib/main.dart 