# How to build + run
- Build
  - `zig build`
- Run
  - `qemu-system-riscv64 -machine virt -serial mon:stdio -bios zig-out/bin/valtos.elf`
- Quit
  - `ctrl-a, x`

# Goal
1. Implement xv6 in zig.
2. ?

# References

- [Zig Language Reference](https://ziglang.org/documentation/master/)
- [Xv6 riscv code](https://github.com/mit-pdos/xv6-riscv)
- [Xv6 book](https://pdos.csail.mit.edu/6.828/2021/xv6/book-riscv-rev2.pdf)
- [MIT OS Course](https://pdos.csail.mit.edu/6.828/2021/)
- Future work
  - [FastVM](https://github.com/FastVM/minivm)

## Riscv
- [Code Models](https://www.sifive.com/blog/all-aboard-part-4-risc-v-code-models)

## TODO
- General
  - Compare time, binary size, LoC when building zig xv6 vs c xv6
- ../../xv6-riscv//kernel:
  - [ ] bio.c
  - [ ] buf.h
  - [x] console.c
  - [ ] date.h
  - [x] defs.h
  - [ ] elf.h
  - [x] entry.S
  - [ ] exec.c
  - [ ] fcntl.h
  - [ ] file.c
  - [ ] file.h
  - [ ] fs.c
  - [ ] fs.h
  - [x] kalloc.c
  - [x] kernel.ld
  - [x] kernelvec.S
  - [ ] log.c
  - [ ] main.c
  - [x] memlayout.h
  - [x] param.h
  - [ ] pipe.c
  - [x] plic.c
  - [x] printf.c
  - [ ] proc.c (either_copyin, either_copyout)
  - [ ] proc.h
  - [ ] ramdisk.c
  - [x] riscv.h
  - [ ] sleeplock.c
  - [ ] sleeplock.h
  - [x] spinlock.c
  - [x] spinlock.h
  - [x] start.c
  - [ ] stat.h
  - [ ] string.c
  - [x] swtch.S
  - [ ] syscall.c
  - [ ] syscall.h
  - [ ] sysfile.c
  - [ ] sysproc.c
  - [x] trampoline.S
  - [ ] trap.c
  - [ ] types.h
  - [x] uart.c
  - [ ] virtio.h
  - [ ] virtio_disk.c
  - [ ] vm.c
- ../../xv6-riscv//mkfs:
  - [ ] mkfs.c
- ../../xv6-riscv//user:
  - [ ] cat.c
  - [ ] echo.c
  - [ ] forktest.c
  - [ ] grep.c
  - [ ] grind.c
  - [ ] init.c
  - [ ] initcode.S
  - [ ] kill.c
  - [ ] ln.c
  - [ ] ls.c
  - [ ] mkdir.c
  - [ ] printf.c
  - [ ] rm.c
  - [ ] sh.c
  - [ ] stressfs.c
  - [ ] ulib.c
  - [ ] umalloc.c
  - [ ] user.h
  - [ ] usertests.c
  - [ ] usys.pl
  - [ ] wc.c
  - [ ] zombie.c
- Todos
  - Address todos in code
  - Use @memset or @memcpy?
