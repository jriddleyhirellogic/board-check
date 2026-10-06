################################################################################
# Automatically-generated file. Do not edit!
################################################################################

# Add inputs and outputs from these tool invocations to the build variables 
C_SRCS += \
../src/FreeRTOS/event_groups.c \
../src/FreeRTOS/heap_1.c \
../src/FreeRTOS/list.c \
../src/FreeRTOS/port.c \
../src/FreeRTOS/queue.c \
../src/FreeRTOS/tasks.c \
../src/FreeRTOS/timers.c 

S_UPPER_SRCS += \
../src/FreeRTOS/portASM.S 

OBJS += \
./src/FreeRTOS/event_groups.o \
./src/FreeRTOS/heap_1.o \
./src/FreeRTOS/list.o \
./src/FreeRTOS/port.o \
./src/FreeRTOS/portASM.o \
./src/FreeRTOS/queue.o \
./src/FreeRTOS/tasks.o \
./src/FreeRTOS/timers.o 

S_UPPER_DEPS += \
./src/FreeRTOS/portASM.d 

C_DEPS += \
./src/FreeRTOS/event_groups.d \
./src/FreeRTOS/heap_1.d \
./src/FreeRTOS/list.d \
./src/FreeRTOS/port.d \
./src/FreeRTOS/queue.d \
./src/FreeRTOS/tasks.d \
./src/FreeRTOS/timers.d 


# Each subdirectory must supply rules for building sources it contributes
src/FreeRTOS/%.o: ../src/FreeRTOS/%.c src/FreeRTOS/subdir.mk
	@echo 'Building file: $<'
	@echo 'Invoking: GNU RISC-V Cross C Compiler'
	riscv64-unknown-elf-gcc -march=rv32im -mabi=ilp32 -mcmodel=medany -msmall-data-limit=8 -mstrict-align -mno-save-restore -Os -fmessage-length=0 -fsigned-char -ffunction-sections -fdata-sections  -g -DDEBUG -DVECTORED_IRQ_FREERTOS -DUSE_ETH1 -DAVIONICS_BOARD -DFULL_STEPPER_CURRENT -DCRC_SLOW -I"/home/iboard/farsight/avtemp/Camera/include" -I"/home/iboard/farsight/avtemp/Camera/src/FreeRTOS" -I"/home/iboard/farsight/avtemp/Camera/src/FreeRTOS/include" -I"/home/iboard/farsight/avtemp/Camera/src" -std=gnu11 -Wa,-adhlns="$@.lst" -v -MMD -MP -MF"$(@:%.o=%.d)" -MT"$@" -c -o "$@" "$<"
	@echo 'Finished building: $<'
	@echo ' '

src/FreeRTOS/%.o: ../src/FreeRTOS/%.S src/FreeRTOS/subdir.mk
	@echo 'Building file: $<'
	@echo 'Invoking: GNU RISC-V Cross Assembler'
	riscv64-unknown-elf-gcc -march=rv32im -mabi=ilp32 -mcmodel=medany -msmall-data-limit=8 -mstrict-align -mno-save-restore -Os -fmessage-length=0 -fsigned-char -ffunction-sections -fdata-sections  -g -x assembler-with-cpp -DADD_SUPPORT_FREERTOS_V11 -DVECTORED_IRQ_FREERTOS -I"/home/iboard/farsight/avtemp/Camera/include" -I"/home/iboard/farsight/avtemp/Camera/src/FreeRTOS" -I"/home/iboard/farsight/avtemp/Camera/src/FreeRTOS/include" -MMD -MP -MF"$(@:%.o=%.d)" -MT"$@" -c -o "$@" "$<"
	@echo 'Finished building: $<'
	@echo ' '


