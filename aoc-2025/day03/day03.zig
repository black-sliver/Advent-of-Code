const std = @import("std");
const builtin = @import("builtin");

fn maxJolts(bank: []const u8) u32 {
    const first_pos = std.mem.indexOfMax(u8, bank[0 .. bank.len - 1]);
    const secoond_pos = std.mem.indexOfMax(u8, bank[first_pos + 1..]) + first_pos + 1;
    const res = (bank[first_pos] - '0') * 10 + bank[secoond_pos] - '0';
    return res;
}

fn maxJoltsEx(bank: []const u8, comptime active: usize) u64 {
    var res: u64 = 0;
    var next_start: usize = 0;
    for (0..active) |i| {
        const remaining = active - 1 - i;
        const end = bank.len - remaining;
        const pos = std.mem.indexOfMax(u8, bank[next_start..end]) + next_start;
        res *= 10;
        res += bank[pos] - '0';
        next_start = pos + 1;
    }
    return res;
}

fn part1(banks: []const []const u8) u32 {
    var res: u32 = 0;
    for (banks) |bank| {
        res += maxJolts(bank);
    }
    return res;
}

fn part2(banks: []const []const u8) u64 {
    var res: u64 = 0;
    for (banks) |bank| {
        res += maxJoltsEx(bank, 12);
    }
    return res;
}

fn readInput(allocator: std.mem.Allocator, data: *std.ArrayList([]u8)) !void {
    var file_buffer: [4096]u8 = undefined;
    const file = try std.fs.cwd().openFile("input.txt", .{});
    defer file.close();
    var reader = file.reader(&file_buffer);
    while (try reader.interface.takeDelimiter('\n')) |line| {
        try data.append(allocator, try allocator.dupe(u8, line));
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

    var banks: std.ArrayList([]u8) = .empty;
    defer banks.deinit(allocator);
    defer for (banks.items) |bank| allocator.free(bank);
    try readInput(allocator, &banks);

    const res1 = part1(banks.items);
    try stdout.print("{}\n", .{res1});
    const res2 = part2(banks.items);
    try stdout.print("{}\n", .{res2});
}

const test_input = [_][]const u8 {
    "987654321111111",
    "811111111111119",
    "234234234234278",
    "818181911112111",
};

test "part1" {
    try std.testing.expectEqual(357, part1(&test_input));
}

test "part2" {
    try std.testing.expectEqual(3121910778619, part2(&test_input));
}
