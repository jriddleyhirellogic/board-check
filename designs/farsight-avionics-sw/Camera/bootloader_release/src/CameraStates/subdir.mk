################################################################################
# Automatically-generated file. Do not edit!
################################################################################

# Add inputs and outputs from these tool invocations to the build variables 
C_SRCS += \
../src/CameraStates/camera_armed_state.c \
../src/CameraStates/camera_busy_state.c \
../src/CameraStates/camera_fault_state.c \
../src/CameraStates/camera_idle_state.c \
../src/CameraStates/camera_low_power_state.c \
../src/CameraStates/camera_transfer_state.c 

OBJS += \
./src/CameraStates/camera_armed_state.o \
./src/CameraStates/camera_busy_state.o \
./src/CameraStates/camera_fault_state.o \
./src/CameraStates/camera_idle_state.o \
./src/CameraStates/camera_low_power_state.o \
./src/CameraStates/camera_transfer_state.o 

C_DEPS += \
./src/CameraStates/camera_armed_state.d \
./src/CameraStates/camera_busy_state.d \
./src/CameraStates/camera_fault_state.d \
./src/CameraStates/camera_idle_state.d \
./src/CameraStates/camera_low_power_state.d \
./src/CameraStates/camera_transfer_state.d 


# Each subdirectory must supply rules for building sources it contributes
src/CameraStates/%.o: ../src/CameraStates/%.c src/CameraStates/subdir.mk
	@echo 'Building file: $<'
	@echo 'Invoking: GNU RISC-V Cross C Compiler'
	riscv64-unknown-elf-gcc -march=rv32im -mabi=ilp32 -mcmodel=medany -msmall-data-limit=8 -mstrict-align -mno-save-restore -Os -fmessage-length=0 -fsigned-char -ffunction-sections -fdata-sections  -g -DDEBUG -DVECTORED_IRQ_FREERTOS -DUSE_ETH1 -DAVIONICS_BOARD -DFULL_STEPPER_CURRENT -DCRC_SLOW -I"/home/iboard/farsight/avtemp/Camera/include" -I"/home/iboard/farsight/avtemp/Camera/src/FreeRTOS" -I"/home/iboard/farsight/avtemp/Camera/src/FreeRTOS/include" -I"/home/iboard/farsight/avtemp/Camera/src" -std=gnu11 -Wa,-adhlns="$@.lst" -v -MMD -MP -MF"$(@:%.o=%.d)" -MT"$@" -c -o "$@" "$<"
	@echo 'Finished building: $<'
	@echo ' '


