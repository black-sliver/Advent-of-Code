// run/build with -lc -lz3
// i.e. `zig build-exe -OReleaseFast -lc -lz3 main.zig`
const std = @import("std");

const days = [_]type{
    @import("day01/day01.zig"),
    @import("day02/day02.zig"),
    @import("day03/day03.zig"),
    @import("day04/day04.zig"),
    @import("day05/day05.zig"),
    @import("day06/day06.zig"),
    @import("day07/day07.zig"),
    @import("day08/day08.zig"),
    @import("day09/day09.zig"),
    @import("day10/day10.zig"),
    @import("day11/day11.zig"),
    @import("day12/day12.zig"),
};

fn cdDay(comptime day: usize) !void {
    const wd = std.fmt.comptimePrint("day{d:02}", .{day});
    var dir = try std.fs.cwd().openDir(wd, .{});
    defer dir.close();
    try dir.setAsCwd();
}

fn cdParent() !void {
    var dir = try std.fs.cwd().openDir("..", .{});
    defer dir.close();
    try dir.setAsCwd();
}

pub fn main() !void {
    var stdout_buffer: [1024]u8 = undefined;
    var stdout_writer = std.fs.File.stdout().writer(&stdout_buffer);
    const stdout = &stdout_writer.interface;
    defer stdout.flush() catch {};

    var total_ms: f64 = 0;
    inline for (days, 1..) |day, number| {
        defer stdout.flush() catch {};

        try cdDay(number);
        defer cdParent() catch {};

        var t = try std.time.Timer.start();
        try day.main();
        const elapsed = t.read();
        const elapsed_ms = @as(f64, @floatFromInt(elapsed)) / std.time.ns_per_ms;
        total_ms += elapsed_ms;

        try stdout.print("took  {d:8.3} ms\n\n", .{elapsed_ms});
    }
    try stdout.print("=================\ntotal {d:8.3} ms\n", .{total_ms});
}

test {
    std.testing.refAllDecls(@This());
}
