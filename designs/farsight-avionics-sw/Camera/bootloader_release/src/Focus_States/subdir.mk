################################################################################
# Automatically-generated file. Do not edit!
################################################################################

# Add inputs and outputs from these tool invocations to the build variables 
C_SRCS += \
../src/Focus_States/Coarse_Focus_State.c \
../src/Focus_States/Fine_Focus_State.c \
../src/Focus_States/Focus_Fault_State.c \
../src/Focus_States/Idle_State.c \
../src/Focus_States/Zero_Coarse_State.c \
../src/Focus_States/Zero_Fine_State.c 

OBJS += \
./src/Focus_States/Coarse_Focus_State.o \
./src/Focus_States/Fine_Focus_State.o \
./src/Focus_States/Focus_Fault_State.o \
./src/Focus_States/Idle_State.o \
./src/Focus_States/Zero_Coarse_State.o \
./src/Focus_States/Zero_Fine_State.o 

C_DEPS += \
./src/Focus_States/Coarse_Focus_State.d \
./src/Focus_States/Fine_Focus_State.d \
./src/Focus_States/Focus_Fault_State.d \
./src/Focus_States/Idle_State.d \
./src/Focus_States/Zero_Coarse_State.d \
./src/Focus_States/Zero_Fine_State.d 


# Each subdirectory must supply rules for building sources it contributes
src/Focus_States/%.o: ../src/Focus_States/%.c src/Focus_States/subdir.mk
	@echo 'Building file: $<'
	@echo 'Invoking: GNU RISC-V Cross C Compiler'
	riscv64-unknown-elf-gcc -march=rv32im -mabi=ilp32 -mcmodel=medany -msmall-data-limit=8 -mstrict-align -mno-save-restore -Os -fmessage-length=0 -fsigned-char -ffunction-sections -fdata-sections  -g -DDEBUG -DVECTORED_IRQ_FREERTOS -DUSE_ETH1 -DAVIONICS_BOARD -DFULL_STEPPER_CURRENT -DCRC_SLOW -I"/home/iboard/farsight/avtemp/Camera/include" -I"/home/iboard/farsight/avtemp/Camera/src/FreeRTOS" -I"/home/iboard/farsight/avtemp/Camera/src/FreeRTOS/include" -I"/home/iboard/farsight/avtemp/Camera/src" -std=gnu11 -Wa,-adhlns="$@.lst" -v -MMD -MP -MF"$(@:%.o=%.d)" -MT"$@" -c -o "$@" "$<"
	@echo 'Finished building: $<'
	@echo ' '


