const std = @import("std");
const fmt = std.fmt;
const math = std.math;
const mem = std.mem;
const testing = std.testing;

const Point = @Vector(2, u16);
const CoordSet = std.AutoArrayHashMap(Point, void);
const RegionCoordList = std.ArrayList(CoordSet);
const down = Point{0, 1};
const right = Point{1, 0};

fn findRegion(val: u8, input: [][]const u8, pos: Point, output: *CoordSet) !void {
    // both part 1 and 2
    if (input[@intCast(pos[1])][@intCast(pos[0])] != val or output.contains(pos)) {
        return;
    }
    try output.put(pos, undefined);
    if (pos[0] > 0) {
        try findRegion(val, input, pos - right, output);
    }
    if (pos[0] < input[0].len - 1) {
        try findRegion(val, input, pos + right, output);
    }
    if (pos[1] > 0) {
        try findRegion(val, input, pos - down, output);
    }
    if (pos[1] < input.len - 1) {
        try findRegion(val, input, pos + down, output);
    }
}

fn getPerimeter(region: *const CoordSet, input: [][]const u8) usize {
    // part of part 1
    const coords = region.keys();
    var sum: usize = 0;
    const val = input[@intCast(coords[0][1])][@intCast(coords[0][0])];
    const width = input[0].len;
    const height = input.len;
    for (coords) |coord| {
        if (coord[0] == 0) {
            sum += 1;
        } else {
            const next_coord = coord - right;
            const next_val = input[@intCast(next_coord[1])][@intCast(next_coord[0])];
            if (next_val != val) {
                sum += 1;
            }
        }
        if (coord[1] == 0) {
            sum += 1;
        } else {
            const next_coord = coord - down;
            const next_val = input[@intCast(next_coord[1])][@intCast(next_coord[0])];
            if (next_val != val) {
                sum += 1;
            }
        }
        if (coord[0] == width - 1) {
            sum += 1;
        } else {
            const next_coord = coord + right;
            const next_val = input[@intCast(next_coord[1])][@intCast(next_coord[0])];
            if (next_val != val) {
                sum += 1;
            }
        }
        if (coord[1] == height - 1) {
            sum += 1;
        } else {
            const next_coord = coord + down;
            const next_val = input[@intCast(next_coord[1])][@intCast(next_coord[0])];
            if (next_val != val) {
                sum += 1;
            }
        }
    }
    return sum;
}

fn getSides(region: *const CoordSet, input: [][]const u8) usize {
    // part of part 2
    // definitely not the fastest solution
    const coords = region.keys();
    const width = input[0].len;
    const height = input.len;
    var min_x: u16 = coords[0][0];
    var max_x: u16 = min_x;
    var min_y: u16 = coords[0][1];
    var max_y: u16 = min_y;
    for (coords[1..]) |coord| {
        if (coord[0] < min_x) {
            min_x = coord[0];
        }
        if (coord[0] > max_x) {
            max_x = coord[0];
        }
        if (coord[1] < min_y) {
            min_y = coord[1];
        }
        if (coord[1] > max_y) {
            max_y = coord[1];
        }
    }

    var total_sides: usize = 0;
    // all rows, all horizontal fences
    for (min_y..max_y+2) |y| {
        var was_fence: u2 = 0;
        for (min_x..max_x+1) |x| {
            const coord = Point{@intCast(x), @intCast(y)};
            const top_val: bool = (y != 0) and region.contains(coord - down);
            const bot_val: bool = (y != height) and region.contains(coord);
            const is_top_fence = !top_val and bot_val;
            const is_bot_fence = top_val and !bot_val;
            if (was_fence != 1 and is_top_fence) {
                total_sides += 1;
                was_fence = 1; // top fence
            } else if (was_fence != 2 and is_bot_fence) {
                total_sides += 1;
                was_fence = 2; // bottom fence
            } else if (!is_top_fence and !is_bot_fence) {
                was_fence = 0; // neither
            }
        }
    }
    // all columns, all vertical fences
    for (min_x..max_x+2) |x| {
        var was_fence: u2 = 0;
        for (min_y..max_y+1) |y| {
            const coord = Point{@intCast(x), @intCast(y)};
            const left_val: bool = (x != 0) and region.contains(coord - right);
            const right_val: bool = (x != width) and region.contains(coord);
            const is_left_fence = !left_val and right_val;
            const is_right_fence = left_val and !right_val;
            if (was_fence != 1 and is_left_fence) {
                total_sides += 1;
                was_fence = 1; // top fence
            } else if (was_fence != 2 and is_right_fence) {
                total_sides += 1;
                was_fence = 2; // bottom fence
            } else if (!is_left_fence and !is_right_fence) {
                was_fence = 0; // neither
            }
        }
    }
    return total_sides;
}

fn getPrice(base_allocator: mem.Allocator, input: [][]const u8,
            comptime getBasePrice: fn (region: *const CoordSet, input: [][]const u8) usize) !usize {
    // both part 1 and 2
    var arena = std.heap.ArenaAllocator.init(base_allocator);
    defer arena.deinit();
    const allocator = arena.allocator();

    var sum: usize = 0;

    var visitedCoords = CoordSet.init(allocator);
    var regionsCoords = RegionCoordList.init(allocator);

    for (input, 0..) |row, y| {
        for (0..row.len) |x| {
            const pos = Point{@intCast(x), @intCast(y)};
            if (visitedCoords.contains(pos)) {
                continue;
            }
            const val: u8 = row[x];
            var region = CoordSet.init(allocator);
            try findRegion(val, input, pos, &region);
            for (region.keys()) |coord| {
                try visitedCoords.put(coord, undefined);
            }
            try regionsCoords.append(region);
        }
    }

    for (regionsCoords.items) |region| {
        const coords = region.keys();
        const base_price = getBasePrice(&region, input);
        sum += coords.len * base_price;
    }

    return sum;
}

test "sample1" {
    var input = [_][]const u8 {
        "AAAA",
        "BBCD",
        "BBCC",
        "EEEC",
    };
    const price1 = try getPrice(testing.allocator, &input, getPerimeter);
    const price2 = try getPrice(testing.allocator, &input, getSides);
    try testing.expectEqual(140, price1);
    try testing.expectEqual(80, price2);
}

test "sample2" {
    var input = [_][]const u8 {
        "OOOOO",
        "OXOXO",
        "OOOOO",
        "OXOXO",
        "OOOOO",
    };
    const price1 = try getPrice(testing.allocator, &input, getPerimeter);
    const price2 = try getPrice(testing.allocator, &input, getSides);
    try testing.expectEqual(772, price1);
    try testing.expectEqual(436, price2);
}

test "sample3" {
    var input = [_][]const u8 {
        "EEEEE",
        "EXXXX",
        "EEEEE",
        "EXXXX",
        "EEEEE",
    };
    const price2 = try getPrice(testing.allocator, &input, getSides);
    try testing.expectEqual(236, price2);
}

test "sample4" {
    var input = [_][]const u8 {
        "AAAAAA",
        "AAABBA",
        "AAABBA",
        "ABBAAA",
        "ABBAAA",
        "AAAAAA",
    };
    const price2 = try getPrice(testing.allocator, &input, getSides);
    try testing.expectEqual(368, price2);
}

test "sample5" {
    var input = [_][]const u8 {
        "RRRRIICCFF",
        "RRRRIICCCF",
        "VVRRRCCFFF",
        "VVRCCCJFFF",
        "VVVVCJJCFE",
        "VVIVCCJJEE",
        "VVIIICJJEE",
        "MIIIIIJJEE",
        "MIIISIJEEE",
        "MMMISSJEEE",
    };
    const price2 = try getPrice(testing.allocator, &input, getSides);
    try testing.expectEqual(1206, price2);
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

    var fields = std.ArrayList([]u8).init(allocator);

    var buf: [256]u8 = undefined;
    while (try stream.readUntilDelimiterOrEof(&buf, '\n')) |line| {
        if (fields.items.len == 0) {
            try fields.ensureTotalCapacityPrecise(line.len);
        }
        try fields.append(try allocator.dupe(u8, line));
    }

    // part 1
    const total_price_standard: usize = try getPrice(allocator, fields.items, getPerimeter);
    // part 2
    const total_price_discount: usize = try getPrice(allocator, fields.items, getSides);

    try stdout.print("Result 1: {d}\n", .{total_price_standard});
    try stdout.print("Result 2: {d}\n", .{total_price_discount});
}
