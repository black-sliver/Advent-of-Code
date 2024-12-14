const std = @import("std");
const fmt = std.fmt;
const math = std.math;
const mem = std.mem;
const testing = std.testing;


fn Machine(T: type, offset: comptime_int) type {
    return struct {
        const Self = @This();
        const cost = [_]u32{3, 1};
        const Point = @Vector(2, T);
        const PointF = @Vector(2, f64);

        prize: Point,
        movement: [2]Point,

        pub fn init(prize: Point, movement: [2]Point) Self {
            return Self{
                .prize = prize + Point{offset, offset},
                .movement = movement,
            };
        }

        fn pointToF(p: Point) PointF {
            return PointF{@floatFromInt(p[0]), @floatFromInt(p[1])};
        }

        fn angleOf(p: PointF) f64 {
            return math.atan(p[1] / p[0]);
        }

        fn magnitudeOf(p: PointF) f64 {
            return math.sqrt(p[0] * p[0] + p[1] * p[1]);
        }

        fn rotate(p: PointF, by: f64) PointF {
            const oldAngle = angleOf(p);
            const newAngle = oldAngle + by;
            const magnitude = magnitudeOf(p);
            return PointF{magnitude * math.cos(newAngle), magnitude * math.sin(newAngle)};
        }

        pub fn tokensForCheapestWin2(self: *const Self) ?u64 {
            // using a rhomboid from the 3 vectors rotated to the x axis
            // there is probably a more generic solution that does not need the rotation
            // (side a is one of the movement vectors and is on the X axis)
            // ha is the rotated y of the prize
            // ha = b * sin(alpha)
            const movement0F = pointToF(self.movement[0]);
            const movement1F = pointToF(self.movement[1]);
            const angle0 = angleOf(movement0F);
            const angle1 = angleOf(movement1F);
            if (math.approxEqAbs(f64, angle0, angle1, 0.001)) {
                // if both vectors have the same angle, this approach won't work
                return self.tokensForCheapestWin1();
            }
            const rotatedPrize = rotate(pointToF(self.prize), -angle0);
            const alpha = angle1 - angle0;
            const ha = rotatedPrize[1];
            const b = ha / math.sin(alpha);
            const magnitude1 = magnitudeOf(movement1F);
            const presses1 = b / magnitude1;
            if (!math.approxEqAbs(f64, presses1, math.round(presses1), 0.001)) {
                // not an integer result -> no solution
                return null;
            }
            const presses1_int: T = @intFromFloat(math.round(presses1));
            // now we calculate the magnitude of a for the other button from the original values
            // this uses fast math, so maybe faster than calculating from the transposed coordinates
            // but most importantly, it's c&p
            const remaining = self.prize - self.movement[1] * @as(Point, @splat(presses1_int));
            const rest = remaining % self.movement[0];
            const count = remaining / self.movement[0];
            if (@reduce(.And, rest == @as(Point, @splat(0))) and count[0] == count[1]) {
                const presses0_int = count[0];
                //std.debug.print("{d}x A + {d}x B\n", .{presses0_int, presses1_int});
                return presses0_int * cost[0] + presses1_int * cost[1];
            }
            return null;
        }

        pub fn tokensForCheapestWin1(self: *const Self) ?u64 {
            if (offset == 0) {
                // exit early if deemed impossible by 100 press limit
                const max_movement = (self.movement[0] + self.movement[1]) * @as(Point, @splat(100));
                const too_far = max_movement < self.prize;
                if (@reduce(.Or, too_far)) {
                    return null;
                }
            }
            // metric: tiles per token
            const effect_a = @reduce(.Add, self.movement[0]) * cost[1];
            const effect_b = @reduce(.Add, self.movement[1]) * cost[0];
            const better = if (effect_a >= effect_b) @as(usize, 0) else @as(usize, 1);
            // const worse = better ^ 1;
            // press the button with fewer tokens per tile as often as possible (up to 100)
            if (better == 0) { // unrolled in case it doesn't get optimized. Could use better/worse as index instead.
                const max_better = @min(
                    if (offset == 0) 100 else math.maxInt(usize),
                    @reduce(.Min, self.prize / self.movement[0])
                );
                var remaining_steps = self.prize - self.movement[0] * @as(Point, @splat(max_better));
                for (0..max_better+1) |i| {
                    const num_better = max_better - i;
                    // then press the other button to reach the goal
                    const rest = remaining_steps % self.movement[1];
                    const count = remaining_steps / self.movement[1];
                    if (offset == 0 and count[0] > 100) {
                        return null;
                    }
                    if (@reduce(.And, rest == @as(Point, @splat(0))) and count[0] == count[1]) {
                        // we done
                        //std.debug.print("{d}x A + {d}x B\n", .{num_better, count[0]});
                        return num_better * cost[0] + count[0] * cost[1];
                    }
                    // reduce the cheaper button if goal is not reachable
                    remaining_steps += self.movement[0];
                }
            } else {
                const max_better = @min(
                    if (offset == 0) 100 else math.maxInt(usize),
                    @reduce(.Min, self.prize / self.movement[1])
                );
                var remaining_steps = self.prize - self.movement[1] * @as(Point, @splat(max_better));
                for (0..max_better+1) |i| {
                    const num_better = max_better - i;
                    // then press the other button to reach the goal
                    const rest = remaining_steps % self.movement[0];
                    const count = remaining_steps / self.movement[0];
                    if (offset == 0 and count[0] > 100) {
                        return null;
                    }
                    if (@reduce(.And, rest == @as(Point, @splat(0))) and count[0] == count[1]) {
                        // we done
                        //std.debug.print("{d}x A + {d}x B\n", .{count[0], num_better});
                        return num_better * cost[1] + count[0] * cost[0];
                    }
                    // reduce the cheaper button if goal is not reachable
                    remaining_steps += self.movement[1];
                }
            }
            return null;
        }
    };
}


test "vector_stuff" {
    const M = Machine(u64, 0);
    // 2 pi = 360°
    const vec1 = M.PointF{1, 1}; // 45°
    const vec2 = M.PointF{math.cos(math.pi / 6.0), math.sin(math.pi / 6.0)}; // 30°
    const angle1 = M.angleOf(vec1);
    const angle2 = M.angleOf(vec2);
    try testing.expectApproxEqAbs(math.pi / 4.0, angle1, 0.001);
    try testing.expectApproxEqAbs(math.pi / 6.0, angle2, 0.001);
    const vec1r = M.rotate(vec1, -angle2);
    const angle1r = M.angleOf(vec1r); // 15°
    try testing.expectApproxEqAbs(math.pi / 12.0, angle1r, 0.001);
    try testing.expectApproxEqAbs(1, M.magnitudeOf(M.PointF{1, 0}), 0.001);
    try testing.expectApproxEqAbs(1, M.magnitudeOf(M.PointF{0, 1}), 0.001);
}


fn parseMovement(s: []u8) ![2]u32 {
    const meaningful = s[12..];
    const split = mem.indexOf(u8, meaningful, ", Y+") orelse return error.ParseError;
    const x = meaningful[0..split];
    const y = meaningful[split+4..];
    return .{
        try fmt.parseInt(u32, x, 10),
        try fmt.parseInt(u32, y, 10),
    };
}

fn parsePrize(s: []u8) ![2]u32 {
    const meaningful = s[9..];
    const split = mem.indexOf(u8, meaningful, ", Y=") orelse return error.ParseError;
    const x = meaningful[0..split];
    const y = meaningful[split+4..];
    return .{
        try fmt.parseInt(u32, x, 10),
        try fmt.parseInt(u32, y, 10),
    };
}

pub fn main() !void {
    const stdout = std.io.getStdOut().writer();

    var file = try std.fs.cwd().openFile("input.txt", .{});
    defer file.close();

    var buffered_reader = std.io.bufferedReader(file.reader());
    var stream = buffered_reader.reader();

    // part1
    const Part1Machine = Machine(u32, 0);
    const Part1Point = Part1Machine.Point;
    var tokens_used_on_expected_machines: u64 = 0;

    // part2
    const Part2Machine = Machine(u64, 10000000000000);
    const Part2Point = Part2Machine.Point;
    var tokens_used_on_actual_machines: u64 = 0;

    var buf: [256]u8 = undefined;
    while (true) {
        var line = stream.readUntilDelimiter(&buf, '\n') catch break;
        const button1 = try parseMovement(line);
        line = stream.readUntilDelimiter(&buf, '\n') catch break;
        const button2 = try parseMovement(line);
        line = stream.readUntilDelimiter(&buf, '\n') catch break;
        const prize = try parsePrize(line);

        // part 1
        const machine1 = Part1Machine.init(
            Part1Point{@intCast(prize[0]), @intCast(prize[1])},
            .{
                Part1Point{@intCast(button1[0]), @intCast(button1[1])},
                Part1Point{@intCast(button2[0]), @intCast(button2[1])},
            }
        );
        //std.debug.print("{}\n", .{machine1});
        if (machine1.tokensForCheapestWin1()) |tokens| {
            tokens_used_on_expected_machines += tokens;
        }

        // part 2
        const machine2 = Part2Machine.init(
            Part2Point{@intCast(prize[0]), @intCast(prize[1])},
            .{
                Part2Point{@intCast(button1[0]), @intCast(button1[1])},
                Part2Point{@intCast(button2[0]), @intCast(button2[1])},
            }
        );
        //std.debug.print("{}\n", .{machine2});
        if (machine2.tokensForCheapestWin2()) |tokens| {
            tokens_used_on_actual_machines += tokens;
        }

        _ = stream.readUntilDelimiter(&buf, '\n') catch break;
    }

    try stdout.print("Result 1: {d}\n", .{tokens_used_on_expected_machines});
    try stdout.print("Result 2: {d}\n", .{tokens_used_on_actual_machines});
}
