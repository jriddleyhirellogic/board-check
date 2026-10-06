import logging
import serial
import array as arr
import sys
import time
from datetime import datetime
import random
import pandas as pd
import math
import struct


SYNC_FRAME = 0x1ACFFC1D
FUNCTION_CODE = 0x10

#function codes from ICD
GET_VERSION_SYS_CMD = 0x00
SET_MODE_SYS_CMD = 0x01
RESET_SYS_CMD = 0x02
REG_READ_SYS_CMD = 0x03
REG_WRITE_SYS_CMD = 0x04
SET_TIME_SYS_CMD = 0x05
START_ACQ_SYS_CMD = 0x06
STOP_ACQ_SYS_CMD = 0x07
FOCUS_SYS_CMD = 0x08
HALT_FOCUS_SYS_CMD = 0x09
XFER_BUFF_SYS_CMD = 0x0A
GET_INFO_SYS_CMD = 0x0C
CONF_EVENT_LOG_SYS_CMD = 0x0D
EN_TL_CHAN_LOG_SYS_CMD = 0x0E
XFER_LOG_SYS_CMD = 0x0F

#RESET_SYS_CMD target_reset bit field
RESET_CAM_SENSOR = 1 << 0
RESET_FOCUS_MECH = 1 << 1
RESET_REG_SPACE  = 1 << 2
RESET_MEM_BUFF   = 1 << 3
RESET_ALL        = RESET_CAM_SENSOR | RESET_FOCUS_MECH | RESET_REG_SPACE | RESET_MEM_BUFF

DDR4_16GB_FRAME_CAPTURE_AMOUNT = 512
DDR4_8GB_FRAME_CAPTURE_AMOUNT  = 256
TOTAL_FRAME_CAPTURE_AMOUNT     = DDR4_16GB_FRAME_CAPTURE_AMOUNT + DDR4_8GB_FRAME_CAPTURE_AMOUNT

# EXPOSURE_REG is the exposure the sensor actually integrates, not the width of the trigger
# pulse. Firmware subtracts the pedestal (GMRWT line periods plus a fixed delay) before
# programming the trigger, which is a 28 bit count of 20 nsec cycles. The register itself is
# 22 bits of microseconds, which is what bounds the exposure. The minimum uses the larger 8GB
# line period so an accepted exposure works for either buffer.
SENSOR_EXPO_USEC_MIN = 43
SENSOR_EXPO_USEC_MAX = (1 << 22) - 1

#User defined to support debug and integration
ECHO_FUNCTION = 25
GET_STATUS_FUNCTION = 26
SET_VREF_FUNCTION = 27
SET_POSITION = 28
SET_CONTROL_OUTPUTS_FUNCTION = 29
ZERO_FUNCTION = 30
SET_LVDT_OFFSET_FUNCTION = 31
GET_POSITION_FUNCTION = 32
GET_PROJECTION = 34
UPDATE_NET_ADDRESS = 36
GET_TLM_READING = 37

FLASH_ERASE_SECTOR = 38
FLASH_ERASE_BLOCK = 39
WRITE_FLASH_PAGE = 40
READ_FLASH = 41
RESET_FLASH = 42
GET_CAMERA_TEMP = 43

# Misc (values continue the Serial_Function_Code_t enum in Camera/include/command.h)
GET_CAMERA_TEMP = 43
GET_FPGA_TEMP = 44
GET_CAMERA_STATE = 45
GET_METADATA = 46
SET_PPS_DELAY = 47
GET_SYSTEM_TIME_CMD = 48
GET_PPS_ERROR_CMD = 49
GET_ALL_TLM_CMD = 50

#Bootloader specific
LOAD_FLASH_TO_MEM = 76
START_APP = 77
UPDATE = 78


#Registers
GAIN_REG = 3
BLO_REG = 4
EXPOSURE_REG = 5
TRIGGER_MODE_SELECT_REG = 20
IMG_PER_TRIGGER_SYS_REG = 21
FRAME_CAPTURE_TIME_SYS_REG = 22
CAPTURE_TIME_SEC_SYS_REG = 23
CAPTURE_TIME_MSEC_SYS_REG = 24
FRAME_COUNT_SYS_REG = 26
SRC_MAC_ADDRESS_0_3_SYS_REG = 37
SRC_MAC_ADDRESS_4_5_SYS_REG = 38
DST_MAC_ADDRESS_0_3_SYS_REG = 39
DST_MAC_ADDRESS_4_5_SYS_REG = 40
SRC_IP_ADDRESS_SYS_REG = 41
DST_IP_ADDRESS_SYS_REG = 42
SRC_PORT_SYS_REG = 43
DST_PORT_SYS_REG = 44
EN_PATTERN_GEN_REG = 45     #1 enables the sensor's internal test pattern, 0 returns to normal imaging
NOOP_REG = 46       #register you can read and write to for testing, has no side effects

#TLM Channels
TLM_1V5_ASIC_ISENSE = 0
TLM_1V5_ASIC = 1
TLM_10V0_SENSE = 2
TLM_3V3_RH = 3
TLM_1V1_IMX_ISENSE = 4
TLM_28V0_EPS = 5
TLM_6V0_REG = 6
TLM_6V0_REG_ISENSE = 7
TLM_4V0_REG_ISENSE = 8
TLM_2V2_REG_ISENSE = 9
TLM_1V0_FPGA_ISENSE = 10
TLM_1V2_16GB_ISENSE = 11
TLM_2V5_16GB_ISENSE = 12
TLM_1V0A_ETH2 = 13
TLM_2V5A_ETH2 = 14
TLM_3V3_ASIC = 15
TLM_V0_REG_ISENSE = 16
TLM_V5_16GB = 17
TLM_V2_16GB = 18
TLM_V6_VTT_16GB = 19
TLM_V0_FPGA = 20
TLM_V5A_ETH1 = 21
TLM_V0_ETH2 = 22
TLM_3V3_ETH2 = 23
TLM_2V2_REG = 24
TLM_3V0_REG = 25
TLM_4V0_REG = 26
TLM_1V1_IMX = 27
TLM_1V8_IMX = 28
TLM_3V3_ETH1 = 29
TLM_1V0_ETH1 = 30
TLM_1V0A_ETH1 = 31
TLM_3V3_IMX_SNS = 32
TLM_2V9_IMX_SNS = 33
TLM_1V0A_FPGA = 34
TLM_1V25A_FPGA = 35
TLM_2V5A_FPGA = 36
TLM_1V2_8GB = 37
TLM_3V3_MISC = 38
TLM_15V0_LVDT = 39
TLM_1V8_FPGA = 40
TLM_1V8_IMX_FPGA = 41
TLM_3V3_B4_FPGA = 42
TLM_3V3_B5_FPGA = 43
TLM_0V6_VTT_8GB = 44
TLM_2V5_8GB = 45
TLM_2V5_8GB_ISENSE = 46
TLM_1V2_8GB_ISENSE = 47

class CRC_32:
    """Calculates CRC-32 using polynomial 0x04C11DB7. No initial or final complement. No reflections.
    The remainder (crc up to that point) is passed in as an argument, allowing this calculation to be
    chained"""
    crc_table = arr.array('I', range(256))
    def __init__(self):
        self.polynomial = 0x04C11DB7
        for n in range(0,256,1):
            remainder = n << 24
            for bit in range(8, 0, -1):
                if remainder & (1 << 31):
                    remainder = (remainder << 1) ^ self.polynomial
                else:
                    remainder = (remainder << 1)
            self.crc_table[n] = remainder & 0xFFFFFFFF

    def check(self, msg, rem):
            remainder = rem & 0xFFFFFFFF
            for x in msg:
                data = (x ^ (remainder >> 24)) & 0xFF
                remainder = self.crc_table[data] ^ (remainder << 8)
                remainder = remainder & 0xFFFFFFFF
            return remainder

crc_check = CRC_32()

class Packet:
    """Basic packet structure from ICD for TMTC interface"""
    def __init__(self, function, error_code, data, sequence_number,*args):
        self.function = function
        self.args = args
        self.data = data
        self.error_code = error_code
        self.sequence_number = sequence_number
        self.data_length = len(data)

class PacketInterface:
    """Sends and receives packet using serial port"""
    def __init__(self, port, timeout=0.1):
        self.port = port
        self.crc = 0
        self.timeout = timeout

    def BuildPacket(self, packet):
        #prepend sync field
        sync = 0x1ACFFC1D

        #SYNC FIELD
        output_packet = sync.to_bytes(4,'big')
        function_field = packet.function.to_bytes(1,'big')

        #OPCODE (function )
        output_packet += function_field
        self.crc = crc_check.check( function_field ,0  )

        #error (used in replies)
        error_field = packet.error_code.to_bytes(1,'big')
        self.crc = crc_check.check( error_field, self.crc)
        output_packet += error_field

        #Sequence number
        sequence_field = packet.sequence_number.to_bytes(1,'big')
        self.crc = crc_check.check( sequence_field, self.crc)
        output_packet += sequence_field

        #length (bytes) of data field
        packet_length = len(packet.data) & 0xFF
        packet_length_field = packet_length.to_bytes(1,'big')
        self.crc = crc_check.check( packet_length_field, self.crc)
        output_packet += packet_length_field

        #reserved field (will some day be used for expanded error reporting)
        reserved = 0
        reserved_field = reserved.to_bytes(8,'big')
        self.crc = crc_check.check( reserved_field, self.crc)
        output_packet += reserved_field

        #data field
        if packet_length > 0:
            self.crc = crc_check.check( packet.data , self.crc)
            output_packet += bytearray(packet.data)

        #append CRC
        output_packet +=self.crc.to_bytes(4,'big')

        return output_packet

    def Send(self, packet):
        response = None

        output_packet = self.BuildPacket(packet)

        response = bytearray()

        with serial.Serial(self.port, 115200, timeout = self.timeout) as ser:
            ser.write( output_packet )
            response = ser.read(160) # receive response

        return response

    def ResponseDetails(self, response):
        """Picks apart the TMTC response packet"""
        sync = int.from_bytes(response[0:4],'big')
        opcode = int.from_bytes(response[4:5],'big')
        error_code = int.from_bytes(response[5:6], 'big')
        sequence_number = int.from_bytes(response[6:7], 'big')
        data_length = int.from_bytes(response[7:8], 'big')
        data = response[16:16+data_length]
        return {"sync":sync,
                "opcode":opcode,
                "error_code":error_code,
                "data_length":data_length,
                "sequence_number":sequence_number,
                "data":data,
                "response_length":len(response) }


class EchoPacket(Packet):
    def __init__(self,test_data) -> None:
        #function, error_code, data, sequence_number,*args
        super().__init__(ECHO_FUNCTION,1,test_data, 2)

class ZeroPacket(Packet):
    def __init__(self):
        super().__init__(ZERO_FUNCTION,1,[], 0)

class Set_LVDT_Offset_Packet(Packet):
    def __init__(self, offset):
        super().__init__(SET_LVDT_OFFSET_FUNCTION,0,offset.to_bytes(4,'little', signed = True), 0)

class Set_Sys_Time_Packet(Packet):
    def __init__(self, time_sec):
        time_data = time_sec.to_bytes(4,'little', signed = False)
        super().__init__(SET_TIME_SYS_CMD,0, time_data, 0)

class Get_TLM_Reading_Packet(Packet):
    def __init__(self, TLM_Channel):
        super().__init__(GET_TLM_READING,0,TLM_Channel.to_bytes(4,'little', signed = True), 0)

class Set_Position_Packet(Packet):
    def __init__(self, Position):
        super().__init__( SET_POSITION, 1, Position.to_bytes(4,'little', signed = True), 0)  

class Focus_Sys_Packet(Packet):
    def __init__(self, Position):
        super().__init__( FOCUS_SYS_CMD, 1, Position.to_bytes(4,'little', signed = True), 0)

class Set_Mode_Packet(Packet):
    def __init__(self, Mode):
        super().__init__( SET_MODE_SYS_CMD, 0, Mode.to_bytes(4,'little', signed = True), 0)

class Transfer_Buffer_Packet(Packet):
    def __init__(self, index, num):
        data = index.to_bytes(2, 'little') + num.to_bytes(2, 'little')
        super().__init__( XFER_BUFF_SYS_CMD, 1, data, 0)

class Get_Metadata_Packet(Packet):
    def __init__(self, index):
        data = index.to_bytes(4, 'little')
        super().__init__( GET_METADATA, 1, data, 0)

class Get_Position_Packet(Packet):
    def __init__(self):
        super().__init__(GET_POSITION_FUNCTION,1, [], 0)

class Get_Projection_Packet(Packet):
    def __init__(self):
        super().__init__(GET_PROJECTION,1, [], 0)  

class Get_Camera_Temp_Packet(Packet):
    def __init__(self):
        super().__init__( GET_CAMERA_TEMP,1, [], 0)

class Get_FPGA_Temp_Packet(Packet):
    def __init__(self):
        super().__init__( GET_FPGA_TEMP,1, [], 0)

class Get_Camera_State_Packet(Packet):
    def __init__(self):
        super().__init__( GET_CAMERA_STATE,1, [], 0)

class Read_Register_Packet(Packet):
    def __init__(self, reg_id):
        super().__init__(REG_READ_SYS_CMD ,1,
                         reg_id.to_bytes(4,'little', signed = True),
                         0)

class Write_Register_Packet(Packet):
    def __init__(self, reg_id, reg_val):
        super().__init__(REG_WRITE_SYS_CMD ,1,
                         reg_id.to_bytes(1,'little', signed = False) +
                         reg_val.to_bytes(4,'little', signed = False),
                         0)  

class Reset_Flash_Packet(Packet):
    def __init__(self):
        super().__init__( RESET_FLASH,0, [], 0)  

class Start_Acq_Packet(Packet):
    def __init__(self):
        super().__init__(START_ACQ_SYS_CMD,0, [], 0) 

class Reset_Sys_Packet(Packet):
    def __init__(self, target_reset):
        super().__init__(RESET_SYS_CMD,0, target_reset.to_bytes(1,'little', signed = False), 0)

class Get_Status_Packet(Packet):  
    def __init__(self):
        super().__init__(GET_STATUS_FUNCTION, 1, [], 0)

class Get_Version_Packet(Packet):  
    def __init__(self):
        super().__init__(GET_VERSION_SYS_CMD, 1, [], 0)

class Get_System_Time_Packet(Packet):  
    def __init__(self):
        super().__init__(GET_SYSTEM_TIME_CMD, 1, [], 0)

class Get_PPS_Error_Packet(Packet):  
    def __init__(self):
        super().__init__(GET_PPS_ERROR_CMD, 1, [], 0)

class Get_All_TLM_Packet(Packet): 
    def __init__(self):
        super().__init__(GET_ALL_TLM_CMD, 1, [], 0)

class Update_Net_Address_Packet(Packet):  
    def __init__(self):
        super().__init__(UPDATE_NET_ADDRESS, 1, [], 0)

class Flash_Erase_Sector_Packet(Packet):
    def __init__(self, address ):
        super().__init__( FLASH_ERASE_SECTOR, 1, address.to_bytes(4,'little', signed = False),   0)

class Flash_Erase_Block_Packet(Packet):
    def __init__(self, address ):
        super().__init__( FLASH_ERASE_BLOCK,  1, address.to_bytes(4,'little', signed = False), 0)

class Flash_Write_Page_Packet(Packet):
    def __init__(self, address, packet_data):
        super().__init__(WRITE_FLASH_PAGE, 1, address.to_bytes(4,'little', signed = True) + packet_data, 0)

class Flash_Read_Packet(Packet):
    def __init__(self, address):
        super().__init__(READ_FLASH, 1, address.to_bytes(4,'little', signed = False), 0)

class Set_PPS_Delay_Packet(Packet):
    def __init__(self, delay):
        super().__init__(SET_PPS_DELAY, 1, delay.to_bytes(4, 'little', signed = False), 0)

def Echo():
    Pinterface = PacketInterface(serial_port_name)
    packet = EchoPacket([1,2,3,4,5,6,7,8])
    response = Pinterface.Send(packet)
    return response

def Set_Position(Position: object) -> bytes:
    Pinterface = PacketInterface(serial_port_name)
    packet = Set_Position_Packet( Position )
    response = Pinterface.Send(packet)
    details = Pinterface.ResponseDetails(response)
    error_code = details['error_code']
    return error_code     

def Focus_Sys(Position: object) -> bytes:
    """ Sets focus based on target distance in meters """
    Pinterface = PacketInterface(serial_port_name)
    packet = Focus_Sys_Packet( Position)
    response = Pinterface.Send(packet)
    details = Pinterface.ResponseDetails(response)
    error_code = details['error_code']
    return error_code 

def Set_Mode(Mode: object) -> bytes:
    Pinterface = PacketInterface(serial_port_name)
    packet = Set_Mode_Packet( Mode )
    response = Pinterface.Send(packet)
    details = Pinterface.ResponseDetails(response)
    error_code = details['error_code']
    return error_code

def Transfer_Buffer(index=0, num=TOTAL_FRAME_CAPTURE_AMOUNT) -> bytes:
    if index < 0 or index >= TOTAL_FRAME_CAPTURE_AMOUNT:
        raise ValueError(f"Index must be in [0, {TOTAL_FRAME_CAPTURE_AMOUNT - 1}], got {index}")
    if num < 1 or num > TOTAL_FRAME_CAPTURE_AMOUNT:
        raise ValueError(f"Num must be in [1, {TOTAL_FRAME_CAPTURE_AMOUNT}], got {num}")
    if index + num > TOTAL_FRAME_CAPTURE_AMOUNT:
        raise ValueError(f"Index + num ({index + num}) exceeds total frame count ({TOTAL_FRAME_CAPTURE_AMOUNT})")
    Pinterface = PacketInterface(serial_port_name)
    packet = Transfer_Buffer_Packet(index, num)
    response = Pinterface.Send(packet)
    details = Pinterface.ResponseDetails(response)
    error_code = details['error_code']
    return error_code


def Get_Metadata(index, delay=0.25):
    if index < 0 or index >= TOTAL_FRAME_CAPTURE_AMOUNT:
        raise ValueError(f"Index must be in [0, {TOTAL_FRAME_CAPTURE_AMOUNT - 1}], got {index}")
    Pinterface = PacketInterface(serial_port_name)
    packet = Get_Metadata_Packet(index)
    response = Pinterface.Send(packet)
    details = Pinterface.ResponseDetails(response)
    data = details['data']

    metadata_endian = 'little'

    start_flag = int.from_bytes(data[0:4],metadata_endian)
    size_bytes = int.from_bytes(data[4:8],metadata_endian)
    sensor_readout_format = int.from_bytes(data[8:12],metadata_endian)
    sensor_read_dir = int.from_bytes(data[12:16],metadata_endian)
    sensor_bit_depth = int.from_bytes(data[16:20],metadata_endian)
    sensor_gain = int.from_bytes(data[20:24],metadata_endian)
    sensor_blo = int.from_bytes(data[24:28],metadata_endian)
    sensor_exposure_usec= int.from_bytes(data[28:32],metadata_endian)
    sensor_trig_mode = int.from_bytes(data[32:36],metadata_endian)
    sensor_temp_raw = int.from_bytes(data[36:40],metadata_endian)
    buff_write_index = int.from_bytes(data[40:44],metadata_endian)
    req_focus_dist = int.from_bytes(data[44:48],metadata_endian)
    comp_focus_dist = int.from_bytes(data[48:52],metadata_endian)
    lvdt_pos = int.from_bytes(data[52:56],metadata_endian)
    timestamp_sec = int.from_bytes(data[56:60],metadata_endian)
    timestamp_nsec = int.from_bytes(data[60:64],metadata_endian)
    version = int.from_bytes(data[64:68],metadata_endian)
    reserved1 = int.from_bytes(data[68:72],metadata_endian)
    reserved2 = int.from_bytes(data[72:76],metadata_endian)
    crc = int.from_bytes(data[76:80],metadata_endian)


    return {
        "METADATA_START_FLAG" : start_flag,
        "METADATA_SIZE_BYTES" : size_bytes,
        "SENSOR_PXL_READOUT_FORMAT": sensor_readout_format,
        "SENSOR_READ_DIR" : sensor_read_dir,
        "SENSOR_BIT_DEPTH" : sensor_bit_depth,
        "SENSOR_GAIN" : sensor_gain,
        "SENSOR_BLO" : sensor_blo,
        "SENSOR_EXPO_USEC" : sensor_exposure_usec,
        "SENSOR_TRIG_MODE" : sensor_trig_mode ,
        "SENSOR_TEMP_RAW" : sensor_temp_raw,
        "BUFF_WRITE_INDEX" : buff_write_index,
        "FOCUS_REQ_DIST_M" : req_focus_dist,
        "FOCUS_COMP_DIST_M" : comp_focus_dist,
        "FOCUS_LVDT_POS_NM" : lvdt_pos,
        "TIMESTAMP_UNIX_EPOCH_SEC" : timestamp_sec,
        "TIMESTAMP_SUBSEC_NSEC" : timestamp_nsec ,
        "VERSION" : version,
        "RESERVED_PADDING0" : reserved1,
        "RESERVED_PADDING1" : reserved2,
        "METADATA_CRC32" : crc
    }


def Write_Register(id, value) -> bytes:
    Pinterface = PacketInterface(serial_port_name)
    packet = Write_Register_Packet(id, value)
    response = Pinterface.Send(packet)
    details = Pinterface.ResponseDetails(response)
    error_code = details['error_code']
    return error_code

def Read_Register(id) -> bytes:
    Pinterface = PacketInterface(serial_port_name)
    packet = Read_Register_Packet(id)
    response = Pinterface.Send(packet)
    details = Pinterface.ResponseDetails(response)
    error_code = details['error_code']
    data = details['data']
    value = int.from_bytes(data[0:4], 'little', signed=True)
    return value

def Set_LVDT_Offset(Offset):
    Pinterface = PacketInterface(serial_port_name)
    packet = Set_LVDT_Offset_Packet(Offset)   
    response = Pinterface.Send(packet)
    return response   

def Set_Sys_Time(Time_Sec):
    Pinterface = PacketInterface(serial_port_name)
    packet = Set_Sys_Time_Packet(Time_Sec)   
    response = Pinterface.Send(packet)
    return response 

def Get_TLM_Reading(sensor):
    Pinterface = PacketInterface(serial_port_name)
    packet = Get_TLM_Reading_Packet(sensor)
    response = Pinterface.Send(packet)
    details = Pinterface.ResponseDetails(response)
    error_code = details['error_code']
    data = details['data']
    value = int.from_bytes(data[0:4], 'little', signed=True)
    return value

def Zero():
    """Moves focus mechanism to the electrical zero of the LVDT. This does not
    depend on any calibration"""
    Pinterface = PacketInterface(serial_port_name)
    packet = ZeroPacket();
    response = Pinterface.Send(packet)
    return response

def Start_Acq():
    """Commands camera to take a picture. Camera must be in armed state"""
    Pinterface = PacketInterface(serial_port_name)
    packet = Start_Acq_Packet();
    response = Pinterface.Send(packet)
    details = Pinterface.ResponseDetails(response)
    error_code = details['error_code']
    return error_code

def Reset():
    """Resets the focus mechanism"""
    return Reset_Sys(RESET_FOCUS_MECH)

def Reset_Frame_Index():
    """Resets the frame index"""
    return Reset_Sys(RESET_MEM_BUFF)

def Reset_Flash():
    Pinterface = PacketInterface(serial_port_name)
    packet = Reset_Flash_Packet()
    response = Pinterface.Send(packet)
    return response 

def Reset_Sys(target_reset = RESET_ALL):
    """Commands a reset of the subsystems selected by the target_reset bit field.

    Bit 0 (RESET_CAM_SENSOR) - reset the camera and imaging sensor
    Bit 1 (RESET_FOCUS_MECH) - reset the focus mechanism
    Bit 2 (RESET_REG_SPACE)  - restore all registers to default values
    Bit 3 (RESET_MEM_BUFF)   - reset the image frame buffer index to 0
    """
    Pinterface = PacketInterface(serial_port_name)
    packet = Reset_Sys_Packet(target_reset)
    response = Pinterface.Send(packet)
    return response

def Get_Status():
    """Returns triple (position-microns, velocity microns/sec * 10, fault status)"""
    Pinterface = PacketInterface(serial_port_name)
    packet = Get_Status_Packet()
    response = Pinterface.Send(packet)
    details =  Pinterface.ResponseDetails(response)
    data = details['data']
    position = int.from_bytes( data[0:4], 'little', signed=True)
    velocity = int.from_bytes( data[4:8], 'little', signed=True)
    fault_status = int.from_bytes( data[8:9], 'little', signed=True)
    return position, velocity, fault_status


def Get_System_Time():
    """Returns triple (position-microns, velocity microns/sec * 10, fault status)"""
    Pinterface = PacketInterface(serial_port_name)
    packet = Get_System_Time_Packet()
    response = Pinterface.Send(packet)
    details =  Pinterface.ResponseDetails(response)
    data = details['data']
    time_sec = int.from_bytes( data[0:4], 'little', signed=False)
    time_nsec = int.from_bytes( data[4:8], 'little', signed=False)
    return time_sec, time_nsec

def Get_Version():
    """Returns dict with PF FPGA version/git hash/build time, PA3 FPGA version,
       software version, FAV device ID and sensor ID"""
    Pinterface = PacketInterface(serial_port_name)
    packet = Get_Version_Packet()
    response = Pinterface.Send(packet)
    details =  Pinterface.ResponseDetails(response)
    data = details['data']
    pf_fpga_version    = int.from_bytes( data[0:4],   'little', signed=False)
    pf_fpga_git_hash   = int.from_bytes( data[4:8],   'little', signed=False)
    pf_fpga_build_time = int.from_bytes( data[8:12],  'little', signed=False)
    pa3_fpga_version   = int.from_bytes( data[12:16], 'little', signed=False)
    pf_fw_version      = int.from_bytes( data[16:20], 'little', signed=False)
    fav_device_id      = int.from_bytes( data[20:24], 'little', signed=False)
    sensor_id          = int.from_bytes( data[24:28], 'little', signed=False)
    return { 'pf_fpga_version'    : f"0x{pf_fpga_version:08X}",
             'pf_fpga_git_hash'   : f"0x{pf_fpga_git_hash:08X}",
             'pf_fpga_build_time' : datetime.utcfromtimestamp(pf_fpga_build_time).strftime('%Y-%m-%d %H:%M:%S UTC'),
             'pa3_fpga_version'   : f"0x{pa3_fpga_version:08X}",
             'pf_fw_version'      : f"0x{pf_fw_version:08X}",
             'fav_device_id'      : f"0x{fav_device_id:08X}",
             'sensor_id'          : f"0x{sensor_id:08X}" }

def Get_PPS_Errors():
    """Returns triple (position-microns, velocity microns/sec * 10, fault status)"""
    Pinterface = PacketInterface(serial_port_name)
    packet = Get_PPS_Error_Packet()
    response = Pinterface.Send(packet)
    details =  Pinterface.ResponseDetails(response)
    data = details['data']
    freq_error = int.from_bytes( data[0:4], 'little', signed=True)
    phase_error = int.from_bytes( data[4:8], 'little', signed=True)
    return freq_error, phase_error

def Get_All_TLM():
    Pinterface = PacketInterface(serial_port_name)
    packet = Get_All_TLM_Packet()
    response = Pinterface.Send(packet)
    details =  Pinterface.ResponseDetails(response)
    data = details['data']
    reading = []
    for n in range(48):
        reading.append( int.from_bytes( data[2*n:2*n+2], 'little', signed=False) )
    return reading

def Get_Position():  
    """Returns position (microns)"""
    Pinterface = PacketInterface(serial_port_name)
    packet = Get_Position_Packet()
    response = Pinterface.Send(packet)
    details =  Pinterface.ResponseDetails(response)
    data = details['data']
    return int.from_bytes(data, 'little', signed=True)

def  Get_Camera_Temp():  
    """Returns position (microns)"""
    Pinterface = PacketInterface(serial_port_name)
    packet = Get_Camera_Temp_Packet()
    response = Pinterface.Send(packet)
    details =  Pinterface.ResponseDetails(response)
    data = details['data']
    temp_val = int.from_bytes(data, 'little', signed=True)
    if temp_val == 0xFF:
        tempC = -100.0
    else:
        tempC =(float(temp_val) - 51.784)/1.3125
    return tempC

def  Get_FPGA_Temp():  
    """Returns position (microns)"""
    Pinterface = PacketInterface(serial_port_name)
    packet = Get_FPGA_Temp_Packet()
    response = Pinterface.Send(packet)
    details =  Pinterface.ResponseDetails(response)
    data = details['data']
    return int.from_bytes(data, 'little', signed=True) - 273

def  Get_Camera_State():  
    """Returns position (microns)"""
    Pinterface = PacketInterface(serial_port_name)
    packet = Get_Camera_State_Packet()
    response = Pinterface.Send(packet)
    details =  Pinterface.ResponseDetails(response)
    data = details['data']
    return int.from_bytes(data, 'little', signed=True)

def Get_Projection():
    """Reads projection of secondary response (complex) onto primary (complex). This is equivalent to
    Re{S/P}"""
    Pinterface = PacketInterface(serial_port_name)
    packet = Get_Projection_Packet()
    response = Pinterface.Send(packet)
    details = Pinterface.ResponseDetails(response)
    data = details['data']
    return int.from_bytes(data, 'little', signed=True)

def Sweep_Projection():
    while True:
        proj = Get_Projection()
        print(f"proj = {proj}")
        time.sleep(1)

def Read_Register(reg_id):
    """Reads register through TMTC interface """
    Pinterface = PacketInterface(serial_port_name)
    packet = Read_Register_Packet(reg_id)
    response = Pinterface.Send(packet)
    details = Pinterface.ResponseDetails(response)
    data = details['data']
    return int.from_bytes(data, 'little', signed=False)    

def Update_Net_Address():
    """Updates the network address using latest from registers"""
    Pinterface = PacketInterface(serial_port_name)
    packet = Update_Net_Address_Packet()
    response = Pinterface.Send(packet)
    return response   

def  Flash_Write_Page(address, packet_data):
    Pinterface = PacketInterface(serial_port_name, timeout=0.010 )
    packet = Flash_Write_Page_Packet(address, packet_data)
    response = Pinterface.Send(packet)
    return response

def Read_Flash(address):
    Pinterface = PacketInterface(serial_port_name, timeout = 0.25)
    packet = Flash_Read_Packet(address)
    response = Pinterface.Send(packet)
    details = Pinterface.ResponseDetails(response)
    data = details['data']
    return data   

#register based operations

def Set_Gain(value):
    error_code = Write_Register(GAIN_REG, value)
    return error_code

def Set_BLO(value):
    error_code = Write_Register(BLO_REG, value)
    return error_code

def Set_Exp(value):
    error_code = Write_Register(EXPOSURE_REG, value)
    return error_code

def Set_Pattern_Gen(value):
    """1 turns the sensor's test pattern generator on, 0 turns it off. Only writable in
       idle or armed mode."""
    error_code = Write_Register(EN_PATTERN_GEN_REG, value)
    return error_code

def Set_SRC_MAC(mac_address):
    """assumes mac address is list with 6 elements 0-255"""
    mac_length = len(mac_address)
    mac_msb = bytearray(mac_address[0:2])
    mac_lsb = bytearray(mac_address[2:mac_length])
    mac_msb_i = int.from_bytes(mac_msb, 'big', signed=False )
    mac_lsb_i = int.from_bytes(mac_lsb, 'big', signed=False)
    Write_Register(SRC_MAC_ADDRESS_0_3_SYS_REG, mac_lsb_i )
    Write_Register(SRC_MAC_ADDRESS_4_5_SYS_REG, mac_msb_i )

def Set_DST_MAC(mac_address):
    """assumes mac address is list with 6 elements 0-255"""
    mac_length = len(mac_address)
    mac_msb = bytearray(mac_address[0:2])
    mac_lsb = bytearray(mac_address[2:mac_length])
    mac_msb_i = int.from_bytes(mac_msb, 'big',signed=False)
    mac_lsb_i = int.from_bytes(mac_lsb, 'big',signed=False)
    # print(mac_address)
    # print(f"mac_msb_i = {mac_msb_i:x}")
    # print(f"mac_lsb_i = {mac_lsb_i:x}")
    Write_Register(DST_MAC_ADDRESS_0_3_SYS_REG, mac_lsb_i )
    Write_Register(DST_MAC_ADDRESS_4_5_SYS_REG, mac_msb_i )

def Set_SRC_IP(ip_address):
    """Argument is list of 4 numbers in range 0-255"""
    ip_length = len(ip_address)
    src_ip = (ip_address[0] << 24 |
             ip_address[1] << 16 |
             ip_address[2] << 8 |
             ip_address[3]) & 0xffffffff
    Write_Register(SRC_IP_ADDRESS_SYS_REG, src_ip )

def Set_DST_IP(ip_address):
    """Argument is list of 4 numbers in range 0-255"""
    ip_length = len(ip_address)
    dst_ip = (ip_address[0] << 24 |
              ip_address[1] << 16 |
              ip_address[2] << 8 |
              ip_address[3]) & 0xffffffff
    Write_Register(DST_IP_ADDRESS_SYS_REG , dst_ip )

def Set_SRC_Por(Port):
    """Argument is number in range 0-65536"""
    Write_Register(SRC_PORT_SYS_REG, Port & 0xffff )

def Set_DST_Port(Port):
    """Argument is number in range 0-65536"""
    Write_Register(DST_PORT_SYS_REG, Port & 0xffff )

#Flash related
def Flash_Erase_Sector(address):
    Pinterface = PacketInterface(serial_port_name)
    packet = Flash_Erase_Sector_Packet(address)
    response = Pinterface.Send(packet)
    details = Pinterface.ResponseDetails(response)
    error_code = details['error_code']
    return error_code

def Flash_Erase_Block(block_address):
    """Erases flash block - the block number 0-126 is converted to address on board"""
    Pinterface = PacketInterface(serial_port_name)
    packet = Flash_Erase_Block_Packet(block_address)
    response = Pinterface.Send(packet)
    details = Pinterface.ResponseDetails(response)
    error_code = details['error_code']
    return error_code

def Get_64K_Flash_Block_Address(block_number):
    """Returns the address of the 64K block by number"""
    if block_number < 0 or block_number > 125:
        raise ValueError("flash block number must be less than 126")
    return 0x10000 + (block_number << 16)

def Get_32K_Flash_Block_Address(block_number):
    """Returns the address of the 32K block by number"""
    if block_number < 0 or block_number > 1:
        raise ValueError("flash block number must be 0 <= n < 2" )
    if block_number == 0:
        return 0x8000
    else:
        return 0x7F0000

def Get_8K_Flash_Block_Address(block_number):
    """Returns the address of the 8K block by number"""
    if block_number < 0  or block_number > 7:
        raise ValueError("flash block number must be 0 <= n < 7")
    if block_number < 4:
        return 0x0000 + (block_number << 13)
    else:
        return 0x7F8000 + (block_number << 13)

def Write_File_To_Flash( filename, block_number ):
    """Writes contents of file to a 64K block"""
    address = Get_64K_Flash_Block_Address(block_number)
    #do block erase on block
    Flash_Erase_Block(address)
    with open(filename, "rb") as file:
        file_data = file.read() # Reads the entire file into memory
        bytes_remaining = len(file_data)
        logging.debug(f"file length = {bytes_remaining}")
        index = 0
        while bytes_remaining > 0:
            logging.debug(f"Writing 128 byte block from offset {index}")
            write_data = file_data[index:index+128]
            Flash_Write_Page(address+index, write_data)
            index = index + 128
            bytes_remaining = bytes_remaining - 128

def Save_Flash_To_File( filename, block_address, size):
    with open(filename, "wb") as file:
        logging.debug(f"saving {size} bytes to file {filename}")
        logging.debug(f"starting address = {block_address}")
        bytes_remaining = size
        logging.debug(f"file length = {bytes_remaining}")
        index = 0
        while bytes_remaining > 0:
            logging.debug(f"Writing 128 byte block from offset {index}")
            read_data = Read_Flash(block_address+index)
            file.write(read_data)
            index = index + 128
            bytes_remaining = bytes_remaining - 128

# Logging
def Init_Log_File(log_filename ="screen"):
    """Starts log file either to disk or to console"""
    if log_filename == "screen":
            logging.basicConfig( level=logging.DEBUG, format = "{asctime} - {levelname} - {message}",
                         style = "{",
                         datefmt = "%Y-%m-%d %H:%M:%S",)
    else:
        logging.basicConfig( filename=log_filename,
                       level=logging.DEBUG, format = "{asctime} - {levelname} - {message}",
                        style = "{",
                        datefmt = "%Y-%m-%d %H:%M:%S",)

if len(sys.argv) > 1:
    serial_port_name = sys.argv[1]
else:
    serial_port_name = '/dev/ttyUSB0'
                                                                                                       
def Set_Serial_Port(name):
    serial_port_name = name

def Net_Setup():
    src_mac_address = bytearray([0x00, 0x04, 0xA3, 0x12, 0x34, 0x56])
    dst_mac_address = bytearray([0x90, 0x2e, 0x16, 0xd7, 0xda, 0x08])
    # dst_mac_address = bytearray([0xc4, 0xcb, 0xe1, 0x3a, 0x62, 0xb8])
    src_ip_address = [10, 101, 48, 192]
    dst_ip_address = [10, 101, 48, 53]
    dst_port = 0x8931
    src_port = 0x04d2
    Set_SRC_MAC(src_mac_address)
    Set_DST_MAC(dst_mac_address)
    Set_SRC_IP(src_ip_address)
    Set_DST_IP(dst_ip_address)
    Set_SRC_Por(src_port)
    Set_DST_Port(dst_port)
    Update_Net_Address()

def Set_PPS_Delay(delay):
    Pinterface = PacketInterface(serial_port_name)
    packet = Set_PPS_Delay_Packet(delay)  
    response = Pinterface.Send(packet)
    return response 

def Set_Capture_Time(time_sec, time_msec):
    """Programs the scheduled capture time registers. Only used when the trigger
    mode is PPS (1). The armed state reads these when Start_Acq is issued."""
    Write_Register( CAPTURE_TIME_SEC_SYS_REG, time_sec )
    Write_Register( CAPTURE_TIME_MSEC_SYS_REG, time_msec )


def Test(n_iterations):
    """This runs back and forth between -800 and 800 microns n_iterations times"""
    logging.debug("zeroing")
    start_time = datetime.now()
    Zero()
    time.sleep(1)
    status = Get_Status()
    time.sleep(0.5)
    while status[1] != 0:
        status = Get_Status()
        time.sleep(1)
    end_time = datetime.now()
    elapsed_time = end_time - start_time
    logging.debug(f"Elapsed time is {elapsed_time}")
    final_position = status[0]
    logging.debug(f"Final Position: {final_position}")
    logging.debug("Beginning")
    for n in range(1,n_iterations):
        logging.debug(f"Test {n}")
        logging.debug(f"Moving to {800}")
        start_time = datetime.now()
        logging.debug(f"Start time is {start_time}")
        Set_Position(800)
        time.sleep(1)
        status = Get_Status()
        while status[1] == 0:         #allow it to get moving
            status = Get_Status()
            time.sleep(0.5)
        while status[1] != 0:
            status = Get_Status()
            time.sleep(0.5)
        final_position = status[0]
        end_time = datetime.now()
        elapsed_time = end_time - start_time
        logging.debug(f"Elapsed time is {elapsed_time}")
        logging.debug(f"Final Position: {final_position}")
        logging.debug("---------------------------------------------------")
        time.sleep(1)
        logging.debug(f"Moving to {-800}")
        start_time = datetime.now()
        logging.debug(f"Start time is {start_time}")
        Set_Position(-800)
        time.sleep(1.0)
        status = Get_Status()
        while status[1] == 0:         #allow it to get moving
            status = Get_Status()
            time.sleep(0.5)
        while status[1] != 0:
            status = Get_Status()
            time.sleep(0.5)
        final_position = status[0]
        end_time = datetime.now()
        elapsed_time = end_time - start_time
        logging.debug(f"Elapsed time is {elapsed_time}")
        logging.debug(f"Final Position: {final_position}")
        logging.debug("---------------------------------------------------")

def Randomize(n_iterations):
    """Moves to randomly chosen locations (microns) between -800 and 800 n_iterations times"""
    logging.debug("Running random tests")
    logging.debug("zeroing")
    start_time = datetime.now()
    Zero()
    time.sleep(1)
    status = Get_Status()
    time.sleep(0.5)
    while status[1] != 0:
        status = Get_Status()
        time.sleep(1)
    end_time = datetime.now()
    elapsed_time = end_time - start_time
    logging.debug(f"Elapsed time is {elapsed_time}")
    final_position = status[0]
    logging.debug(f"Final Position: {final_position}")
    logging.debug("Beginning")
    for n in range(1,n_iterations):
        logging.debug(f"Test {n}")
        start_time = datetime.now()
        logging.debug(f"Start time is {start_time}")
        new_location = random.randint(-800, 800)
        logging.debug(f"Moving to {new_location}")
        Set_Position(new_location)
        time.sleep(1)
        status = Get_Status()
        time.sleep(0.5)
        while status[1] != 0:
            status = Get_Status()
        final_position = status[0]
        end_time = datetime.now()
        elapsed_time = end_time - start_time
        logging.debug(f"Elapsed time is {elapsed_time}")
        logging.debug(f"Final Position: {final_position}")
        logging.debug("---------------------------------------------------")
        time.sleep(1)

default_camera_gain = 0   
default_camera_blo = 0   

def Set_Trigger_Mode(trigger_mode = 0):
    Write_Register( TRIGGER_MODE_SELECT_REG, trigger_mode )


def Camera_Setup(images_per_trigger=1, trigger_mode=0):
    """Goes through states for camera in ICD, takes single picture and sends through UDP."""
    logging.debug(f"Starting camera test - powering down camera")
    time.sleep(1.0)

    Net_Setup()
    time.sleep(1.0)

    Set_Mode(1) # Power down camera
    time.sleep(2.0)
    logging.debug(f"Setting camera params")
    Write_Register(GAIN_REG, default_camera_gain)
    Write_Register(BLO_REG, default_camera_blo)
    Write_Register(EXPOSURE_REG, 50)

    Write_Register( IMG_PER_TRIGGER_SYS_REG, images_per_trigger )
    Write_Register( FRAME_CAPTURE_TIME_SYS_REG, 20000)

    logging.debug(f"Setting camera trigger mode to {trigger_mode}")
    Write_Register( TRIGGER_MODE_SELECT_REG, trigger_mode )

    logging.debug(f"Powering up camera")
    Set_Mode(2)
    Reset_Frame_Index()
    time.sleep(10.0)


    logging.debug(f"Configuring network registers")
    # Write_Register(SRC_MAC_ADDRESS_0_3_SYS_REG, 0xA3123456)
    # Write_Register(SRC_MAC_ADDRESS_4_5_SYS_REG, 0x0004)
    # Write_Register(DST_MAC_ADDRESS_0_3_SYS_REG, 0xC25649ED)
    # Write_Register(DST_MAC_ADDRESS_4_5_SYS_REG, 0x88A4)
    # Write_Register(SRC_IP_ADDRESS_SYS_REG, (10 << 24) | (101 << 16) | (15 << 8) | 192)
    # Write_Register(DST_IP_ADDRESS_SYS_REG, (10 << 24) | (101 << 16) | (15 << 8) | 195)
    # Write_Register(SRC_PORT_SYS_REG, 0x04D2)
    # Write_Register(DST_PORT_SYS_REG, 0x8931)
    Net_Setup()
    Update_Net_Address()

    logging.debug(f"Setting camera mode to armed")
    Set_Mode(4)
    time.sleep(5.0)

def Take_Picture():
        Start_Acq()
        time.sleep(2)

def  Read_TLMs():
    """This retrieves all 48 TLM values at once and returns an array of 16 bit raw counts
    as the TLM channels are still uncalibrated"""
    for n in range(0, 48):
        reading = Get_TLM_Reading(n)
        print(f"TLM({n}) = {reading}")
        time.sleep(0.1)

def Test_PPS_Camera():
    """This tests timed captures using the external PPS input. The system time
    is synchronized and set to 0 and a capture is scheduled 5 seconds into the future"""
    logging.debug(f"Initializing local clock to 0 sec, o nsec")
    Set_Sys_Time(0,0)
    Camera_Setup(images_per_trigger=500, trigger_mode=1)
    current_tsec, current_tmsec = Get_System_Time()
    capture_tsec = current_tsec + 10
    capture_tmsec = current_tmsec
    Set_Capture_Time(capture_tsec, capture_tmsec)

    logging.debug(f"Current time is {current_tsec} sec {current_tmsec} nsec")
    logging.debug(f"Programming capture time {capture_tsec} sec {capture_tmsec} nsec")

MAX_HIGH_GAIN_POINTS = 12
MAX_LO_GAIN_POINTS  =  25
LVDT_CAL_OFFSET  =   64
MOTION_CAL_OFFSET = 600
TLM_CAL_OFFSET  =  728

class Calibration:
    def __init__(self):
        self.data = bytearray(2048)
        self.index = 0
        self.cal_version= 3
    def Add_Int(self,x):
        x = int(x)
        self.data[self.index:self.index+4] = x.to_bytes(4, byteorder='little', signed=True)
        self.index += 4
    def Add_Float(self, x):
        self.data[self.index:self.index+4] = bytearray(struct.pack('f', x))
        self.index += 4
    def Add_Reserved(self, n):
        self.index += n
    def Read_LVDT(self, filename):
        self.lvdt_frame = pd.read_excel(filename, sheet_name='LVDT') 

        #High Gain (8) points
        self.D_G8 = self.lvdt_frame['Displacement_G8']
        self.D_G8 = [x for x in self.D_G8 if not math.isnan(x)]

        self.lvdt_n_high_gain_pts = len(self.D_G8)
        logging.debug(f"Number high gain points found = {self.lvdt_n_high_gain_pts}")

        self.P_G8 = self.lvdt_frame['Projection_G8']
        self.P_G8 = [x for x in self.P_G8 if not math.isnan(x)]

        if len(self.D_G8) > MAX_HIGH_GAIN_POINTS:
            raise ValueError(f"LVDT:The number of high gain points must be no more than {MAX_HIGH_GAIN_POINTS}")

        #low gain (1) points
        self.D_G1 = self.lvdt_frame['Displacement_G1']
        self.D_G1 = [x for x in self.D_G1 if not math.isnan(x)]

        if len(self.D_G1) > MAX_LO_GAIN_POINTS:
            raise ValueError(f"LVDT:The number of low gain points must be no more than {MAX_LO_GAIN_POINTS}")

        self.lvdt_n_low_gain_pts = len(self.D_G1)

        self.P_G1 = self.lvdt_frame['Projection_G1']
        self.P_G1 = [x for x in self.P_G1 if not math.isnan(x)]

    def Read_Motion(self, filename):
        self.motion_frame = pd.read_excel(filename, index_col=0, sheet_name='Motion') 
        self.Deadband_microns = self.motion_frame.at['Deadband_microns', 'Value']
        self.Deadband_Hyst_Count = self.motion_frame.at['Deadband_Hyst_Count', 'Value']
        self.Soft_Limit_microns = self.motion_frame.at['Soft_Limit_microns', 'Value']
        self.Fault_Timeout_ms = self.motion_frame.at['Fault_Timeout_ms', 'Value']
        self.Fine_Focus_Speed = self.motion_frame.at['Fine_Focus_Speed', 'Value']
        self.Fine_Focus_Threshold_microns = self.motion_frame.at['Fine_Focus_Threshold_microns', 'Value']
        self.Coarse_Focus_Speed = self.motion_frame.at['Coarse_Focus_Speed', 'Value']
        self.Coarse_Zero_Speed = self.motion_frame.at['Coarse_Zero_Speed', 'Value']
        self.Fine_Zero_Speed = self.motion_frame.at['Fine_Zero_Speed', 'Value']
        self.Coarse_Fine_Proj_Threshold = self.motion_frame.at['Coarse_Fine_Proj_Threshold', 'Value']
        self.u32_Motion_Sense = self.motion_frame.at['Motion_Sense', 'Value']


    def Read_TLM(self, filename):
        self.TLM_Frame = pd.read_excel(filename, sheet_name='TLM')
        self.TLM_Gain = self.TLM_Frame['Gain']
        self.TLM_Gain = [float(x) for x in self.TLM_Gain]

        self.TLM_Offset = self.TLM_Frame['Offset']
        self.TLM_Offset = [float(x) for x in self.TLM_Offset]

    def Make_Bytearray(self):
        #Version
        self.index = 0
        self.Add_Int(self.cal_version)
        logging.debug(f"Cal version = {self.cal_version}")
        #reserved for future expansion

        #LVDT section
        self.index = LVDT_CAL_OFFSET
        #LVDT
        logging.debug(f"LVDT Index = {self.index:x}")
        self.Add_Int(self.lvdt_n_high_gain_pts)
        logging.debug(f"LVDT:High Gain Pts = {self.lvdt_n_high_gain_pts}")
        self.Add_Int(self.lvdt_n_low_gain_pts)
        logging.debug(f"LVDT:Low Gain Pts = {self.lvdt_n_low_gain_pts}")

        #High gain points for small displacements
        for n in range(self.lvdt_n_high_gain_pts):
            self.Add_Float(self.D_G8[n])
            self.Add_Int(int(self.P_G8[n]))
            logging.debug(f"LVDT:H:D={self.D_G8[n]} P={self.P_G8[n]}")

        #zero unused entries
        for n in range(MAX_HIGH_GAIN_POINTS-self.lvdt_n_high_gain_pts): #pad this so offsets are correct
            self.Add_Int(0)
            self.Add_Int(0)

        #low gain points for larger displacements
        for n in range(self.lvdt_n_low_gain_pts):
            self.Add_Float(self.D_G1[n])
            self.Add_Int(int(self.P_G1[n]))
            logging.debug(f"LVDT:L:D={self.D_G1[n]} P={self.P_G1[n]}")

        #zero unused entries
        for n in range(MAX_LO_GAIN_POINTS-self.lvdt_n_low_gain_pts): #pad this so offsets are correct
            self.Add_Int(0)
            self.Add_Int(0)

        #Focus mechanism motion section
        self.index = MOTION_CAL_OFFSET

        logging.debug(f"Motion index = {self.index:x}")
        self.Add_Int(self.Deadband_microns)
        logging.debug(f"Deadband = {self.Deadband_microns}")

        self.Add_Int(self.Deadband_Hyst_Count)
        logging.debug(f"Hysteresis count = {self.Deadband_Hyst_Count}")

        self.Add_Int(self.Soft_Limit_microns)
        logging.debug(f"Soft limit = {self.Soft_Limit_microns}")

        self.Add_Int(self.Fault_Timeout_ms)
        logging.debug(f"Fault timeout = {self.Fault_Timeout_ms}")

        self.Add_Int(self.Fine_Focus_Speed )
        logging.debug(f"Fine focus speed = {self.Fine_Focus_Speed}")

        self.Add_Int(self.Fine_Focus_Threshold_microns)
        logging.debug(f"Fine focus threshold = {self.Fine_Focus_Threshold_microns}")

        self.Add_Int(self.Coarse_Focus_Speed)
        logging.debug(f"Coarse focus speed = {self.Coarse_Focus_Speed}")

        self.Add_Int(self.Coarse_Zero_Speed)
        logging.debug(f"Coarse zero speed = {self.Coarse_Zero_Speed}")

        self.Add_Int(self.Fine_Zero_Speed)
        logging.debug(f"Fine zero speed = {self.Fine_Zero_Speed}")

        self.Add_Int(self.Coarse_Fine_Proj_Threshold)
        logging.debug(f"Coarse/fine projection threshold for zero = {self.Coarse_Fine_Proj_Threshold}")

        self.Add_Int(self.u32_Motion_Sense)      
        logging.debug(f"Convention for motion direction = {self.u32_Motion_Sense}")
    

        #TLM
        self.index = TLM_CAL_OFFSET
        logging.debug(f"TLM index = {self.index:x}")
        for n in range(len(self.TLM_Gain)):
            self.Add_Float(self.TLM_Gain[n])
            self.Add_Float(self.TLM_Offset[n])

    def Save_to_File(self, filename ):
        with open(filename, "wb") as file:
            bytes_remaining = 2048
            index = 0
            while bytes_remaining > 0:
                write_data = self.data[index:index+128]
                file.write(write_data)
                index = index + 128
                bytes_remaining = bytes_remaining - 128

    def Write_Flash(self):
        flash_address = Get_8K_Flash_Block_Address(1)
        logging.debug(f"Writing to flash address {flash_address:x}")
        Flash_Erase_Block(flash_address)
        time.sleep(1.0)
        bytes_remaining = 2048
        index = 0
        while bytes_remaining > 0:
            logging.debug(f"Writing 128 byte block from offset {index}")
            write_data = self.data[index:index+128]
            Flash_Write_Page(flash_address+index, write_data)
            index = index + 128
            bytes_remaining = bytes_remaining - 128

def Install_Application(binary_filename, block_number):
    if block_number < 0 or block_number > 125:
        raise ValueError("64K blocks must be between 0 and 125")
    logging.debug(f"writing file {binary_filename} to 64K block:{block_number}")
    app_size_bytes = Write_File_To_Flash( binary_filename, block_number )
    md = Metadata()
    md.add_application(binary_filename, block_number)
    md.update_flash()

def create_cal_file(spreadsheet_file, output_file):
    cal=Calibration()
    cal.Read_LVDT(spreadsheet_file)
    cal.Read_Motion(spreadsheet_file)
    cal.Read_TLM(spreadsheet_file)
    cal.Make_Bytearray()
    cal.Save_to_File(output_file)

def Update_Calibration(filename):
     with open(filename, "rb") as file:
        flash_address = Get_8K_Flash_Block_Address(1) #Cal data always goes in 8K sector(1)
        cal_data = file.read()
        if len(cal_data) != 2048:
            raise ValueError("Cal file must be 2048 bytes")
        logging.debug(f"Writing 2048 bytes to cal block - address 0x{flash_address:x}")
        bytes_remaining = 2048
        offset = 0
        Flash_Erase_Block(flash_address)
        while bytes_remaining > 0:
            write_data = cal_data[offset:offset+128]
            Flash_Write_Page(flash_address+offset, write_data)
            bytes_remaining -= 128
            offset += 128

CAL_FILE = "installation/cal_3d.bin"
EXECUTABLE_FILE = "installation/Camera.bin"
INSTALL_BLOCK = 4

def New_Board(): 
    """ This assumes that the appropriate bootloader has been built into the bitstream. This installs the chosen calibration (depending 
on the focus mechanism being used) and the application firmware. The metadata is updated"""
    logging.debug("Installing application")
    Install_Application(EXECUTABLE_FILE, INSTALL_BLOCK)
    logging.debug("Updating calibrations")
    Update_Calibration(CAL_FILE)

class Metadata():                   #For now, convention is that metadata will go in 1st 8K block
    def __init__(self ):
        self.data = bytearray(128)
        self.offset = 0
        self.crc = CRC_32()
    def add_application( self, filename, app_flash_block_number ):
        try:
            with open(filename, "rb") as file:
                app_data = file.read()
        except FileNotFoundError:
            logging.debug("Error: The file does not exist.")
        except PermissionError:
            logging.debug("Error: You do not have permission to access this file.")
        except OSError as e:
            logging.debug(f"An OS-level error occurred: {e}")

        app_size_bytes = len(app_data)
        logging.debug(f"App size = {app_size_bytes}")

        flash_address = Get_64K_Flash_Block_Address( app_flash_block_number )
        logging.debug(f"Flash address block[{app_flash_block_number}] = 0x{flash_address:x}")

        crc_check  = self.crc.check(app_data, 0)
        logging.debug(f"crc = 0x{crc_check:x}")

        self.data[self.offset:self.offset+4] = flash_address.to_bytes(4, byteorder='little')
        self.data[self.offset+4:self.offset+8] = app_size_bytes.to_bytes(4, byteorder='little')
        self.data[self.offset+8:self.offset+12] = crc_check.to_bytes(4, byteorder='little')
        self.offset += 12

    def update_flash(self): #implication is that metadata is always in the first 8K block
        Flash_Erase_Block( 0 )
        Flash_Write_Page( 0, self.data)
    
Init_Log_File()

if __name__ == '__main__':
    error_code = Echo()







