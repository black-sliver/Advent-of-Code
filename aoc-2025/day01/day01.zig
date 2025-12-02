const std = @import("std");
const builtin = @import("builtin");

const Dir = enum {
    L,
    R,
};

const Move = struct {
    dir: Dir,
    distance: i32,
};

fn part1(moves: []const Move) u32 {
    var res: u32 = 0;
    var pos: i32 = 50;
    for (moves) |move| {
        switch (move.dir) {
            .L => {
                pos = @mod(pos - move.distance, 100);
            },
            .R => {
                pos = @mod(pos + move.distance, 100);
            },
        }
        if (pos == 0)
            res += 1;
    }
    return res;
}

fn part2(moves: []const Move) u32 {
    var res: u32 = 0;
    var pos: i32 = 50;
    for (moves) |move| {
        switch (move.dir) {
            .L => {
                // count number of full turns + 1 if we hit 0 or underflow and did not start at 0
                const last_pos = pos;
                res += @intCast(@divTrunc(move.distance, 100));
                pos = @intCast(@mod(pos - move.distance, 100));
                if ((pos == 0 or pos > last_pos) and last_pos != 0)
                    res += 1;
            },
            .R => {
                // count number of overflows
                res += @intCast(@divTrunc(pos + move.distance, 100));
                pos = @intCast(@mod(pos + move.distance, 100));
            },
        }
    }
    return res;
}

fn readInput(allocator: std.mem.Allocator, moves: *std.ArrayList(Move)) !void {
    var file_buffer: [4096]u8 = undefined;
    const file = try std.fs.cwd().openFile("input.txt", .{});
    defer file.close();
    var reader = file.reader(&file_buffer);
    while (try reader.interface.takeDelimiter('\n')) |line| {
        if (line.len < 2) {
            return error.BadFormat;
        }
        var move: Move = undefined;
        if (line.ptr[0] == 'L') {
            move.dir = .L;
        } else if (line.ptr[0] == 'R') {
            move.dir = .R;
        } else {
            return error.InvalidDir;
        }
        move.distance = try std.fmt.parseInt(i32, line[1..], 10);
        if (move.distance < 1) {
            return error.InvalidDistance;
        }
        try moves.append(allocator, move);
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

    var moves: std.ArrayList(Move) = .empty;
    defer moves.deinit(allocator);
    try readInput(allocator, &moves);

    const res1 = part1(moves.items);
    try stdout.print("{}\n", .{res1});
    const res2 = part2(moves.items);
    try stdout.print("{}\n", .{res2});
}

const test_moves = [_]Move{
    .{ .dir = .L, .distance = 68 },
    .{ .dir = .L, .distance = 30 },
    .{ .dir = .R, .distance = 48 },
    .{ .dir = .L, .distance = 5 },
    .{ .dir = .R, .distance = 60 },
    .{ .dir = .L, .distance = 55 },
    .{ .dir = .L, .distance = 1 },
    .{ .dir = .L, .distance = 99 },
    .{ .dir = .R, .distance = 14 },
    .{ .dir = .L, .distance = 82 },
};

test "Part1 Example" {
    try std.testing.expectEqual(3, part1(&test_moves));
}

test "Part2 Example" {
    try std.testing.expectEqual(6, part2(&test_moves));
}
