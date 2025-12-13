const std = @import("std");
const builtin = @import("builtin");

const Range = struct {
    first: u64,
    last: u64,
};

// not my favorite solution ever

fn part1(ranges: []const Range) u64 {
    var sum: u64 = 0;
    for (ranges) |range| {
        for (range.first..range.last + 1) |id| {
            const n: u64 = @intCast(id);
            const l = std.math.log10_int(n);
            if (@mod(l, 2) == 0)
                continue;
            const mask: u64 = std.math.pow(u64, 10, (l + 1) / 2);
            const top = n / mask;
            const bot = n % mask;
            if (top == bot) {
                sum += n;
            }
        }
    }
    return sum;
}

fn part2(ranges: []const Range) u64 {
    var sum: u64 = 0;
    for (ranges) |range| {
        for (range.first..range.last + 1) |id| {
            const n: u64 = @intCast(id);
            const l = std.math.log10_int(n) + 1;
            label1: for (2..l + 1) |repetitions| {
                if (l % repetitions != 0) {
                    continue;
                }
                const mask: u64 = std.math.pow(u64, 10, l / repetitions);
                const bot = n % mask;
                var rest = n;
                for (1..repetitions) |_| {
                    rest /= mask;
                    if (rest % mask != bot) {
                        continue :label1;
                    }
                }
                sum += n;
                break;
            }
        }
    }
    return sum;
}

fn readInput(allocator: std.mem.Allocator, ranges: *std.ArrayList(Range)) !void {
    var file_buffer: [4096]u8 = undefined;
    const file = try std.fs.cwd().openFile("input.txt", .{});
    defer file.close();
    var reader = file.reader(&file_buffer);
    while (try reader.interface.takeDelimiter(',')) |line| {
        if (line.len < 2) {
            return error.BadFormat;
        }
        const p = std.mem.indexOfScalar(u8, line, '-') orelse return error.InvalidRange;
        const e = std.mem.lastIndexOfNone(u8, line, "\r\n") orelse continue;
        const range: Range = .{
            .first = try std.fmt.parseInt(u64, line[0..p], 10),
            .last = try std.fmt.parseInt(u64, line[p + 1 .. e + 1], 10),
        };
        try ranges.append(allocator, range);
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

    var ranges: std.ArrayList(Range) = .empty;
    defer ranges.deinit(allocator);
    try readInput(allocator, &ranges);

    const res1 = part1(ranges.items);
    try stdout.print("day02 pt.1: {}\n", .{res1});
    const res2 = part2(ranges.items);
    try stdout.print("day02 pt.2: {}\n", .{res2});
}

const test_input = [_]Range{
    .{ .first = 11, .last = 22 },
    .{ .first = 95, .last = 115 },
    .{ .first = 998, .last = 1012 },
    .{ .first = 1188511880, .last = 1188511890 },
    .{ .first = 222220, .last = 222224 },
    .{ .first = 1698522, .last = 1698528 },
    .{ .first = 446443, .last = 446449 },
    .{ .first = 38593856, .last = 38593862 },
    .{ .first = 565653, .last = 565659 },
    .{ .first = 824824821, .last = 824824827 },
    .{ .first = 2121212118, .last = 2121212124 },
};

test "part1" {
    try std.testing.expectEqual(1227775554, part1(&test_input));
}

test "part2" {
    try std.testing.expectEqual(4174379265, part2(&test_input));
}
