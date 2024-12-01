const std = @import("std");

pub fn main() !void {
    const stdout = std.io.getStdOut().writer();

    var file = try std.fs.cwd().openFile("input.txt", .{});
    defer file.close();

    var bufferedReader = std.io.bufferedReader(file.reader());
    var stream = bufferedReader.reader();

    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    const allocator = gpa.allocator();

    var firstList = std.ArrayList(i32).init(allocator);
    var secondList = std.ArrayList(i32).init(allocator);

    var buf: [128]u8 = undefined;
    while (try stream.readUntilDelimiterOrEof(&buf, '\n')) |line| {
        var it = std.mem.split(u8, line, "   ");
        const first = try std.fmt.parseInt(i32, it.next() orelse "", 10);
        const second = try std.fmt.parseInt(i32, it.next() orelse "", 10);
        try firstList.append(first);
        try secondList.append(second);
    }

    const firstSlice = try firstList.toOwnedSlice();
    const secondSlice = try secondList.toOwnedSlice();

    std.mem.sort(i32, firstSlice, {}, std.sort.asc(i32));
    std.mem.sort(i32, secondSlice, {}, std.sort.asc(i32));

    var sum: u32 = 0;
    var similarity: i64 = 0;

    for (firstSlice, secondSlice) |first, second| {
        const diff = @abs(first - second);
        const occurences: i32 = @intCast(std.mem.count(i32, secondSlice, &[_]i32{first}));
        similarity += first * occurences;
        sum += diff;
    }

    try stdout.print("Result 1: {d}\n", .{sum});
    try stdout.print("Result 2: {d}\n", .{similarity});
}
