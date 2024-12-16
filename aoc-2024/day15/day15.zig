const std = @import("std");
const testing = std.testing;


const Tile = enum {
    empty,
    box,
    wall,
    attach
};

const Row = std.ArrayList(Tile);
const Map = std.ArrayList(Row);
const I = i16;
const Coord = @Vector(2, I);


// part 1
fn move(map: *Map, from: Coord, dir: Coord) bool {
    var objects: I = 0;
    var next = from;
    while (true) : (next += dir)  {
        const tile = map.items[@intCast(next[1])].items[@intCast(next[0])];
        switch (tile) {
            Tile.wall => return false,
            Tile.box => objects += 1,
            Tile.empty => break,
            else => {},
        }
    }

    const end = from + dir * Coord{objects, objects};
    map.items[@intCast(end[1])].items[@intCast(end[0])] = Tile.box;
    map.items[@intCast(from[1])].items[@intCast(from[0])] = Tile.empty;

    return true;
}

// part 2
fn move2(map: *Map, from: Coord, dir: Coord) bool {
    if (dir[0] == 0) {
        return move2Y(map, from, dir);
    } else {
        return move2X(map, from, dir);
    }
}

fn move2Y(map: *Map, from: Coord, dir: Coord) bool {
    const tile = map.items[@intCast(from[1])].items[@intCast(from[0])];
    var other_tile: Tile = undefined;
    var other: Coord = undefined;
    switch (tile) {
        Tile.empty => return true,
        Tile.wall => return false,
        Tile.box => {
            other = from + Coord{1, 0};
            other_tile = Tile.attach;
        },
        Tile.attach => {
            other = from + Coord{-1, 0};
            other_tile = Tile.box;
        },
    }
    const to = from + dir;
    const to2 = other + dir;
    const next_tile = map.items[@intCast(to[1])].items[@intCast(to[0])];
    if (next_tile != tile) {
        // if next object is not aligned, we have to first check all connected objects
        if (!canMove2Y(map, to, dir) or !canMove2Y(map, to2, dir)) {
            return false;
        }
        move2YUnchecked(map, to, dir);
        move2YUnchecked(map, to2, dir);
    } else if (!move2Y(map, to, dir)) {
        // otherwise we can just recurse
        return false;
    }
    map.items[@intCast(from[1])].items[@intCast(from[0])] = Tile.empty;
    map.items[@intCast(other[1])].items[@intCast(other[0])] = Tile.empty;
    map.items[@intCast(to[1])].items[@intCast(to[0])] = tile;
    map.items[@intCast(to2[1])].items[@intCast(to2[0])] = other_tile;
    return true;
}

fn canMove2Y(map: *Map, from: Coord, dir: Coord) bool {
    const tile = map.items[@intCast(from[1])].items[@intCast(from[0])];
    var other: Coord = undefined;
    switch (tile) {
        Tile.empty => return true,
        Tile.wall => return false,
        Tile.box => other = from + Coord{1, 0},
        Tile.attach => other = from + Coord{-1, 0},
    }
    const to = from + dir;
    const to2 = other + dir;
    const next_tile = map.items[@intCast(to[1])].items[@intCast(to[0])];
    if (next_tile != tile and !canMove2Y(map, to2, dir)) {
        // if unaligned, check the other side
        return false;
    }
    return canMove2Y(map, to, dir);
}

fn move2YUnchecked(map: *Map, from: Coord, dir: Coord) void {
    const tile = map.items[@intCast(from[1])].items[@intCast(from[0])];
    var other_tile: Tile = undefined;
    var other: Coord = undefined;
    switch (tile) {
        Tile.box => {
            other = from + Coord{1, 0};
            other_tile = Tile.attach;
        },
        Tile.attach => {
            other = from + Coord{-1, 0};
            other_tile = Tile.box;
        },
        else => return, // done
    }
    const to = from + dir;
    const to2 = other + dir;
    const next_tile = map.items[@intCast(to[1])].items[@intCast(to[0])];
    move2YUnchecked(map, to, dir);
    if (next_tile != tile) {
        // if unaligned, move the other side
        move2YUnchecked(map, to2, dir);
    }
    map.items[@intCast(from[1])].items[@intCast(from[0])] = Tile.empty;
    map.items[@intCast(other[1])].items[@intCast(other[0])] = Tile.empty;
    map.items[@intCast(to[1])].items[@intCast(to[0])] = tile;
    map.items[@intCast(to2[1])].items[@intCast(to2[0])] = other_tile;
}

fn move2X(map: *Map, from: Coord, dir: Coord) bool {
    var objects: usize = 0;
    var next: Coord = undefined;

    next = from;
    while (true) : (next += dir) {
        const tile = map.items[@intCast(next[1])].items[@intCast(next[0])];
        switch (tile) {
            Tile.wall => return false,
            Tile.box => objects += 1,
            Tile.empty => break,
            else => {},
        }
    }

    map.items[@intCast(from[1])].items[@intCast(from[0])] = Tile.empty;
    next = from + dir;
    if (dir[0] < 0) {
        next += dir; // box, not attach
    }
    for (0..objects) |_| {
        map.items[@intCast(next[1])].items[@intCast(next[0])] = Tile.box;
        map.items[@intCast(next[1])].items[@intCast(next[0]+1)] = Tile.attach;
        next += dir;
        next += dir;
    }

    return true;
}

// helper
fn calculateGpsSum(map: *const Map) usize {
    var sum: usize = 0;
    for (map.items, 0..) |row, y| {
        for (row.items, 0..) |tile, x| {
            if (tile == Tile.box) {
                const gps = 100 * y + x;
                sum += gps;
            }
        }
    }
    return sum;
}

fn dirFromChar(c: u8) Coord {
    if (c == '<') {
        return Coord{-1, 0};
    } else if (c == '^') {
        return Coord{0, -1};
    } else if (c == '>') {
        return Coord{1, 0};
    } else if (c == 'v') {
        return Coord{0, 1};
    } else {
        std.debug.assert(false);
        return Coord{0, 0};
    }
}

fn parseRow(line: []const u8, row: *Row, row2: *Row, robot: *Coord, y: usize) !void {
    for (line) |c| {
        if (c == '.') {
            try row.append(Tile.empty);
            try row2.append(Tile.empty);
            try row2.append(Tile.empty);
        } else if (c == '#') {
            try row.append(Tile.wall);
            try row2.append(Tile.wall);
            try row2.append(Tile.wall);
        } else if (c == 'O') {
            try row.append(Tile.box);
            try row2.append(Tile.box);
            try row2.append(Tile.attach);
        } else if (c == '@') {
            robot[0] = @intCast(row.items.len);
            robot[1] = @intCast(y);
            try row.append(Tile.empty);
            try row2.append(Tile.empty);
            try row2.append(Tile.empty);
        } else {
            std.debug.assert(false);
        }
    }
}

// debug
fn waitForEnter() void {
    const stdin = std.io.getStdIn().reader();
    var tmp: [1]u8 = undefined;
    _ = stdin.readUntilDelimiterOrEof(&tmp, '\n') catch return;
}

fn printMap(map: *Map, robot: Coord, arrow: u8) void {
    for (map.items, 0..) |row, y| {
        for (row.items, 0..) |tile, x| {
            const c: u8 = if (y == robot[1] and x == robot[0] and tile != Tile.empty)
                'X'
            else if (y == robot[1] and x == robot[0])
                    arrow
                else if (tile == Tile.box)
                        '['
                    else if (tile == Tile.attach)
                            ']'
                        else if (tile == Tile.wall)
                                '#'
                            else
                                '.';
            std.debug.print("{c}", .{c});
        }
        std.debug.print("\n", .{});
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

    var map1 = Map.init(allocator);
    var map2 = Map.init(allocator);
    var robot_start: Coord = undefined;

    var buf: [1024]u8 = undefined;
    while (try stream.readUntilDelimiterOrEof(&buf, '\n')) |line| {
        if (map1.capacity == 0) {
            try map1.ensureTotalCapacityPrecise(line.len);
            try map2.ensureTotalCapacityPrecise(line.len);
        }
        if (line.len == 0) {
            break;
        }
        var row = try Row.initCapacity(allocator, line.len);
        var row2 = try Row.initCapacity(allocator, line.len * 2);
        try parseRow(line, &row, &row2, &robot_start, map1.items.len);
        try map1.append(row);
        try map2.append(row2);
    }
    var robot1 = robot_start;
    var robot2 = robot_start*Coord{2, 1};
    while (try stream.readUntilDelimiterOrEof(&buf, '\n')) |line| {
        for (line) |c| {
            const direction: Coord = dirFromChar(c);
            // part 1
            if (move(&map1, robot1 + direction, direction)) {
                robot1 += direction;
            }
            // part 2
            if (move2(&map2, robot2 + direction, direction)) {
                robot2 += direction;
            }
        }
    }

    const gps_sum1: usize = calculateGpsSum(&map1);
    const gps_sum2: usize = calculateGpsSum(&map2);

    try stdout.print("Result 1: {d}\n", .{gps_sum1});
    try stdout.print("Result 2: {d}\n", .{gps_sum2});
}


test "move2" {
    var map = Map.init(testing.allocator);
    defer {
        for (map.items) |row| {
            row.deinit();
        }
        map.deinit();
    }

    const input = [_][]const u8{
        "##########",
        "#  [][]@##",
        "##  [][]##",
        "##      ##",
        "## [][] ##",
        "##  []  ##",
    };

    for (input) |line| {
        var row = try Row.initCapacity(testing.allocator, 10);
        // ## [][]@##
        for (line) |c| {
            if (c == '[') {
                try row.append(Tile.box);
            } else if (c == ']') {
                try row.append(Tile.attach);
            } else if (c == '#') {
                try row.append(Tile.wall);
            } else {
                try row.append(Tile.empty);
            }
        }
        try map.append(row);
    }
    const data = map.items[1].items;
    std.debug.print("{any}\n", .{data});
    try testing.expect(move2(&map, Coord{6, 1}, Coord{-1, 0}));
    std.debug.print("{any}\n", .{data});
    try testing.expectEqual(Tile.box, data[2]);
    try testing.expectEqual(Tile.attach, data[3]);
    try testing.expectEqual(Tile.box, data[4]);
    try testing.expectEqual(Tile.attach, data[5]);
    try testing.expectEqual(Tile.empty, data[6]);
    try testing.expect(move2(&map, Coord{5, 1}, Coord{-1, 0}));
    try testing.expectEqual(Tile.empty, data[5]);
    try testing.expect(!move2(&map, Coord{4, 1}, Coord{-1, 0}));
    try testing.expect(move2(&map, Coord{1, 1}, Coord{1, 0}));
    try testing.expectEqual(Tile.attach, data[5]);
    try testing.expectEqual(Tile.empty, data[6]);
    try testing.expect(move2(&map, Coord{2, 1}, Coord{1, 0}));
    std.debug.print("{any}\n", .{data});
    try testing.expectEqual(Tile.empty, data[2]);
    try testing.expectEqual(Tile.box, data[3]);
    try testing.expectEqual(Tile.attach, data[4]);
    try testing.expectEqual(Tile.box, data[5]);
    try testing.expectEqual(Tile.attach, data[6]);
    try testing.expectEqual(Tile.empty, data[7]);
    try testing.expect(move2(&map, Coord{3, 1}, Coord{1, 0}));
    std.debug.print("{any}\n", .{data});
    try testing.expectEqual(Tile.empty, data[3]);
    try testing.expectEqual(Tile.box, data[4]);
    try testing.expectEqual(Tile.attach, data[5]);
    try testing.expectEqual(Tile.box, data[6]);
    try testing.expectEqual(Tile.attach, data[7]);
    try testing.expectEqual(Tile.wall, data[8]);
    try testing.expect(!move2(&map, Coord{4, 1}, Coord{1, 0}));
}

test "big_example" {
    const input = [_][]const u8 {
        "##########",
        "#..O..O.O#",
        "#......O.#",
        "#.OO..O.O#",
        "#..O@..O.#",
        "#O#..O...#",
        "#O..O..O.#",
        "#.OO.O.OO#",
        "#....O...#",
        "##########",
        "",
        "<vv>^<v^>v>^vv^v>v<>v^v<v<^vv<<<^><<><>>v<vvv<>^v^>^<<<><<v<<<v^vv^v>^",
        "vvv<<^>^v^^><<>>><>^<<><^vv^^<>vvv<>><^^v>^>vv<>v<<<<v<^v>^<^^>>>^<v<v",
        "><>vv>v^v^<>><>>>><^^>vv>v<^^^>>v^v^<^^>v^^>v^<^v>v<>>v^v^<v>v^^<^^vv<",
        "<<v<^>>^^^^>>>v^<>vvv^><v<<<>^^^vv^<vvv>^>v<^^^^v<>^>vvvv><>>v^<<^^^^^",
        "^><^><>>><>^^<<^^v>>><^<v>^<vv>>v>>>^v><>^v><<<<v>>v<v<v>vvv>^<><<>^><",
        "^>><>^v<><^vvv<^^<><v<<<<<><^v<<<><<<^^<v<^^^><^>>^<v^><<<^>>^v<v^v<v^",
        ">^>>^v>vv>^<<^v<>><<><<v<<v><>v<^vv<<<>^^v^>^^>>><<^v>>v^v><^^>>^<>vv^",
        "<><^^>^^^<><vvvvv^v<v<<>^v<v>v<<^><<><<><<<^^<<<^<<>><<><^^^>^^<>^>v<>",
        "^^>vv<^v^v<vv>^<><v<^v>^^^>>>^^vvv^>vvv<>>>^<^>>>>>^<<^v>^vvv<>^<><<v>",
        "v^^>>><<^^<>>^v^<v^vv<>v^<<>^<^v^v><^<<<><<^<v><v<>vv>>v><v^<vv<>v^<<^",
    };

    var map = Map.init(testing.allocator);
    defer {
        for (map.items) |row| {
            row.deinit();
        }
        map.deinit();
    }
    var map2 = Map.init(testing.allocator);
    defer {
        for (map2.items) |row| {
            row.deinit();
        }
        map2.deinit();
    }

    var robot_start: Coord = undefined;
    var robot1: Coord = undefined;
    var robot2: Coord = undefined;

    var is_movement = false;
    for (input) |line| {
        if (line.len == 0) {
            robot1 = robot_start;
            robot2 = robot_start*Coord{2,1};
            is_movement = true;
            printMap(&map2, robot2, '@');
        }
        if (!is_movement) {
            var row = try Row.initCapacity(testing.allocator, line.len);
            var row2 = try Row.initCapacity(testing.allocator, line.len * 2);
            try parseRow(line, &row, &row2, &robot_start, map.items.len);
            try map.append(row);
            try map2.append(row2);
        } else {
            for (line) |c| {
                const direction: Coord = dirFromChar(c);
                if (move(&map, robot1 + direction, direction)) {
                    robot1 += direction;
                }
                //waitForEnter();
                std.debug.print("{c} from {} -> ", .{c, robot2});
                if (move2(&map2, robot2 + direction, direction)) {
                    robot2 += direction;
                }
                std.debug.print("{}\n", .{robot2});
                printMap(&map2, robot2, c);
            }
        }
    }

    const gps_sum1: usize = calculateGpsSum(&map);
    const gps_sum2: usize = calculateGpsSum(&map2);

    std.debug.print("{d}\n", .{gps_sum1});
    try testing.expectEqual(10092, gps_sum1);
    printMap(&map2, robot2, '@');
    std.debug.print("{d}\n", .{gps_sum2});
    try testing.expectEqual(9021, gps_sum2);
}

test "bonus_example" {
    const input = [_][]const u8 {
        "#######",
        "#...#.#",
        "#.....#",
        "#..OO@#",
        "#..O..#",
        "#.....#",
        "#######",
        "",
        "<vv<<^^<<^^",
    };

   var map2 = Map.init(testing.allocator);
    defer {
        for (map2.items) |row| {
            row.deinit();
        }
        map2.deinit();
    }

    var robot_start: Coord = undefined;
    var robot2: Coord = undefined;

    var is_movement = false;
    for (input) |line| {
        if (line.len == 0) {
            is_movement = true;
            robot2 = robot_start * Coord{2, 1};
        }
        if (!is_movement) {
            var row = try Row.initCapacity(testing.allocator, line.len);
            defer row.deinit();
            var row2 = try Row.initCapacity(testing.allocator, line.len * 2);
            try parseRow(line, &row, &row2, &robot_start, map2.items.len);
            try map2.append(row2);
        } else {
            for (line, 0..) |c, i| {
                //std.debug.print("{d}:\n", .{i});
                //printMap(&map2, robot2);
                _ = i;
                const direction: Coord = dirFromChar(c);
                if (move2(&map2, robot2 + direction, direction)) {
                    robot2 += direction;
                }
            }
        }
    }
    std.debug.print("final:\n", .{});
    printMap(&map2, robot2, '@');
}
