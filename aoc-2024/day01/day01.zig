const std = @import("std");

pub fn main() !void {
    const stdout = std.io.getStdOut().writer();

    var file = try std.fs.cwd().openFile("input.txt", .{});
    defer file.close();

    var buffered_reader = std.io.bufferedReader(file.reader());
    var stream = buffered_reader.reader();

    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    const allocator = gpa.allocator();

    var first_list = std.ArrayList(i32).init(allocator);
    var second_list = std.ArrayList(i32).init(allocator);

    var buf: [128]u8 = undefined;
    while (try stream.readUntilDelimiterOrEof(&buf, '\n')) |line| {
        var it = std.mem.split(u8, line, "   ");
        const first = try std.fmt.parseInt(i32, it.next() orelse "", 10);
        const second = try std.fmt.parseInt(i32, it.next() orelse "", 10);
        try first_list.append(first);
        try second_list.append(second);
    }

    const first_slice = try first_list.toOwnedSlice();
    const second_slice = try second_list.toOwnedSlice();

    std.mem.sort(i32, first_slice, {}, std.sort.asc(i32));
    std.mem.sort(i32, second_slice, {}, std.sort.asc(i32));

    var sum: u32 = 0;
    var similarity: i64 = 0;

    for (first_slice, second_slice) |first, second| {
        const diff = @abs(first - second);
        const occurrences: i32 = @intCast(std.mem.count(i32, second_slice, &[_]i32{first}));
        similarity += first * occurrences;
        sum += diff;
    }

    try stdout.print("Result 1: {d}\n", .{sum});
    try stdout.print("Result 2: {d}\n", .{similarity});
}
