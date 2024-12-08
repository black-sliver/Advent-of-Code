const std = @import("std");
const fmt = std.fmt;
const mem = std.mem;
const math = std.math;
const assert = std.debug.assert;

const Coord = struct {
    const Self = @This();

    x: i32,
    y: i32,

    pub fn Add(self: Self, other: Self) Self {
        return Coord{
            .x = self.x + other.x,
            .y = self.y + other.y,
        };
    }

    pub fn Sub(self: Self, other: Self) Self {
        return Coord{
            .x = self.x - other.x,
            .y = self.y - other.y,
        };
    }
};

const CoordMap = std.AutoHashMap(u8, std.ArrayList(Coord));


fn countAntinodesWrong(allocator: mem.Allocator, width: usize, height: usize, antennas: CoordMap) !usize {
    // part1
    var arena = std.heap.ArenaAllocator.init(allocator);
    defer arena.deinit();
    const arena_allocator = arena.allocator();

    var antinodes = std.ArrayList(std.DynamicBitSet).init(arena_allocator);
    defer antinodes.deinit();
    for (0..height) |_| {
        try antinodes.append(try std.DynamicBitSet.initEmpty(arena_allocator, width));
    }

    var count: usize = 0;

    var it = antennas.valueIterator();
    while (it.next()) |coords| {
        for (coords.items, 0..) |coord1, i| {
            for (coords.items[i+1..]) |coord2| {
                const pairs = [_][2]Coord {.{coord1, coord2}, .{coord2, coord1}};
                for (0..2) |n| {
                    const antinode = pairs[n][0].Sub(pairs[n][1].Sub(pairs[n][0]));
                    if (antinode.y < 0 or antinode.y >= height or antinode.x < 0 or antinode.x >= width)
                        continue;
                    if (antinodes.items[@intCast(antinode.y)].isSet(@intCast(antinode.x)))
                        continue;
                    antinodes.items[@intCast(antinode.y)].set(@intCast(antinode.x));
                    count += 1;

                }
            }
        }
    }

    return count;
}

fn countAntinodesCorrect(allocator: mem.Allocator, width: usize, height: usize, antennas: CoordMap) !usize {
    // part2
    var arena = std.heap.ArenaAllocator.init(allocator);
    defer arena.deinit();
    const arena_allocator = arena.allocator();

    var antinodes = std.ArrayList(std.DynamicBitSet).init(arena_allocator);
    for (0..height) |_| {
        try antinodes.append(try std.DynamicBitSet.initEmpty(arena_allocator, width));
    }

    var count: usize = 0;

    var it = antennas.valueIterator();
    while (it.next()) |coords| {
        for (coords.items) |coord1| {
            for (coords.items) |coord2| {
                const p1 = coord1;
                var p2 = coord2;
                const delta = p2.Sub(p1);
                if (delta.x == 0 and delta.y == 0) {
                    continue;
                }
                while (true) {
                    p2 = p2.Sub(delta);
                    const antinode = p2;
                    if (antinode.y < 0 or antinode.y >= height or antinode.x < 0 or antinode.x >= width)
                        break;
                    if (antinodes.items[@intCast(antinode.y)].isSet(@intCast(antinode.x)))
                        continue;
                    antinodes.items[@intCast(antinode.y)].set(@intCast(antinode.x));
                    count += 1;
                }
            }
        }
    }

    return count;
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

    var antennas = CoordMap.init(allocator);

    var buf: [256]u8 = undefined;
    var height: usize = 0;
    var width: usize = 0;
    while (try stream.readUntilDelimiterOrEof(&buf, '\n')) |line| : (height += 1) {
        if (height == 0) {
            width = line.len;
        } else {
            assert(line.len == width);
        }
        for (line, 0..) |c, x| {
            if (! std.ascii.isAlphanumeric(c)) {
                continue;
            }
            var entry = try antennas.getOrPut(c);
            if (!entry.found_existing) {
                entry.value_ptr.* = std.ArrayList(Coord).init(allocator);
            }
            try entry.value_ptr.append(Coord{.x = @intCast(x), .y = @intCast(height)});
        }
    }

    std.debug.print("w={d}, h={d}, t={d}\n", .{width, height, antennas.count()});

    // part1
    const num_antinodes = try countAntinodesWrong(allocator, width, height, antennas);
    // part2
    const num_actual_antinodes = try countAntinodesCorrect(allocator, width, height, antennas);

    try stdout.print("Result 1: {d}\n", .{num_antinodes});
    try stdout.print("Result 2: {d}\n", .{num_actual_antinodes});
}
