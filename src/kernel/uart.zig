//
// low-level driver routines for 16550a UART.
//

const std = @import("std");

const console = @import("console.zig");
const memlayout = @import("memlayout.zig");
const printf = @import("printf.zig");
const proc = @import("proc.zig");
const riscv = @import("riscv.zig");
const spinlock = @import("spinlock.zig");

// the UART control registers are memory-mapped
// at address UART0. this macro returns the
// address of one of the registers.
pub fn reg(r: u64) *volatile u8 {
    return @intToPtr(*volatile u8, memlayout.UART0 + r);
}

// the UART control registers.
// some have different meanings for
// read vs write.
// see http://byterunner.com/16550.html
const RHR = 0;                 // receive holding register (for input bytes)
const THR = 0;                 // transmit holding register (for output bytes)
const IER = 1;                 // interrupt enable register
const IER_RX_ENABLE = (1<<0);
const IER_TX_ENABLE = (1<<1);
const FCR = 2;                 // FIFO control register
const FCR_FIFO_ENABLE = (1<<0);
const FCR_FIFO_CLEAR = (3<<1); // clear the content of the two FIFOs
const ISR = 2;                 // interrupt status register
const LCR = 3;                 // line control register
const LCR_EIGHT_BITS = (3<<0);
const LCR_BAUD_LATCH = (1<<7); // special mode to set baud rate
const LSR = 5;                 // line status register
const LSR_RX_READY = (1<<0);   // input is waiting to be read from RHR
const LSR_TX_IDLE = (1<<5);    // THR can accept another character to send

pub fn readReg(r: u64) u8 {
    return reg(r).*;
}
pub fn writeReg(r: u64, v: u8) void {
    reg(r).* = v;
}

// the transmit output buffer.
var uart_tx_lock = spinlock.Spinlock{};
const UART_TX_BUF_SIZE = 32;
var uart_tx_buf: [UART_TX_BUF_SIZE]u8 = std.mem.zeroes([UART_TX_BUF_SIZE]u8);
var uart_tx_w: u64 = 0; // write next to uart_tx_buf[uart_tx_w % UART_TX_BUF_SIZE]
var uart_tx_r: u64 = 0; // read next from uart_tx_buf[uart_tx_r % UART_TX_BUF_SIZE]

pub fn uartinit() void {
    // disable interrupts.
    writeReg(IER, 0x00);

    // special mode to set baud rate.
    writeReg(LCR, LCR_BAUD_LATCH);

    // LSB for baud rate of 38.4K.
    writeReg(0, 0x03);

    // MSB for baud rate of 38.4K.
    writeReg(1, 0x00);

    // leave set-baud mode,
    // and set word length to 8 bits, no parity.
    writeReg(LCR, LCR_EIGHT_BITS);

    // reset and enable FIFOs.
    writeReg(FCR, FCR_FIFO_ENABLE | FCR_FIFO_CLEAR);

    // enable transmit and receive interrupts.
    writeReg(IER, IER_TX_ENABLE | IER_RX_ENABLE);

    spinlock.initlock(&uart_tx_lock, "uart");
}

// add a character to the output buffer and tell the
// UART to start sending if it isn't already.
// blocks if the output buffer is full.
// because it may block, it can't be called
// from interrupts; it's only suitable for use
// by write().
pub fn uartputc(c: u8) void {
  spinlock.acquire(&uart_tx_lock);

  if (printf.panicked) {
    while (true) {
    }
  }

  while (true) {
    if (uart_tx_w == uart_tx_r + UART_TX_BUF_SIZE) {
      // buffer is full.
      // wait for uartstart() to open up space in the buffer.
      proc.sleep(&uart_tx_r, &uart_tx_lock);
    } else {
      uart_tx_buf[uart_tx_w % UART_TX_BUF_SIZE] = c;
      uart_tx_w += 1;
      uartstart();
      spinlock.release(&uart_tx_lock);
      return;
    }
  }
}

// alternate version of uartputc() that doesn't 
// use interrupts, for use by kernel printf() and
// to echo characters. it spins waiting for the uart's
// output register to be empty.
pub fn uartputc_sync(c: u8) void {
    spinlock.push_off();

    if (printf.panicked) {
        while (true) {
        }
    }

    // wait for Transmit Holding Empty to be set in LSR.
    while ((readReg(LSR) & LSR_TX_IDLE) == 0) {
    }
    writeReg(THR, c);

    spinlock.pop_off();
}

// if the UART is idle, and a character is waiting
// in the transmit buffer, send it.
// caller must hold uart_tx_lock.
// called from both the top- and bottom-half.
pub fn uartstart() void {
    while (true) {
        if (uart_tx_w == uart_tx_r) {
            // transmit buffer is empty.
            return;
        }

        if ((readReg(LSR) & LSR_TX_IDLE) == 0) {
            // the UART transmit holding register is full,
            // so we cannot give it another byte.
            // it will interrupt when it's ready for a new byte.
            return;
        }

        var c = uart_tx_buf[uart_tx_r % UART_TX_BUF_SIZE];
        uart_tx_r += 1;

        // maybe uartputc() is waiting for space in the buffer.
        proc.wakeup(&uart_tx_r);

        writeReg(THR, c);
    }
}

// read one input character from the UART.
// return -1 if none is waiting.
pub fn uartgetc() i32 {
    if (readReg(LSR) & 0x01) {
        // input data is ready.
        return readReg(RHR);
    } else {
        return -1;
    }
}

// handle a uart interrupt, raised because input has
// arrived, or the uart is ready for more output, or
// both. called from trap.c.
pub fn uartintr() void {
    // read and process incoming characters.
    while (true) {
        const c = uartgetc();
        if (c == -1) {
            break;
        }
        console.consoleintr(c);
    }

    // send buffered characters.
    spinlock.acquire(&uart_tx_lock);
    uartstart();
    spinlock.release(&uart_tx_lock);
}
