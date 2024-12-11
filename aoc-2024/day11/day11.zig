const std = @import("std");
const fmt = std.fmt;
const math = std.math;
const mem = std.mem;
const testing = std.testing;

const StoneList = std.ArrayList(u64);

// initial solution
fn blink(inputs: []const u64, output: *StoneList) !void {
    for (inputs) |stone| {
        if (stone == 0) {
            try output.append(1);
        } else {
            const digits = math.log10_int(stone) + 1;
            if (digits % 2 == 0) {
                // even number of digits
                const split = math.pow(u64, 10, digits / 2);
                try output.append(stone / split);
                try output.append(stone % split);
            } else {
                // odd number of digits
                try output.append(stone * 2024);
            }
        }
    }
}

const CacheKey = [2]u64;
const Cache = std.AutoHashMap(CacheKey, u64);

fn countBlinkGrow1(cache: *Cache, stone: u64, times: u64) !u64 {
    if (times == 0) {
        return 1;
    }

    const key = [2]u64{times, stone};
    if (cache.get(key)) |v| {
        return v;
    }

    var res: u64 = undefined;
    if (stone == 0) {
        res = try countBlinkGrow1(cache, 1, times - 1);
    } else {
        const digits = math.log10_int(stone) + 1;
        if (digits % 2 == 0) {
            // even number of digits
            const split = math.pow(u64, 10, digits / 2);
            res =  try countBlinkGrow1(cache, stone / split, times - 1) +
                    try countBlinkGrow1(cache, stone % split, times - 1);
        } else {
            // odd number of digits
            res = try countBlinkGrow1(cache, stone * 2024, times - 1);
        }
    }

    try cache.put(key, res);
    return res;
}

fn countBlinkGrow(cache: *Cache, inputs: []const u64, times: usize) !u64 {
    if (times == 0) {
        return inputs.len;
    }

    var sum: u64 = 0;
    for (inputs) |stone| {
        sum += try countBlinkGrow1(cache, stone, times);
    }
    return sum;
}

test "log10" {
    try testing.expectEqual(1, math.log10_int(@as(u32, 10)));
    try testing.expectEqual(2, math.log10_int(@as(u32, 100)));
    try testing.expectEqual(3, (math.log10_int(@as(u32, 253000)) + 1) / 2);
}

test "blink1" {
    const input = [_]u64{125, 17};
    const expected = [_]u64{253000, 1, 7};
    var result = try StoneList.initCapacity(testing.allocator, expected.len);
    defer result.deinit();
    try blink(&input, &result);
    try testing.expectEqualSlices(u64, &expected, result.items);
}

test "blink2" {
    const input = [_]u64{253000, 1, 7};
    const expected = [_]u64{253, 0, 2024, 14168};
    var result = try StoneList.initCapacity(testing.allocator, expected.len);
    defer result.deinit();
    try blink(&input, &result);
    try testing.expectEqualSlices(u64, &expected, result.items);
}

test "part2_code" {
    const input = [_]u64{125, 17};
    var cache: Cache = Cache.init(testing.allocator);
    defer cache.deinit();
    const result = try countBlinkGrow(&cache, &input, 25);
    try testing.expectEqual(55312, result);
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

    var data = try allocator.create(StoneList);
    data.* = StoneList.init(allocator);

    var buf: [128]u8 = undefined;
    if (try stream.readUntilDelimiterOrEof(&buf, '\n')) |line| {
        var it = std.mem.split(u8, line, " ");
        while (it.next()) |stone| {
            try data.append(try fmt.parseInt(u64, stone, 10));
        }
    }

    // original part1
    //var output = try allocator.create(StoneList);
    //output.* = StoneList.init(allocator);
    //for (0..25) |_| {
    //    try blink(data.items, output);
    //    const tmp = data;
    //    data = output;
    //    output = tmp;
    //    output.clearRetainingCapacity();
    //}
    //const num_stones_after_25_blinks = data.items.len;

    var cache: Cache = Cache.init(allocator);

    // part1
    const num_stones_after_25_blinks = try countBlinkGrow(&cache, data.items, 25);

    // part2
    const num_stones_after_75_blinks = try countBlinkGrow(&cache, data.items, 75);

    try stdout.print("Result 1: {d}\n", .{num_stones_after_25_blinks});
    try stdout.print("Result 2: {d}\n", .{num_stones_after_75_blinks});
}
