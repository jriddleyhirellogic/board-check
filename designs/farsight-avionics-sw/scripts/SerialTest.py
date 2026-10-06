import logging
import serial
import array as arr
import sys
import time
from datetime import datetime
import random


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
RESET_BUFF_SYS_CMD = 0x0B
GET_INFO_SYS_CMD = 0x0C
CONF_EVENT_LOG_SYS_CMD = 0x0D
EN_TL_CHAN_LOG_SYS_CMD = 0x0E
XFER_LOG_SYS_CMD = 0x0F
RESET_FRAME_INDEX=0x10

#User defined to support debug and integration
ECHO_FUNCTION = 25
GET_STATUS_FUNCTION = 26
SET_VREF_FUNCTION = 27
SET_POSITION = 28
SET_CONTROL_OUTPUTS_FUNCTION = 29
ZERO_FUNCTION = 30
SET_LVDT_OFFSET_FUNCTION = 31
GET_POSITION_FUNCTION = 32
RESET_FUNCTION = 33
GET_PROJECTION = 34
RUN_UDP_TEST = 35
UPDATE_NET_ADDRESS = 36
GET_TLM_READING = 37

FLASH_ERASE_SECTOR = 38
FLASH_ERASE_BLOCK = 39
WRITE_FLASH_PAGE = 40
READ_FLASH = 41
RESET_FLASH = 42
GET_CAMERA_TEMP = 43
GET_FPGA_TEMP = 44


#Registers
IMAGE_BUFFER_SELECT_REG = 33
GAIN_REG = 3
BLO_REG = 4
EXPOSURE_REG = 5
SRC_MAC_ADDRESS_0_3_SYS_REG = 42
SRC_MAC_ADDRESS_4_5_SYS_REG = 43
DST_MAC_ADDRESS_0_3_SYS_REG = 44
DST_MAC_ADDRESS_4_5_SYS_REG = 45
SRC_IP_ADDRESS_SYS_REG = 46
DST_IP_ADDRESS_SYS_REG = 47
SRC_PORT_SYS_REG = 50
DST_PORT_SYS_REG = 51
NOOP_REG = 62       #register you can read and write to for testing, has no side effects

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

    def Send(self, packet):
        response = None

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

        #for x in output_packet:
            #print(f"{x:02x}")
        #print(self.crc)

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

class Get_TLM_Reading_Packet(Packet):
    def __init__(self, TLM_Channel):
        super().__init__(GET_TLM_READING,0,TLM_Channel.to_bytes(4,'little', signed = True), 0)

class Set_Position_Packet(Packet):
    def __init__(self, Position):
        super().__init__( SET_POSITION, 1, Position.to_bytes(4,'little', signed = True), 0)

class Set_Mode_Packet(Packet):
    def __init__(self, Mode):
        super().__init__( SET_MODE_SYS_CMD, 1, Mode.to_bytes(4,'little', signed = True), 0)

class Transfer_Buffer_Packet(Packet):
    def __init__(self):
        super().__init__( XFER_BUFF_SYS_CMD, 1,[], 0)

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

class Read_Register_Packet(Packet):
    def __init__(self, reg_id):
        super().__init__(REG_READ_SYS_CMD ,1,
                         reg_id.to_bytes(4,'little', signed = True),
                         0)

class Write_Register_Packet(Packet):
    def __init__(self, reg_id, reg_val):
        super().__init__(REG_WRITE_SYS_CMD ,1,
                         reg_id.to_bytes(1,'little', signed = True) +
                         reg_val.to_bytes(4,'little', signed = True),
                         0)

class Reset_Packet(Packet):
    def __init__(self):
        super().__init__(RESET_FUNCTION,0, [], 0)  

class Reset_Frame_Index_Packet(Packet):
    def __init__(self):
        super().__init__(RESET_FRAME_INDEX,0, [], 0)

class Reset_Flash_Packet(Packet):
    def __init__(self):
        super().__init__( RESET_FLASH,0, [], 0)  

class UDP_Test_Packet(Packet):
    def __init__(self):
        super().__init__(RUN_UDP_TEST,0, [], 0)  

class Start_Acq_Packet(Packet):
    def __init__(self):
        super().__init__(START_ACQ_SYS_CMD,0, [], 0) 

class Reset_Sys_Packet(Packet):
    def __init__(self):
        super().__init__(RESET_SYS_CMD,0, [], 0)

class Get_Status_Packet(Packet):  
    def __init__(self):
        super().__init__(GET_STATUS_FUNCTION, 1, [], 0)

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

def Set_Mode(Mode: object) -> bytes:
    Pinterface = PacketInterface(serial_port_name)
    packet = Set_Mode_Packet( Mode )
    response = Pinterface.Send(packet)
    details = Pinterface.ResponseDetails(response)
    error_code = details['error_code']
    return error_code

def Transfer_Buffer() -> bytes:
    Pinterface = PacketInterface(serial_port_name)
    packet = Transfer_Buffer_Packet( )
    response = Pinterface.Send(packet)
    details = Pinterface.ResponseDetails(response)
    error_code = details['error_code']
    return error_code

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

def UDP_Test():
    """Starts test - spraying packets on UDP interface """
    Pinterface = PacketInterface(serial_port_name)
    packet = UDP_Test_Packet();
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
    Pinterface = PacketInterface(serial_port_name)
    packet = Reset_Packet()
    response = Pinterface.Send(packet)
    return response   

def Reset_Frame_Index():
    """Resets the frame index"""
    Pinterface = PacketInterface(serial_port_name)
    packet = Reset_Frame_Index_Packet()
    response = Pinterface.Send(packet)
    return response 

def Reset_Flash():
    Pinterface = PacketInterface(serial_port_name)
    packet = Reset_Flash_Packet()
    response = Pinterface.Send(packet)
    return response 

def Reset_Sys():
    """Commands a global reset of registers, focus and camera"""
    Pinterface = PacketInterface(serial_port_name)
    packet = Reset_Sys_Packet()
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

def Get_Projection():
    """Reads projection of secondary response (complex) onto primary (complex). This is equivalent to
    Re{S/P}"""
    Pinterface = PacketInterface(serial_port_name)
    packet = Get_Projection_Packet()
    response = Pinterface.Send(packet)
    details = Pinterface.ResponseDetails(response)
    data = details['data']
    return int.from_bytes(data, 'little', signed=True)

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
    Pinterface = PacketInterface(serial_port_name, timeout = 0.025)
    packet = Flash_Read_Packet(address)
    response = Pinterface.Send(packet)
    details = Pinterface.ResponseDetails(response)
    data = details['data']
    return data   

#register based operations

def Select_Image_Buffer(value):
    error_code = Write_Register(IMAGE_BUFFER_SELECT_REG, value)
    return error_code

def Set_Gain(value):
    error_code = Write_Register(GAIN_REG, value)
    return error_code

def Set_BLO(value):
    error_code = Write_Register(BLO_REG, value)
    return error_code

def Set_Exp(value):
    error_code = Write_Register(EXPOSURE_REG, value)
    return error_code

DST_IP_ADDRESS_SYS_REG = 47

def Set_SRC_MAC(mac_address):
    """assumes mac address is list with 6 elements 0-255"""
    mac_length = len(mac_address)
    mac_msb = bytearray(mac_address[0:2])
    mac_lsb = bytearray(mac_address[2:mac_length])
    mac_msb_i = int.from_bytes(mac_msb, 'big' )
    mac_lsb_i = int.from_bytes(mac_lsb, 'big')
    Write_Register(SRC_MAC_ADDRESS_0_3_SYS_REG, mac_lsb_i )
    Write_Register(SRC_MAC_ADDRESS_4_5_SYS_REG, mac_msb_i )

def Set_DST_MAC(mac_address):
    """assumes mac address is list with 6 elements 0-255"""
    mac_length = len(mac_address)
    mac_msb = bytearray(mac_address[0:2])
    mac_lsb = bytearray(mac_address[2:mac_length])
    mac_msb_i = int.from_bytes(mac_msb, 'big')
    mac_lsb_i = int.from_bytes(mac_lsb, 'big')
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
    Write_Register(SRC_PORT_SYS_REG, port & 0xffff )

def Set_DST_Port(Port):
    """Argument is number in range 0-65536"""
    Write_Register(DST_PORT_SYS_REG, port & 0xffff )

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
        print(f"file length = {bytes_remaining}")
        index = 0
        while bytes_remaining > 0:
            print(f"Writing 128 byte block from offset {index}")
            write_data = file_data[index:index+128]
            Flash_Write_Page(address+index, write_data)
            index = index + 128
            bytes_remaining = bytes_remaining - 128

def Save_Flash_To_File( filename, block_number, size):
    address = Get_64K_Flash_Block_Address(block_number)
    with open(filename, "wb") as file:
        bytes_remaining = size
        print(f"file length = {bytes_remaining}")
        index = 0
        while bytes_remaining > 0:
            print(f"Writing 128 byte block from offset {index}")
            read_data = Read_Flash(address+index)
            file.write(read_data)
            index = index + 128
            bytes_remaining = bytes_remaining - 128

# Logging
def Init_Log_File(log_filename):
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

default_camera_gain = 240   
default_camera_blo = 240   

def Camera_Test(buffer_select, number_images):
    """Goes through states for camera in ICD, takes single picture and sends through UDP.
    The buffer select argument is 0-8GB DDR4 1-16GB DDR4"""
    logging.debug(f"Starting camera test - powering down camera")
    Select_Image_Buffer(buffer_select) # 0 -> 8GB 1 -> 16GB
    logging.debug(f"Using buffer {buffer_select}")
    time.sleep(1.0)
    Set_Mode(1) # Power down camera
    time.sleep(2.0)
    logging.debug(f"Setting camera params")
    Write_Register(GAIN_REG, default_camera_gain)
    Write_Register(BLO_REG, default_camera_blo)
    Write_Register(EXPOSURE_REG, 3000)
    logging.debug(f"Powering up camera")
    Set_Mode(2)
    time.sleep(2.0)
    logging.debug(f"Arming Camera")
    Set_Mode(4)
    time.sleep(1.0)
    for n in range(number_images):
        logging.debug(f"Taking picture")
        Start_Acq()
        time.sleep(2)
        logging.debug(f"Transferring buffer contents")
        Transfer_Buffer()
        time.sleep(2)

def Camera_Setup(buffer_select):
    """Goes through states for camera in ICD, takes single picture and sends through UDP.
    The buffer select argument is 0-8GB DDR4 1-16GB DDR4"""
    logging.debug(f"Starting camera test - powering down camera")
    Select_Image_Buffer(buffer_select) # 0 -> 8GB 1 -> 16GB
    logging.debug(f"Using buffer {buffer_select}")
    time.sleep(1.0)
    Set_Mode(1) # Power down camera
    #time.sleep(2.0)
    time.sleep(2.0)
    logging.debug(f"Setting camera params")
    Write_Register(GAIN_REG, default_camera_gain)
    Write_Register(BLO_REG, default_camera_blo)
    Write_Register(EXPOSURE_REG, 3000)
    logging.debug(f"Powering up camera")
    Set_Mode(2)
    #time.sleep(2.0)
    time.sleep(10.0) #5
    Set_Mode(4)
    #time.sleep(1.0)
    time.sleep(5.0) #5

def Take_Picture():
        Start_Acq()
        #time.sleep(2)
        time.sleep(2)
        logging.debug(f"Transferring buffer contents")
        Transfer_Buffer()
        #time.sleep(2)
        #time.sleep(5)

def  Read_TLMs():
    for n in range(0, 48):
        reading = Get_TLM_Reading(n)
        print(reading)
        time.sleep(0.1)

if __name__ == '__main__':
    #(x,y,z) = Get_Status()
    error_code = Echo()
    #error_code = Write_Register(58,0x12345678)
    #error_code = Read_Register(58)
    #print(hex(error_code))
    #error_code = Get_Status()
    #error_code =   Set_Mode(0)
    #x = Read_Register(58)
    #print( hex(x) )
    #print( x )
    #print(error_code, value)
    #print(x,y,z)
    ##print(hex(error_code))
    #logging.basicConfig( filename='test_out',
                        #level=logging.DEBUG, format = "{asctime} - {levelname} - {message}",
                         #style = "{",
                         #datefmt = "%Y-%m-%d %H:%M:%S",)
    #Test()






