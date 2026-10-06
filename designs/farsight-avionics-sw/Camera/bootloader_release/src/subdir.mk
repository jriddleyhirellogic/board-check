################################################################################
# Automatically-generated file. Do not edit!
################################################################################

# Add inputs and outputs from these tool invocations to the build variables 
C_SRCS += \
../src/cal.c \
../src/camera.c \
../src/camera_sm.c \
../src/camera_task.c \
../src/command.c \
../src/crc32.c \
../src/eth.c \
../src/flash.c \
../src/focus.c \
../src/focus_sm.c \
../src/hw_init.c \
../src/hw_version.c \
../src/main.c \
../src/misc.c \
../src/pps.c \
../src/register.c \
../src/register_callbacks.c \
../src/serial_sm.c \
../src/status.c \
../src/system.c \
../src/tlm_adc.c \
../src/util.c \
../src/version.c 

OBJS += \
./src/cal.o \
./src/camera.o \
./src/camera_sm.o \
./src/camera_task.o \
./src/command.o \
./src/crc32.o \
./src/eth.o \
./src/flash.o \
./src/focus.o \
./src/focus_sm.o \
./src/hw_init.o \
./src/hw_version.o \
./src/main.o \
./src/misc.o \
./src/pps.o \
./src/register.o \
./src/register_callbacks.o \
./src/serial_sm.o \
./src/status.o \
./src/system.o \
./src/tlm_adc.o \
./src/util.o \
./src/version.o 

C_DEPS += \
./src/cal.d \
./src/camera.d \
./src/camera_sm.d \
./src/camera_task.d \
./src/command.d \
./src/crc32.d \
./src/eth.d \
./src/flash.d \
./src/focus.d \
./src/focus_sm.d \
./src/hw_init.d \
./src/hw_version.d \
./src/main.d \
./src/misc.d \
./src/pps.d \
./src/register.d \
./src/register_callbacks.d \
./src/serial_sm.d \
./src/status.d \
./src/system.d \
./src/tlm_adc.d \
./src/util.d \
./src/version.d 


# Each subdirectory must supply rules for building sources it contributes
src/%.o: ../src/%.c src/subdir.mk
	@echo 'Building file: $<'
	@echo 'Invoking: GNU RISC-V Cross C Compiler'
	riscv64-unknown-elf-gcc -march=rv32im -mabi=ilp32 -mcmodel=medany -msmall-data-limit=8 -mstrict-align -mno-save-restore -Os -fmessage-length=0 -fsigned-char -ffunction-sections -fdata-sections  -g -DDEBUG -DVECTORED_IRQ_FREERTOS -DUSE_ETH1 -DAVIONICS_BOARD -DFULL_STEPPER_CURRENT -DCRC_SLOW -I"/home/iboard/farsight/avtemp/Camera/include" -I"/home/iboard/farsight/avtemp/Camera/src/FreeRTOS" -I"/home/iboard/farsight/avtemp/Camera/src/FreeRTOS/include" -I"/home/iboard/farsight/avtemp/Camera/src" -std=gnu11 -Wa,-adhlns="$@.lst" -v -MMD -MP -MF"$(@:%.o=%.d)" -MT"$@" -c -o "$@" "$<"
	@echo 'Finished building: $<'
	@echo ' '


