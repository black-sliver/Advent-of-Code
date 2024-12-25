const std = @import("std");
const fmt = std.fmt;
const math = std.math;
const mem = std.mem;

const Tile = enum {
    space,
    wall,
    path,
};

const Dir = enum {
    east,
    south,
    west,
    north,
};

const turn_cost = 1000;
const step_cost = 1;

const I = u32;
const Coord = @Vector(2, I);

const Link = struct {
    to: *Node,
    points: usize,
};

const Node = struct {
    const Self = @This();

    allocator: mem.Allocator,
    next: []Link,
    pos: Coord,
    dir: Dir,

    pub fn init(allocator: mem.Allocator, coord: Coord, dir: Dir) !Self {
        var res = Node{
            .next = try allocator.alloc(Link, 3),
            .pos = coord,
            .dir = dir,
            .allocator = allocator,
        };
        res.next.len = 0;
        return res;
    }

    pub fn deinit(self: *Self) void {
        self.allocator.free(self.next);
    }

    pub fn connect(self: *Self, to: *Node, points: usize) !void {
        //std.debug.print("Connect {} {} -> {} {}\n", .{self.pos, self.dir, to.pos, to.dir});
        if (self.next.len >= 3) {
            return error.Full;
        }
        self.next.len += 1;
        self.next[self.next.len - 1] = Link{
            .to = to,
            .points =  points,
        };
    }
};

const PathNode = struct{
    const Self = @This();

    points: usize,
    node: *Node,
    from: std.ArrayList(*Node),

    fn init(allocator: mem.Allocator, points: usize, node: *Node, from: ?*Node) !Self {
        var self = Self{
            .points = points,
            .node = node,
            .from = std.ArrayList(*Node).init(allocator),
        };
        if (from != null) {
            try self.from.append(from.?);
        }
        return self;
    }

    fn deinit(self: *Self) void {
        self.from.clearRetainingCapacity(); // set len=0, just in case
        self.from.deinit();
    }
};

const Key = struct {
    pos: Coord,
    dir: Dir,
};

const Row = std.ArrayList(Tile);
const Map = std.ArrayList(Row);
const Nodes = std.AutoHashMap(Key, *Node);
const PathNodes = std.AutoHashMap(*Node, PathNode);
const Unprocessed = std.AutoArrayHashMap(*Node, PathNode);
const CoordSet = std.AutoArrayHashMap(Key, void);

fn parseRow(line: []const u8, row: *Row, start: *Coord, end: *Coord, y: I) !void {
    for (line) |c| {
        if (c == '#') {
            try row.append(Tile.wall);
        } else if (c == '.') {
            try row.append(Tile.space);
        } else if (c == 'S') {
            start.* = Coord{@intCast(row.items.len), y};
            try row.append(Tile.space);
        } else if (c == 'E') {
            end.* = Coord{@intCast(row.items.len), y};
            try row.append(Tile.space);
        } else {
            std.debug.assert(false);
            try row.append(Tile.space);
        }
    }
}

fn step(p: Coord, dir: Dir) Coord {
    switch (dir) {
        Dir.east => return Coord{p[0]+1, p[1]},
        Dir.south => return Coord{p[0], p[1]+1},
        Dir.west => return Coord{p[0]-1, p[1]},
        Dir.north => return Coord{p[0], p[1]-1},
    }
}

fn back(dir: Dir) Dir {
    switch (dir) {
        Dir.east => return Dir.west,
        Dir.south => return Dir.north,
        Dir.west => return Dir.east,
        Dir.north => return Dir.south,
    }
}

fn left(dir: Dir) Dir {
    switch (dir) {
        Dir.east => return Dir.north,
        Dir.south => return Dir.east,
        Dir.west => return Dir.south,
        Dir.north => return Dir.west,
    }
}

fn right(dir: Dir) Dir {
    switch (dir) {
        Dir.east => return Dir.south,
        Dir.south => return Dir.west,
        Dir.west => return Dir.north,
        Dir.north => return Dir.east,
    }
}

fn cleanupNodes(nodes: *Nodes, start: *Node) !Nodes {
    const allocator = nodes.allocator;
    var next = try std.ArrayList(*Node).initCapacity(allocator, 20);
    defer next.deinit();
    var new_nodes = Nodes.init(nodes.allocator);
    try next.append(start);
    var count: usize = 0;
    while (next.items.len > 0) {
        count += 1;
        const node = next.orderedRemove(0);
        for (node.next) |link| {
            const key = Key{.pos = link.to.pos, .dir = link.to.dir};
            const e = try new_nodes.getOrPut(key);
            if (!e.found_existing) {
                e.value_ptr.* = link.to;
                try next.append(link.to);
            }
        }
    }
    nodes.deinit();
    return new_nodes;
}

fn printMap(map: *Map) void {
    var buf = [_]u8{0} ** 2048;
    for (map.items) |row| {
        var p: usize = 0;
        for (row.items) |tile| {
            const tile_sym = switch (tile) {
                Tile.wall => "███",
                Tile.space => "   ",
                Tile.path => " O ",
            };
            @memcpy(buf[p..p+tile_sym.len], tile_sym);
            p += tile_sym.len;
        }
        std.debug.print("{s}\n", .{buf[0..p]});
    }
}

fn fillPath(map: *Map, output: *PathNodes, end: Coord) void {
    map.items[end[1]].items[end[0]] = Tile.path;
    var node = output.get(end).?;
    var dir = back(node.dir);
    var pos = step(end, dir);
    while (true) : (pos = step(pos, dir)) {
        map.items[pos[1]].items[pos[0]] = Tile.path;
        if (output.get(pos)) |new_node| {
            if (new_node.points == 0) {
                break; // done
            }
            node = new_node;
            dir = back(new_node.dir);
        }
        const next_pos = step(pos, dir);
        if (map.items[next_pos[1]].items[next_pos[0]] == Tile.wall) {
            const left_pos = step(pos, left(dir));
            if (map.items[left_pos[1]].items[left_pos[0]] != Tile.wall) {
                dir = left(dir);
            } else {
                dir = right(dir);
            }
        }
    }
}

fn countPathTiles(map: *Map) usize {
    var sum: usize = 0;
    for (map.items) |row| {
        for (row.items) |tile| {
            if (tile == Tile.path) {
                sum += 1;
            }
        }
    }
    return sum;
}

fn getMinPointsEntry(unprocessed: *Unprocessed) ?@TypeOf(unprocessed.*).Entry {
    var min_entry: ?@TypeOf(unprocessed.*).Entry = null;
    var min_points: usize = math.maxInt(usize);

    var it = unprocessed.iterator();
    while (it.next()) |entry| {
        if (entry.value_ptr.points < min_points) {
            min_points = entry.value_ptr.points;
            min_entry = entry;
        }
    }
    return min_entry;
}

fn findBestPath(nodes: *Nodes, output: *PathNodes, start: *Node, end: *const Node) !bool {
    const allocator = output.allocator;
    const node_count = nodes.count();
    try output.ensureTotalCapacity(node_count);
    var unprocessed = Unprocessed.init(allocator);
    defer unprocessed.deinit();
    try unprocessed.ensureTotalCapacity(node_count / 40);
    try unprocessed.put(start, try PathNode.init(allocator, 0, start, null));

    for (0..node_count) |_| {
        const entry = getMinPointsEntry(&unprocessed) orelse break; // error.AlreadyFinished;

        const current_node = entry.value_ptr.node;
        try output.put(entry.key_ptr.*, entry.value_ptr.*);
        const points = entry.value_ptr.points;
        _ = unprocessed.swapRemove(entry.key_ptr.*); // moved to output, so don't deinit

        if (current_node == end) {
            // done
            break;
        }

        // update each connected node
        for (current_node.next) |connection| {
            const key = connection.to;
            if (output.contains(key)) {
                continue; // already processed
            }
            const next_points = points + connection.points;
            var dest_entry = try unprocessed.getOrPut(key);
            if (!dest_entry.found_existing) {
                dest_entry.value_ptr.* = try PathNode.init(allocator, next_points, connection.to, current_node);
            } else if (next_points < dest_entry.value_ptr.points) {
                dest_entry.value_ptr.points = next_points;
                dest_entry.value_ptr.from.clearRetainingCapacity();
                try dest_entry.value_ptr.from.append(current_node);
            } else if (next_points == dest_entry.value_ptr.points) {
                try dest_entry.value_ptr.from.append(current_node);
            }
        }
    }
    return true;
}

inline fn createStartNodes(allocator: mem.Allocator, pos: Coord, dir: Dir, map: *Map) ![4]*Node {
    const nodes = try createNodes(allocator, pos, map);
    const start_node = nodes[@intFromEnum(dir)];
    const left_dir = left(dir);
    const right_dir = right(dir);
    const left_node = nodes[@intFromEnum(left_dir)];
    try start_node.connect(left_node, turn_cost);
    const right_node = nodes[@intFromEnum(right_dir)];
    try start_node.connect(right_node, turn_cost);
    return nodes;
}

inline fn createEndNodes(allocator: mem.Allocator, pos: Coord, map: *Map) ![4]*Node {
    // TODO: special-case this one so we don't create connections FROM end, only TO end.
    return createNodes(allocator, pos, map);
}

inline fn createNodes(allocator: mem.Allocator, pos: Coord, map: *Map) ![4]*Node {
    var nodes = [_]*Node{
        try allocator.create(Node),
        try allocator.create(Node),
        try allocator.create(Node),
        try allocator.create(Node),
    };
    inline for (std.meta.fields(Dir)) |f| {
        const dir: Dir = @enumFromInt(f.value);
        nodes[f.value].* = try Node.init(allocator, pos, dir);
    }
    inline for (std.meta.fields(Dir)) |f| {
        const dir: Dir = @enumFromInt(f.value);
        const left_dir = left(dir);
        const right_dir = right(dir);
        const left_pos = step(pos, left_dir);
        const right_pos = step(pos, right_dir);
        const back_pos = step(pos, back(dir));
        // never turn towards a wall.
        // never turn when moving away from a wall.
        // this removes a lot of unused connections and allows us to collapse nodes later
        if (map.items[left_pos[1]].items[left_pos[0]] != Tile.wall
                and map.items[back_pos[1]].items[back_pos[0]] != Tile.wall) {
            const turn_left = nodes[@intFromEnum(left_dir)];
            try nodes[f.value].connect(turn_left, turn_cost);
        }
        if (map.items[right_pos[1]].items[right_pos[0]] != Tile.wall
                and map.items[back_pos[1]].items[back_pos[0]] != Tile.wall) {
            const turn_right = nodes[@intFromEnum(right_dir)];
            try nodes[f.value].connect(turn_right, turn_cost);
        }
    }
    return nodes;
}

fn findNodes(allocator: mem.Allocator, nodes: *Nodes, map: *Map, start_pos: Coord, end_pos: Coord) !void {
    for (map.items[1..map.items.len-1], 1..) |row, y| {
        var last_x: usize = 0;
        // indexOfScalarPosLinear would maybe be better if that existed
        while (std.mem.indexOfScalarPos(Tile, row.items, last_x+1, Tile.space)) |x| : (last_x = x) {
            var horizontal_directions: usize = 0;
            var vertical_directions: usize = 0;
            const pos = Coord{@intCast(x), @intCast(y)};
            if (@reduce(.And, pos == start_pos) or @reduce(.And, pos == end_pos)) {
                continue;
            }
            inline for (std.meta.fields(Dir)) |f| {
                const next_dir: Dir = @enumFromInt(f.value);
                const next_pos = step(pos, next_dir);
                if (map.items[next_pos[1]].items[next_pos[0]] == Tile.space) {
                    if (next_dir == Dir.north or next_dir == Dir.south) {
                        vertical_directions += 1;
                    } else {
                        horizontal_directions += 1;
                    }
                }
            }
            if (horizontal_directions < 1 or vertical_directions < 1) {
                // straigt line
                continue;
            }
            // crossing or corner -> create 4 nodes, 1 per direction and connect them
            for (try createNodes(allocator, pos, map)) |node| {
                try nodes.put(.{.pos = node.pos, .dir = node.dir}, node);
            }
        }
    }
}

fn findConnection(nodes: *Nodes, map: *Map, start_pos: Coord, dir: Dir) !void {
    var pos = step(start_pos, dir);
    var entry: ?Nodes.Entry = null;
    var cost: usize = step_cost; // TODO: instead we could calculate the distance between start and end
    while (true) : (cost += step_cost) {
        // step until we hit a dead end or another node
        if (map.items[pos[1]].items[pos[0]] == Tile.wall) {
            return;
        }
        entry = nodes.getEntry(.{.pos = pos, .dir = dir});
        if (entry != null) {
            break;
        }
        pos = step(pos, dir);
    }
    // add connection to node
    std.debug.assert(entry != null); // should return early if that'd be true
    var start_node = nodes.get(.{.pos = start_pos, .dir = dir}) orelse return error.NoSuchNode;
    const end_node = entry.?.value_ptr.*;
    try start_node.connect(end_node, cost);
}

fn collapseConnections(nodes: *Nodes, start_node: *const Node, end_node: *const Node) !void {
    var it = nodes.iterator();
    while (it.next()) |e| {
        const start = e.value_ptr.*;
        var node = start;
        var points: usize = 0;
        while (node.next.len == 1) {
            points += node.next[0].points;
            node = node.next[0].to;
            if (node == start_node or node == end_node) {
                break; // don't remove start or end nodes
            }
        }
        if (node != start and node != start.next[0].to) {
            start.next[0].to = node;
            start.next[0].points = points;
        }
    }
}

fn hasCoord(haystack: []Coord, needle: Coord) bool {
    for (haystack) |item| {
        if (@reduce(.And, item == needle)) {
            return true;
        }
    }
    return false;
}

fn collapseEndNodes(all_nodes: *Nodes, nodes: []*Node) *Node {
    const node = nodes[0];
    var coord_buf: [4]Coord = undefined;
    var coords: []Coord = coord_buf[0..0];
    // find all adjacent positions
    for (nodes) |a_node| {
        for (a_node.next) |a_link| {
            const pos = a_link.to.pos;
            if (!hasCoord(coords, pos)) {
                coord_buf[coords.len] = pos;
                coords = coord_buf[0..coords.len+1];
            }
        }
    }
    // update all adjecent nodes to point to node instead
    for (coords) |pos| {
        inline for (std.meta.fields(Dir)) |f| {
            const dir: Dir = @enumFromInt(f.value);
            if (all_nodes.get(.{.pos = pos, .dir = dir})) |other| {
                for (0..other.next.len) |i| {
                    if (@reduce(.And, other.next[i].to.pos == node.pos)) {
                        other.next[i].to = node;
                    }
                }
            }
        }
    }
    // also remove all outgoing connections from the end node
    node.next.len = 0;
    return node;
}

fn drawPathOnMap(map: *Map, path_nodes: *PathNodes, end: *Node) void {
    const path_end = path_nodes.get(end).?;
    for (path_end.from.items) |from| {
        var pos = from.pos;
        var dir = from.dir;
        while (true) {
            map.items[pos[1]].items[pos[0]] = Tile.path;
            if (@reduce(.And, pos == end.pos)) {
                break;
            }
            var next_dir = dir;
            var next_pos = step(pos, next_dir);
            if (map.items[next_pos[1]].items[next_pos[0]] == Tile.wall) {
                next_dir = left(dir);
                next_pos = step(pos, next_dir);
                if (map.items[next_pos[1]].items[next_pos[0]] == Tile.wall) {
                    next_dir = right(dir);
                    next_pos = step(pos, next_dir);
                    if (map.items[next_pos[1]].items[next_pos[0]] == Tile.wall) {
                        @panic("Invalid path_nodes!");
                    }
                }
            }
            pos = next_pos;
            dir = next_dir;
        }
        drawPathOnMap(map, path_nodes, from);
    }
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

    var map = Map.init(allocator);

    var start: Coord = undefined;
    var end: Coord = undefined;

    var buf: [256]u8 = undefined;
    while (try stream.readUntilDelimiterOrEof(&buf, '\n')) |line| {
        if (map.capacity == 0) {
            try map.ensureTotalCapacityPrecise(line.len);
        }
        var row = try Row.initCapacity(allocator, line.len);
        try parseRow(line, &row, &start, &end, @intCast(map.items.len));
        try map.append(row);
    }

    var nodes = Nodes.init(allocator);
    const start_nodes = try createStartNodes(allocator, start, Dir.east, &map);
    const start_node = start_nodes[@intFromEnum(Dir.east)];
    for (start_nodes) |node| {
        try nodes.put(.{.pos = node.pos, .dir = node.dir}, node);
    }
    var end_nodes = try createEndNodes(allocator, end, &map);
    for (end_nodes) |node| {
        try nodes.put(.{.pos = node.pos, .dir = node.dir}, node);
    }

    try findNodes(allocator, &nodes, &map, start, end);
    var it = nodes.keyIterator();
    while (it.next()) |key| {
        try findConnection(&nodes, &map, key.pos, key.dir);
    }
    const end_node = collapseEndNodes(&nodes, &end_nodes);

    // FIXME: this currently breaks when we hit dead ends, so we run without
    //try collapseConnections(&nodes, start_node, end_node);
    //nodes = try cleanupNodes(&nodes, start_node);

    var path_output = PathNodes.init(allocator);
    _ = try findBestPath(&nodes, &path_output, start_node, end_node);

    var result1: usize = math.maxInt(usize);
    if (path_output.get(end_node)) |p| {
        result1 = p.points;
    }

    drawPathOnMap(&map, &path_output, end_node);

    //printMap(&map);
    //try stdout.print("\n", .{});

    const result2 = countPathTiles(&map);

    try stdout.print("Result1: {d}\n", .{result1});
    try stdout.print("Result2: {d}\n", .{result2});
}
