const std = @import("std");
const builtin = @import("builtin");

fn part1(allocator: std.mem.Allocator, data: []const u8) !u32 {
    const width = std.mem.indexOfScalar(u8, data, '\n') orelse return error.InvalidInput;
    const stride = std.mem.indexOfNonePos(u8, data, width + 1, "\r") orelse return error.InvalidInput;
    const height = (data.len + 2) / stride;
    const start_x = std.mem.indexOfScalar(u8, data, 'S') orelse return error.InvalidInput;
    if (start_x >= width) {
        return error.InvalidInput;
    }
    if (height < 2) {
        return error.InvalidInput;
    }
    var beams: std.ArrayList(usize) = .empty;
    defer beams.deinit(allocator);
    try beams.ensureTotalCapacity(allocator, width);
    beams.appendAssumeCapacity(start_x);
    var res: u32 = 0;
    for (1..height) |y| {
        var i: usize = 0;
        while (i < beams.items.len) : (i += 1) {
            const beam_x = beams.items[i];
            if (data[y * stride + beam_x] == '^') {
                // split it
                if (std.mem.indexOfScalar(usize, beams.items, beam_x - 1) != null) {
                    if (std.mem.indexOfScalar(usize, beams.items, beam_x + 1) != null) {
                        // remove it
                        _ = beams.swapRemove(i);
                        i -= 1;
                    } else {
                        beams.items[i] = beam_x + 1;
                    }
                } else {
                    beams.items[i] = beam_x - 1;
                    if (std.mem.indexOfScalar(usize, beams.items, beam_x + 1) == null) {
                        beams.appendAssumeCapacity(beam_x + 1);
                    }
                }
                res += 1;
            }
        }
    }
    return res;
}

fn part2(allocator: std.mem.Allocator, data: []const u8) !u64 {
    const width = std.mem.indexOfScalar(u8, data, '\n') orelse return error.InvalidInput;
    const stride = std.mem.indexOfNonePos(u8, data, width + 1, "\r") orelse return error.InvalidInput;
    const height = (data.len + 2) / stride;
    const start_x = std.mem.indexOfScalar(u8, data, 'S') orelse return error.InvalidInput;
    if (start_x >= width) {
        return error.InvalidInput;
    }
    if (height < 2) {
        return error.InvalidInput;
    }
    var beams: []u64 = try allocator.alloc(u64, width);
    defer allocator.free(beams);
    @memset(beams, 0);
    beams[start_x] = 1;

    for (1..height) |y| {
        var carry: u64 = 0;
        for (0..width) |x| {
            beams[x] += carry;
            carry = 0;
            if (beams[x] > 0) {
                if (data[y * stride + x] == '^') {
                    beams[x - 1] += beams[x];
                    carry = beams[x];
                    beams[x] = 0;
                }
            }
        }
    }
    var res: u64 = 0;
    for (beams) |beam| {
        res += beam;
    }
    return res;
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

    const res1 = try part1(allocator, data);
    try stdout.print("{}\n", .{res1});
    const res2 = try part2(allocator, data);
    try stdout.print("{}\n", .{res2});
}

const test_input =
    \\.......S.......
    \\...............
    \\.......^.......
    \\...............
    \\......^.^......
    \\...............
    \\.....^.^.^.....
    \\...............
    \\....^.^...^....
    \\...............
    \\...^.^...^.^...
    \\...............
    \\..^...^.....^..
    \\...............
    \\.^.^.^.^.^...^.
    \\...............
;

test "part1" {
    try std.testing.expectEqual(21, try part1(std.testing.allocator, test_input));
}

test "part2" {
    try std.testing.expectEqual(40, try part2(std.testing.allocator, test_input));
}
