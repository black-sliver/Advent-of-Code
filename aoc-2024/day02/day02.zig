const std = @import("std");

const SafetyLevel = enum {
    unsafe,
    safe,
    still_safe,
};

pub fn isSafe(levels: std.ArrayList(i32), skip: i32) bool {
    var prev: i32 = undefined;
    var first: bool = true;
    var dir: i32 = 0;
    for (levels.items, 0..) |level, i| {
        if (i == skip)
            continue;
        if (first) {
            prev = level;
            first = false;
            continue;
        }
        if (dir == 0 and level > prev) {
            dir = 1;
        } else if (dir == 0 and level < prev) {
            dir = -1;
        } else if (dir == 0) {
            return false;
        }
        const diff: i32 = (level - prev) * dir;
        if (diff < 1 or diff > 3) {
            return false;
        }

        prev = level;
    }
    return true;
}

pub fn reportSafety(line: []u8) !SafetyLevel {
    var it = std.mem.split(u8, line, " ");

    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    const allocator = gpa.allocator();
    var list = std.ArrayList(i32).init(allocator);

    while (it.next()) |col| {
        try list.append(try std.fmt.parseInt(i32, col, 10));
    }
    if (isSafe(list, -1))
        return SafetyLevel.safe;
    for (0..list.items.len) |i| {
        if (isSafe(list, @intCast(i))) {
            return SafetyLevel.still_safe;
        }
    }
    return SafetyLevel.unsafe;
}

pub fn main() !void {
    const stdout = std.io.getStdOut().writer();

    var file = try std.fs.cwd().openFile("input.txt", .{});
    defer file.close();

    var buffered_reader = std.io.bufferedReader(file.reader());
    var stream = buffered_reader.reader();

    var totally_safe_count: i32 = 0;
    var still_safe_count: i32 = 0;

    var buf: [128]u8 = undefined;
    while (try stream.readUntilDelimiterOrEof(&buf, '\n')) |line| {
        switch(reportSafety(line) catch |err| {
            try stdout.print("Invalid line: {s}: {s}\n", .{line, @errorName(err)});
            std.posix.exit(1);
        }) {
            SafetyLevel.safe => {
                totally_safe_count += 1;
                still_safe_count += 1;
            },
            SafetyLevel.still_safe => {
                still_safe_count += 1;
            },
            SafetyLevel.unsafe => {},
        }
    }

    try stdout.print("Result 1: {d}\n", .{totally_safe_count});
    try stdout.print("Result 2: {d}\n", .{still_safe_count});
}
