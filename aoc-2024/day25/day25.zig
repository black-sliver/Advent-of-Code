const std = @import("std");
const fmt = std.fmt;
const math = std.math;
const mem = std.mem;

const Key = @Vector(5, u8);
const Lock = @Vector(5, u8);

const KeyList = std.ArrayList(Key);
const LockList = std.ArrayList(Lock);

inline fn fits(key: Key, lock: Lock) bool {
    // Important: instead of storing the pin heights for locks, we store the space heights
    return @reduce(.And, lock >= key);
}


pub fn main() !void {
    const stdout = std.io.getStdOut().writer();

    var file = try std.fs.cwd().openFile("input.txt", .{});
    defer file.close();

    var buffered_reader = std.io.bufferedReader(file.reader());
    var stream = buffered_reader.reader();

    var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    defer arena.deinit();
    const allocator = arena.allocator();

    var locks = KeyList.init(allocator);
    var keys = KeyList.init(allocator);

    var buf1: [8]u8 = undefined;
    while (try stream.readUntilDelimiterOrEof(&buf1, '\n')) |starting_line| {
        var buf2: [8]u8 = undefined;
        const is_lock = starting_line[0] == '#';
        var val = Key{0, 0, 0, 0, 0};
        for (0..5) |_| {
            const line = try stream.readUntilDelimiterOrEof(&buf2, '\n') orelse return error.BadInput;
            for (0..5) |p| {
                if (line[p] == '#') {
                    val[p] += 1;
                }
            }
        }
        if (is_lock) {
            try locks.append(Lock{5, 5, 5, 5, 5} - val);
        } else {
            try keys.append(val);
        }
        _ = try stream.readUntilDelimiterOrEof(&buf2, '\n'); // bottom row
        _ = try stream.readUntilDelimiterOrEof(&buf2, '\n'); // blank line
    }

    // part1: this is fine.
    // faster approach may be grouping by first height and only comparing the other 4
    var result1: usize = 0;
    for (keys.items) |key| {
        for (locks.items) |lock| {
            if (fits(key, lock)) {
                result1 += 1;
            }
        }
    }

    try stdout.print("Result1: {d}\n", .{result1});
}