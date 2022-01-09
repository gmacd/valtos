//
// Support functions for system calls that involve file descriptors.
//

const std = @import("std");

const fs = @import("fs.zig");
const param = @import("param.zig");
const pipe = @import("pipe.zig");
const sleeplock = @import("sleeplock.zig");
const spinlock = @import("spinlock.zig");

const FileType = enum(u16) { FD_NONE, FD_PIPE, FD_INODE, FD_DEVICE };

pub const File = struct {
    ref: i32 = 0, // reference count
    readable: u8 = 0,
    writable: u8 = 0,
    pipe: ?*pipe.Pipe = null, // FD_PIPE
    ip: ?*Inode = null, // FD_INODE and FD_DEVICE
    off: u32 = 0, // FD_INODE
    major: u16 = 0, // FD_DEVICE
};

// #define major(dev)  ((dev) >> 16 & 0xFFFF)
// #define minor(dev)  ((dev) & 0xFFFF)
// #define	mkdev(m,n)  ((uint)((m)<<16| (n)))

// in-memory copy of an inode
pub const Inode = struct {
    dev: u32 = 0, // Device number
    inum: u32 = 0, // Inode number
    ref: i32 = 0, // Reference count
    lock: sleeplock.Sleeplock = .{}, // protects everything below here
    valid: bool = false, // inode has been read from disk?

    type: FileType = .FD_NONE, // copy of disk inode
    major: i16 = 0,
    minor: i16 = 0,
    nlink: i16 = 0,
    size: u32 = 0,
    addrs: [fs.NDIRECT + 1]u32 = [_]u32{0} ** (fs.NDIRECT + 1),
};

// map major device number to device functions.
pub const DevSw = struct {
    read: ?fn (user_dst: i32, dst: u64, n: i32) i32 = null,
    write: ?fn (user_dst: i32, src: u64, n: i32) i32 = null,
};

pub const CONSOLE = 1;

pub var devsw: [param.NDEV]DevSw = std.mem.zeroes([param.NDEV]DevSw);

pub const Ftable = struct {
    lock: spinlock.Spinlock = .{},
    file: [param.NFILE]File = [_]File{.{}} ** (param.NFILE),
};
var ftable: Ftable = .{};

pub fn fileinit() void {
    spinlock.initlock(&ftable.lock, "ftable");
}

// // Allocate a file structure.
// struct file*
// filealloc(void)
// {
//   struct file *f;

//   acquire(&ftable.lock);
//   for(f = ftable.file; f < ftable.file + NFILE; f++){
//     if(f->ref == 0){
//       f->ref = 1;
//       release(&ftable.lock);
//       return f;
//     }
//   }
//   release(&ftable.lock);
//   return 0;
// }

// // Increment ref count for file f.
// struct file*
// filedup(struct file *f)
// {
//   acquire(&ftable.lock);
//   if(f->ref < 1)
//     panic("filedup");
//   f->ref++;
//   release(&ftable.lock);
//   return f;
// }

// // Close file f.  (Decrement ref count, close when reaches 0.)
// void
// fileclose(struct file *f)
// {
//   struct file ff;

//   acquire(&ftable.lock);
//   if(f->ref < 1)
//     panic("fileclose");
//   if(--f->ref > 0){
//     release(&ftable.lock);
//     return;
//   }
//   ff = *f;
//   f->ref = 0;
//   f->type = FD_NONE;
//   release(&ftable.lock);

//   if(ff.type == FD_PIPE){
//     pipeclose(ff.pipe, ff.writable);
//   } else if(ff.type == FD_INODE || ff.type == FD_DEVICE){
//     begin_op();
//     iput(ff.ip);
//     end_op();
//   }
// }

// // Get metadata about file f.
// // addr is a user virtual address, pointing to a struct stat.
// int
// filestat(struct file *f, uint64 addr)
// {
//   struct proc *p = myproc();
//   struct stat st;

//   if(f->type == FD_INODE || f->type == FD_DEVICE){
//     ilock(f->ip);
//     stati(f->ip, &st);
//     iunlock(f->ip);
//     if(copyout(p->pagetable, addr, (char *)&st, sizeof(st)) < 0)
//       return -1;
//     return 0;
//   }
//   return -1;
// }

// // Read from file f.
// // addr is a user virtual address.
// int
// fileread(struct file *f, uint64 addr, int n)
// {
//   int r = 0;

//   if(f->readable == 0)
//     return -1;

//   if(f->type == FD_PIPE){
//     r = piperead(f->pipe, addr, n);
//   } else if(f->type == FD_DEVICE){
//     if(f->major < 0 || f->major >= NDEV || !devsw[f->major].read)
//       return -1;
//     r = devsw[f->major].read(1, addr, n);
//   } else if(f->type == FD_INODE){
//     ilock(f->ip);
//     if((r = readi(f->ip, 1, addr, f->off, n)) > 0)
//       f->off += r;
//     iunlock(f->ip);
//   } else {
//     panic("fileread");
//   }

//   return r;
// }

// // Write to file f.
// // addr is a user virtual address.
// int
// filewrite(struct file *f, uint64 addr, int n)
// {
//   int r, ret = 0;

//   if(f->writable == 0)
//     return -1;

//   if(f->type == FD_PIPE){
//     ret = pipewrite(f->pipe, addr, n);
//   } else if(f->type == FD_DEVICE){
//     if(f->major < 0 || f->major >= NDEV || !devsw[f->major].write)
//       return -1;
//     ret = devsw[f->major].write(1, addr, n);
//   } else if(f->type == FD_INODE){
//     // write a few blocks at a time to avoid exceeding
//     // the maximum log transaction size, including
//     // i-node, indirect block, allocation blocks,
//     // and 2 blocks of slop for non-aligned writes.
//     // this really belongs lower down, since writei()
//     // might be writing a device like the console.
//     int max = ((MAXOPBLOCKS-1-1-2) / 2) * BSIZE;
//     int i = 0;
//     while(i < n){
//       int n1 = n - i;
//       if(n1 > max)
//         n1 = max;

//       begin_op();
//       ilock(f->ip);
//       if ((r = writei(f->ip, 1, addr + i, f->off, n1)) > 0)
//         f->off += r;
//       iunlock(f->ip);
//       end_op();

//       if(r != n1){
//         // error from writei
//         break;
//       }
//       i += r;
//     }
//     ret = (i == n ? n : -1);
//   } else {
//     panic("filewrite");
//   }

//   return ret;
// }

