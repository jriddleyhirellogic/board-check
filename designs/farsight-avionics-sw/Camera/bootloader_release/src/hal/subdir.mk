################################################################################
# Automatically-generated file. Do not edit!
################################################################################

# Add inputs and outputs from these tool invocations to the build variables 
C_SRCS += \
../src/hal/core_gpio.c \
../src/hal/core_spi.c \
../src/hal/debug_gpio.c \
../src/hal/debug_mux.c \
../src/hal/debug_switches.c \
../src/hal/hal_lvdt.c \
../src/hal/hal_pwm.c \
../src/hal/hal_stepper.c \
../src/hal/hal_uart16550.c \
../src/hal/serial_comm.c \
../src/hal/timer.c 

S_UPPER_SRCS += \
../src/hal/hw_reg_access.S 

OBJS += \
./src/hal/core_gpio.o \
./src/hal/core_spi.o \
./src/hal/debug_gpio.o \
./src/hal/debug_mux.o \
./src/hal/debug_switches.o \
./src/hal/hal_lvdt.o \
./src/hal/hal_pwm.o \
./src/hal/hal_stepper.o \
./src/hal/hal_uart16550.o \
./src/hal/hw_reg_access.o \
./src/hal/serial_comm.o \
./src/hal/timer.o 

S_UPPER_DEPS += \
./src/hal/hw_reg_access.d 

C_DEPS += \
./src/hal/core_gpio.d \
./src/hal/core_spi.d \
./src/hal/debug_gpio.d \
./src/hal/debug_mux.d \
./src/hal/debug_switches.d \
./src/hal/hal_lvdt.d \
./src/hal/hal_pwm.d \
./src/hal/hal_stepper.d \
./src/hal/hal_uart16550.d \
./src/hal/serial_comm.d \
./src/hal/timer.d 


# Each subdirectory must supply rules for building sources it contributes
src/hal/%.o: ../src/hal/%.c src/hal/subdir.mk
	@echo 'Building file: $<'
	@echo 'Invoking: GNU RISC-V Cross C Compiler'
	riscv64-unknown-elf-gcc -march=rv32im -mabi=ilp32 -mcmodel=medany -msmall-data-limit=8 -mstrict-align -mno-save-restore -Os -fmessage-length=0 -fsigned-char -ffunction-sections -fdata-sections  -g -DDEBUG -DVECTORED_IRQ_FREERTOS -DUSE_ETH1 -DAVIONICS_BOARD -DFULL_STEPPER_CURRENT -DCRC_SLOW -I"/home/iboard/farsight/avtemp/Camera/include" -I"/home/iboard/farsight/avtemp/Camera/src/FreeRTOS" -I"/home/iboard/farsight/avtemp/Camera/src/FreeRTOS/include" -I"/home/iboard/farsight/avtemp/Camera/src" -std=gnu11 -Wa,-adhlns="$@.lst" -v -MMD -MP -MF"$(@:%.o=%.d)" -MT"$@" -c -o "$@" "$<"
	@echo 'Finished building: $<'
	@echo ' '

src/hal/%.o: ../src/hal/%.S src/hal/subdir.mk
	@echo 'Building file: $<'
	@echo 'Invoking: GNU RISC-V Cross Assembler'
	riscv64-unknown-elf-gcc -march=rv32im -mabi=ilp32 -mcmodel=medany -msmall-data-limit=8 -mstrict-align -mno-save-restore -Os -fmessage-length=0 -fsigned-char -ffunction-sections -fdata-sections  -g -x assembler-with-cpp -DADD_SUPPORT_FREERTOS_V11 -DVECTORED_IRQ_FREERTOS -I"/home/iboard/farsight/avtemp/Camera/include" -I"/home/iboard/farsight/avtemp/Camera/src/FreeRTOS" -I"/home/iboard/farsight/avtemp/Camera/src/FreeRTOS/include" -MMD -MP -MF"$(@:%.o=%.d)" -MT"$@" -c -o "$@" "$<"
	@echo 'Finished building: $<'
	@echo ' '


