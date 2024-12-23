const builtin = @import("builtin");
const std = @import("std");
const dbg = builtin.mode == .Debug;
const fmt = std.fmt;
const mem = std.mem;
const testing = std.testing;

const ChangeSequences = std.AutoHashMap([4]i8, u32);
const ChangesSet = std.AutoHashMap([4]i8, void);

fn random(prev: u24) u24 {
    const a: u24 = prev ^ @as(u24, (prev << 6) & 0xffffff);
    const b: u24 = a ^ (a >> 5);
    const c: u24 = b ^ @as(u24, (b << 11) & 0xffffff);
    return c;
}

fn nth_random(prev: u24, n: usize) u24 {
    var number = prev;
    for (0..n) |_| {
        number = random(number);
    }
    return number;
}

fn getBestSequence(allocator: mem.Allocator, numbers: []const u24) !usize {
    var change_sequences = ChangeSequences.init(allocator);
    defer change_sequences.deinit();
    try change_sequences.ensureTotalCapacity(2000);

    var changes_set = ChangesSet.init(allocator);
    defer changes_set.deinit();
    try changes_set.ensureTotalCapacity(1997);

    var best_seq: [4]i8 = .{0, 0, 0, 0};
    var best_sum: usize = 0;
    for (numbers) |start| {
        var number = start;
        var old_price: i8 = @intCast(number % 10);
        var seq: [4]i8 = .{0, 0, 0, 0};
        changes_set.clearRetainingCapacity();
        for (0..2000) |i| {
            const new = random(number);
            const new_price: i8 = @intCast(new % 10);
            const new_change = new_price - old_price;
            mem.copyForwards(i8, &seq, seq[1..]);
            seq[3] = new_change;
            if (i >= 3) {
                if (new_price > 0) {
                    if (!(try changes_set.getOrPut(seq)).found_existing){
                        const entry = try change_sequences.getOrPutValue(seq, 0);
                        const new_sum: usize = entry.value_ptr.* + @as(u32, @intCast(new_price));
                        entry.value_ptr.* = @intCast(new_sum);
                        if (new_sum > best_sum) {
                            best_sum = new_sum;
                            if (dbg) {
                                best_seq = seq;
                            }
                        }
                    }
                }
            }
            number = new;
            old_price = new_price;
        }
    }

    if (dbg) {
        std.debug.print("Best sequence: {d},{d},{d},{d}\n",
            .{best_seq[0], best_seq[1], best_seq[2], best_seq[3]}
        );
    }
    return best_sum;
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

    var result1: usize = 0;

    var numbers = try std.ArrayList(u24).initCapacity(allocator, 2154);

    var buf: [256]u8 = undefined;
    while (try stream.readUntilDelimiterOrEof(&buf, '\n')) |line| {
        const number = try fmt.parseInt(u24, line, 10);
        result1 += nth_random(number, 2000); // part1
        try numbers.append(number);
    }

    const result2 = try getBestSequence(allocator, numbers.items);

    try stdout.print("Result1: {d}\n", .{result1});
    try stdout.print("Result2: {d}\n", .{result2});
}

test "no_overflow" {
    try testing.expect(random(0xffffff) < 0xffffff);
}

test "part1_example" {
    const n1 = nth_random(1, 2000);
    const n2 = nth_random(10, 2000);
    const n3 = nth_random(100, 2000);
    const n4 = nth_random(2024, 2000);
    try testing.expectEqual(n1, 8685429);
    try testing.expectEqual(n2, 4700978);
    try testing.expectEqual(n3, 15273692);
    try testing.expectEqual(n4, 8667524);
}

test "part2_example" {
    const input = [_]u24 {
        1,
        2,
        3,
        2024,
    };
    const result = try getBestSequence(testing.allocator, &input);
    try testing.expectEqual(23, result);
}
