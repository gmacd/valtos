# How to build + run
- Build
  - `zig build`
- Run
  - `qemu-system-riscv64 -machine virt -serial mon:stdio -bios zig-out/bin/valtos.elf`
- Quit
  - `ctrl-a, x`

# Goal
Build something similar to xv6, for riscv64, aarch64, etc, in zig.

# References

- [Zig Language Reference](https://ziglang.org/documentation/master/)
- [Xv6 riscv code](https://github.com/mit-pdos/xv6-riscv)
- [Xv6 book](https://pdos.csail.mit.edu/6.828/2021/xv6/book-riscv-rev2.pdf)
- [MIT OS Course](https://pdos.csail.mit.edu/6.828/2021/)

## Riscv
- [Code Models](https://www.sifive.com/blog/all-aboard-part-4-risc-v-code-models)
