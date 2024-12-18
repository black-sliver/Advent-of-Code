const std = @import("std");
const fmt = std.fmt;
const math = std.math;
const mem = std.mem;


const Tile = enum {
    space,
    wall,
};

const I = usize;
const Coord = @Vector(2, I);
const Row = std.ArrayList(Tile);
const Map = std.ArrayList(Row);
const Node = struct {
    connections: u8 = 0,
    to: [4]Coord = [_]Coord{Coord{0, 0}} ** 4,
};
const Nodes = std.AutoHashMap(Coord, Node);

const DijkstraNode = struct {
    visited: bool = false,
    distance: usize = math.maxInt(usize),
};

const DijkstraNodes = std.AutoHashMap(Coord, DijkstraNode);

fn minDistance(output: *DijkstraNodes) ?Coord {
    var min_coord: ?Coord = null;
    var min_distance: usize = math.maxInt(usize);

    var it = output.iterator();
    while (it.next()) |entry| {
        if (entry.value_ptr.visited) {
            continue;
        }
        if (entry.value_ptr.distance < min_distance) {
            min_distance = entry.value_ptr.distance;
            min_coord = entry.key_ptr.*;
        }
    }

    return min_coord;
}

fn dijkstra(nodes: *Nodes, output: *DijkstraNodes, start: Coord, end: Coord) !void {
    _ = end;
    try output.put(start, DijkstraNode{.distance = 0});

    for (0..nodes.count() - 1) |_| {
        const pos = minDistance(output) orelse return; // error.AlreadyDone;
        var entry = output.getEntry(pos).?;

        const current_node = nodes.get(pos) orelse return error.NoStart;
        entry.value_ptr.visited = true;

        // update each connected node
        for (current_node.to[0..current_node.connections]) |connection| {
            var dest_entry = output.getEntry(connection);
            if (dest_entry != null and dest_entry.?.value_ptr.visited) {
                continue;
            }
            const next_distance = entry.value_ptr.distance + 1;
            if (dest_entry == null) {
                try output.put(connection, DijkstraNode{
                    .distance = next_distance,
                });
            }
            else if (next_distance < dest_entry.?.value_ptr.distance) {
                dest_entry.?.value_ptr.distance = next_distance;
            }
        }
    }
}

fn removeConnection(node: *Node, pos: Coord) bool {
    for (node.to[0..node.connections], 0..) |to, i| {
        if (@reduce(.And, to == pos)) {
            for (i..node.connections-1) |j| {
                node.to[j] = node.to[j+1];
            }
            node.connections -= 1;
            return true;
        }
    }
    return false;
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

    const start: Coord = Coord{0, 0};
    const end: Coord = Coord{70, 70}; // real
    //const end: Coord = Coord{6, 6}; // sample
    //var remaining: usize = 12; // sample
    var remaining: usize = 1024; // real

    const width: usize = end[0] + 1;
    var map: [width][width]Tile = undefined;
    for (0..width) |y| {
        @memset(&map[y], Tile.space);
    }

    var buf: [256]u8 = undefined;
    while (try stream.readUntilDelimiterOrEof(&buf, '\n')) |line| {
        var it = std.mem.splitScalar(u8, line, ',');
        const x = try fmt.parseInt(u8, it.next() orelse return error.Input, 10);
        const y = try fmt.parseInt(u8, it.next() orelse return error.Input, 10);
        map[y][x] = Tile.wall;
        remaining -= 1;
        if (remaining == 0) {
            break;
        }
    }

    var nodes = Nodes.init(allocator);

    for (0..width) |y| {
        for (0..width) |x| {
            if (map[y][x] == Tile.space) {
                try nodes.put(Coord{x, y}, Node{});
            }
        }
    }

    {
        var it = nodes.iterator();
        while (it.next()) |entry| {
            const pos = entry.key_ptr.*;
            if (pos[0] > 0) {
                const other = Coord{pos[0] - 1, pos[1]};
                if (nodes.contains(other)) {
                    entry.value_ptr.to[entry.value_ptr.connections] = other;
                    entry.value_ptr.connections += 1;
                }
            }
            if (pos[0] < width - 1) {
                const other = Coord{pos[0] + 1, pos[1]};
                if (nodes.contains(other)) {
                    entry.value_ptr.to[entry.value_ptr.connections] = other;
                    entry.value_ptr.connections += 1;
                }
            }
            if (pos[1] > 0) {
                const other = Coord{pos[0], pos[1] - 1};
                if (nodes.contains(other)) {
                    entry.value_ptr.to[entry.value_ptr.connections] = other;
                    entry.value_ptr.connections += 1;
                }
            }
            if (pos[1] < width - 1) {
                const other = Coord{pos[0], pos[1] + 1};
                if (nodes.contains(other)) {
                    entry.value_ptr.to[entry.value_ptr.connections] = other;
                    entry.value_ptr.connections += 1;
                }
            }
        }
    }

    // part 1:
    var distances = DijkstraNodes.init(allocator);
    try distances.ensureTotalCapacity(nodes.count());
    try dijkstra(&nodes, &distances, start, end);

    const result1 = distances.get(end).?.distance;

    try stdout.print("Result1: {d}\n", .{result1});

    // part 2:
    // IMPORTANT: build with -OReleaseFast and it should finish in a minute
    while (try stream.readUntilDelimiterOrEof(&buf, '\n')) |line| {
        var it = std.mem.splitScalar(u8, line, ',');
        const x = try fmt.parseInt(u8, it.next() orelse return error.Input, 10);
        const y = try fmt.parseInt(u8, it.next() orelse return error.Input, 10);

        const pos = Coord{x, y};
        if (x > 0) {
            if (nodes.getPtr(Coord{x-1, y})) |node| {
                _ = removeConnection(node, pos);
            }
        }
        if (y > 0) {
            if (nodes.getPtr(Coord{x, y-1})) |node| {
                _ = removeConnection(node, pos);
            }
        }
        if (x < width - 1) {
            if (nodes.getPtr(Coord{x+1, y})) |node| {
                _ = removeConnection(node, pos);
            }
        }
        if (y < width - 1) {
            if (nodes.getPtr(Coord{x, y+1})) |node| {
                _ = removeConnection(node, pos);
            }
        }
        if (@reduce(.And, pos == start)) {
            std.debug.print("Removed start\n", .{});
            try stdout.print("Result2: {d},{d}\n", .{x, y});
            break;
        }

        distances.clearRetainingCapacity();
        try dijkstra(&nodes, &distances, start, end);
        const end_distance = distances.get(end);
        if (end_distance == null or end_distance.?.distance == math.maxInt(usize)) {
            try stdout.print("Result2: {d},{d}\n", .{x, y});
            break;
        }
    }
}
