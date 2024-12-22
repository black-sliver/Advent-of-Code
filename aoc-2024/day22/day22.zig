const std = @import("std");
const fmt = std.fmt;
const mem = std.mem;
const testing = std.testing;

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

const Prices = std.ArrayList(i8);
const Changes = std.ArrayList(i8);
const ChangesPrices = std.AutoHashMap([4]i8, i8);

fn getBestSequence(allocator: mem.Allocator, numbers: []const u24) !struct{seq: [4]i8, sum: usize} {
    //var prices_list = try std.ArrayList(Prices).initCapacity(allocator, numbers.len);
    //var changes_list = try std.ArrayList(Changes).initCapacity(allocator, numbers.len);
    var changes_prices_list = try std.ArrayList(ChangesPrices).initCapacity(allocator, numbers.len);
    defer {
        for (changes_prices_list.items) |map| {
            var wtf = map;
            wtf.deinit();
        }
        changes_prices_list.deinit();
        //for (changes_list.items) |changes| {
        //    changes.deinit();
        //}
        //changes_list.deinit();
        //for (prices_list.items) |prices| {
        //    prices.deinit();
        //}
        //prices_list.deinit();
    }
    for (numbers) |start| {
        //var prices = try Prices.initCapacity(allocator, 2000);
        //var changes = try Changes.initCapacity(allocator, 2000);
        var changes_prices = ChangesPrices.init(allocator);
        try changes_prices.ensureTotalCapacity(2000);
        var number = start;
        var old_price: i8 = @intCast(number % 10);
        var seq: [4]i8 = .{0, 0, 0, 0};
        for (0..2000) |i| {
            const new = random(number);
            const new_price: i8 = @intCast(new % 10);
            const new_change = new_price - old_price;
            mem.copyForwards(i8, &seq, seq[1..]);
            seq[3] = new_change;
            //try prices.append(new_price);
            //try changes.append(new_change);
            if (i >= 3) {
                _ = try changes_prices.getOrPutValue(seq, new_price);
            }
            number = new;
            old_price = new_price;
        }
        //try prices_list.append(prices);
        //try changes_list.append(changes);
        try changes_prices_list.append(changes_prices);
    }
    std.debug.print("Generating", .{});
    var best: [4]i8 = .{0, 0, 0, 0};
    var best_sum: usize = 0;
    var seq: [4]i8 = .{0, 0, 0, 0};
    // TODO: instead of generating all possible combinations, check only the ones that actually exist (in a set)
    for (0..18+1) |i| {
        seq[0] = @as(i8, @intCast(i)) - 9;
        for (0..18+1) |j| {
            std.debug.print(".", .{});
            seq[1] =  @as(i8, @intCast(j)) - 9;
            for (0..18+1) |k| {
                seq[2] =  @as(i8, @intCast(k)) - 9;
                for (0..18+1) |l| {
                    seq[3] =  @as(i8, @intCast(l)) - 9;
                    var sum: usize = 0;
                    for (changes_prices_list.items) |map| {
                        if (map.get(seq)) |price| {
                            sum += @intCast(price);
                        }
                    }
                    //for (changes_list.items, 0..) |changes, buyer| {
                    //    if (mem.indexOf(i8, changes.items, &seq)) |pos| {
                    //        const price_pos = pos + 3;
                    //        sum += @intCast(prices_list.items[buyer].items[price_pos]);
                    //    }
                    //}
                    //for (changes_list.items, 0..) |changes, buyer| {
                    if (sum > best_sum) {
                        best_sum = sum;
                        best = seq;
                    }
                }
            }
        }
    }
    std.debug.print("\n", .{});
    return .{
        .seq = best,
        .sum = best_sum,
    };
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
    std.debug.print("Best sequence: {d},{d},{d},{d}\n",
        .{result2.seq[0], result2.seq[1], result2.seq[2], result2.seq[3]}
    );

    try stdout.print("Result1: {d}\n", .{result1});
    try stdout.print(
        "Result2: {d}\n",
        .{result2.sum}
    );
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
    try testing.expectEqualSlices(i8, &[_]i8{-2, 1, -1, 3}, &result);
}
