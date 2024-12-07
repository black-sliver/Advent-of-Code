const std = @import("std");
const fmt = std.fmt;
const mem = std.mem;
const DynamicBitSet = std.DynamicBitSet;

const Direction = enum {
    Up,
    Right,
    Down,
    Left,
};

pub fn part1(allocator: std.mem.Allocator, obstacles: std.ArrayList(DynamicBitSet), start_x: usize, start_y: usize, max_step: usize) !struct {
        count: i32,
        visited: std.ArrayList(DynamicBitSet)
} {
    // returns number of unique tiles visisted and the bits
    var x = start_x;
    var y = start_y;
    var dir = Direction.Up;
    var num_visited: i32 = 0;
    const height = obstacles.items.len;
    const width = obstacles.items[0].capacity();
    var visited = try std.ArrayList(DynamicBitSet).initCapacity(allocator, height);
    for (0..height) |_| {
        try visited.append(try DynamicBitSet.initEmpty(allocator, width));
    }

    visited.items[y].set(x);
    num_visited += 1;
    var num_steps: usize = 0;

    while (true) {
        num_steps += 1;
        if (num_steps > max_step)
            return error.Overflow;
        switch (dir) {
            Direction.Up => {
                if (y == 0) {
                    break;
                }
                if (obstacles.items[y - 1].isSet(x)) {
                    dir = Direction.Right;
                } else {
                    y -= 1;
                }
            },
            Direction.Right => {
                if (x == width - 1) {
                    break;
                }
                if (obstacles.items[y].isSet(x + 1)) {
                    dir = Direction.Down;
                } else {
                    x += 1;
                }
            },
            Direction.Down => {
                if (y == height - 1) {
                    break;
                }
                if (obstacles.items[y + 1].isSet(x)) {
                    dir = Direction.Left;
                } else {
                    y += 1;
                }
            },
            Direction.Left => {
                if (x == 0) {
                    break;
                }
                if (obstacles.items[y].isSet(x - 1)) {
                    dir = Direction.Up;
                } else {
                    x -= 1;
                }
            }
        }
        if (!visited.items[y].isSet(x)) {
            visited.items[y].set(x);
            num_visited += 1;
        }
    }

    return .{.count=num_visited, .visited=visited};
}

pub fn part2(allocator: std.mem.Allocator, obstacles: std.ArrayList(DynamicBitSet), start_x: usize, start_y: usize) !i32 {
    // the naive approach
    const height = obstacles.items.len;
    const width = obstacles.items[0].capacity();
    const limit: usize = @intCast(width * height * 2);
    const res1 = try part1(allocator, obstacles, start_x, start_y, limit);
    var res2: i32 = 0;
    for (0..height) |y| {
        for (0..width) |x| {
            if (res1.visited.items[y].isSet(x)
                    and !obstacles.items[y].isSet(x)
                    and (x != start_x or y != start_y)) {
                obstacles.items[y].set(x);
                _ = part1(allocator, obstacles, start_x, start_y, limit) catch |e| {
                    switch (e) {
                        error.Overflow => {
                            res2 += 1;
                        },
                        else => {
                            return e;
                        }
                    }
                };
                obstacles.items[y].unset(x);
            }
        }
    }
    return res2;
}

pub fn main() !void {

    // something in front -> right 90°
    // otherwise step forward

    const stdout = std.io.getStdOut().writer();

    var file = try std.fs.cwd().openFile("input.txt", .{});
    defer file.close();

    var buffered_reader = std.io.bufferedReader(file.reader());
    var stream = buffered_reader.reader();

    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    const allocator = gpa.allocator();

    var start_x: usize = 0;
    var start_y: usize = 0;
    var obstacles = std.ArrayList(DynamicBitSet).init(allocator);

    var buf: [256]u8 = undefined;
    while (try stream.readUntilDelimiterOrEof(&buf, '\n')) |line| {
        var obstacle_row = try DynamicBitSet.initEmpty(allocator, line.len);
        for (line, 0..) |c, x| {
            if (c == '#') {
                obstacle_row.set(x);
            }
            else if (c == '^') {
                start_x = x;
                start_y = obstacles.items.len;
            }
        }
        try obstacles.append(obstacle_row);
    }

    const num_visited_tiles = (try part1(allocator,
        obstacles,
        start_x,
        start_y,
        std.math.maxInt(usize))).count;
    const num_possible_loops = try part2(allocator,
        obstacles,
        start_x,
        start_y);

    try stdout.print("Result 1: {d}\n", .{num_visited_tiles});
    try stdout.print("Result 2: {d}\n", .{num_possible_loops});
}
