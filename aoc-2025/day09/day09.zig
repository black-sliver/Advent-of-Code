const std = @import("std");
const builtin = @import("builtin");

const Coord = @Vector(2, i64);

fn part1(coords: []const Coord) u64 {
    var max: u64 = 0;
    for (coords, 0..) |a, i| {
        for (coords[i+1..]) |b| {
            const one = @Vector(2, u64){1, 1};
            const d = @abs(a - b);
            const area = @reduce(.Mul, d + one);
            if (area > max) {
                max = area;
            }
        }
    }
    return max;
}

fn isValid(a: Coord, b: Coord, coords: []const Coord) bool {
    // could presort and cache all edges by x and y and do binary search
    const xmin = @min(a[0], b[0]);
    const xmax = @max(a[0], b[0]);
    const ymin = @min(a[1], b[1]);
    const ymax = @max(a[1], b[1]);
    for (0..coords.len) |i| {
        const j = if (i == coords.len - 1) 0 else i + 1;
        const c = coords[i];
        const d = coords[j];
        if (c[0] == d[0]) {
            // up/down
            if (c[0] > xmin and c[0] < xmax) {
                const ysmall = @min(c[1], d[1]);
                const ybig = @max(c[1], d[1]);
                // for edge y=ymin check if there is a line going +y between xmin and xmax
                if (ysmall <= ymin and ybig > ymin) {
                    return false;
                }
                // for edge y=ymax check if there is a line going -y between xmin and xmax
                if (ybig >= ymax and ysmall < ymax) {
                    return false;
                }
            }
        } else {
            // left/right
            if (c[1] > ymin and c[1] < ymax) {
                const xsmall = @min(c[0], d[0]);
                const xbig = @max(c[0], d[0]);
                // for edge x=xmin check if there is a line going +x between ymin and ymax
                if (xsmall <= xmin and xbig > xmin) {
                    return false;
                }
                // for edge x=xmax check if there is a line going -x between ymin and ymax
                if (xbig >= xmax and xsmall < xmax) {
                    return false;
                }
            }
        }
    }
    return true;
}

fn part2(coords: []const Coord) u64 {
    // i'm sure there is gonna be an algorithm that walks the edge, but i couldn't find it :S
    // but this is plenty fast with 14ms with -OReleaseFast
    var max: u64 = 0;
    for (coords, 0..) |a, i| {
        for (coords[i+1..]) |b| {
            const one = @Vector(2, u64){1, 1};
            const d = @abs(a - b);
            const area = @reduce(.Mul, d + one);
            if (area > max) {
                if (isValid(a, b, coords)) {
                    max = area;
                }
            }
        }
    }
    return max;
}

fn readInput(allocator: std.mem.Allocator, coords: *std.ArrayList(Coord)) !void {
    var file_buffer: [4096]u8 = undefined;
    const file = try std.fs.cwd().openFile("input.txt", .{});
    defer file.close();
    var reader = file.reader(&file_buffer);
    while (try reader.interface.takeDelimiter('\n')) |line| {
        var it = std.mem.splitScalar(u8, line, ',');
        const coord = Coord{
            try std.fmt.parseInt(i64, it.next() orelse return error.InvalidInput, 10),
            try std.fmt.parseInt(i64, it.next() orelse return error.InvalidInput, 10),
        };
        try coords.append(allocator, coord);
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

    var coords: std.ArrayList(Coord) = .empty;
    defer coords.deinit(allocator);

    try readInput(allocator, &coords);

    const res1 = part1(coords.items);
    try stdout.print("{}\n", .{res1});
    const res2 = part2(coords.items);
    try stdout.print("{}\n", .{res2});
}

const test_input = [_]Coord{
    .{ 7,1 },
    .{ 11,1 },
    .{ 11,7 },
    .{ 9,7 },
    .{ 9,5 },
    .{ 2,5 },
    .{ 2,3 },
    .{ 7,3 },
};

test "part1" {
    try std.testing.expectEqual(50, part1(&test_input));
}

test "part2" {
    try std.testing.expectEqual(24, part2(&test_input));
}
