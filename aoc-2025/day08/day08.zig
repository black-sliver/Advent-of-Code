const std = @import("std");
const builtin = @import("builtin");

const F = f32;

const Coord = @Vector(3, F);
const Connection = struct {
    a: usize,
    b: usize,
    distance: F,
};

fn getDistance(a: Coord, b: Coord) F {
    const d = a - b;
    const d2 = d * d;
    return std.math.sqrt(@reduce(.Add, d2));
}

fn sortByDistance(_: void, a: Connection, b: Connection) bool {
    return a.distance < b.distance;
}

const IndexSet = std.AutoHashMap(usize, void);
const SetMap = std.AutoHashMap(usize, usize);

fn findAllConnections(allocator: std.mem.Allocator, boxes: []const Coord) !std.ArrayList(Connection) {
    // NOTE: majority of time is spent in this function.
    // This could be improved by filtering what to add to the connection list.
    if (boxes.len >= 4096) {
        return error.TooMuchMemory;
    }
    var res: std.ArrayList(Connection) = .empty;
    try res.ensureTotalCapacity(allocator, boxes.len * boxes.len / 2);
    for (0..boxes.len) |i| {
        for (i + 1..boxes.len) |j| {
            res.appendAssumeCapacity(.{
                .a = i,
                .b = j,
                .distance = getDistance(boxes[i], boxes[j]),
            });
        }
    }
    std.mem.sortUnstable(Connection, res.items, {}, sortByDistance);
    return res;
}

// - part1 -

fn biggestSetFirst(_: void, a: IndexSet, b: IndexSet) bool {
    return a.count() > b.count();
}

fn findSets(allocator: std.mem.Allocator, comptime num_sets: usize, comptime num_connections: usize, connections: []const Connection, res: *[num_sets]IndexSet) !void {
    var sets_used: usize = 0;
    var sets: [num_connections]IndexSet = undefined;
    defer for (num_sets..sets_used) |i| sets[i].deinit();
    var set_map: SetMap = .init(allocator); // for each index points to one of the sets
    defer set_map.deinit();
    // create all sets
    for (connections) |connection| {
        const a_set_i = set_map.get(connection.a);
        if (a_set_i) |i| {
            // found a -> insert b
            try sets[i].put(connection.b, {});
            try set_map.put(connection.b, i);
        } else {
            const b_set_i = set_map.get(connection.b);
            if (b_set_i) |i| {
                // found b -> insert a
                try sets[i].put(connection.a, {});
                try set_map.put(connection.a, i);
            } else {
                // both a and b new
                const i = sets_used;
                sets_used += 1;
                sets[i] = IndexSet.init(allocator);
                try sets[i].put(connection.a, {});
                try sets[i].put(connection.b, {});
                try set_map.put(connection.a, i);
                try set_map.put(connection.b, i);
            }
        }
    }
    // merge all sets
    outer: for (0..sets_used) |i| {
        var it = sets[i].keyIterator();
        while (it.next()) |check| {
            for (i + 1..sets_used) |j| {
                if (sets[j].contains(check.*)) {
                    // merge sets[i] into sets[j]
                    var it2 = sets[i].keyIterator();
                    while (it2.next()) |value| {
                        try sets[j].put(value.*, {});
                    }
                    // clear sets[i]
                    sets[i].clearRetainingCapacity();
                    continue :outer;
                }
            }
        }
    }
    // sort and return top N
    std.mem.sortUnstable(IndexSet, sets[0..sets_used], {}, biggestSetFirst);
    std.mem.copyForwards(IndexSet, res, sets[0..num_sets]);
}

fn part1(allocator: std.mem.Allocator, comptime num_sets: usize, comptime num_connections: usize, connections: []const Connection) !usize {
    var sets: [num_sets]IndexSet = undefined;
    try findSets(allocator, num_sets, num_connections, connections[0..num_connections], &sets);
    defer for (&sets) |*set| set.deinit();
    var res: usize = 1;
    for (sets) |set| {
        res *= set.count();
    }
    return res;
}

// - part2 -

fn part2(allocator: std.mem.Allocator, connections: []const Connection, boxes: []const Coord) !F {
    var sets: std.ArrayList(std.ArrayList(usize)) = .empty;
    defer sets.deinit(allocator);
    defer for (sets.items) |*set| set.deinit(allocator);
    var set_map: SetMap = .init(allocator); // for each index points to one of the sets
    defer set_map.deinit();

    var last_mod: usize = 0;

    for (connections, 0..) |connection, n| {
        const a_set_i = set_map.get(connection.a);
        const b_set_i = set_map.get(connection.b);
        if (a_set_i) |i| {
            if (b_set_i) |j| {
                if (i == j) {
                    // already the same set
                } else {
                    // found a and b
                    // if new sets has all boxes in it, we are done
                    if (sets.items[i].items.len + sets.items[j].items.len == boxes.len) {
                        last_mod = n;
                        break;
                    }
                    // otherwise merge sets[i] into sets[j]
                    for (sets.items[i].items) |value| {
                        try set_map.put(value, j);
                        try sets.items[j].append(allocator, value);
                    }
                    // clear and remove sets[i]
                    sets.items[i].clearRetainingCapacity();
                    if (i == sets.items.len - 1) {
                        sets.items[i].deinit(allocator);
                        _ = sets.orderedRemove(i);
                    }
                }
            } else {
                // found a -> insert b
                try sets.items[i].append(allocator, connection.b);
                try set_map.put(connection.b, i);
                // if sets[i] has all boxes in it, we are done
                if (sets.items[i].items.len == boxes.len) {
                    last_mod = n;
                    break;
                }
            }
        } else if (b_set_i) |i| {
            // found b -> insert a
            try sets.items[i].append(allocator, connection.a);
            try set_map.put(connection.a, i);
            // if sets[i] has all boxes in it, we are done
            if (sets.items[i].items.len == boxes.len) {
                last_mod = n;
                break;
            }
        } else {
            // both a and b new
            const i = sets.items.len;
            try sets.append(allocator, .empty);
            try sets.items[i].append(allocator, connection.a);
            try sets.items[i].append(allocator, connection.b);
            try set_map.put(connection.a, i);
            try set_map.put(connection.b, i);
        }
    }

    return boxes[connections[last_mod].a][0] * boxes[connections[last_mod].b][0];
}

// - main -

fn readInput(allocator: std.mem.Allocator, boxes: *std.ArrayList(Coord)) !void {
    var file_buffer: [4096]u8 = undefined;
    const file = try std.fs.cwd().openFile("input.txt", .{});
    defer file.close();
    var reader = file.reader(&file_buffer);
    while (try reader.interface.takeDelimiter('\n')) |line| {
        var it = std.mem.splitScalar(u8, line, ',');
        const box = Coord{
            try std.fmt.parseFloat(F, it.next() orelse return error.InvalidInput),
            try std.fmt.parseFloat(F, it.next() orelse return error.InvalidInput),
            try std.fmt.parseFloat(F, it.next() orelse return error.InvalidInput),
        };
        try boxes.append(allocator, box);
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

    var boxes: std.ArrayList(Coord) = .empty;
    defer boxes.deinit(allocator);

    try readInput(allocator, &boxes);

    var connections = try findAllConnections(allocator, boxes.items);
    defer connections.deinit(allocator);

    const res1 = try part1(allocator, 3, 1000, connections.items);
    try stdout.print("{}\n", .{res1});
    const res2 = try part2(allocator, connections.items, boxes.items);
    try stdout.print("{}\n", .{res2});
}

const test_input = [_]Coord{
    .{ 162, 817, 812 },
    .{ 57, 618, 57 },
    .{ 906, 360, 560 },
    .{ 592, 479, 940 },
    .{ 352, 342, 300 },
    .{ 466, 668, 158 },
    .{ 542, 29, 236 },
    .{ 431, 825, 988 },
    .{ 739, 650, 466 },
    .{ 52, 470, 668 },
    .{ 216, 146, 977 },
    .{ 819, 987, 18 },
    .{ 117, 168, 530 },
    .{ 805, 96, 715 },
    .{ 346, 949, 466 },
    .{ 970, 615, 88 },
    .{ 941, 993, 340 },
    .{ 862, 61, 35 },
    .{ 984, 92, 344 },
    .{ 425, 690, 689 },
};

test "part1" {
    const allocator = std.testing.allocator;
    var connections = try findAllConnections(allocator, &test_input);
    defer connections.deinit(allocator);
    try std.testing.expectEqual(40, try part1(allocator, 3, 10, connections.items));
}

test "part2" {
    const allocator = std.testing.allocator;
    var connections = try findAllConnections(allocator, &test_input);
    defer connections.deinit(allocator);
    try std.testing.expectEqual(25272, try part2(allocator, connections.items, &test_input));
}
