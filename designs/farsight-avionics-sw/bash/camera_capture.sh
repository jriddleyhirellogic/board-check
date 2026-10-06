#!/bin/bash
# Mirrors Camera_Setup(1) and Take_Picture() from SerialTest.py over /dev/ttyUSB0

PORT=${1:-/dev/ttyUSB0}

stty -F "$PORT" 115200 raw cs8 -cstopb -parenb -echo

# CRC-32: polynomial 0x04C11DB7, no reflection, no complement (matches SerialTest.py)
declare -a CRC_TABLE
for (( n=0; n<256; n++ )); do
    rem=$(( n << 24 ))
    for (( b=0; b<8; b++ )); do
        if (( rem & 0x80000000 )); then
            rem=$(( ((rem << 1) ^ 0x04C11DB7) & 0xFFFFFFFF ))
        else
            rem=$(( (rem << 1) & 0xFFFFFFFF ))
        fi
    done
    CRC_TABLE[$n]=$rem
done

crc32() {
    local rem=0 d
    for byte in "$@"; do
        d=$(( (byte ^ (rem >> 24)) & 0xFF ))
        rem=$(( (CRC_TABLE[d] ^ (rem << 8)) & 0xFFFFFFFF ))
    done
    echo $rem
}

# send_packet FUNC ERR [DATA_BYTES...]
# Packet layout: SYNC(4) | func(1) | err(1) | seq=0(1) | len(1) | reserved(8) | data | CRC(4)
send_packet() {
    local func=$1 err=$2
    shift 2
    local -a data=("$@")
    local len=${#data[@]}
    local crc hex

    crc=$(crc32 $func $err 0 $len 0 0 0 0 0 0 0 0 "${data[@]}")

    hex='\x1a\xcf\xfc\x1d'
    hex+=$(printf '\\x%02x\\x%02x\\x00\\x%02x' $func $err $len)
    hex+='\x00\x00\x00\x00\x00\x00\x00\x00'
    for b in "${data[@]}"; do
        hex+=$(printf '\\x%02x' $b)
    done
    hex+=$(printf '\\x%02x\\x%02x\\x%02x\\x%02x' \
        $(( (crc >> 24) & 0xFF )) \
        $(( (crc >> 16) & 0xFF )) \
        $(( (crc >>  8) & 0xFF )) \
        $((  crc        & 0xFF )))

    printf '%b' "$hex" > "$PORT"
}

# Outputs 4 decimal byte values for a 32-bit little-endian word
le32() {
    local v=$1
    echo $(( v & 0xFF )) $(( (v >> 8) & 0xFF )) $(( (v >> 16) & 0xFF )) $(( (v >> 24) & 0xFF ))
}

# Opcodes
REG_WRITE=0x04
SET_MODE=0x01
START_ACQ=0x06
XFER_BUFF=0x0A
UPDATE_NET=36

# Register IDs
REG_BUF_SELECT=33
REG_GAIN=3
REG_BLO=4
REG_EXPOSURE=5
REG_SRC_MAC_0_3=42
REG_SRC_MAC_4_5=43
REG_DST_MAC_0_3=44
REG_DST_MAC_4_5=45
REG_SRC_IP=46
REG_DST_IP=47
REG_SRC_PORT=50
REG_DST_PORT=51

reg_write() { send_packet $REG_WRITE 1 $1 $(le32 $2); }
set_mode()  { send_packet $SET_MODE  1 $(le32 $1);    }

# --- Camera_Setup(1) ---
echo "[camera_capture] Selecting image buffer 1"
reg_write $REG_BUF_SELECT 1
sleep 1

echo "[camera_capture] Powering down camera (mode 1)"
set_mode 1
sleep 2

echo "[camera_capture] Setting gain=240, BLO=240, exposure=3000"
reg_write $REG_GAIN     240
reg_write $REG_BLO      240
reg_write $REG_EXPOSURE 3000

echo "[camera_capture] Powering up camera (mode 2)"
set_mode 2
sleep 10

echo "[camera_capture] Configuring network registers"
reg_write $REG_SRC_MAC_0_3 0xA3123456
reg_write $REG_SRC_MAC_4_5 0x0004
reg_write $REG_DST_MAC_0_3 0xC25649ED
reg_write $REG_DST_MAC_4_5 0x88A4
reg_write $REG_SRC_IP      $(( (10  << 24) | (101 << 16) | (15 << 8) | 192 ))
reg_write $REG_DST_IP      $(( (10  << 24) | (101 << 16) | (15 << 8) | 195 ))
reg_write $REG_SRC_PORT    0x04D2
reg_write $REG_DST_PORT    0x8931
send_packet $UPDATE_NET 1
sleep 2

echo "[camera_capture] Arming camera (mode 4)"
set_mode 4
sleep 7

# --- Take_Picture() ---
echo "[camera_capture] Starting acquisition"
send_packet $START_ACQ 0
sleep 2

echo "[camera_capture] Transferring buffer"
send_packet $XFER_BUFF 1

echo "[camera_capture] Done"
