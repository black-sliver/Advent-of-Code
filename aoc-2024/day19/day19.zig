const builtin = @import("builtin");
const std = @import("std");
const mem = std.mem;


/// sorts by length
fn lengthSorter(_: void, lhs: []const u8, rhs: []const u8) bool {
    return (lhs.len < rhs.len);
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

    const highest_color: u8 = 'w';
    const colors = "wubrg";
    const expected_towel_count = 447;
    var grouped: [highest_color + 1]std.ArrayList([]const u8) = undefined;
    for (colors) |color| {
        grouped[color] = try std.ArrayList([]const u8).initCapacity(
            allocator,
            (expected_towel_count+colors.len-1)/colors.len
        );
    }

    var max_towel_len: usize = 0;
    var towel_buf: [4096]u8 = undefined;
    if (try stream.readUntilDelimiterOrEof(&towel_buf, '\n')) |line| {
        var it = mem.split(u8, line, ", ");
        while (it.next()) |towel| {
            const g = towel[0];
            try grouped[g].append(towel);
            if (towel.len > max_towel_len) {
                max_towel_len = towel.len;
            }
        }
    }

    for (colors) |color| {
        _ = mem.sortUnstable([]const u8, grouped[color].items, {}, lengthSorter);
    }

    var buf: [64]u8 = undefined;
    _ = try stream.readUntilDelimiterOrEof(&buf, '\n');

    var can_be_made: usize = 0; // <- part1
    var possibilities: usize = 0; // <- part2
    var visit = try std.ArrayList(usize).initCapacity(allocator, max_towel_len);
    var reached = try std.ArrayList(usize).initCapacity(allocator, 64);
    try reached.append(1); // first character always reached once

    while (try stream.readUntilDelimiterOrEof(&buf, '\n')) |pattern| {
        var ok = false; // <- part1
        visit.clearRetainingCapacity();
        try visit.append(0);
        try reached.resize(1); // first character always reached once
        try reached.appendNTimes(0, pattern.len); // extra zero for debugging
        //queue: while (true) { // this for part1
        while (visit.items.len > 0) {
            const pos = visit.items[0];
            const first = pattern[pos];
            _ = visit.orderedRemove(0);
            for (grouped[first].items) |towel| {
                if (towel.len > pattern.len - pos) {
                    continue;
                }
                if (mem.eql(u8, pattern[pos..pos+towel.len], towel)) {
                    const new_end = pos + towel.len;
                    if (new_end == pattern.len) {
                        ok = true;
                        // break :queue; // break here for part 1
                        possibilities += reached.items[pos]; // this is part 2
                    } else {
                        if (mem.indexOfScalar(usize, visit.items, new_end) == null) {
                            try visit.append(new_end);
                            if (visit.items.len > 1) {
                                if (visit.items[visit.items.len - 2] > new_end) {
                                    // TODO: insert in the right spot instead
                                    _ = mem.sortUnstable(usize, visit.items, {}, std.sort.asc(usize));
                                }
                                std.debug.assert(visit.items[visit.items.len - 2] < visit.items[visit.items.len - 1]);
                            }
                        }
                    }
                    reached.items[new_end] += reached.items[pos];
                }
            }
        }
        if (ok) {
            can_be_made += 1; // this is part 1
        }
    }

    try stdout.print("Result1: {d}\n", .{can_be_made});
    try stdout.print("Result2: {d}\n", .{possibilities});
}
