const std = @import("std");

const Point = @Vector(2, u8);
const TrailHash = std.AutoHashMap(Point, void);
const TrailRating = std.AutoHashMap(Point, u16);

fn findTrailEnds(map: [][]u8, x: usize, y: usize, next: u8, trail_ends: *TrailHash) !void {
    // part1; superseded by findTrailRatings
    if (next == 10) {
        try trail_ends.put(.{@intCast(x), @intCast(y)}, undefined);
        return;
    }
    if (x > 0 and map[y][x-1] == next) {
        try findTrailEnds(map, x-1, y, next+1, trail_ends);
    }
    if (x < map[y].len - 1 and map[y][x+1] == next) {
        try findTrailEnds(map, x+1, y, next+1, trail_ends);
    }
    if (y > 0 and map[y-1][x] == next) {
        try findTrailEnds(map, x, y-1, next+1, trail_ends);
    }
    if (y < map.len - 1 and map[y+1][x] == next) {
        try findTrailEnds(map, x, y+1, next+1, trail_ends);
    }
}

fn findTrailRatings(map: [][]u8, x: usize, y: usize, next: u8, trail_ends: *TrailRating) !void {
    // part2
    if (next == 10) {
        const entry = try trail_ends.getOrPutValue(.{@intCast(x), @intCast(y)}, 0);
        entry.value_ptr.* += 1;
        return;
    }
    if (x > 0 and map[y][x-1] == next) {
        try findTrailRatings(map, x-1, y, next+1, trail_ends);
    }
    if (x < map[y].len - 1 and map[y][x+1] == next) {
        try findTrailRatings(map, x+1, y, next+1, trail_ends);
    }
    if (y > 0 and map[y-1][x] == next) {
        try findTrailRatings(map, x, y-1, next+1, trail_ends);
    }
    if (y < map.len - 1 and map[y+1][x] == next) {
        try findTrailRatings(map, x, y+1, next+1, trail_ends);
    }
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

    var map = std.ArrayList([]u8).init(allocator);
    var width: usize = 0;

    var buf: [128]u8 = undefined;
    while (try stream.readUntilDelimiterOrEof(&buf, '\n')) |line| {
        if (map.items.len == 0) {
            try map.ensureTotalCapacityPrecise(line.len);
            width = line.len;
        }
        var row = try allocator.alloc(u8, line.len);
        for (line, 0..)  |c, i| {
            row[i] = c - '0';
        }
        try map.append(row);
    }

    var sum_trail_points: usize = 0;
    var sum_trail_ratings: usize = 0;
    var trail_ratings = TrailRating.init(allocator);
    for (map.items, 0..) |row, y| {
        for (0..width) |x| {
            if (row[x] == 0) {
                try findTrailRatings(map.items, x, y, 1, &trail_ratings);
                var it = trail_ratings.valueIterator();
                // part1
                sum_trail_points += trail_ratings.count();
                // part2
                while (it.next()) |val| {
                    sum_trail_ratings += val.*;
                }
                trail_ratings.clearRetainingCapacity();
            }
        }
    }

    try stdout.print("Result 1: {d}\n", .{sum_trail_points});
    try stdout.print("Result 2: {d}\n", .{sum_trail_ratings});
}
