################################################################################
# Automatically-generated file. Do not edit!
################################################################################

# Add inputs and outputs from these tool invocations to the build variables 
C_SRCS += \
../src/miv_rv32_hal/miv_rv32_hal.c \
../src/miv_rv32_hal/miv_rv32_init.c \
../src/miv_rv32_hal/miv_rv32_stubs.c \
../src/miv_rv32_hal/miv_rv32_syscall.c 

S_UPPER_SRCS += \
../src/miv_rv32_hal/app_bl_entry.S 

OBJS += \
./src/miv_rv32_hal/app_bl_entry.o \
./src/miv_rv32_hal/miv_rv32_hal.o \
./src/miv_rv32_hal/miv_rv32_init.o \
./src/miv_rv32_hal/miv_rv32_stubs.o \
./src/miv_rv32_hal/miv_rv32_syscall.o 

S_UPPER_DEPS += \
./src/miv_rv32_hal/app_bl_entry.d 

C_DEPS += \
./src/miv_rv32_hal/miv_rv32_hal.d \
./src/miv_rv32_hal/miv_rv32_init.d \
./src/miv_rv32_hal/miv_rv32_stubs.d \
./src/miv_rv32_hal/miv_rv32_syscall.d 


# Each subdirectory must supply rules for building sources it contributes
src/miv_rv32_hal/%.o: ../src/miv_rv32_hal/%.S src/miv_rv32_hal/subdir.mk
	@echo 'Building file: $<'
	@echo 'Invoking: GNU RISC-V Cross Assembler'
	riscv64-unknown-elf-gcc -march=rv32im -mabi=ilp32 -mcmodel=medany -msmall-data-limit=8 -mstrict-align -mno-save-restore -Os -fmessage-length=0 -fsigned-char -ffunction-sections -fdata-sections  -g -x assembler-with-cpp -DADD_SUPPORT_FREERTOS_V11 -DVECTORED_IRQ_FREERTOS -I"/home/iboard/farsight/avtemp/Camera/include" -I"/home/iboard/farsight/avtemp/Camera/src/FreeRTOS" -I"/home/iboard/farsight/avtemp/Camera/src/FreeRTOS/include" -MMD -MP -MF"$(@:%.o=%.d)" -MT"$@" -c -o "$@" "$<"
	@echo 'Finished building: $<'
	@echo ' '

src/miv_rv32_hal/%.o: ../src/miv_rv32_hal/%.c src/miv_rv32_hal/subdir.mk
	@echo 'Building file: $<'
	@echo 'Invoking: GNU RISC-V Cross C Compiler'
	riscv64-unknown-elf-gcc -march=rv32im -mabi=ilp32 -mcmodel=medany -msmall-data-limit=8 -mstrict-align -mno-save-restore -Os -fmessage-length=0 -fsigned-char -ffunction-sections -fdata-sections  -g -DDEBUG -DVECTORED_IRQ_FREERTOS -DUSE_ETH1 -DAVIONICS_BOARD -DFULL_STEPPER_CURRENT -DCRC_SLOW -I"/home/iboard/farsight/avtemp/Camera/include" -I"/home/iboard/farsight/avtemp/Camera/src/FreeRTOS" -I"/home/iboard/farsight/avtemp/Camera/src/FreeRTOS/include" -I"/home/iboard/farsight/avtemp/Camera/src" -std=gnu11 -Wa,-adhlns="$@.lst" -v -MMD -MP -MF"$(@:%.o=%.d)" -MT"$@" -c -o "$@" "$<"
	@echo 'Finished building: $<'
	@echo ' '


