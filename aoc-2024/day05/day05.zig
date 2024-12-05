const std = @import("std");
const fmt = std.fmt;
const mem = std.mem;

fn isOrdered(update: []const i32, orderings: []const [2]i32) bool {
    // for each page in the update, we check if it's first in any ordering
    // and if so, we checck that second of the ordering does not exist before it
    for (0.., update) |i, page| {
        for (orderings) |ordering| {
            if (page == ordering[0]) {
                for (update[0..i]) |page_before| {
                    if (page_before == ordering[1]) {
                        return false;
                    }
                }
            }
        }
    }
    return true;
}

fn getCenter(update: []const i32) i32 {
    return update[update.len / 2];
}

fn hasPair(haystack: []const [2]i32, needle: [2]i32) bool {
    for (haystack) |hay| {
        if (mem.eql(i32, &hay, &needle))
            return true;
    }
    return false;
}

fn printBefore(orderings: []const [2]i32, lhs: i32, rhs: i32) bool {
    // returns true if lhs should be printed before rhs
    if (hasPair(orderings, .{lhs, rhs})) {
        return true;
    }
    return false;
}

fn order(update: []i32, orderings: []const [2]i32) void {
    mem.sort(i32, update, orderings, printBefore);
}

pub fn main() !void {
    const stdout = std.io.getStdOut().writer();

    var file = try std.fs.cwd().openFile("input.txt", .{});
    defer file.close();

    var buffered_reader = std.io.bufferedReader(file.reader());
    var stream = buffered_reader.reader();

    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    const allocator = gpa.allocator();

    var sum_preordered: i32 = 0;
    var sum_reordered: i32 = 0;

    var ordering = std.ArrayList([2]i32).init(allocator);
    var buf: [128]u8 = undefined;
    while (try stream.readUntilDelimiterOrEof(&buf, '\n')) |line| {
        if (mem.eql(u8, line, "")) {
            break;
        }
        var it = mem.split(u8, line, "|");
        const first = try fmt.parseInt(i32, it.next() orelse "", 10);
        const second = try fmt.parseInt(i32, it.next() orelse "", 10);
        try ordering.append(.{first, second});
    }
    while (try stream.readUntilDelimiterOrEof(&buf, '\n')) |line| {
        var update = std.ArrayList(i32).init(allocator);
        var it = std.mem.split(u8, line, ",");
        while (it.next()) |page| {
            try update.append(try fmt.parseInt(i32, page, 10));
        }
        if (isOrdered(update.items, ordering.items)) {
            // part1
            sum_preordered += getCenter(update.items);
        } else {
            // part2
            order(update.items, ordering.items);
            sum_reordered += getCenter(update.items);
        }
    }

    try stdout.print("Result 1: {d}\n", .{sum_preordered});
    try stdout.print("Result 2: {d}\n", .{sum_reordered});
}
