const std = @import("std");
const fmt = std.fmt;
const mem = std.mem;
const testing = std.testing;

// Common between part 1 and 2

const PC = [2]u8;
const Connection = [2]PC;
const ConnectionList = std.ArrayList(Connection);
const Connections = []Connection;

// part 1, without memory allocation

const Order = std.math.Order;

inline fn isHistorian(pc: PC) bool {
    return pc[0] == 't';
}

fn historianLessThan(lhs: PC, rhs: PC) bool {
    if (lhs[0] == rhs[0]) {
        return lhs[1] < rhs[1];
    }
    if (isHistorian(rhs)) {
        return false;
    }
    return (isHistorian(lhs) or lhs[0] < rhs[0]);
}

fn historianConnectionLessThan(_: void, lhs: Connection, rhs: Connection) bool {
    // expect that pc1 of each connection is lower than pc2
    // if (pc1 of connection1 == pc1 of connection2), then compare pc2
    // otherwise compare only pc1
    if (mem.eql(u8, &lhs[0], &rhs[0])) {
        return historianLessThan(lhs[1], rhs[1]);
    }
    return historianLessThan(lhs[0], rhs[0]);
}

fn historianFindConnection(_: void, key: Connection, mid_item: Connection) Order {
    if (mem.eql(PC, &key, &mid_item)) {
        return Order.eq;
    }
    if (historianConnectionLessThan({}, key, mid_item)) {
        return Order.lt;
    }
    return Order.gt;
}

fn countHistorianLANs(conns: Connections) usize {
    // we try to find a solution that doesn't need to allocate
    var res: usize = 0;

    // sort the points in each pair
    for (conns, 0..) |_,i| {
        if (historianLessThan(conns[i][1], conns[i][0])) {
            mem.swap(PC, &conns[i][0], &conns[i][1]);
        }
    }
    // sort the pairs
    mem.sortUnstable(Connection, conns, {}, historianConnectionLessThan);

    // look for triplets
    for (conns, 1..) |conn1, i| {
        if (!isHistorian(conn1[0])) {
            break;
        }
        for (conns[i..], i+1..) |conn2, j| {
            if (!mem.eql(u8, &conn2[0], &conn1[0])) {
                break;
            }
            var conn3 = [2]PC{conn1[1], conn2[1]};
            if (historianLessThan(conn3[1], conn3[0])) {
                mem.swap(PC, &conn3[0], &conn3[1]);
            }

            // binary search for the 3rd connection
            if (std.sort.binarySearch(Connection, conn3, conns[j..], {}, historianFindConnection)) |_| {
                res += 1;
            }
        }
    }

    return res;
}

// part2

const PCSet = std.AutoHashMap(PC, void);
const ConnectionsMap = std.AutoHashMap(PC, PCSet);

fn pcLessThan(_: void, lhs: PC, rhs: PC) bool {
    if (lhs[0] == rhs[0]) {
        return lhs[1] < rhs[1];
    }
    return lhs[0] < rhs[0];
}

fn copySetInto(to: *PCSet, from: *const PCSet) !void {
    to.clearRetainingCapacity();
    var it = from.keyIterator();
    while (it.next()) |key1| {
        try to.put(key1.*, {});
    }
}

fn setIntersectionInto(to: *PCSet, from1: *const PCSet, from2: *const PCSet) !void {
    to.clearRetainingCapacity();
    var it1 = from1.keyIterator();
    while (it1.next()) |key1| {
        if (from2.contains(key1.*)) {
            try to.put(key1.*, {});
        }
    }
}

fn bronKerbosch2(allocator: mem.Allocator, connections: *ConnectionsMap, r: *PCSet, p: *PCSet, x: *PCSet, res: *PCSet) !usize {
    var pivot: PC = undefined;
    var p_it = p.keyIterator();
    if (p_it.next()) |p_key| {
        pivot = p_key.*;
    } else {
        var x_it = x.keyIterator();
        if (x_it.next()) |x_key| {
            pivot = x_key.*;
        } else {
            try copySetInto(res, r);
            return res.count();
        }
    }

    var best_len: usize = 0;
    var best_res = PCSet.init(allocator);
    defer best_res.deinit();
    var sub_res = PCSet.init(allocator);
    defer sub_res.deinit();
    var new_p = PCSet.init(allocator);
    defer new_p.deinit();
    var new_x = PCSet.init(allocator);
    defer new_x.deinit();
    var new_r = PCSet.init(allocator);
    defer new_r.deinit();

    const pivot_connections = connections.get(pivot);
    p_it = p.keyIterator();
    while (p_it.next()) |p_key| {
        const v = p_key.*;
        if (pivot_connections.?.contains(v)) {
            continue;
        }
        // (R ⋃ {v}, P ⋂ N(v), X ⋂ N(v))
        try copySetInto(&new_r, r);
        try new_r.put(v, {});
        const v_connections = connections.get(v).?;
        try setIntersectionInto(&new_p, p, &v_connections);
        try setIntersectionInto(&new_x, x, &v_connections);
        const new_len = try bronKerbosch2(allocator, connections, &new_r, &new_p, &new_x, &sub_res);
        if (new_len > best_len) {
            try copySetInto(&best_res, &sub_res);
            best_len = new_len;
        }
        _ = p.remove(v);
        try x.put(v, {});
    }

    res.clearRetainingCapacity();
    var res_it = best_res.keyIterator();
    while (res_it.next()) |pc| {
        try res.put(pc.*, {});
    }
    return best_len;
}

fn findBiggestLanSorted(allocator: mem.Allocator, conns: Connections, res: *std.ArrayList(PC)) !void {
    var empty1 = PCSet.init(allocator);
    defer empty1.deinit();
    var empty2 = PCSet.init(allocator);
    defer empty2.deinit();
    var pcs = PCSet.init(allocator);
    defer pcs.deinit();
    var set_res = PCSet.init(allocator);
    defer set_res.deinit();
    // conns -> set of pcs, conns -> set of connections
    var connections_map = ConnectionsMap.init(allocator);
    defer {
        var it = connections_map.valueIterator();
        while (it.next()) |value| {
            value.deinit();
        }
        connections_map.deinit();
    }
    for (conns) |conn| {
        for (0..2) |i| {
            try pcs.put(conn[i], {});
            const connections_entry = try connections_map.getOrPut(conn[i]);
            if (!connections_entry.found_existing) {
                connections_entry.value_ptr.* = PCSet.init(allocator);
            }
            try connections_entry.value_ptr.*.put(conn[i^1], {});
        }
    }
    _ = try bronKerbosch2(allocator, &connections_map, &empty1, &pcs, &empty2, &set_res);
    var res_it = set_res.keyIterator();
    while (res_it.next()) |pc| {
        try res.append(pc.*);
    }
    mem.sortUnstable(PC, res.items, {}, pcLessThan);
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

    var input = try ConnectionList.initCapacity(allocator, 3380);

    var buf: [8]u8 = undefined;
    while (try stream.readUntilDelimiterOrEof(&buf, '\n')) |line| {
        std.debug.assert(line.len == 5 and line[2] == '-');
        try input.append(.{line[0..2].*, line[3..5].*});
    }

    const result1 = countHistorianLANs(input.items);
    try stdout.print("Result1: {d}\n", .{result1});

    var result2 = std.ArrayList(PC).init(allocator);
    try findBiggestLanSorted(allocator, input.items, &result2);

    try stdout.print("Result2: ", .{});
    for (result2.items, 0..) |pc, i| {
        if (i > 0) {
            try stdout.print(",", .{});
        }
        try stdout.print("{c}{c}", .{pc[0], pc[1]});
    }
    try stdout.print("\n", .{});
}

const sample_input = [_]*const [5:0]u8{
    "kh-tc", "qp-kh", "de-cg", "ka-co", "yn-aq", "qp-ub", "cg-tb", "vc-aq",
    "tb-ka", "wh-tc", "yn-cg", "kh-ub", "ta-co", "de-co", "tc-td", "tb-wq",
    "wh-td", "ta-ka", "td-qp", "aq-cg", "wq-ub", "ub-vc", "de-ta", "wq-aq",
    "wq-vc", "wh-yn", "ka-de", "kh-ta", "co-tc", "wh-qp", "tb-vc", "td-yn",
};

test "part1_sample" {
    var input: [sample_input.len]Connection = undefined;
    for (sample_input, 0..) |line, i| {
        input[i] = (.{line[0..2].*, line[3..5].*});
    }
    const result = countHistorianLANs(&input);
    const expected = 7;
    try testing.expectEqual(expected, result);
}

test "part2_sample" {
    const allocator = testing.allocator;
    var input: [sample_input.len]Connection = undefined;
    for (sample_input, 0..) |line, i| {
        input[i] = (.{line[0..2].*, line[3..5].*});
    }
    var result = std.ArrayList(PC).init(allocator);
    defer result.deinit();
    try findBiggestLanSorted(allocator, &input, &result);
    var result_str = std.ArrayList(u8).init(allocator);
    defer result_str.deinit();
    for (result.items, 0..) |pc, i| {
        if (i != 0) {
            try result_str.append(',');
        }
        try result_str.append(pc[0]);
        try result_str.append(pc[1]);
    }
    const expected: []const u8 = "co,de,ka,ta";
    try testing.expectEqualSlices(u8, expected, result_str.items);
}
