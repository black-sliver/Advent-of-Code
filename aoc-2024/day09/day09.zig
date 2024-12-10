const std = @import("std");
const fmt = std.fmt;
const mem = std.mem;
const math = std.math;
const assert = std.debug.assert;

fn findFreeSpace(fs: []const i16, len: usize) ?usize {
    var start: usize = 0;
    var found: usize = 0;
    while (found < len) {
        start = mem.indexOfScalarPos(i16, fs, start + found, -1) orelse return null;
        const end = mem.indexOfNonePos(i16, fs, start, &[_]i16{-1}) orelse fs.len;
        found = end - start;
    }
    return start;
}

fn checkSum(fs: []const i16) usize {
    var res: u64 = 0;
    const end = if (fs[fs.len-1] == -1) fs.len - 1
            else mem.lastIndexOfNone(i16, fs, &[_]i16{-1}) orelse fs.len - 1;
    for (0..end+1) |i| {
        if (fs[i] < 0) {
            continue;
        }
        const uid: u64 = @intCast(fs[i]);
        res += @as(u64, i) * uid;
    }
    return res;
}

fn printFs(fs: []const i16) void {
    for (fs) |c| {
        if (c == -1) {
            std.debug.print(".", .{});
        } else {
            std.debug.print("{d}", .{c});
        }
    }
    std.debug.print("\n", .{});
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

    var filesystem = try std.ArrayList(i16).initCapacity(allocator, 32768);
    defer filesystem.deinit();

    var id: i16 = 0;
    var first_free: usize = math.maxInt(usize);
    while (true) : (id += 1) {
        const v: u8 = stream.readByte() catch break;
        try filesystem.appendNTimes(id, @intCast(v-0x30));
        const s: u8 = stream.readByte() catch break;
        if (s == '\n') break;
        if (s != '0' and first_free == math.maxInt(usize)) {
            first_free = filesystem.items.len;
        }
        try filesystem.appendNTimes(-1, @intCast(s-0x30));
    }
    var fs2 = try allocator.dupe(i16, filesystem.items);
    std.debug.print("total size: {}\n", .{filesystem.items.len});

    // part1
    var next_free = first_free;
    assert(filesystem.items[filesystem.items.len-1] != -1);
    defrag: for (0..filesystem.items.len) |i| {
        const p = filesystem.items.len - 1 - i;
        if (filesystem.items[p] == -1) {
            continue;
        }
        if (next_free >= p) {
            break :defrag;
        }
        filesystem.items[next_free] = filesystem.items[p];
        filesystem.items[p] = -1;
        next_free += 1;
        while(filesystem.items[next_free] != -1) {
            next_free += 1;
        }
    }
    const checksum1 = checkSum(filesystem.items);

    // part2 - the jank way, instead of keeping a list of free block
    var cursor = fs2.len - 1;
    while (true) {
        const c = fs2[cursor];
        const left = mem.lastIndexOfNone(i16, fs2[0..cursor], &[_]i16{c}) orelse break;
        //     -1 9 9 9 9 9
        // left ^         ^ cur
        const len = cursor - left;
        const start = left + 1;
        if (findFreeSpace(fs2[0..start], len)) |free_pos| {
            mem.copyForwards(i16, fs2[free_pos..], fs2[start..start+len]);
            @memset(fs2[start..start+len], -1);
        }
        if (fs2[left] == -1) {
            cursor = mem.lastIndexOfNone(i16, fs2[0..left], &[_]i16{-1}) orelse break;
        } else {
            cursor = left;
        }
    }
    const checksum2 = checkSum(fs2);

    try stdout.print("Result 1: {d}\n", .{checksum1});
    try stdout.print("Result 2: {d}\n", .{checksum2});
}
