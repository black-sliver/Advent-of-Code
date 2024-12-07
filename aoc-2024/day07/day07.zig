const std = @import("std");
const fmt = std.fmt;
const mem = std.mem;
const math = std.math;


const Operation = enum {
    Add,
    Multiply,
    Concat,
};

pub fn NumberYielder(comptime T: type, comptime final_op: Operation, comptime max_numbers: usize) type {
    return struct {
        const Self = @This();

        numbers: []const T,
        ops: [max_numbers - 1]Operation,
        limit: u64,
        done: bool,

        pub fn init(numbers: []const T, limit: u64, skip_add_mul: bool) !Self {
            if (numbers.len > max_numbers)
                return error.OverflowError;

            var res = Self{
                .numbers = numbers,
                .ops = [_]Operation{Operation.Add} ** (max_numbers - 1),
                .limit = limit,
                .done = false,
            };
            if (skip_add_mul) {
                res.ops[0] = Operation.Concat;
            }
            return res;
        }

        pub fn next(self: *Self) ?u64 {
            const SumT = u64;
            var sum: SumT = undefined;
            var valid = false;

            while (!valid) {
                if (self.done) {
                    return null;
                }

                //std.debug.print("{d}", .{self.numbers[0]});

                valid = true;
                sum = self.numbers[0];
                number_loop: for (self.numbers[1..], 0..) |number, i| {
                    const op = self.ops[i];
                    switch (op) {
                        Operation.Add => {
                            sum = math.add(SumT, sum, number) catch {
                                valid = false;
                                break :number_loop;
                            };
                        },
                        Operation.Multiply => {
                            sum = math.mul(SumT, sum, number) catch {
                                valid = false;
                                break :number_loop;
                            };
                        },
                        Operation.Concat => {
                            var tmp = number;
                            sum = math.mul(SumT, sum, 10) catch {
                                valid = false;
                                break :number_loop;
                            };
                            while (tmp >= 10) : (tmp = @divTrunc(tmp, 10)) {
                                sum = math.mul(SumT, sum, 10) catch {
                                    valid = false;
                                    break :number_loop;
                                };
                            }
                            sum = math.add(SumT, sum, number) catch {
                                valid = false;
                                break :number_loop;
                            };
                        },
                    }
                    if (sum > self.limit) {
                        valid = false;
                        break :number_loop;
                    }
                    //std.debug.print(" {s} {d}", .{if (op == Operation.Add) "+" else "*", number});
                }

                //std.debug.print("\n", .{});

                if (self.numbers.len < 2) {
                    self.done = true;
                }
                for (self.numbers[1..], 0..) |_, i| {
                    if (self.ops[i] == Operation.Add) {
                        self.ops[i] = Operation.Multiply;
                        break;
                    } else if (final_op != Operation.Multiply and self.ops[i] == Operation.Multiply) {
                        self.ops[i] = Operation.Concat;
                        break;
                    } else {
                        self.ops[i] = Operation.Add;
                        // and change the next one
                        if (i == self.numbers.len - 2) {
                            // unless it was the last one
                            self.done = true;
                                break;
                        }
                    }
                }
            }

            return sum;
        }
    };
}

fn canBeSolvedWithoutConcat(result: u64, numbers: []const u32) !bool {
    // part1 rules
    var it = try NumberYielder(u32, Operation.Multiply, 17).init(numbers, result, false);
    while (it.next()) |res| {
        if (res == result) {
            return true;
        }
    }
    return false;
}

fn canBeSolvedWithConcat(result: u64, numbers: []const u32) !bool {
    // part2 rules
    var it = try NumberYielder(u32, Operation.Concat, 17).init(numbers, result, true);
    while (it.next()) |res| {
        if (res == result) {
            return true;
        }
    }
    return false;
}

test "concat10" {
    try std.testing.expect(try canBeSolvedWithConcat(
        101010, &[_]u32{10, 10, 10}
    ) == true);
}

pub fn main() !void {
    const stdout = std.io.getStdOut().writer();

    var file = try std.fs.cwd().openFile("input.txt", .{});
    defer file.close();

    var buffered_reader = std.io.bufferedReader(file.reader());
    var stream = buffered_reader.reader();

    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    const allocator = gpa.allocator();

    var num_solved_with_plus_and_multiply: u64 = 0;
    var num_solved_with_extra_concat: u64 = 0;
    var numbers = try std.ArrayList(u32).initCapacity(allocator, 10);

    var buf: [256]u8 = undefined;
    while (try stream.readUntilDelimiterOrEof(&buf, '\n')) |line| {
        var it = mem.split(u8, line, ": ");
        const result = try fmt.parseInt(u64, it.next() orelse "", 10);
        var it2 = mem.split(u8, it.next() orelse "", " ");
        while (it2.next()) |number| {
            try numbers.append(try fmt.parseInt(u32, number, 10));
        }
        // part1
        if (try canBeSolvedWithoutConcat(result, numbers.items)) {
            num_solved_with_plus_and_multiply += result;
            num_solved_with_extra_concat += result;
        }
        // part2
        else if (try canBeSolvedWithConcat(result, numbers.items)) {
            num_solved_with_extra_concat += result;
        }
        numbers.clearRetainingCapacity();
    }

    try stdout.print("Result 1: {d}\n", .{num_solved_with_plus_and_multiply});
    try stdout.print("Result 2: {d}\n", .{num_solved_with_extra_concat});
}
