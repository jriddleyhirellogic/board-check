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

#include "assembly_macros.h"

  .section      .entry, "ax"
  .globl _start

_start:
  j handle_reset

/* Some of the Mi-V soft IP cores support compressed 'C' extension. If the Mi-V
   core in your design doesn't support 'C' extension and you enable 'C' extension
   in firmware project compiler options, then it would result in a trap. For this
   case, we are avoiding compressed instruction here so you can put a breakpoint
   at the jump and you can at least look at mcause, mepc and get some hints
   about the crash. */
trap_entry:
.option push
.option norvc
//           /* 0 */
#ifdef VECTORED_IRQ_FREERTOS
#pragma message "Vectored interrupts being used!!"
j freertos_risc_v_trap_handler
#else
j generic_trap_handler
#endif

.option pop
  .word 0
  .word 0

sw_trap_entry:
  j vector_sw_trap_handler
#ifdef __riscv_compressed
  .2byte 0
#endif
  .word 0
  .word 0
  .word 0

tmr_trap_entry:                   // 7 - Timer
  #ifdef VECTORED_IRQ_FREERTOS
  j freertos_risc_v_trap_handler
  #else
  j vector_tmr_trap_handler
  #endif

#ifdef __riscv_compressed
  .2byte 0
#endif
  .word 0
  .word 0
  .word 0

ext_trap_entry:
  j vector_ext_trap_handler       // External Interrupt -  11
#ifdef __riscv_compressed
  .2byte 0
#endif
  .word 0
  .word 0
  .word 0
  .word 0

#ifndef MIV_LEGACY_RV32
MGEUI_trap_entry:
  j vector_MGEUI_trap_handler   // ECC uncorrectable - 16
#ifdef __riscv_compressed
  .2byte 0
#endif

MGECI_trap_entry:
  j vector_MGECI_trap_handler   // ECC correctable error - 17
#ifdef __riscv_compressed
  .2byte 0
#endif
  .word 0
  .word 0
  .word 0
  .word 0
  .word 0
  .word 0

MSYS_EI0_trap_entry:               // MSYS external interrupts down -> Increasing  priority
  j vector_MSYS_EI0_trap_handler   // 24
#ifdef __riscv_compressed
  .2byte 0
#endif

MSYS_EI1_trap_entry:
  j vector_MSYS_EI1_trap_handler   // 25
#ifdef __riscv_compressed
  .2byte 0
#endif

MSYS_EI2_trap_entry:
  j vector_MSYS_EI2_trap_handler   // 26
#ifdef __riscv_compressed
  .2byte 0
#endif

MSYS_EI3_trap_entry:
#ifdef VECTORED_IRQ_FREERTOS
  j freertos_risc_v_trap_handler   // 27 cam trigger - route via FreeRTOS ISR-stack path
#else
  j vector_MSYS_EI3_trap_handler    // 27
#endif
#ifdef __riscv_compressed
  .2byte 0
#endif

MSYS_EI4_trap_entry:
#ifdef VECTORED_IRQ_FREERTOS
  j freertos_risc_v_trap_handler   // 28 PPS - route via FreeRTOS ISR-stack path
#else
  j vector_MSYS_EI4_trap_handler   // 28
#endif
#ifdef __riscv_compressed
  .2byte 0
#endif

MSYS_EI5_trap_entry:
#ifdef VECTORED_IRQ_FREERTOS
  j freertos_risc_v_trap_handler   // 29 UDP xfer - route via FreeRTOS ISR-stack path
#else
  j vector_MSYS_EI5_trap_handler   // 29
#endif
#ifdef __riscv_compressed
  .2byte 0
#endif

#ifdef __riscv_compressed
  .2byte 0
#endif

OPSRV_trap_entry:
  j vector_OPSRV_IRQHandler        // Offload processor subsystem - handles stuff like jtag, etc..
#endif  /* MIV_LEGACY_RV32 */

.align 4
generic_trap_handler:
  irq_save_regs
  csrr a0, mcause
  csrr a1, mepc
  jal handle_trap
  irq_restore_regs

vector_sw_trap_handler:
  irq_save_regs
  jal handle_m_soft_interrupt
  irq_restore_regs

vector_tmr_trap_handler:
  irq_save_regs
  jal handle_m_timer_interrupt
  irq_restore_regs

vector_ext_trap_handler:
  irq_save_regs
#ifdef MIV_LEGACY_RV32
  jal handle_m_ext_interrupt
#else
  jal External_IRQHandler
#endif /* MIV_LEGACY_RV32 */
  irq_restore_regs

#ifndef MIV_LEGACY_RV32
vector_MGEUI_trap_handler:
  irq_save_regs
  jal MGEUI_IRQHandler
  irq_restore_regs

vector_MGECI_trap_handler:
  irq_save_regs
  jal MGECI_IRQHandler
  irq_restore_regs

vector_MSYS_EI0_trap_handler:
  irq_save_regs
#ifdef VECTORED_IRQ_FREERTOS
  jal v_Comm_Timer_Handler
#else
  jal MSYS_EI0_IRQHandler
#endif
  irq_restore_regs

vector_MSYS_EI1_trap_handler:
  irq_save_regs
#ifdef VECTORED_IRQ_FREERTOS
  jal v_UART16550_Handler
#else
  jal MSYS_EI1_IRQHandler
#endif
  irq_restore_regs

vector_MSYS_EI2_trap_handler:
  irq_save_regs
  jal MSYS_EI2_IRQHandler
  irq_restore_regs

vector_MSYS_EI3_trap_handler:
  irq_save_regs
  jal MSYS_EI3_IRQHandler
  irq_restore_regs

vector_MSYS_EI4_trap_handler:
  irq_save_regs
  jal MSYS_EI4_IRQHandler
  irq_restore_regs

vector_MSYS_EI5_trap_handler:
  irq_save_regs
  jal MSYS_EI5_IRQHandler
  irq_restore_regs

vector_OPSRV_IRQHandler:
  irq_save_regs
  jal OPSRV_IRQHandler
  irq_restore_regs
#endif /* MIV_LEGACY_RV32 */

/*
generic_restore:
  LREG x1, 0 * REGBYTES(sp)
  LREG x2, 1 * REGBYTES(sp)
  LREG x3, 2 * REGBYTES(sp)
  LREG x4, 3 * REGBYTES(sp)
  LREG x5, 4 * REGBYTES(sp)
  LREG x6, 5 * REGBYTES(sp)
  LREG x7, 6 * REGBYTES(sp)
  LREG x8, 7 * REGBYTES(sp)
  LREG x9, 8 * REGBYTES(sp)
  LREG x10, 9 * REGBYTES(sp)
  LREG x11, 10 * REGBYTES(sp)
  LREG x12, 11 * REGBYTES(sp)
  LREG x13, 12 * REGBYTES(sp)
  LREG x14, 13 * REGBYTES(sp)
  LREG x15, 14 * REGBYTES(sp)
  LREG x16, 15 * REGBYTES(sp)
  LREG x17, 16 * REGBYTES(sp)
  LREG x18, 17 * REGBYTES(sp)
  LREG x19, 18 * REGBYTES(sp)
  LREG x20, 19 * REGBYTES(sp)
  LREG x21, 20 * REGBYTES(sp)
  LREG x22, 21 * REGBYTES(sp)
  LREG x23, 22 * REGBYTES(sp)
  LREG x24, 23 * REGBYTES(sp)
  LREG x25, 24 * REGBYTES(sp)
  LREG x26, 25 * REGBYTES(sp)
  LREG x27, 26 * REGBYTES(sp)
  LREG x28, 27 * REGBYTES(sp)
  LREG x29, 28 * REGBYTES(sp)
  LREG x30, 29 * REGBYTES(sp)
  LREG x31, 30 * REGBYTES(sp)

  addi sp, sp, 32*REGBYTES
  mret
  */

  .section      .text, "ax"
handle_reset:
/* Ensure instructions are not relaxed, since gp is not yet set */
.option push
.option norelax

  csrwi mstatus, 0  // Write imm to mstatus. Disable global irqs MIE=0
  csrwi mie, 0      // Machine Interrupt Enable
  la ra, _start     // load return address

/* Clearnig this to be on safer side as RTL doesnt seem to clear it on reset. */
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
     /*
  csrr t0, mtvec
  andi t0, t0, 0xFFFFFFFC       // zero 2 lsbs of mtvec contents
  la t1, trap_entry
  bne t0, t1, vector_address_not_matching  // mtvec doesn't point to trap_entry
  */
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
  la sp, __stack_top

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

#endif /*ENTRY_S*/
