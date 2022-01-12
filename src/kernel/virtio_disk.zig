//
// driver for qemu's virtio disk device.
// uses qemu's mmio interface to virtio.
// qemu presents a "legacy" virtio interface.
//
// qemu ... -drive file=fs.img,if=none,format=raw,id=x0 -device virtio-blk-device,drive=x0,bus=virtio-mmio-bus.0
//

const bio = @import("bio.zig");
const memlayout = @import("memlayout.zig");
const printf = @import("printf.zig");
const proc = @import("proc.zig");
const riscv = @import("riscv.zig");
const spinlock = @import("spinlock.zig");
const string = @import("string.zig");

//
// virtio device definitions.
// for both the mmio interface, and virtio descriptors.
// only tested with qemu.
// this is the "legacy" virtio interface.
//
// the virtio spec:
// https://docs.oasis-open.org/virtio/virtio/v1.1/virtio-v1.1.pdf
//

// virtio mmio control registers, mapped starting at 0x10001000.
// from qemu virtio_mmio.h
const VIRTIO_MMIO_MAGIC_VALUE = 0x000; // 0x74726976
const VIRTIO_MMIO_VERSION = 0x004; // version; 1 is legacy
const VIRTIO_MMIO_DEVICE_ID = 0x008; // device type; 1 is net, 2 is disk
const VIRTIO_MMIO_VENDOR_ID = 0x00c; // 0x554d4551
const VIRTIO_MMIO_DEVICE_FEATURES = 0x010;
const VIRTIO_MMIO_DRIVER_FEATURES = 0x020;
const VIRTIO_MMIO_GUEST_PAGE_SIZE = 0x028; // page size for PFN, write-only
const VIRTIO_MMIO_QUEUE_SEL = 0x030; // select queue, write-only
const VIRTIO_MMIO_QUEUE_NUM_MAX = 0x034; // max size of current queue, read-only
const VIRTIO_MMIO_QUEUE_NUM = 0x038; // size of current queue, write-only
const VIRTIO_MMIO_QUEUE_ALIGN = 0x03c; // used ring alignment, write-only
const VIRTIO_MMIO_QUEUE_PFN = 0x040; // physical page number for queue, read/write
const VIRTIO_MMIO_QUEUE_READY = 0x044; // ready bit
const VIRTIO_MMIO_QUEUE_NOTIFY = 0x050; // write-only
const VIRTIO_MMIO_INTERRUPT_STATUS = 0x060; // read-only
const VIRTIO_MMIO_INTERRUPT_ACK = 0x064; // write-only
const VIRTIO_MMIO_STATUS = 0x070; // read/write

// status register bits, from qemu virtio_config.h
const VIRTIO_CONFIG_S_ACKNOWLEDGE = 1;
const VIRTIO_CONFIG_S_DRIVER = 2;
const VIRTIO_CONFIG_S_DRIVER_OK = 4;
const VIRTIO_CONFIG_S_FEATURES_OK = 8;

// device feature bits
const VIRTIO_BLK_F_RO: u64 =              5; // Disk is read-only
const VIRTIO_BLK_F_SCSI: u64 =            7; // Supports scsi command passthru
const VIRTIO_BLK_F_CONFIG_WCE: u64 =     11; // Writeback mode available in config
const VIRTIO_BLK_F_MQ: u64 =             12; // support more than one vq
const VIRTIO_F_ANY_LAYOUT: u64 =         27;
const VIRTIO_RING_F_INDIRECT_DESC: u64 = 28;
const VIRTIO_RING_F_EVENT_IDX: u64 =     29;

// this many virtio descriptors.
// must be a power of two.
const NUM = 8;

// a single descriptor, from the spec.
const VirtQDesc = struct {
    addr: u64 = 0,
    len: u32 = 0,
    flags: u16 = 0,
    next: u16 = 0,
};
const VRING_DESC_F_NEXT =  1; // chained with another descriptor
const VRING_DESC_F_WRITE = 2; // device writes (vs read)

// the (entire) avail ring, from the spec.
const VirtQAvail = struct {
    flags: u16 = 0, // always zero
    idx: u16 = 0,   // driver will write ring[idx] next
    ring: [NUM]u16 = [_]u16{0} ** NUM, // descriptor numbers of chain heads
    unused: u16 = 0,
};

// one entry in the "used" ring, with which the
// device tells the driver about completed requests.
const VirtQUsedElem = struct {
    id: u32 = 0,   // index of start of completed descriptor chain
    len: u32 = 0,
};

const VirtQUsed = struct {
    flags: u16 = 0, // always zero
    idx: u16 = 0,   // device increments when it adds a ring[] entry
    ring: [NUM]VirtQUsedElem = [_]VirtQUsedElem{.{}} ** NUM,
};

// these are specific to virtio block devices, e.g. disks,
// described in Section 5.2 of the spec.

const VIRTIO_BLK_T_IN =  0; // read the disk
const VIRTIO_BLK_T_OUT = 1; // write the disk

// the format of the first descriptor in a disk request.
// to be followed by two more descriptors containing
// the block, and a one-byte status.
const VirtIoBlkReq = struct {
    type: u32 = 0, // VIRTIO_BLK_T_IN or ..._OUT
    reserved: u32 = 0,
    sector: u64 = 0,
};

// the address of virtio mmio register r.
fn R(comptime T:type, r: u64) *volatile T {
    return @intToPtr(*volatile T, memlayout.VIRTIO0 + r);
}

// track info about in-flight operations,
// for use when completion interrupt arrives.
// indexed by first descriptor index of chain.
const DiskInfo = struct {
    b: ?*bio.Buf = null,
    status: u8 = 0,
};

const Disk = struct {
    // the virtio driver and device mostly communicate through a set of
    // structures in RAM. pages[] allocates that memory. pages[] is a
    // global (instead of calls to kalloc()) because it must consist of
    // two contiguous pages of page-aligned physical memory.
    pages: [2*riscv.PGSIZE]u8 = [_]u8{0} ** (2*riscv.PGSIZE),

    // pages[] is divided into three regions (descriptors, avail, and
    // used), as explained in Section 2.6 of the virtio specification
    // for the legacy interface.
    // https://docs.oasis-open.org/virtio/virtio/v1.1/virtio-v1.1.pdf

    // the first region of pages[] is a set (not a ring) of DMA
    // descriptors, with which the driver tells the device where to read
    // and write individual disk operations. there are NUM descriptors.
    // most commands consist of a "chain" (a linked list) of a couple of
    // these descriptors.
    // points into pages[].
    desc: ?*VirtQDesc = null,

    // next is a ring in which the driver writes descriptor numbers
    // that the driver would like the device to process.  it only
    // includes the head descriptor of each chain. the ring has
    // NUM elements.
    // points into pages[].
    avail: ?*VirtQAvail = null,

    // finally a ring in which the device writes descriptor numbers that
    // the device has finished processing (just the head of each chain).
    // there are NUM used ring entries.
    // points into pages[].
    used: ?*VirtQUsed = null,

    // our own book-keeping.
    free: [NUM]bool = [_]bool{false} ** NUM,  // is a descriptor free?
    used_idx: u16 = 0, // we've looked this far in used[2..NUM].

    // track info about in-flight operations,
    // for use when completion interrupt arrives.
    // indexed by first descriptor index of chain.
    info: [NUM]DiskInfo = [_]DiskInfo{.{}} ** NUM,

    // disk command headers.
    // one-for-one with descriptors, for convenience.
    ops: [NUM]VirtIoBlkReq = [_]VirtIoBlkReq{.{}} ** NUM,

    vdisk_lock: spinlock.Spinlock = .{},
};
var disk: Disk align(riscv.PGSIZE) = .{};

pub fn virtio_disk_init() void {
    spinlock.initlock(&disk.vdisk_lock, "virtio_disk");

    if ((R(u32, VIRTIO_MMIO_MAGIC_VALUE).* != 0x74726976) or
        (R(u32, VIRTIO_MMIO_VERSION).* != 1) or
        (R(u32, VIRTIO_MMIO_DEVICE_ID).* != 2) or
        (R(u32, VIRTIO_MMIO_VENDOR_ID).* != 0x554d4551)) {
        printf.panic("could not find virtio disk");
    }

    var status: u32 = 0;
    status |= VIRTIO_CONFIG_S_ACKNOWLEDGE;
    R(u32, VIRTIO_MMIO_STATUS).* = status;

    status |= VIRTIO_CONFIG_S_DRIVER;
    R(u32, VIRTIO_MMIO_STATUS).* = status;

    // negotiate features
    var features = R(u64, VIRTIO_MMIO_DEVICE_FEATURES).*;
    features &= @shlExact(VIRTIO_BLK_F_RO, 1);
    features &= @shlExact(VIRTIO_BLK_F_SCSI, 1);
    features &= @shlExact(VIRTIO_BLK_F_CONFIG_WCE, 1);
    features &= @shlExact(VIRTIO_BLK_F_MQ, 1);
    features &= @shlExact(VIRTIO_F_ANY_LAYOUT, 1);
    features &= @shlExact(VIRTIO_RING_F_EVENT_IDX, 1);
    features &= @shlExact(VIRTIO_RING_F_INDIRECT_DESC, 1);
    R(u64, VIRTIO_MMIO_DRIVER_FEATURES).* = features;

    // tell device that feature negotiation is complete.
    status |= VIRTIO_CONFIG_S_FEATURES_OK;
    R(u32, VIRTIO_MMIO_STATUS).* = status;

    // tell device we're completely ready.
    status |= VIRTIO_CONFIG_S_DRIVER_OK;
    R(u32, VIRTIO_MMIO_STATUS).* = status;

    R(u32, VIRTIO_MMIO_GUEST_PAGE_SIZE).* = riscv.PGSIZE;

    // initialize queue 0.
    R(u32, VIRTIO_MMIO_QUEUE_SEL).* = 0;
    var max = R(u32, VIRTIO_MMIO_QUEUE_NUM_MAX).*;
    if (max == 0) {
        printf.panic("virtio disk has no queue 0");
    }
    if (max < NUM) {
        printf.panic("virtio disk max queue too short");
    }
    R(u32, VIRTIO_MMIO_QUEUE_NUM).* = NUM;
    _ = string.memset(@ptrCast([*]u8, &disk.pages), 0, @sizeOf(u8)*disk.pages.len);
    R(u64, VIRTIO_MMIO_QUEUE_PFN).* = @intCast(u64, @ptrToInt(&disk.pages)) >> riscv.PGSHIFT;

    // desc = pages -- num * virtq_desc
    // avail = pages + 0x40 -- 2 * uint16, then num * uint16
    // used = pages + 4096 -- 2 * uint16, then num * vRingUsedElem

    disk.desc = @ptrCast(*VirtQDesc, &disk.pages);
    disk.avail = @intToPtr(*VirtQAvail, @ptrToInt(&disk.pages) + NUM*@sizeOf(VirtQDesc));
    disk.used = @intToPtr(*VirtQUsed, @ptrToInt(&disk.pages) + riscv.PGSIZE);

    // all NUM descriptors start out unused.
    for (disk.free) |_, i| {
        disk.free[i] = true;
    }

    // plic.c and trap.c arrange for interrupts from VIRTIO0_IRQ.
}

// find a free descriptor, mark it non-free, return its index.
fn alloc_desc() i32 {
    for (disk.free) |*free, i| {
        if (free.*) {
            free.* = false;
            return i;
        }
    }
    return -1;
}

// mark a descriptor as free.
fn free_desc(i: i32) void {
    if (i >= NUM) {
        printf.panic("free_desc 1");
    }
    if (disk.free[i]) {
        printf.panic("free_desc 2");
    }
    disk.desc[i].addr = 0;
    disk.desc[i].len = 0;
    disk.desc[i].flags = 0;
    disk.desc[i].next = 0;
    disk.free[i] = true;
    proc.wakeup(&disk.free[0]);
}

// // free a chain of descriptors.
// static void
// free_chain(int i)
// {
//   while(1){
//     int flag = disk.desc[i].flags;
//     int nxt = disk.desc[i].next;
//     free_desc(i);
//     if(flag & VRING_DESC_F_NEXT)
//       i = nxt;
//     else
//       break;
//   }
// }

// // allocate three descriptors (they need not be contiguous).
// // disk transfers always use three descriptors.
// static int
// alloc3_desc(int *idx)
// {
//   for(int i = 0; i < 3; i++){
//     idx[i] = alloc_desc();
//     if(idx[i] < 0){
//       for(int j = 0; j < i; j++)
//         free_desc(idx[j]);
//       return -1;
//     }
//   }
//   return 0;
// }

// void
// virtio_disk_rw(struct buf *b, int write)
// {
//   uint64 sector = b->blockno * (BSIZE / 512);

//   acquire(&disk.vdisk_lock);

//   // the spec's Section 5.2 says that legacy block operations use
//   // three descriptors: one for type/reserved/sector, one for the
//   // data, one for a 1-byte status result.

//   // allocate the three descriptors.
//   int idx[3];
//   while(1){
//     if(alloc3_desc(idx) == 0) {
//       break;
//     }
//     sleep(&disk.free[0], &disk.vdisk_lock);
//   }

//   // format the three descriptors.
//   // qemu's virtio-blk.c reads them.

//   struct virtio_blk_req *buf0 = &disk.ops[idx[0]];

//   if(write)
//     buf0->type = VIRTIO_BLK_T_OUT; // write the disk
//   else
//     buf0->type = VIRTIO_BLK_T_IN; // read the disk
//   buf0->reserved = 0;
//   buf0->sector = sector;

//   disk.desc[idx[0]].addr = (uint64) buf0;
//   disk.desc[idx[0]].len = sizeof(struct virtio_blk_req);
//   disk.desc[idx[0]].flags = VRING_DESC_F_NEXT;
//   disk.desc[idx[0]].next = idx[1];

//   disk.desc[idx[1]].addr = (uint64) b->data;
//   disk.desc[idx[1]].len = BSIZE;
//   if(write)
//     disk.desc[idx[1]].flags = 0; // device reads b->data
//   else
//     disk.desc[idx[1]].flags = VRING_DESC_F_WRITE; // device writes b->data
//   disk.desc[idx[1]].flags |= VRING_DESC_F_NEXT;
//   disk.desc[idx[1]].next = idx[2];

//   disk.info[idx[0]].status = 0xff; // device writes 0 on success
//   disk.desc[idx[2]].addr = (uint64) &disk.info[idx[0]].status;
//   disk.desc[idx[2]].len = 1;
//   disk.desc[idx[2]].flags = VRING_DESC_F_WRITE; // device writes the status
//   disk.desc[idx[2]].next = 0;

//   // record struct buf for virtio_disk_intr().
//   b->disk = 1;
//   disk.info[idx[0]].b = b;

//   // tell the device the first index in our chain of descriptors.
//   disk.avail->ring[disk.avail->idx % NUM] = idx[0];

//   __sync_synchronize();

//   // tell the device another avail ring entry is available.
//   disk.avail->idx += 1; // not % NUM ...

//   __sync_synchronize();

//   *R(VIRTIO_MMIO_QUEUE_NOTIFY) = 0; // value is queue number

//   // Wait for virtio_disk_intr() to say request has finished.
//   while(b->disk == 1) {
//     sleep(b, &disk.vdisk_lock);
//   }

//   disk.info[idx[0]].b = 0;
//   free_chain(idx[0]);

//   release(&disk.vdisk_lock);
// }

// void
// virtio_disk_intr()
// {
//   acquire(&disk.vdisk_lock);

//   // the device won't raise another interrupt until we tell it
//   // we've seen this interrupt, which the following line does.
//   // this may race with the device writing new entries to
//   // the "used" ring, in which case we may process the new
//   // completion entries in this interrupt, and have nothing to do
//   // in the next interrupt, which is harmless.
//   *R(VIRTIO_MMIO_INTERRUPT_ACK) = *R(VIRTIO_MMIO_INTERRUPT_STATUS) & 0x3;

//   __sync_synchronize();

//   // the device increments disk.used->idx when it
//   // adds an entry to the used ring.

//   while(disk.used_idx != disk.used->idx){
//     __sync_synchronize();
//     int id = disk.used->ring[disk.used_idx % NUM].id;

//     if(disk.info[id].status != 0)
//       panic("virtio_disk_intr status");

//     struct buf *b = disk.info[id].b;
//     b->disk = 0;   // disk is done with buf
//     wakeup(b);

//     disk.used_idx += 1;
//   }

//   release(&disk.vdisk_lock);
// }
