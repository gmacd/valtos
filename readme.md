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

## Riscv
- [Code Models](https://www.sifive.com/blog/all-aboard-part-4-risc-v-code-models)

## TODO
- ../../xv6-riscv//kernel:
  - [ ] bio.c
  - [ ] buf.h
  - [ ] console.c
  - [ ] date.h
  - [ ] defs.h
  - [ ] elf.h
  - [x] entry.S
  - [ ] exec.c
  - [ ] fcntl.h
  - [ ] file.c
  - [ ] file.h
  - [ ] fs.c
  - [ ] fs.h
  - [ ] kalloc.c
  - [x] kernel.ld
  - [x] kernelvec.S
  - [ ] log.c
  - [ ] main.c
  - [ ] memlayout.h
  - [ ] param.h
  - [ ] pipe.c
  - [ ] plic.c
  - [ ] printf.c
  - [ ] proc.c
  - [ ] proc.h
  - [ ] ramdisk.c
  - [ ] riscv.h
  - [ ] sleeplock.c
  - [ ] sleeplock.h
  - [ ] spinlock.c
  - [ ] spinlock.h
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
  - [ ] uart.c
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
