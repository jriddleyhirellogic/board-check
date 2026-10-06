/*******************************************************************************
 * Copyright 2019-2022 Microchip FPGA Embedded Systems Solutions.
 *
 * SPDX-License-Identifier: MIT
 *
 * @file miv_rv32_entry.S
 * @author Microchip FPGA Embedded Systems Solutions
 * @brief Mi-V soft processor vectors, trap handling and startup code.
 *
 */
#ifndef ENTRY_S
#define ENTRY_S

#define A_EXTENSION_MASK                0x00000001u
#define MTVEC_MODE_BIT_MASK             0x00000003u
#define MTVEC_VECTORED_MODE_VAL         0x00000001u

#define MTIMEH_ADDR                     0x200BFFCu

#if __riscv_xlen == 64
# define LREG ld
# define SREG sd
# define REGBYTES 8
#else
# define LREG lw
# define SREG sw
# define REGBYTES 4
#endif

.equ BOOTLOADER_SIZE, 16384

#include "assembly_macros.h"

  .section      .entry, "ax"
  .globl _start
  .globl start_application

_start:               j handle_reset

/* Some of the Mi-V soft IP cores support compressed 'C' extension. If the Mi-V
   core in your design doesn't support 'C' extension and you enable 'C' extension
   in firmware project compiler options, then it would result in a trap. For this
   case, we are avoiding compressed instruction here so you can put a breakpoint
   at the jump and you can at least look at mcause, mepc and get some hints
   about the crash. */

.option push
.option norvc               // No compressed instructions
//trap_entry:           j generic_trap_handler          //  0 - exceptions get handled here

trap_entry:           j .+BOOTLOADER_SIZE              // jump by bootloader size
.option pop
                      .word 0                          // 1
                      .word 0                          // 2
sw_trap_entry:        .word 0                          // 3
                      .word 0                          // 4
                      .word 0                          // 5
                      .word 0                          // 6
tmr_trap_entry:       j .+BOOTLOADER_SIZE              // 7 - Timer
                      .word 0                          // 8
                      .word 0                          // 9
                      .word 0                          // 10
ext_trap_entry:       .word 0                          // 11 External Interrupt
                      .word 0                          // 12
                      .word 0                          // 13
                      .word 0                          // 14
                      .word 0                          // 15
MGEUI_trap_entry:     .word 0                          // 16 ECC uncorrectable - 16
MGECI_trap_entry:     .word 0                          // 17 ECC correctable error
                      .word 0                          // 18
                      .word 0                          // 19
                      .word 0                          // 20
                      .word 0                          // 21
                      .word 0                          // 22
                      .word 0                          // 23
MSYS_EI0_trap_entry:  j .+BOOTLOADER_SIZE              // 24 MSYS external interrupts down -> Increasing  priority
MSYS_EI1_trap_entry:  j .+BOOTLOADER_SIZE              // 25
MSYS_EI2_trap_entry:  j .+BOOTLOADER_SIZE              // 26
MSYS_EI3_trap_entry:  j .+BOOTLOADER_SIZE              // 27
MSYS_EI4_trap_entry:  j .+BOOTLOADER_SIZE              // 28
MSYS_EI5_trap_entry:  j .+BOOTLOADER_SIZE              // 29
OPSRV_trap_entry:     .word 0                          // Offload processor subsystem - handles stuff like jtag, etc..

.align 4
generic_trap_handler: j generic_trap_handler
/*
vector_tmr_trap_handler:
  irq_save_regs
  jal  v_Redirect_IRQ
  irq_restore_regs


vector_MSYS_EI0_trap_handler:
  irq_save_regs
  jal v_Redirect_IRQ
  irq_restore_regs

vector_MSYS_EI1_trap_handler:
  irq_save_regs
  jal v_Redirect_IRQ
  irq_restore_regs

  */

.section   .text, "ax"
handle_reset:
/* Ensure instructions are not relaxed, since gp is not yet set */
.option push
.option norelax

  csrwi mstatus, 0  // Write imm to mstatus. Disable global irqs MIE=0
  csrwi mie, 0      // Machine Interrupt Enable - Disable all
  la ra, _start     // load return address

/* Clearing this to be on safer side as RTL doesnt seem to clear it on reset. */
#ifndef MIV_LEGACY_RV32
  li t0, MTIMEH_ADDR   // load immediate MTIMEH_ADDR into t0
  sw x0, 0(t0)         // zeroist location MTIMEH_ADDR
#endif

  csrr t0, misa
  andi t0, t0, A_EXTENSION_MASK
  bnez t0, ima_cores_setup          /* Jump to IMA core handling */

/* For MIV_RV32 cores the mtvec exception base address is fixed at Reset vector
   address + 0x4. Check the mode bits. */
  csrr t0, mtvec
  andi t0, t0, MTVEC_MODE_BIT_MASK   // 3, keep last 2 bits
  li t1, MTVEC_VECTORED_MODE_VAL
  bne t0, t1, ima_cores_setup        /* Jump to IMA core handling */

  /* When mode = 1 => this is vectored mode on MIV_RV32 core.
     Verify that the trap_handler address matches the configuration in MTVEC */
  csrr t0, mtvec
  andi t0, t0, 0xFFFFFFFC       // zero 2 lsbs of mtvec contents
  la t1, trap_entry
  bne t0, t1, vector_address_not_matching  // mtvec doesn't point to trap_entry
  j generic_reset_handling

ima_cores_setup:
  la t0, trap_entry

#ifdef MIV_LEGACY_RV32_VECTORED_INTERRUPTS
  addi t0, t0, 0x01 /* Set the mode bit for IMA cores.
                       For MIV_RV32 cores this is done by configurator. */
#endif
  csrw mtvec, t0

generic_reset_handling:
/* Copy sdata section first so that the gp is set and linker relaxation can be
   used */
    la a4, __sdata_load
    la a5, __sdata_start
    la a6, __sdata_end
    beq a4, a5, 1f     /* Exit if source and dest are same */
    beq a5, a6, 1f     /* Exit if section start and end addresses are same */
    call block_copy

1:
  /* initialize global pointer */
  la gp, __global_pointer$

.option pop

/* Floating point support configuration */
#ifdef __riscv_flen
  csrr t0, mstatus
  lui t1, 0xffffa
  addi t1, t1, -1
  and t0, t0, t1
  lui t1, 0x4
  or t1, t0, t1
  csrw mstatus, t1

  lui t0, 0x0
  fscsr t0
#endif

//------------------------------------------------------------------------------
// Start: Patch fix for Microchip MiV to work with FreeRTOS V11.2
//------------------------------------------------------------------------------
#ifdef ADD_SUPPORT_FREERTOS_V11
  // SJ: Set mtvec to the FreeRTOS trap handler
  #ifndef VECTORED_IRQ_FREERTOS  // mtvec value for vectored interrupt mode is fixed - IRB
  la t0, freertos_risc_v_trap_handler
  csrw mtvec, t0
  #endif
  // SJ: Ensure interrupts are initially disabled for FreeRTOS
  // SJ: FreeRTOS will enable them when the first task starts.
  csrci mstatus, 0x00000008 // Clear MIE bit in mstatus
#endif
//------------------------------------------------------------------------------
// Patch End
//------------------------------------------------------------------------------
  call initializations
  /* Initialize stack pointer */
  la sp, __stack_top

  /* Jump into C code */
  j _init

/* Error: trap_entry is not at the expected address of reset_vector+mtvec offset
   as configured in the MIV_RV32 core vectored mode */
vector_address_not_matching:
  ebreak

initializations:
/* Initialize the .bss section */
    mv t0, ra           /* Store ra for future use */
    la  a5, __bss_start
    la  a6, __bss_end
    beq a5, a6, 1f     /* Section start and end address are the same */
    call zeroize_block

1:
/* Initialize the .sbss section */
    la  a5, __sbss_start
    la  a6, __sbss_end
    beq a5, a6, 1f     /* Section start and end address are the same */
    call zeroize_block

 /* zeroise the metadata */
    la  a5, __metadata_start
    la  a6, __metadata_end
    andi a6, a6, 0xFFFFFFFC   # Clears the LSBs (bits 1 and 0)
    beq a5, a6, 1f     /* Section start and end address are the same */
    call zeroize_block

/* Clear heap */
    la  a5, __heap_start
    la  a6, __heap_end
    beq a5, a6, 1f     /* Section start and end address are the same */
    call zeroize_block

1:

/* Copy data section */
    la  a4, __data_load
    la  a5, __data_start
    la  a6, __data_end
    beq a4, a5, 1f     /* Exit early if source and dest are same */
    beq a5, a6, 1f     /* Section start and end addresses are the same */
    call block_copy
1:
    mv ra, t0           /* Retrieve ra */
    ret

zeroize_block:
    bltu a6, a5, block_copy_error   /* Error. End address is less than start */
    or a7, a6, a5                   /* Check if start or end is unalined */
    andi a7, a7, 0x03u
    bgtz a7, block_copy_error       /* Unaligned addresses error*/
zeroize_loop:
    sw x0, 0(a5)
    add a5, a5, __SIZEOF_POINTER__
    blt a5, a6, zeroize_loop
    ret

block_copy:
    bltu a6, a5, block_copy_error   /* Error. End address is less than start */
    or a7, a6, a5                   /* Check if start or end is unalined */
    andi a7, a7, 0x03u
    bgtz a7, block_copy_error       /* Unaligned addresses error*/
block_copy_loop:
    lw a7, 0(a4)
    sw a7, 0(a5)
    addi a5, a5, 0x04
    addi a4, a4, 0x04
    blt a5, a6, block_copy_loop
    j block_copy_exit

block_copy_error:
    j block_copy_error

block_copy_exit:
    ret

unhandled_exception:
    csrr t0, mcause
    csrr t1, mepc
    csrr t2, mstatus
unhandled_done:  j unhandled_done

start_application:
    #application start is at 0x80004000
    add t0,zero,zero
    lui  t0, 0x80004       #upper 20 bits of address
    jr t0


#endif /*ENTRY_S*/
