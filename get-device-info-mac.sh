#!/bin/bash
# CNS IT - Device Info Collector (macOS)
# Double-click RUN-Device-Info.command to launch.

clear
echo "====================================================="
echo "   CNS IT - Device Info Collector (macOS)"
echo "====================================================="
echo ""
echo "Gathering device info..."
echo ""

# Model
MODEL=$(system_profiler SPHardwareDataType 2>/dev/null | awk -F': ' '/Model Name/{print $2}')
CHIP=$(system_profiler SPHardwareDataType 2>/dev/null | awk -F': ' '/Chip/{print $2}')
if [ -z "$MODEL" ]; then MODEL="Unknown"; fi

# Serial Number
SERIAL=$(system_profiler SPHardwareDataType 2>/dev/null | awk -F': ' '/Serial Number/{print $2}')
if [ -z "$SERIAL" ]; then SERIAL=$(ioreg -l | grep IOPlatformSerialNumber | awk -F'"' '{print $4}'); fi

# MAC Addresses (Wi-Fi and Ethernet, internal only - exclude USB and virtual)
WIFI_MAC=""
ETH_MAC=""

# Use networksetup -listallhardwareports to identify built-in interfaces
# This properly excludes USB adapters which show as separate "USB 10/100/1000 LAN" etc.
HW_PORTS=$(networksetup -listallhardwareports 2>/dev/null)

# Find Wi-Fi MAC (always built-in)
WIFI_MAC=$(echo "$HW_PORTS" | awk '
    /Hardware Port: Wi-Fi/ { found=1; next }
    found && /Ethernet Address/ { print $3; exit }
')

# Find Ethernet MAC - built-in only, not USB or Thunderbolt adapters
# Built-in ethernet shows as just "Ethernet" or "Ethernet Slot X"
# USB adapters show as "USB 10/100/1000 LAN" or similar
# Thunderbolt adapters show as "Thunderbolt Ethernet Slot X" - we keep these as they're often docked
ETH_MAC=$(echo "$HW_PORTS" | awk '
    /Hardware Port: Ethernet$/ || /Hardware Port: Ethernet Slot/ { found=1; next }
    found && /Ethernet Address/ { print $3; exit }
')

# Fallback to ifconfig en0 if networksetup gave nothing for Wi-Fi
if [ -z "$WIFI_MAC" ]; then
    WIFI_MAC=$(ifconfig en0 2>/dev/null | awk '/ether/{print $2}')
fi

# OS Version
OS_VER=$(sw_vers -productVersion 2>/dev/null)
OS_NAME=$(sw_vers -productName 2>/dev/null)

# FileVault Status
FV_STATUS=$(fdesetup status 2>/dev/null)
if echo "$FV_STATUS" | grep -q "On"; then
    ENCRYPTION="FileVault: On (Fully Enabled)"
elif echo "$FV_STATUS" | grep -q "Off"; then
    ENCRYPTION="FileVault: Off"
else
    ENCRYPTION="FileVault: Unknown"
fi

# Computer Name
COMP_NAME=$(scutil --get ComputerName 2>/dev/null)

# IP Address
IP_ADDR=$(ipconfig getifaddr en0 2>/dev/null)
if [ -z "$IP_ADDR" ]; then IP_ADDR=$(ipconfig getifaddr en1 2>/dev/null); fi

# UT Tag (last 6 characters of computer name)
COMP_LEN=${#COMP_NAME}
if [ "$COMP_LEN" -ge 6 ]; then
    UT_TAG=${COMP_NAME: -6}
else
    UT_TAG=$COMP_NAME
fi

# === OUTPUT ===
LINE="======================================================"
echo "$LINE"
echo "  DEVICE INFO - COPY INTO DEPLOYMENT FORM"
echo "$LINE"
echo ""
if [ -n "$CHIP" ]; then
    echo "  Model:        $MODEL ($CHIP)"
else
    echo "  Model:        $MODEL"
fi
echo "  Serial:       $SERIAL"
echo "  MAC Address:"
if [ -n "$WIFI_MAC" ]; then echo "    Wi-Fi:      $WIFI_MAC"; fi
if [ -n "$ETH_MAC" ];  then echo "    Ethernet:   $ETH_MAC"; fi
if [ -z "$WIFI_MAC" ] && [ -z "$ETH_MAC" ]; then echo "    Unknown"; fi
echo "  OS:           $OS_NAME $OS_VER"
echo "  Encryption:   $ENCRYPTION"
echo "  Computer:     $COMP_NAME"
echo "  UT Tag:       $UT_TAG"
echo "  IP Address:   $IP_ADDR"
echo ""
echo "$LINE"

# Save to USB drive (find KINGSTON or any mounted volume that contains this script)
USB_DIR=""
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
# Check if script is running from a /Volumes/ mount
if [[ "$SCRIPT_DIR" == /Volumes/* ]]; then
    # Get just the volume root
    USB_DIR=$(echo "$SCRIPT_DIR" | awk -F'/' '{print "/"$2"/"$3}')
fi
# Fallback: look for any USB volume
if [ -z "$USB_DIR" ] || [ ! -d "$USB_DIR" ]; then
    for vol in /Volumes/*/; do
        if [ -w "$vol" ] && [ "$vol" != "/Volumes/Macintosh HD/" ]; then
            USB_DIR="$vol"
            break
        fi
    done
fi

if [ -n "$USB_DIR" ] && [ -d "$USB_DIR" ]; then
    SAVE_DIR="$USB_DIR/Mac deployed"
    mkdir -p "$SAVE_DIR" 2>/dev/null
    TIMESTAMP=$(date +%Y%m%d-%H%M%S)
    OUTFILE="$SAVE_DIR/device-info-$COMP_NAME-$TIMESTAMP.txt"
    {
        echo "CNS IT Device Info - $(date)"
        echo "Model: $MODEL $([ -n "$CHIP" ] && echo "($CHIP)")"
        echo "Serial: $SERIAL"
        echo "MAC Address:"
        if [ -n "$WIFI_MAC" ]; then echo "  Wi-Fi: $WIFI_MAC"; fi
        if [ -n "$ETH_MAC" ];  then echo "  Ethernet: $ETH_MAC"; fi
        if [ -z "$WIFI_MAC" ] && [ -z "$ETH_MAC" ]; then echo "  Unknown"; fi
        echo "OS: $OS_NAME $OS_VER"
        echo "Encryption: $ENCRYPTION"
        echo "Computer Name: $COMP_NAME"
        echo "UT Tag: $UT_TAG"
        echo "IP: $IP_ADDR"
    } > "$OUTFILE" 2>/dev/null

    if [ -f "$OUTFILE" ]; then
        echo ""
        echo "  Saved to USB: $OUTFILE"
    else
        echo ""
        echo "  (Could not save to USB)"
    fi
else
    echo ""
    echo "  (No USB drive detected)"
fi

echo ""
echo "Press Enter to close..."
read
