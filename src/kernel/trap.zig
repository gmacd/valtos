// interrupts and exceptions from kernel code go here via kernelvec,
// on whatever the current kernel stack is.
export fn kerneltrap() void {
    
//   int which_dev = 0;
//   uint64 sepc = r_sepc();
//   uint64 sstatus = r_sstatus();
//   uint64 scause = r_scause();
  
//   if((sstatus & SSTATUS_SPP) == 0)
//     panic("kerneltrap: not from supervisor mode");
//   if(intr_get() != 0)
//     panic("kerneltrap: interrupts enabled");

//   if((which_dev = devintr()) == 0){
//     printf("scause %p\n", scause);
//     printf("sepc=%p stval=%p\n", r_sepc(), r_stval());
//     panic("kerneltrap");
//   }

//   // give up the CPU if this is a timer interrupt.
//   if(which_dev == 2 && myproc() != 0 && myproc()->state == RUNNING)
//     yield();

//   // the yield() may have caused some traps to occur,
//   // so restore trap registers for use by kernelvec.S's sepc instruction.
//   w_sepc(sepc);
//   w_sstatus(sstatus);
}
