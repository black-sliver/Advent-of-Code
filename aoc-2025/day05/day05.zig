const std = @import("std");
const builtin = @import("builtin");

const Range = struct {
    first: u64,
    last: u64,
};

fn part1(ranges: []const Range, ids: []const u64) usize {
    var res: usize = 0;
    for (ids) |id| {
        for (ranges) |range| {
            if (id >= range.first and id <= range.last) {
                res += 1;
                break;
            }
        }
    }
    return res;
}

pub fn toTheRightSmaller(_: void, a: Range, b: Range) bool {
    if (a.first > b.first)
        return true;
    if (a.first < b.first)
        return false;
    return a.last < b.last; // this sorts the smaller range to the top
}

fn part2(ranges: []Range) usize {
    // merge ranges
    std.mem.sortUnstable(Range, ranges, {}, toTheRightSmaller);
    for (0..ranges.len - 1) |i| {
        for (i + 1..ranges.len) |j| {
            // if they overlap: merge i into j and clear i
            const source_range = &ranges[i];
            const dest_range = &ranges[j];
            if (source_range.first >= dest_range.first) {
                if (source_range.last <= dest_range.last) {
                    // inside another one
                    source_range.first = 0xffffffffffffffff;
                    break;
                } else if (source_range.first <= dest_range.last + 1) {
                    // extends another one to the right
                    std.debug.assert(source_range.last > dest_range.last);
                    dest_range.last = source_range.last;
                    source_range.first = 0xffffffffffffffff;
                    break;
                }
            }
        }
    }
    // sum up all ranges
    var res: u64 = 0;
    for (ranges) |range| {
        if (range.first > range.last)
            continue; // cleared value
        res += range.last - range.first + 1;
    }
    return res;
}

fn readInput(allocator: std.mem.Allocator, ranges: *std.ArrayList(Range), ids: *std.ArrayList(u64)) !void {
    var file_buffer: [4096]u8 = undefined;
    const file = try std.fs.cwd().openFile("input.txt", .{});
    defer file.close();
    var reader = file.reader(&file_buffer);
    while (try reader.interface.takeDelimiter('\n')) |line| {
        if (line.len == 0) break;
        const p = std.mem.indexOfScalar(u8, line, '-') orelse return error.InvalidRange;
        const range = Range{
            .first = try std.fmt.parseUnsigned(u64, line[0..p], 10),
            .last = try std.fmt.parseUnsigned(u64, line[p + 1 ..], 10),
        };
        try ranges.append(allocator, range);
    }
    while (try reader.interface.takeDelimiter('\n')) |line| {
        try ids.append(allocator, try std.fmt.parseUnsigned(u64, line, 10));
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
    var ids: std.ArrayList(u64) = .empty;
    defer ids.deinit(allocator);

    try readInput(allocator, &ranges, &ids);

    const res1 = part1(ranges.items, ids.items);
    try stdout.print("{}\n", .{res1});
    const res2 = part2(ranges.items);
    try stdout.print("{}\n", .{res2});
}

const test_ranges = [_]Range{
    .{ .first = 3, .last = 5 },
    .{ .first = 10, .last = 14 },
    .{ .first = 16, .last = 20 },
    .{ .first = 12, .last = 18 },
};

const test_ids = [_]u64{
    1,
    5,
    8,
    11,
    17,
    32,
};

test "part1" {
    try std.testing.expectEqual(3, part1(&test_ranges, &test_ids));
}

test "part2" {
    const test_ranges_copy = try std.testing.allocator.dupe(Range, &test_ranges);
    defer std.testing.allocator.free(test_ranges_copy);
    try std.testing.expectEqual(14, part2(test_ranges_copy));
}
