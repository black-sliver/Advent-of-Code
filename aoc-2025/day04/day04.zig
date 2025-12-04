const std = @import("std");
const builtin = @import("builtin");

fn pass(data: []u8, cols: usize, stride: usize, comptime replace: bool) u32 {
    var res: u32 = 0;
    const rows = (data.len + 1) / stride;
    for (0..rows) |y| {
        for (0..cols) |x| {
            if (data[x + y * stride] == '.')
                continue;
            var adject_blocked: usize = 0;
            for (0..3) |off_y| {
                for (0..3) |off_x| {
                    if (off_x == 1 and off_y == 1)
                        continue;
                    if (x + off_x == 0)
                        continue;
                    if (y + off_y == 0)
                        continue;
                    if (x + off_x == cols + 1)
                        continue;
                    if (y + off_y == rows + 1)
                        continue;
                    if (data[x + off_x - 1 + (y + off_y - 1) * stride] != '.')
                        adject_blocked += 1;
                }
            }
            if (adject_blocked < 4) {
                res += 1;
                if (replace)
                    data[x + y * stride] = '.';
            }
        }
    }
    return res;
}

fn part1(data: []u8, cols: usize, stride: usize) u32 {
    return pass(data, cols, stride, false);
}

fn part2(data: []u8, cols: usize, stride: usize) u32 {
    var res: u32 = 0;
    while (true) {
        const sub = pass(data, cols, stride, true);
        if (sub == 0)
            return res;
        res += sub;
    }
}

pub fn main() !void {
    var stdout_buffer: [1024]u8 = undefined;
    var stdout_writer = std.fs.File.stdout().writer(&stdout_buffer);
    const stdout = &stdout_writer.interface;
    defer stdout.flush() catch {};

    var debug_allocator: std.heap.DebugAllocator(.{}) = .init;
    defer if (builtin.mode == .Debug) {
        _ = debug_allocator.deinit();
    };
    const allocator = if (builtin.mode == .Debug) debug_allocator.allocator() else std.heap.smp_allocator;

    var file_buffer: [4096]u8 = undefined;
    const file = try std.fs.cwd().openFile("input.txt", .{});
    defer file.close();
    var reader = file.reader(&file_buffer);
    const file_size = try reader.getSize();
    const data = try reader.interface.readAlloc(allocator, file_size);
    defer allocator.free(data);
    const cols = std.mem.indexOfScalar(u8, data, '\n') orelse @panic("no line break");

    const res1 = part1(data, cols, cols + 1);
    try stdout.print("{}\n", .{res1});
    const res2 = part2(data, cols, cols + 1);
    try stdout.print("{}\n", .{res2});
}

const test_input =
    \\..@@.@@@@.
    \\@@@.@.@.@@
    \\@@@@@.@.@@
    \\@.@@@@..@.
    \\@@.@@@@.@@
    \\.@@@@@@@.@
    \\.@.@.@.@@@
    \\@.@@@.@@@@
    \\.@@@@@@@@.
    \\@.@.@@@.@.
;

test "part1" {
    const in = try std.testing.allocator.dupe(u8, test_input);
    defer std.testing.allocator.free(in);
    try std.testing.expectEqual(13, part1(in, 10, 11));
}

test "part2" {
    const in = try std.testing.allocator.dupe(u8, test_input);
    defer std.testing.allocator.free(in);
    try std.testing.expectEqual(43, part2(in, 10, 11));
}
