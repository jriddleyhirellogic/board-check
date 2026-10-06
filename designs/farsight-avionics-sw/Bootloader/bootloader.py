import logging
import serial
import array as arr
import sys
import time
import os

SYNC_FRAME = 0x1ACFFC1D
FUNCTION_CODE = 0x10

#function codes from ICD
GET_VERSION_SYS_CMD = 0x00
#SET_MODE_SYS_CMD = 0x01
#RESET_SYS_CMD = 0x02
#REG_READ_SYS_CMD = 0x03
#REG_WRITE_SYS_CMD = 0x04
#SET_TIME_SYS_CMD = 0x05
#START_ACQ_SYS_CMD = 0x06
#STOP_ACQ_SYS_CMD = 0x07
#FOCUS_SYS_CMD = 0x08
#HALT_FOCUS_SYS_CMD = 0x09
#XFER_BUFF_SYS_CMD = 0x0A
#RESET_BUFF_SYS_CMD = 0x0B
#GET_INFO_SYS_CMD = 0x0C
#CONF_EVENT_LOG_SYS_CMD = 0x0D
#EN_TL_CHAN_LOG_SYS_CMD = 0x0E
#XFER_LOG_SYS_CMD = 0x0F
#RESET_FRAME_INDEX=0x10

#User defined to support debug and integration
ECHO_FUNCTION = 25
GET_STATUS_FUNCTION = 26
#SET_VREF_FUNCTION = 27
#SET_POSITION = 28
#SET_CONTROL_OUTPUTS_FUNCTION = 29
#ZERO_FUNCTION = 30
#SET_LVDT_OFFSET_FUNCTION = 31
#GET_POSITION_FUNCTION = 32
RESET_FUNCTION = 33
#GET_PROJECTION = 34
#RUN_UDP_TEST = 35
#UPDATE_NET_ADDRESS = 36
#GET_TLM_READING = 37

FLASH_ERASE_SECTOR = 38
FLASH_ERASE_BLOCK = 39
WRITE_FLASH_PAGE = 40
READ_FLASH = 41
RESET_FLASH = 42

#For development
LOAD_FLASH_TO_MEM = 43
START_APP = 44
UPDATE = 45


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

crc = CRC_32()

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
        self.crc = crc.check( function_field ,0  )

        #error (used in replies)
        error_field = packet.error_code.to_bytes(1,'big')
        self.crc = crc.check( error_field, self.crc)
        output_packet += error_field

        #Sequence number
        sequence_field = packet.sequence_number.to_bytes(1,'big')
        self.crc = crc.check( sequence_field, self.crc)
        output_packet += sequence_field

        #length (bytes) of data field
        packet_length = len(packet.data) & 0xFF
        packet_length_field = packet_length.to_bytes(1,'big')
        self.crc = crc.check( packet_length_field, self.crc)
        output_packet += packet_length_field

        #reserved field (will some day be used for expanded error reporting)
        reserved = 0
        reserved_field = reserved.to_bytes(8,'big')
        self.crc = crc.check( reserved_field, self.crc)
        output_packet += reserved_field

        #data field
        if packet_length > 0:
            self.crc = crc.check( packet.data , self.crc)
            output_packet += bytearray(packet.data)

        #append CRC
        output_packet +=self.crc.to_bytes(4,'big')

        #for x in output_packet:
            #print(f"{x:02x}")
        #print(self.crc)

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


class Reset_Packet(Packet):
    def __init__(self):
        super().__init__(RESET_FUNCTION,0, [], 0)  


class Reset_Flash_Packet(Packet):
    def __init__(self):
        super().__init__( RESET_FLASH,0, [], 0)  


class Get_Status_Packet(Packet):  
    def __init__(self):
        super().__init__(GET_STATUS_FUNCTION, 1, [], 0)

class Get_Version_Packet(Packet):  
    def __init__(self):
        super().__init__(GET_VERSION_SYS_CMD, 1, [], 0)

class Flash_Erase_Sector_Packet(Packet):
    def __init__(self, address ):
        super().__init__( FLASH_ERASE_SECTOR, 1, address.to_bytes(4,'little', signed = False),   0)

class Flash_Erase_Block_Packet(Packet):
    def __init__(self, address ):
        super().__init__( FLASH_ERASE_BLOCK,  1, address.to_bytes(4,'little', signed = False), 0)

class Load_Flash_To_Mem_Packet(Packet):
    def __init__(self, flash_address, mem_address, nbytes ):
        super().__init__( LOAD_FLASH_TO_MEM,  1, 
            flash_address.to_bytes(4,'little', signed = False) + 
            mem_address.to_bytes(4,'little', signed = False) +
            nbytes.to_bytes(4,'little', signed = False),  0) 

class Start_App_Packet(Packet):
    def __init__(self):
        super().__init__( START_APP,0, [], 0)  

class Update_Packet(Packet):
    def __init__(self):
        super().__init__( UPDATE, 0, [], 0)  

class Flash_Write_Page_Packet(Packet):
    def __init__(self, address, packet_data):
        super().__init__(WRITE_FLASH_PAGE, 1, address.to_bytes(4,'little',signed = True) + packet_data, 0)

class Flash_Read_Packet(Packet):
    def __init__(self, address):
        super().__init__(READ_FLASH, 1, address.to_bytes(4,'little', signed = False), 0)

def Echo():
    Pinterface = PacketInterface(serial_port_name)
    packet = EchoPacket([1,2,3,4,5,6,7,8])
    response = Pinterface.Send(packet)
    return response

def Reset():
    """Resets the focus mechanism"""
    Pinterface = PacketInterface(serial_port_name)
    packet = Reset_Packet()
    response = Pinterface.Send(packet)
    return response   

def Reset_Flash():
    Pinterface = PacketInterface(serial_port_name)
    packet = Reset_Flash_Packet()
    response = Pinterface.Send(packet)
    return response 

def Start_Application():
    Pinterface = PacketInterface(serial_port_name)
    packet = Start_App_Packet()
    response = Pinterface.Send(packet)
    return response 

def Update():
    Pinterface = PacketInterface(serial_port_name)
    packet = Update_Packet()
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

def Get_Version():
    """Returns triple (position-microns, velocity microns/sec * 10, fault status)"""
    Pinterface = PacketInterface(serial_port_name)
    packet = Get_Version_Packet()
    response = Pinterface.Send(packet)
    details =  Pinterface.ResponseDetails(response)
    data = details['data']
    return data


def Load_Flash_To_Mem( flash_address, mem_address, nbytes):
    Pinterface = PacketInterface(serial_port_name, timeout=0.010 )
    packet = Load_Flash_To_Mem_Packet( flash_address,  mem_address, nbytes )
    response = Pinterface.Send(packet)
    return response

def Install_Application(binary_filename, block_number):
    if block_number < 0 or block_number > 125:
        raise ValueError("64K blocks must be between 0 and 125")
    print(f"writing file {binary_filename} to 64K block:{block_number}")
    app_size_bytes = Write_File_To_Flash( binary_filename, block_number )
    md = Metadata()
    md.add_application(binary_filename, block_number)
    md.update_flash()

def Update_Calibration(cal_filename):
     with open(filename, "rb") as file:
        flash_address = Get_8K_Flash_Block_Address(1) #Cal data always goes in 8K sector(1)
        cal_data = file.read()
        if len(cal_data) != 2048:
            raise ValueError("Cal file must be 2048 bytes")
        print(f"Writing 2048 bytes to cal block - address 0x{flash_address:x}")
        bytes_remaining = 2048
        offset = 0
        Flash_Erase_Block(flash_address)
        while bytes_remaining > 0:
            write_data = cal_data[offset:offset+128]
            Flash_Write_Page(flash_address+offset, write_data)
            bytes_remaining -= 128
            offset += 128

def Flash_Write_Page(address, packet_data):
    Pinterface = PacketInterface(serial_port_name, timeout=0.015 )
    packet = Flash_Write_Page_Packet(address, packet_data)
    response = Pinterface.Send(packet)
    return response

class Metadata():                   #For now, convention is that metadata will go in 1st 8K block
    def __init__(self ):
        self.data = bytearray(128)
        self.offset = 0
    def add_application( self, filename, app_flash_block_number ):
        try:
            with open(filename, "rb") as file:
                app_data = file.read()
        except FileNotFoundError:
            print("Error: The file does not exist.")
        except PermissionError:
            print("Error: You do not have permission to access this file.")
        except OSError as e:
            print(f"An OS-level error occurred: {e}")

        app_size_bytes = len(app_data)
        print(f"App size = {app_size_bytes}")

        flash_address = Get_64K_Flash_Block_Address( app_flash_block_number )
        print(f"Flash address block[{app_flash_block_number}] = 0x{flash_address:x}")

        crc_check  = crc.check(app_data, 0)
        print(f"crc = 0x{crc_check:x}")

        self.data[self.offset:self.offset+4] = flash_address.to_bytes(4, byteorder='little')
        self.data[self.offset+4:self.offset+8] = app_size_bytes.to_bytes(4, byteorder='little')
        self.data[self.offset+8:self.offset+12] = crc_check.to_bytes(4, byteorder='little')
        self.offset += 12

    def update_flash(self): #implication is that metadata is always in the first 8K block
        Flash_Erase_Block( 0 )
        Flash_Write_Page( 0, self.data)


def Read_Flash(address):
    Pinterface = PacketInterface(serial_port_name, timeout = 0.2)
    packet = Flash_Read_Packet(address)
    response = Pinterface.Send(packet)
    details = Pinterface.ResponseDetails(response)
    data = details['data']
    return data   

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

def Erase_Blocks(starting_block, number_blocks):
    for block_number in range(number_blocks):
        block_address = Get_64K_Flash_Block_Address(starting_block + block_number)
        Flash_Erase_Block(block_address)


def Write_File_To_Flash( filename, block_number ):
    """Writes contents of file to a 64K block"""
    app_size_bytes = 0
    try:
        with open(filename, "rb") as file:
            file_data = file.read()
            bytes_remaining = len(file_data)
            app_size_bytes = bytes_remaining
            print(f"file size = {bytes_remaining}")
            #round up to multiple of 128
            bytes_remaining = ((bytes_remaining + 127)//128) * 128
            print(f"file size (rounded up to 128 block) = {bytes_remaining}")
            #Erasing flash block
            address = Get_64K_Flash_Block_Address(block_number)
            print(f"Erasing block at address {address:x}")
            Flash_Erase_Block(address)
            # #writing to flash
            index = 0
            while bytes_remaining > 0:
                print(f"Writing 128 byte block from offset {index}")
                write_data = file_data[index:index+128]
                Flash_Write_Page(address+index, write_data)
                index = index + 128
                bytes_remaining = bytes_remaining - 128
    except FileNotFoundError:
        print("Error: The file does not exist.")
    except PermissionError:
        print("Error: You do not have permission to access this file.")
    except OSError as e:
        print(f"An OS-level error occurred: {e}")
    return app_size_bytes

def Load_Mem(block_number, nbytes):
    flash_address = Get_64K_Flash_Block_Address(block_number)
    Load_Flash_To_Mem( flash_address, 0x80004000, nbytes)

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
    serial_port_name = '/dev/ttyUSB1'

def Set_Serial_Port(name):
    serial_port_name = name


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






