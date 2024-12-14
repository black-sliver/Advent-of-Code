const std = @import("std");
const fmt = std.fmt;
const math = std.math;
const mem = std.mem;
const testing = std.testing;

const I = i32;
const Coord = @Vector(2, I);


const Robot = struct {
    const Self = @This();

    position: Coord,
    velocity: Coord,

    pub fn initFromLine(line: []const u8) !Self {
        const s = line[2..];
        const p1 = mem.indexOfScalar(u8, s, ',') orelse return error.ParseError;
        const p2 = mem.indexOfScalarPos(u8, s, p1+2, ' ') orelse return error.ParseError;
        const p3 = mem.indexOfScalarPos(u8, s, p2+4, ',') orelse return error.ParseError;
        const px = try fmt.parseInt(I, s[0..p1], 10);
        const py = try fmt.parseInt(I, s[p1+1..p2], 10);
        const vx = try fmt.parseInt(I, s[p2+3..p3], 10);
        const vy = try fmt.parseInt(I, s[p3+1..], 10);
        return Self{
            .position = Coord{px, py},
            .velocity = Coord{vx, vy},
        };
    }

    pub fn step(self: *Self, steps: i32, size: Coord) void {
        const vsteps = @as(Coord, @splat(steps));
        self.position = @mod((self.position + self.velocity * vsteps), size);
        std.debug.assert(self.position[0] >= 0 and self.position[0] < size[0]);
        std.debug.assert(self.position[1] >= 0 and self.position[1] < size[1]);
    }

    pub fn getQuadrant(self: *const Self, size: Coord) ?usize {
        const middle = @divTrunc(size, Coord{2, 2});
        if (self.position[0] < middle[0]) {
            if (self.position[1] < middle[1]) {
                return 0;
            } else if (self.position[1] > middle[1]) {
                return 2;
            }
        } else if (self.position[0] > middle[0]) {
            if (self.position[1] < middle[1]) {
                return 1;
            } else if (self.position[1] > middle[1]) {
                return 3;
            }
        }
        return null;
    }
};

fn countElements(positions: *std.AutoHashMap(Coord, void), start: Coord, dir: Coord) I {
    var n: I = 0;
    var pos = start + dir;
    while (positions.contains(pos)) {
        n += 1;
        pos += dir;
    }
    return n;
}

fn isPictureFrame(positions: *std.AutoHashMap(Coord, void)) bool {
    var it = positions.keyIterator();
    while (it.next()) |posp| {
        const pos = posp.*;
        var len_right = countElements(positions, pos,  Coord{1, 0});
        if (len_right < 6) {
            continue;
        }
        var len_bottom = countElements(positions, pos,  Coord{0, 1});
        //std.debug.print("tl v {d}\n", .{len_bottom});
        if (len_bottom < 6) {
            continue;
        }
        var top_right = pos + Coord{len_right, 0};
        const len_bottom2 = countElements(positions, top_right,  Coord{0, 1});
        //std.debug.print("tr v {d}\n", .{len_bottom2});
        if (len_bottom2 == len_bottom - 1) {
            len_bottom -= 1;
        } else if (len_bottom2 != len_bottom) {
            len_right -= 1;
            top_right = pos + Coord{len_right, 0};
            const len_bottom3 = countElements(positions, top_right,  Coord{0, 1});
            //std.debug.print("tr v {d}\n", .{len_bottom3});
            if (len_bottom3 == len_bottom - 1) {
                len_bottom -= 1;
            } else if (len_bottom3 != len_bottom) {
                continue;
            }
        }
        const bot_left = pos + Coord{0, len_bottom};
        const len_right2 = countElements(positions, bot_left,  Coord{1, 0});
        //std.debug.print("bl-> {d}\n", .{len_right2});
        if (len_right2 >= len_right) {
            return true;
        }
    }
    return false;
}

fn printRobots(positions: *std.AutoHashMap(Coord, void)) void {
    var buf: [101]u8 = undefined;
    for (0..103) |y| {
        @memset(&buf, '.');
        for (0..101) |x| {
            if (positions.contains(Coord{@intCast(x), @intCast(y)})) {
                buf[x] = 'X';
            }
        }
        std.debug.print("{s}\n", .{buf});
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

    // sample:
    //const size = Coord{11, 7};
    // real:
    const size = Coord{101, 103};
    const steps: i32 = 100;

    var robots = std.ArrayList(Robot).init(allocator);

    var count_in_quadrant = [4]usize{0,0,0,0};

    var buf: [32]u8 = undefined;
    while (try stream.readUntilDelimiterOrEof(&buf, '\n')) |line| {
        var robot = try Robot.initFromLine(line);
        //std.debug.print("{}\n", .{robot});
        // for part 2 below
        try robots.append(robot);
        // part 1:
        robot.step(steps, size);
        if (robot.getQuadrant(size)) |i| {
            count_in_quadrant[i] += 1;
        }
    }

    const result1: usize =
        count_in_quadrant[0] *
        count_in_quadrant[1] *
        count_in_quadrant[2] *
        count_in_quadrant[3];

    var result2: usize = 0;
    var robot_locations = std.AutoHashMap(Coord, void).init(allocator);
    for (0..10000000) |i| {
        count_in_quadrant = [4]usize{0,0,0,0};
        for (0..robots.items.len) |j| {
            var robot = &robots.items[j];
            try robot_locations.put(robot.position, undefined);
            robot.step(1, size);
        }

        if (isPictureFrame(&robot_locations)) {
            std.debug.print("{d}:\n", .{i});
            printRobots(&robot_locations);
            result2 = i;
            break;
        }
        robot_locations.clearRetainingCapacity();
    }

    try stdout.print("Result 1: {d}\n", .{result1});
    try stdout.print("Result 2: {d}\n", .{result2});
}

test "sample" {
    const input = [_][]const u8{
        "p=0,4 v=3,-3",
        "p=6,3 v=-1,-3",
        "p=10,3 v=-1,2",
        "p=2,0 v=2,-1",
        "p=0,0 v=1,3",
        "p=3,0 v=-2,-2",
        "p=7,6 v=-1,-3",
        "p=3,0 v=-1,-2",
        "p=9,3 v=2,3",
        "p=7,3 v=-1,2",
        "p=2,4 v=2,-3",
        "p=9,5 v=-3,-3",
    };

    const steps: i32 = 100;
    const size = Coord{11, 7};

    var count_in_quadrant = [4]usize{0,0,0,0};

    for (input) |line| {
        var robot = try Robot.initFromLine(line);
        std.debug.print("{} -> ", .{robot});
        robot.step(steps, size);
        std.debug.print("{}\n", .{robot.position});
        if (robot.getQuadrant(size)) |i| {
            count_in_quadrant[i] += 1;
        }
    }
    std.debug.print("{any}\n", .{count_in_quadrant});
    try testing.expectEqual(12,
        count_in_quadrant[0] *
            count_in_quadrant[1] *
            count_in_quadrant[2] *
            count_in_quadrant[3]
    );
}

test "find_frame" {
    const input = [_][]const u8{
        // top end
        "p=2,2 v=0,0",
        "p=3,2 v=0,0",
        "p=4,2 v=0,0",
        "p=5,2 v=0,0",
        "p=6,2 v=0,0",
        "p=7,2 v=0,0",
        "p=8,2 v=0,0",
        "p=9,2 v=0,0",
        // bottom end
        "p=2,9 v=0,0",
        "p=3,9 v=0,0",
        "p=4,9 v=0,0",
        "p=5,9 v=0,0",
        "p=6,9 v=0,0",
        "p=7,9 v=0,0",
        "p=8,9 v=0,0",
        "p=9,9 v=0,0",
        // left end
        "p=2,3 v=0,0",
        "p=2,4 v=0,0",
        "p=2,5 v=0,0",
        "p=2,6 v=0,0",
        "p=2,7 v=0,0",
        "p=2,8 v=0,0",
        // right end
        "p=9,3 v=0,0",
        "p=9,4 v=0,0",
        "p=9,5 v=0,0",
        "p=9,6 v=0,0",
        "p=9,7 v=0,0",
        "p=9,8 v=0,0",
    };

    var robots = std.ArrayList(Robot).init(testing.allocator);
    defer robots.deinit();

    for (input) |line| {
        const robot = try Robot.initFromLine(line);
        std.debug.print("{}\n", .{robot});
        try robots.append(robot);
    }

    var robot_locations = std.AutoHashMap(Coord, void).init(testing.allocator);
    defer robot_locations.deinit();
    for (0..robots.items.len) |j| {
        const robot = &robots.items[j];
        try robot_locations.put(robot.position, undefined);
    }

    printRobots(&robot_locations);
    try testing.expect(isPictureFrame(&robot_locations));
}
