const std = @import("std");
const assert = std.debug.assert;

pub fn main() !void {
    const stdout = std.io.getStdOut().writer();

    var file = try std.fs.cwd().openFile("input.txt", .{});
    defer file.close();

    var buffered_reader = std.io.bufferedReader(file.reader());
    var stream = buffered_reader.reader();

    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    const allocator = gpa.allocator();

    var rows = std.ArrayList(std.ArrayList(u8)).init(allocator);

    var buf: [256]u8 = undefined;
    while (try stream.readUntilDelimiterOrEof(&buf, '\n')) |line| {
        var row = std.ArrayList(u8).init(allocator);
        try row.appendSlice(line);
        if (rows.items.len != 0) {
            assert(row.items.len == rows.items[0].items.len);
        }
        try rows.append(row);
    }

    const row_count = rows.items.len;
    const col_count = rows.items[0].items.len;

    // part 1
    var count: usize = 0;
    const needle = "XMAS";
    for (0..row_count) |y| {
        for (0..col_count) |x| {
            if (x + 3 < col_count) {
                for (0..needle.len, x..x + needle.len) |i, x1| {
                    if (rows.items[y].items[x1] != needle[i])
                        break;
                    if (i == 3)
                        count += 1;
                }
                for (0..needle.len, x..x + needle.len) |i, x1| {
                    if (rows.items[y].items[x1] != needle[needle.len - i - 1])
                        break;
                    if (i == 3)
                        count += 1;
                }
            }
            if (y + 3 < row_count) {
                for (0..needle.len, y..y + needle.len) |i, y1| {
                    if (rows.items[y1].items[x] != needle[i])
                        break;
                    if (i == 3)
                        count += 1;
                }
                for (0..needle.len, y..y + needle.len) |i, y1| {
                    if (rows.items[y1].items[x] != needle[needle.len - i - 1])
                        break;
                    if (i == 3)
                        count += 1;
                }
            }
            if (x + 3 < col_count and y + 3 < row_count) {
                for (0..needle.len, x..x + needle.len, y..y + needle.len) |i, x1, y1| {
                    if (rows.items[y1].items[x1] != needle[i])
                        break;
                    if (i == 3)
                        count += 1;
                }
                for (0..needle.len, x..x + needle.len, y..y + needle.len) |i, x1, y1| {
                    if (rows.items[y1].items[x1] != needle[needle.len - i - 1])
                        break;
                    if (i == 3)
                        count += 1;
                }
            }
            if (x >= 3 and y + 3 < row_count) {
                for (0..needle.len, y..y + needle.len) |i, y1| {
                    if (rows.items[y1].items[x-i] != needle[i])
                        break;
                    if (i == 3)
                        count += 1;
                }
                for (0..needle.len, y..y + needle.len) |i, y1| {
                    if (rows.items[y1].items[x-i] != needle[needle.len - i - 1])
                        break;
                    if (i == 3)
                        count += 1;
                }
            }
        }
    }

    // part2
    var proper_count: usize = 0;
    for (1..row_count-1) |y| {
        for (1..col_count-1) |x| {
            if (rows.items[y].items[x] != 'A')
                continue;
            const ctl = rows.items[y-1].items[x-1];
            const ctr = rows.items[y-1].items[x+1];
            const cbl = rows.items[y+1].items[x-1];
            const cbr = rows.items[y+1].items[x+1];
            if (((ctl == 'M' and cbr == 'S') or (ctl == 'S' and cbr == 'M')) and
                    ((ctr == 'M' and cbl == 'S') or (ctr == 'S' and cbl == 'M'))) {
                proper_count += 1;
            }
        }
    }

    try stdout.print("Result 1: {d}\n", .{count});
    try stdout.print("Result 2: {d}\n", .{proper_count});
}
