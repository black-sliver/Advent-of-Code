const std = @import("std");
const fmt = std.fmt;
const math = std.math;
const mem = std.mem;
const testing = std.testing;

const verbosity = 1;

var arena: std.heap.ArenaAllocator = std.heap.ArenaAllocator.init(std.heap.page_allocator);
const allocator = arena.allocator();

const Moves = @Vector(2, isize);
const MovesMap = std.AutoHashMap([2]u8, Moves);

const Coord = @Vector(2, isize);
const KeyMap = std.AutoHashMap(u8, Coord);

var keypad_layout: KeyMap = undefined;
var keypad_moves: MovesMap = undefined;

var dirpad_layout: KeyMap = undefined;
var dirpad_moves: MovesMap = undefined;

const Order = enum {
    dont_care,
    x_first,
    y_first,
};

const CacheKey = struct {
    move: Moves,
    level: usize,
    order: Order,
};

const RcCache = std.AutoHashMap(CacheKey, usize);
var rc_cache: RcCache = undefined;

fn init() !void {
    keypad_layout = KeyMap.init(allocator);
    try keypad_layout.ensureTotalCapacity(11);
    try keypad_layout.put('7', .{-2, 3});
    try keypad_layout.put('8', .{-1, 3});
    try keypad_layout.put('9', .{ 0, 3});
    try keypad_layout.put('4', .{-2, 2});
    try keypad_layout.put('5', .{-1, 2});
    try keypad_layout.put('6', .{ 0, 2});
    try keypad_layout.put('1', .{-2, 1});
    try keypad_layout.put('2', .{-1, 1});
    try keypad_layout.put('3', .{ 0, 1});
    try keypad_layout.put('0', .{-1, 0});
    try keypad_layout.put('A', .{ 0, 0});

    dirpad_layout = KeyMap.init(allocator);
    try dirpad_layout.ensureTotalCapacity(5);
    try dirpad_layout.put('^', .{-1, 0});
    try dirpad_layout.put('A', .{ 0, 0});
    try dirpad_layout.put('<', .{-2, -1});
    try dirpad_layout.put('V', .{-1, -1});
    try dirpad_layout.put('>', .{ 0, -1});

    keypad_moves = MovesMap.init(allocator);
    try keypad_moves.ensureTotalCapacity(11 * 11);
    var key_it = keypad_layout.iterator();
    while (key_it.next()) |from| {
        var to_it = keypad_layout.iterator();
        while (to_it.next()) |to| {
            try keypad_moves.put(
                .{from.key_ptr.*, to.key_ptr.*},
                to.value_ptr.* - from.value_ptr.*
            );
        }
    }

    dirpad_moves = MovesMap.init(allocator);
    try dirpad_moves.ensureTotalCapacity(5 * 5);
    var dir_it = dirpad_layout.iterator();
    while (dir_it.next()) |from| {
        var to_it = dirpad_layout.iterator();
        while (to_it.next()) |to| {
            try dirpad_moves.put(
                .{from.key_ptr.*, to.key_ptr.*},
                to.value_ptr.* - from.value_ptr.*
            );
        }
    }

    rc_cache = RcCache.init(allocator);
}

fn deinit() void {
    keypad_layout.deinit();
    dirpad_layout.deinit();
    keypad_moves.deinit();
    dirpad_moves.deinit();
    rc_cache.deinit();
    //arena.deinit();
}

fn getCodeComplexity(line: []const u8, robots_in_between: usize) !usize {
    const digits: usize = try fmt.parseInt(usize, line[0..line.len-1], 10);
    const presses= rc_keypad(line, robots_in_between);

    if (verbosity > 0) {
        std.debug.print(
            "🖕{d:>2}x↔️🤖: {d} * {d} = {d}\n",
            .{robots_in_between, presses, digits, presses * digits}
        );
    }

    return digits * presses;
}

pub fn main() !void {
    const stdout = std.io.getStdOut().writer();

    try init();
    defer deinit();

    var file = try std.fs.cwd().openFile("input.txt", .{});
    defer file.close();

    var buffered_reader = std.io.bufferedReader(file.reader());
    var stream = buffered_reader.reader();

    var result1: usize = 0;
    var result2: usize = 0;

    var buf: [256]u8 = undefined;
    while (try stream.readUntilDelimiterOrEof(&buf, '\n')) |line| {
        result1 += try getCodeComplexity(line, 2); // part1
        result2 += try getCodeComplexity(line, 25); // part2
    }

    // 201935320071738 too low for part 2
    // 240663529801006 is wrong for part 2
    // 277554934879758 is wrong for part 2
    // 318167107995060 too high for part 2
    // 512223765078440 too high for part 2

    try stdout.print("Result1: {d}\n", .{result1});
    try stdout.print("Result2: {d}\n", .{result2});
}

fn printMove(move: Moves, a_presses: usize) void {
    if (verbosity < 3) {
        return;
    }
    if (move[0] > 0) {
        for (0..@abs(move[0])) |_| {
            std.debug.print(">", .{});
        }
    }
    if (move[0] < 0) {
        for (0..@abs(move[0])) |_| {
            std.debug.print("<", .{});
        }
    }
    if (move[1] > 0) {
        for (0..@abs(move[1])) |_| {
            std.debug.print("^", .{});
        }
    }
    if (move[1] < 0) {
        for (0..@abs(move[1])) |_| {
            std.debug.print("v", .{});
        }
    }
    for (0..a_presses) |_| {
        std.debug.print("A", .{});
    }
}

fn rc_dirpad(move: Moves, level: usize, order: Order) usize {
    const cache_key = CacheKey{.move = move, .level = level, .order = order};
    if (rc_cache.get(cache_key)) |cached| {
        return cached;
    }
    const sum = rc_dirpad_uncached(move, level, order);
    if (verbosity < 3) {
        rc_cache.put(
            cache_key,
            sum,
        ) catch {};
    }
    return sum;
}

fn rc_dirpad_uncached(move: Moves, level: usize, order: Order) usize {
    // FIXME: this seems to not find the optimal path under some circumstances still
    //        i.e. works for level=2 but not for level=25
    var sum_x_first: usize = math.maxInt(usize);
    var sum_y_first: usize = math.maxInt(usize);
    {
        var sum: usize = 0;
        var inner_from: u8 = 'A';
        // do X first
        if (move[0] > 0) {
            const inner_order = Order.dont_care;
            const inner_move = dirpad_moves.get(.{inner_from, '>'}).?;
            if (level > 0) {
                sum += rc_dirpad(inner_move, level - 1, inner_order);
            } else {
                sum += @reduce(.Add, @abs(inner_move)); // to the > key (manually or via rc)
                printMove(inner_move, 0);
            }
            sum += @abs(move[0]); // and press it N times (manually or should already be on A)
            printMove(.{0, 0}, @abs(move[0]));
            inner_from = '>';
        }
        if (move[0] < 0) {
            const inner_order = if (inner_from == '^' or inner_from == 'A') Order.y_first else Order.dont_care;
            const inner_move = dirpad_moves.get(.{inner_from, '<'}).?;
            if (level > 0) {
                sum += rc_dirpad(inner_move, level - 1, inner_order);
            } else {
                sum += @reduce(.Add, @abs(inner_move)); // to the < key
                printMove(inner_move, 0);
            }
            sum += @abs(move[0]); // and press it N times
            printMove(.{0, 0}, @abs(move[0]));
            inner_from = '<';
        }
        // then Y
        if (move[1] > 0) {
            const inner_order = if (inner_from == '<') Order.x_first else Order.dont_care;
            const inner_move = dirpad_moves.get(.{inner_from, '^'}).?;
            if (level > 0) {
                sum += rc_dirpad(inner_move, level - 1, inner_order);
            } else  {
                sum += @reduce(.Add, @abs(inner_move)); // to the ^ key
                printMove(inner_move, 0);
            }
            sum += @abs(move[1]); // and press it N times
            printMove(.{0, 0}, @abs(move[1]));
            inner_from = '^';
        }
        if (move[1] < 0) {
            const inner_order = Order.dont_care;
            const inner_move = dirpad_moves.get(.{inner_from, 'V'}).?;
            if (level > 0) {
                sum += rc_dirpad(inner_move, level - 1, inner_order);
            } else {
                sum += @reduce(.Add, @abs(inner_move)); // to the V key
                printMove(inner_move, 0);
            }
            sum += @abs(move[1]); // and press it N times
            printMove(.{0, 0}, @abs(move[1]));
            inner_from = 'V';
        }
        // activate button
        {
            const inner_order = if (inner_from == '<') Order.x_first else Order.dont_care;
            const inner_move = dirpad_moves.get(.{inner_from, 'A'}).?;
            if (level > 0) {
                sum += rc_dirpad(inner_move, level - 1, inner_order);
            } else {
                sum += @reduce(.Add, @abs(inner_move)); // to the A key (manually or via rc)
                // actual press happens on a different level
                printMove(inner_move, 0);
            }
            inner_from = 'A';
        }
        sum_x_first = sum;
    }
    {
        var sum: usize = 0;
        var inner_from: u8 = 'A';
        // do Y first
        if (move[1] > 0) {
            const inner_order = if (inner_from == '<') Order.x_first else Order.dont_care;
            const inner_move = dirpad_moves.get(.{inner_from, '^'}).?;
            if (level > 0) {
                sum += rc_dirpad(inner_move, level - 1, inner_order);
            } else  {
                sum += @reduce(.Add, @abs(inner_move)); // to the ^ key
                printMove(inner_move, 0);
            }
            sum += @abs(move[1]); // and press it N times
            printMove(.{0, 0}, @abs(move[1]));
            inner_from = '^';
        }
        if (move[1] < 0) {
            const inner_order = Order.dont_care;
            const inner_move = dirpad_moves.get(.{inner_from, 'V'}).?;
            if (level > 0) {
                sum += rc_dirpad(inner_move, level - 1, inner_order);
            } else {
                sum += @reduce(.Add, @abs(inner_move)); // to the V key
                printMove(inner_move, 0);
            }
            sum += @abs(move[1]); // and press it N times
            printMove(.{0, 0}, @abs(move[1]));
            inner_from = 'V';
        }
        // then X
        if (move[0] > 0) {
            const inner_order = Order.dont_care;
            const inner_move = dirpad_moves.get(.{inner_from, '>'}).?;
            if (level > 0) {
                sum += rc_dirpad(inner_move, level - 1, inner_order);
            } else {
                sum += @reduce(.Add, @abs(inner_move)); // to the > key (manually or via rc)
                printMove(inner_move, 0);
            }
            sum += @abs(move[0]); // and press it N times (manually or should already be on A)
            printMove(.{0, 0}, @abs(move[0]));
            inner_from = '>';
        }
        if (move[0] < 0) {
            const inner_order = if (inner_from == '^' or inner_from == 'A') Order.y_first else Order.dont_care;
            const inner_move = dirpad_moves.get(.{inner_from, '<'}).?;
            if (level > 0) {
                sum += rc_dirpad(inner_move, level - 1, inner_order);
            } else {
                sum += @reduce(.Add, @abs(inner_move)); // to the < key
                printMove(inner_move, 0);
            }
            sum += @abs(move[0]); // and press it N times
            printMove(.{0, 0}, @abs(move[0]));
            inner_from = '<';
        }
        // activate button
        {
            const inner_order = if (inner_from == '<') Order.x_first else Order.dont_care;
            const inner_move = dirpad_moves.get(.{inner_from, 'A'}).?;
            if (level > 0) {
                sum += rc_dirpad(inner_move, level - 1, inner_order);
            } else {
                sum += @reduce(.Add, @abs(inner_move)); // to the A key (manually or via rc)
                // actual press happens on a different level
                printMove(inner_move, 0);
            }
            inner_from = 'A';
        }
        sum_y_first = sum;
    }

    const sum: usize = switch(order) {
        .x_first => sum_x_first,
        .y_first => sum_y_first,
        .dont_care => @min(sum_x_first, sum_y_first),
    };
    if (verbosity == 2) {
        std.debug.print("{d}: {d} <-> {d} => {d}\n", .{level, sum_x_first, sum_y_first, sum});
    }
    return sum;
}

fn rc_keypad(input: []const u8, level: usize) usize {
    // level = how many robots between user and final robot
    var sum: usize = 0;
    var from: u8 = 'A';
    for (input) |to| {
        if (verbosity > 1) {
            std.debug.print(" ({c}) ", .{to});
        }
        if (verbosity == 2) {
            std.debug.print("\n", .{});
        }
        const order = if (keypad_layout.get(from).?[0] == -2 and keypad_layout.get(to).?[1] == 0) Order.x_first
            else if (keypad_layout.get(to).?[0] == -2 and keypad_layout.get(from).?[1] == 0) Order.y_first
            else Order.dont_care;
        const move = keypad_moves.get(.{from, to}).?;
        sum += rc_dirpad(move, level - 1, order);
        sum += 1; // and press it
        printMove(.{0, 0}, 1);
        from = to;
    }
    if (verbosity > 2) {
        std.debug.print("\n", .{});
    }
    return sum;
}

test "keypad_moves" {
    try init();
    defer deinit();

    const input = "029A";
    const expected: usize = "<A^A>^^AvvvA".len;
    var sum: usize = input.len; // activations
    var from: u8 = 'A';
    for (input) |to| {
        const move = keypad_moves.get(.{from, to}).?;
        sum += @reduce(.Add, @abs(move));
        from = to;
    }
    try testing.expectEqual(expected, sum);
}

test "1dir_keypad" {
    try init();
    defer deinit();
    const input = "029A";
    const expected = "v<<A>>^A<A>AvA<^AA>A<vAAA>^A".len;
    const sum = rc_keypad(input, 1);
    try testing.expectEqual(expected, sum);
}

test "2dir_keypad" {
    try init();
    defer deinit();
    const input = "029A";
    const expected = "<vA<AA>>^AvAA<^A>A<v<A>>^AvA^A<vA>^A<v<A>^A>AAvA^A<v<A>A>^AAAvA<^A>A".len;
    const sum = rc_keypad(input, 2);
    try testing.expectEqual(expected, sum);
}

test "2dir_keypad_379A" {
    try init();
    defer deinit();
    const input = "379A";
    const expected = "<v<A>>^AvA^A<vA<AA>>^AAvA<^A>AAvA^A<vA>^AA<A>A<v<A>A>^AAAvA<^A>A".len;
    const sum = rc_keypad(input, 2);
    try testing.expectEqual(expected, sum);
}
