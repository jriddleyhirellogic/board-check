import logging
import serial
import array as arr
import sys
import time
from datetime import datetime
import random

from SerialTest import *

def run():
	# Configure the logging system
	# Generates a filename like: log_2026-06-02_13-46-00.log
	current_time = datetime.now().strftime("%Y-%m-%d_%H-%M-%S")
	log_filename = f"log_{current_time}.log"

	logging.basicConfig(
	    level=logging.DEBUG,
	    format="%(asctime)s [%(levelname)s] %(message)s",
	    handlers=[
	        logging.FileHandler(log_filename, mode="w"),  # Saves logs to a file
	        logging.StreamHandler(sys.stdout)          # Prints logs to the screen
	    ]
	)

	logging.info("Starting")
	logging.info("Initializing camera")
	Write_Register(26,1)        #sets camera to take single picture
	Camera_Setup(1)
	#picture taking loop
	n = 0
	while True:
		logging.info(f"Picture: {n}")
		Take_Picture()
		fpga_temp = Get_FPGA_Temp()
		camera_temp = Get_Camera_Temp()
		logging.info(f"FPGA Temp = {fpga_temp}C Camera_Temp = {camera_temp}C")
		n += 1
		time.sleep(60)


if __name__ == '__main__':
	run()




