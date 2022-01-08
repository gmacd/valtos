const std = @import("std");

const kalloc = @import("kalloc.zig");
const memlayout = @import("memlayout.zig");
const param = @import("param.zig");
const printf = @import("printf.zig");
const riscv = @import("riscv.zig");
const spinlock = @import("spinlock.zig");
const string = @import("string.zig");
const vm = @import("vm.zig");

extern fn swtch(oldCtx: *Context, newCtx: *Context) void;

// Saved registers for kernel context switches.
pub const Context = struct {
    ra: u64,
    sp: u64,

    // callee-saved
    s0: u64,
    s1: u64,
    s2: u64,
    s3: u64,
    s4: u64,
    s5: u64,
    s6: u64,
    s7: u64,
    s8: u64,
    s9: u64,
    s10: u64,
    s11: u64,
};

// Per-CPU state.
pub const Cpu = struct {
    proc: ?*Proc,            // The process running on this cpu, or null.
    context: Context,      // swtch() here to enter scheduler().
    noff: i32,              // Depth of push_off() nesting.
    intena: bool,           // Were interrupts enabled before push_off()?
};


// per-process data for the trap handling code in trampoline.S.
// sits in a page by itself just under the trampoline page in the
// user page table. not specially mapped in the kernel page table.
// the sscratch register points here.
// uservec in trampoline.S saves user registers in the trapframe,
// then initializes registers from the trapframe's
// kernel_sp, kernel_hartid, kernel_satp, and jumps to kernel_trap.
// usertrapret() and userret in trampoline.S set up
// the trapframe's kernel_*, restore user registers from the
// trapframe, switch to the user page table, and enter user space.
// the trapframe includes callee-saved user registers like s0-s11 because the
// return-to-user path via usertrapret() doesn't return through
// the entire kernel call stack.
pub const TrapFrame = struct {
    kernel_satp: u64,   //   0 kernel page table
    kernel_sp: u64,     //   8 top of process's kernel stack
    kernel_trap: u64,   //  16 usertrap()
    epc: u64,           //  24 saved user program counter
    kernel_hartid: u64, //  32 saved kernel tp
    ra: u64,            //  40
    sp: u64,            //  48
    gp: u64,            //  56
    tp: u64,            //  64
    t0: u64,            //  72
    t1: u64,            //  80
    t2: u64,            //  88
    s0: u64,            //  96
    s1: u64,            // 104
    a0: u64,            // 112
    a1: u64,            // 120
    a2: u64,            // 128
    a3: u64,            // 136
    a4: u64,            // 144
    a5: u64,            // 152
    a6: u64,            // 160
    a7: u64,            // 168
    s2: u64,            // 176
    s3: u64,            // 184
    s4: u64,            // 192
    s5: u64,            // 200
    s6: u64,            // 208
    s7: u64,            // 216
    s8: u64,            // 224
    s9: u64,            // 232
    s10: u64,           // 240
    s11: u64,           // 248
    t3: u64,            // 256
    t4: u64,            // 264
    t5: u64,            // 272
    t6: u64,            // 280
};

const ProcState = enum { UNUSED, USED, SLEEPING, RUNNABLE, RUNNING, ZOMBIE };

// Per-process state
pub const Proc = struct {
    lock: spinlock.Spinlock = spinlock.Spinlock{},

    // p->lock must be held when using these:
    state: ProcState = .UNUSED,           // Process state
    chan: ?*anyopaque = null,                 // If non-zero, sleeping on chan
    killed: bool = false,                 // If non-zero, have been killed
    xstate: i32 = 0,                 // Exit status to be returned to parent's wait
    pid: i32 = 0,                    // Process ID

    // wait_lock must be held when using this:
    //struct proc *parent;        // Parent process

    // these are private to the process, so p->lock need not be held.
    kstack: u64 = 0,              // Virtual address of kernel stack
    sz: u64 = 0,                  // Size of process memory (bytes)
    //pagetable_t pagetable;      // User page table
    //struct trapframe *trapframe;// data page for trampoline.S
    context: Context,     // swtch() here to run process
    //struct file *ofile[NOFILE]; // Open files
    //struct inode *cwd;          // Current directory
    name: [16]u8 = std.mem.zeroes([16]u8),              // Process name (debugging)
};

var cpus: [param.NCPU]Cpu = std.mem.zeroes([param.NCPU]Cpu);

var proc: [param.NPROC]Proc = std.mem.zeroes([param.NPROC]Proc);

// struct proc *initproc;

// int nextpid = 1;
// struct spinlock pid_lock;

// extern void forkret(void);
// static void freeproc(struct proc *p);

// extern char trampoline[]; // trampoline.S

// // helps ensure that wakeups of wait()ing
// // parents are not lost. helps obey the
// // memory model when using p->parent.
// // must be acquired before any p->lock.
// struct spinlock wait_lock;

// Allocate a page for each process's kernel stack.
// Map it high in memory, followed by an invalid
// guard page.
pub fn proc_mapstacks(kpgtbl: *riscv.pagetable_t) void {
    for (proc) |_, i| {
        var pa = kalloc.kalloc() orelse printf.panic("kalloc");
        var va = memlayout.kstack(i);
        vm.kvmmap(kpgtbl, va, @ptrToInt(pa), riscv.PGSIZE, riscv.PTE_R | riscv.PTE_W);
    }
}

// // initialize the proc table at boot time.
// void
// procinit(void)
// {
//   struct proc *p;
  
//   initlock(&pid_lock, "nextpid");
//   initlock(&wait_lock, "wait_lock");
//   for(p = proc; p < &proc[NPROC]; p++) {
//       initlock(&p->lock, "proc");
//       p->kstack = KSTACK((int) (p - proc));
//   }
// }

// Must be called with interrupts disabled,
// to prevent race with process being moved
// to a different CPU.
pub fn cpuid() u64 {
    return riscv.readTp();
}

// Return this CPU's cpu struct.
// Interrupts must be disabled.
pub fn mycpu() *Cpu {
    var id = cpuid();
    var c = &cpus[id];
    return c;
}

// Return the current struct proc *, or zero if none.
pub fn myproc() ?*Proc {
    spinlock.push_off();
    var c = mycpu();
    var p = c.proc;
    spinlock.pop_off();
    return p;
}

// int
// allocpid() {
//   int pid;
  
//   acquire(&pid_lock);
//   pid = nextpid;
//   nextpid = nextpid + 1;
//   release(&pid_lock);

//   return pid;
// }

// // Look in the process table for an UNUSED proc.
// // If found, initialize state required to run in the kernel,
// // and return with p->lock held.
// // If there are no free procs, or a memory allocation fails, return 0.
// static struct proc*
// allocproc(void)
// {
//   struct proc *p;

//   for(p = proc; p < &proc[NPROC]; p++) {
//     acquire(&p->lock);
//     if(p->state == UNUSED) {
//       goto found;
//     } else {
//       release(&p->lock);
//     }
//   }
//   return 0;

// found:
//   p->pid = allocpid();
//   p->state = USED;

//   // Allocate a trapframe page.
//   if((p->trapframe = (struct trapframe *)kalloc()) == 0){
//     freeproc(p);
//     release(&p->lock);
//     return 0;
//   }

//   // An empty user page table.
//   p->pagetable = proc_pagetable(p);
//   if(p->pagetable == 0){
//     freeproc(p);
//     release(&p->lock);
//     return 0;
//   }

//   // Set up new context to start executing at forkret,
//   // which returns to user space.
//   memset(&p->context, 0, sizeof(p->context));
//   p->context.ra = (uint64)forkret;
//   p->context.sp = p->kstack + PGSIZE;

//   return p;
// }

// // free a proc structure and the data hanging from it,
// // including user pages.
// // p->lock must be held.
// static void
// freeproc(struct proc *p)
// {
//   if(p->trapframe)
//     kfree((void*)p->trapframe);
//   p->trapframe = 0;
//   if(p->pagetable)
//     proc_freepagetable(p->pagetable, p->sz);
//   p->pagetable = 0;
//   p->sz = 0;
//   p->pid = 0;
//   p->parent = 0;
//   p->name[0] = 0;
//   p->chan = 0;
//   p->killed = 0;
//   p->xstate = 0;
//   p->state = UNUSED;
// }

// // Create a user page table for a given process,
// // with no user memory, but with trampoline pages.
// pagetable_t
// proc_pagetable(struct proc *p)
// {
//   pagetable_t pagetable;

//   // An empty page table.
//   pagetable = uvmcreate();
//   if(pagetable == 0)
//     return 0;

//   // map the trampoline code (for system call return)
//   // at the highest user virtual address.
//   // only the supervisor uses it, on the way
//   // to/from user space, so not PTE_U.
//   if(mappages(pagetable, TRAMPOLINE, PGSIZE,
//               (uint64)trampoline, PTE_R | PTE_X) < 0){
//     uvmfree(pagetable, 0);
//     return 0;
//   }

//   // map the trapframe just below TRAMPOLINE, for trampoline.S.
//   if(mappages(pagetable, TRAPFRAME, PGSIZE,
//               (uint64)(p->trapframe), PTE_R | PTE_W) < 0){
//     uvmunmap(pagetable, TRAMPOLINE, 1, 0);
//     uvmfree(pagetable, 0);
//     return 0;
//   }

//   return pagetable;
// }

// // Free a process's page table, and free the
// // physical memory it refers to.
// void
// proc_freepagetable(pagetable_t pagetable, uint64 sz)
// {
//   uvmunmap(pagetable, TRAMPOLINE, 1, 0);
//   uvmunmap(pagetable, TRAPFRAME, 1, 0);
//   uvmfree(pagetable, sz);
// }

// // a user program that calls exec("/init")
// // od -t xC initcode
// uchar initcode[] = {
//   0x17, 0x05, 0x00, 0x00, 0x13, 0x05, 0x45, 0x02,
//   0x97, 0x05, 0x00, 0x00, 0x93, 0x85, 0x35, 0x02,
//   0x93, 0x08, 0x70, 0x00, 0x73, 0x00, 0x00, 0x00,
//   0x93, 0x08, 0x20, 0x00, 0x73, 0x00, 0x00, 0x00,
//   0xef, 0xf0, 0x9f, 0xff, 0x2f, 0x69, 0x6e, 0x69,
//   0x74, 0x00, 0x00, 0x24, 0x00, 0x00, 0x00, 0x00,
//   0x00, 0x00, 0x00, 0x00
// };

// // Set up first user process.
// void
// userinit(void)
// {
//   struct proc *p;

//   p = allocproc();
//   initproc = p;
  
//   // allocate one user page and copy init's instructions
//   // and data into it.
//   uvminit(p->pagetable, initcode, sizeof(initcode));
//   p->sz = PGSIZE;

//   // prepare for the very first "return" from kernel to user.
//   p->trapframe->epc = 0;      // user program counter
//   p->trapframe->sp = PGSIZE;  // user stack pointer

//   safestrcpy(p->name, "initcode", sizeof(p->name));
//   p->cwd = namei("/");

//   p->state = RUNNABLE;

//   release(&p->lock);
// }

// // Grow or shrink user memory by n bytes.
// // Return 0 on success, -1 on failure.
// int
// growproc(int n)
// {
//   uint sz;
//   struct proc *p = myproc();

//   sz = p->sz;
//   if(n > 0){
//     if((sz = uvmalloc(p->pagetable, sz, sz + n)) == 0) {
//       return -1;
//     }
//   } else if(n < 0){
//     sz = uvmdealloc(p->pagetable, sz, sz + n);
//   }
//   p->sz = sz;
//   return 0;
// }

// // Create a new process, copying the parent.
// // Sets up child kernel stack to return as if from fork() system call.
// int
// fork(void)
// {
//   int i, pid;
//   struct proc *np;
//   struct proc *p = myproc();

//   // Allocate process.
//   if((np = allocproc()) == 0){
//     return -1;
//   }

//   // Copy user memory from parent to child.
//   if(uvmcopy(p->pagetable, np->pagetable, p->sz) < 0){
//     freeproc(np);
//     release(&np->lock);
//     return -1;
//   }
//   np->sz = p->sz;

//   // copy saved user registers.
//   *(np->trapframe) = *(p->trapframe);

//   // Cause fork to return 0 in the child.
//   np->trapframe->a0 = 0;

//   // increment reference counts on open file descriptors.
//   for(i = 0; i < NOFILE; i++)
//     if(p->ofile[i])
//       np->ofile[i] = filedup(p->ofile[i]);
//   np->cwd = idup(p->cwd);

//   safestrcpy(np->name, p->name, sizeof(p->name));

//   pid = np->pid;

//   release(&np->lock);

//   acquire(&wait_lock);
//   np->parent = p;
//   release(&wait_lock);

//   acquire(&np->lock);
//   np->state = RUNNABLE;
//   release(&np->lock);

//   return pid;
// }

// // Pass p's abandoned children to init.
// // Caller must hold wait_lock.
// void
// reparent(struct proc *p)
// {
//   struct proc *pp;

//   for(pp = proc; pp < &proc[NPROC]; pp++){
//     if(pp->parent == p){
//       pp->parent = initproc;
//       wakeup(initproc);
//     }
//   }
// }

// // Exit the current process.  Does not return.
// // An exited process remains in the zombie state
// // until its parent calls wait().
// void
// exit(int status)
// {
//   struct proc *p = myproc();

//   if(p == initproc)
//     panic("init exiting");

//   // Close all open files.
//   for(int fd = 0; fd < NOFILE; fd++){
//     if(p->ofile[fd]){
//       struct file *f = p->ofile[fd];
//       fileclose(f);
//       p->ofile[fd] = 0;
//     }
//   }

//   begin_op();
//   iput(p->cwd);
//   end_op();
//   p->cwd = 0;

//   acquire(&wait_lock);

//   // Give any children to init.
//   reparent(p);

//   // Parent might be sleeping in wait().
//   wakeup(p->parent);
  
//   acquire(&p->lock);

//   p->xstate = status;
//   p->state = ZOMBIE;

//   release(&wait_lock);

//   // Jump into the scheduler, never to return.
//   sched();
//   panic("zombie exit");
// }

// // Wait for a child process to exit and return its pid.
// // Return -1 if this process has no children.
// int
// wait(uint64 addr)
// {
//   struct proc *np;
//   int havekids, pid;
//   struct proc *p = myproc();

//   acquire(&wait_lock);

//   for(;;){
//     // Scan through table looking for exited children.
//     havekids = 0;
//     for(np = proc; np < &proc[NPROC]; np++){
//       if(np->parent == p){
//         // make sure the child isn't still in exit() or swtch().
//         acquire(&np->lock);

//         havekids = 1;
//         if(np->state == ZOMBIE){
//           // Found one.
//           pid = np->pid;
//           if(addr != 0 && copyout(p->pagetable, addr, (char *)&np->xstate,
//                                   sizeof(np->xstate)) < 0) {
//             release(&np->lock);
//             release(&wait_lock);
//             return -1;
//           }
//           freeproc(np);
//           release(&np->lock);
//           release(&wait_lock);
//           return pid;
//         }
//         release(&np->lock);
//       }
//     }

//     // No point waiting if we don't have any children.
//     if(!havekids || p->killed){
//       release(&wait_lock);
//       return -1;
//     }
    
//     // Wait for a child to exit.
//     sleep(p, &wait_lock);  //DOC: wait-sleep
//   }
// }

// // Per-CPU process scheduler.
// // Each CPU calls scheduler() after setting itself up.
// // Scheduler never returns.  It loops, doing:
// //  - choose a process to run.
// //  - swtch to start running that process.
// //  - eventually that process transfers control
// //    via swtch back to the scheduler.
// void
// scheduler(void)
// {
//   struct proc *p;
//   struct cpu *c = mycpu();
  
//   c->proc = 0;
//   for(;;){
//     // Avoid deadlock by ensuring that devices can interrupt.
//     intr_on();

//     for(p = proc; p < &proc[NPROC]; p++) {
//       acquire(&p->lock);
//       if(p->state == RUNNABLE) {
//         // Switch to chosen process.  It is the process's job
//         // to release its lock and then reacquire it
//         // before jumping back to us.
//         p->state = RUNNING;
//         c->proc = p;
//         swtch(&c->context, &p->context);

//         // Process is done running for now.
//         // It should have changed its p->state before coming back.
//         c->proc = 0;
//       }
//       release(&p->lock);
//     }
//   }
// }

// Switch to scheduler.  Must hold only p->lock
// and have changed proc->state. Saves and restores
// intena because intena is a property of this
// kernel thread, not this CPU. It should
// be proc->intena and proc->noff, but that would
// break in the few places where a lock is held but
// there's no process.
pub fn sched() void {
    var p = myproc() orelse { printf.panic("no proc to sched"); return; };

    if (!spinlock.holding(&p.lock)) {
        printf.panic("sched p->lock");
    }
    if (mycpu().noff != 1) {
        printf.panic("sched locks");
    }
    if (p.state == .RUNNING) {
        printf.panic("sched running");
    }
    if (riscv.intr_get()) {
        printf.panic("sched interruptible");
    }

    var intena = mycpu().intena;
    swtch(&p.context, &mycpu().context);
    mycpu().intena = intena;
}

// Give up the CPU for one scheduling round.
pub fn yield() void {
  var p = myproc();
  spinlock.acquire(&p.lock);
  p.state = .RUNNABLE;
  sched();
  spinlock.release(&p.lock);
}

// // A fork child's very first scheduling by scheduler()
// // will swtch to forkret.
// void
// forkret(void)
// {
//   static int first = 1;

//   // Still holding p->lock from scheduler.
//   release(&myproc()->lock);

//   if (first) {
//     // File system initialization must be run in the context of a
//     // regular process (e.g., because it calls sleep), and thus cannot
//     // be run from main().
//     first = 0;
//     fsinit(ROOTDEV);
//   }

//   usertrapret();
// }

// Atomically release lock and sleep on chan.
// Reacquires lock when awakened.
pub fn sleep(chan: anytype, lk: *spinlock.Spinlock) void {
  var p = myproc() orelse { printf.panic("no proc to sleep"); return; };
  
  // Must acquire p->lock in order to
  // change p->state and then call sched.
  // Once we hold p->lock, we can be
  // guaranteed that we won't miss any wakeup
  // (wakeup locks p->lock),
  // so it's okay to release lk.

  spinlock.acquire(&p.lock);  //DOC: sleeplock1
  spinlock.release(lk);

  // Go to sleep.
  p.chan = chan;
  p.state = .SLEEPING;

  sched();

  // Tidy up.
  p.chan = null;

  // Reacquire original lock.
  spinlock.release(&p.lock);
  spinlock.acquire(lk);
}

// Wake up all processes sleeping on chan.
// Must be called without any p->lock.
pub fn wakeup(chan: *anyopaque) void {
  for (proc) |*p| {
    if (p != myproc()) {
      spinlock.acquire(&p.lock);
      if ((p.state == .SLEEPING) and (p.chan == chan)) {
        p.state = .RUNNABLE;
      }
      spinlock.release(&p.lock);
    }
  }
}

// // Kill the process with the given pid.
// // The victim won't exit until it tries to return
// // to user space (see usertrap() in trap.c).
// int
// kill(int pid)
// {
//   struct proc *p;

//   for(p = proc; p < &proc[NPROC]; p++){
//     acquire(&p->lock);
//     if(p->pid == pid){
//       p->killed = 1;
//       if(p->state == SLEEPING){
//         // Wake process from sleep().
//         p->state = RUNNABLE;
//       }
//       release(&p->lock);
//       return 0;
//     }
//     release(&p->lock);
//   }
//   return -1;
// }

// Copy to either a user address, or kernel address,
// depending on usr_dst.
// Returns 0 on success, -1 on error.
pub fn either_copyout(user_dst: i32, dst: u64, src: [*]u8, len: u64) i32 {
  //var p = myproc();
  if (user_dst > 0) {
    // return copyout(p->pagetable, dst, src, len);
    // TODO
    return 0;
  } else {
    _ = string.memmove(@intToPtr([*]u8, dst), src, len);
    return 0;
  }
}

// Copy from either a user address, or kernel address,
// depending on usr_src.
// Returns 0 on success, -1 on error.
pub fn either_copyin(dst: [*]u8, user_src: i32, src: u64, len: u64) i32 {
    //var p = myproc();
    if (user_src > 0) {
        //return copyin(p.pagetable, dst, src, len);
        // TODO
        return 0;
    } else {
        _ = string.memmove(dst, @intToPtr([*]u8, src), len);
        return 0;
    }
}

// Print a process listing to console.  For debugging.
// Runs when user types ^P on console.
// No lock to avoid wedging a stuck machine further.
pub fn procdump() void {
    printf.printf("\n", .{});
    for (proc) |*p| {
        if (p.state == .UNUSED) {
            continue;
        }
        printf.printf("%d %s %s\n", .{ p.pid, @tagName(p.state), p.name });
    }
}
