const std = @import("std");
const builtin = @import("builtin");

const Op = enum {
    Plus,
    Times,
};

const Problem = struct {
    op: Op = .Plus,
    numbers: std.ArrayList(u32) = .empty,

    fn solve(self: Problem) u64 {
        var res: u64 = self.numbers.items[0];
        switch (self.op) {
            .Plus => {
                for (self.numbers.items[1..]) |number| {
                    res += number;
                }
                return res;
            },
            .Times => {
                for (self.numbers.items[1..]) |number| {
                    res *= number;
                }
                return res;
            },
        }
    }

    fn deinit(self: *Problem, allocator: std.mem.Allocator) void {
        self.numbers.deinit(allocator);
    }
};

fn solveAll(problems: []const Problem) u64 {
    var sum: u64 = 0;
    for (problems) |problem| {
        sum += problem.solve();
    }
    return sum;
}

fn readInput1(allocator: std.mem.Allocator, problems: *std.ArrayList(Problem)) !void {
    var file_buffer: [4096]u8 = undefined;
    const file = try std.fs.cwd().openFile("input.txt", .{});
    defer file.close();
    var reader = file.reader(&file_buffer);
    var first_line: bool = true;
    while (try reader.interface.takeDelimiter('\n')) |line| {
        var it = std.mem.tokenizeScalar(u8, line, ' ');
        var i: usize = 0;
        const last_line = !std.ascii.isDigit(line[0]);
        while (it.next()) |part| : (i += 1) {
            if (first_line) {
                var problem: Problem = .{};
                try problem.numbers.append(allocator, try std.fmt.parseUnsigned(u32, part, 10));
                try problems.append(allocator, problem);
            } else if (!last_line) {
                try problems.items[i].numbers.append(allocator, try std.fmt.parseUnsigned(u32, part, 10));
            } else {
                problems.items[i].op = switch (part[0]) {
                    '+' => .Plus,
                    '*' => .Times,
                    else => @panic("Invalid op"),
                };
            }
        }
        first_line = false;
    }
}

fn readInput2(allocator: std.mem.Allocator, problems: *std.ArrayList(Problem)) !void {
    var file_buffer: [4096]u8 = undefined;
    const file = try std.fs.cwd().openFile("input.txt", .{});
    defer file.close();

    // first pass: extract column widths and ops from data (last line)
    var reader = file.reader(&file_buffer);
    var line_counter: usize = 0;
    while (try reader.interface.takeDelimiter('\n')) |line| : (line_counter += 1) {
        const last_line = line[0] == '+' or line[0] == '*';
        if (!last_line)
            continue;
        var pos: usize = 0;
        while (pos < line.len) {
            const next_pos = std.mem.indexOfNonePos(u8, line, pos + 1, " ") orelse line.len + 1;
            const number_count = next_pos - pos - 1;
            var problem: Problem = .{ .op = switch (line[pos]) {
                '+' => .Plus,
                '*' => .Times,
                else => @panic("Invalid op"),
            } };
            try problem.numbers.appendNTimes(allocator, 0, number_count);
            try problems.append(allocator, problem);
            pos = next_pos;
        }
    }

    // second pass: extract numbers
    try reader.seekTo(0);
    while (try reader.interface.takeDelimiter('\n')) |line| : (line_counter -= 1) {
        if (line_counter == 1)
            break;
        var i: usize = 0;
        var p: usize = 0;
        while (p < line.len) : (i += 1) {
            const numbers = &problems.items[i].numbers.items;
            for (0..numbers.len) |j| {
                const c = line[p];
                if (c != ' ') {
                    numbers.*[j] *= 10;
                    numbers.*[j] += c - '0';
                }
                p += 1;
            }
            p += 1; // skip space
        }
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

    var problems: std.ArrayList(Problem) = .empty;
    defer problems.deinit(allocator);
    defer for (problems.items) |*problem| problem.deinit(allocator);

    try readInput1(allocator, &problems);
    const res1 = solveAll(problems.items);
    try stdout.print("{}\n", .{res1});

    for (problems.items) |*problem| problem.deinit(allocator);
    problems.clearRetainingCapacity();

    try readInput2(allocator, &problems);
    const res2 = solveAll(problems.items);
    try stdout.print("{}\n", .{res2});
}

test "solveAll" {
    const allocator = std.testing.allocator;
    var test_data = [_]Problem{
        .{ .op = .Times, .numbers = .empty },
        .{ .op = .Plus, .numbers = .empty },
        .{ .op = .Times, .numbers = .empty },
        .{ .op = .Plus, .numbers = .empty },
    };
    defer for (&test_data) |*problem| problem.deinit(allocator);

    try test_data[0].numbers.appendSlice(allocator, &[_]u32{ 123, 45, 6 });
    try test_data[1].numbers.appendSlice(allocator, &[_]u32{ 328, 64, 98 });
    try test_data[2].numbers.appendSlice(allocator, &[_]u32{ 51, 387, 215 });
    try test_data[3].numbers.appendSlice(allocator, &[_]u32{ 64, 23, 314 });

    try std.testing.expectEqual(4277556, solveAll(&test_data));
}
