const std = @import("std");
const CrossTarget = std.zig.CrossTarget;
const FileSource = std.build.FileSource;

pub fn build(b: *std.build.Builder) void {
    const target = CrossTarget{
        .cpu_arch = .riscv64,
        .os_tag = .freestanding,
        .abi = .none,
        //.cpu_features_sub = std.Target.riscv.cpu.baseline_rv32.features,
        //.cpu_features_add = fe310_cpu_feat,
    };

    // Standard release options allow the person running `zig build` to select
    // between Debug, ReleaseSafe, ReleaseFast, and ReleaseSmall.
    const buildMode = b.standardReleaseOptions();

    const kernel = b.addExecutable("valtos.elf", "src/kernel/start.zig");
    kernel.addAssemblyFile("src/kernel/entry.s");
    kernel.addAssemblyFile("src/kernel/kernelvec.s");
    kernel.setTarget(target);
    kernel.setBuildMode(buildMode);
    kernel.setLinkerScriptPath(FileSource{ .path = "src/kernel/kernel.ld" });
    kernel.code_model = .medium;

    const installKernel = b.addInstallArtifact(kernel);
    b.getInstallStep().dependOn(&installKernel.step);

    const run_cmd = kernel.run();
    run_cmd.step.dependOn(b.getInstallStep());

    const run_step = b.step("run", "Run the app");
    run_step.dependOn(&run_cmd.step);

    const kernel_tests = b.addTest("src/kernel/start.zig");
    kernel_tests.setTarget(target);
    kernel_tests.setBuildMode(buildMode);

    const test_step = b.step("test", "Run unit tests");
    test_step.dependOn(&kernel_tests.step);
}
