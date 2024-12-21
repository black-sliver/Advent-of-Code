const builtin = @import("builtin");
const std = @import("std");
const mem = std.mem;


const Coord = @Vector(2, u32);

const ICoord = @Vector(2, isize);

const Node = struct {
    pos: Coord,
    next: [2]?*Node = [_]?*Node{null, null},
    distance: usize = 0, // from the start
};

const Nodes = std.AutoHashMap(Coord, *Node);

fn eastOf(pos: Coord) Coord {
    return pos + Coord{1, 0};
}

fn east2Of(pos: Coord) Coord {
    return pos + Coord{2, 0};
}

fn westOf(pos: Coord) Coord {
    return pos - Coord{1, 0};
}

fn west2Of(pos: Coord) Coord {
    return pos - Coord{2, 0};
}

fn southOf(pos: Coord) Coord {
    return pos + Coord{0, 1};
}

fn south2Of(pos: Coord) Coord {
    return pos + Coord{0, 2};
}

fn northOf(pos: Coord) Coord {
    return pos - Coord{0, 1};
}

fn north2Of(pos: Coord) Coord {
    return pos - Coord{0, 2};
}

inline fn getDistance(nodes: *Nodes, node: *Node, x: usize, y: usize, walk_distance: usize) usize {
    const other_pos = Coord{@intCast(x), @intCast(y)};
    if (nodes.get(other_pos)) |other| {
        if (other.distance > node.distance + walk_distance) {
            return other.distance - node.distance - walk_distance;
        }
        return 0;
    }
    return 0;
}

fn part2(nodes: *Nodes, node: *Node, width: usize, height: usize, limit: usize) usize {
    var count: usize = 0;
    const x: u32 = @intCast(node.pos[0]);
    const y: u32 = @intCast(node.pos[1]);
    const left = if (x < 21) 1 else x - 20;
    const right = if (x > width - 22) width - 2 else x + 20;
    const top = if (y < 21) 1 else y - 20;
    const bottom = if (y > height - 22) height - 2 else y + 20;

    for (left..right+1) |x1| {
        for (top..bottom+1) |y1| {
            const walk_distance = @reduce(.Add, @abs(ICoord{@intCast(x1), @intCast(y1)} - @as(ICoord, node.pos)));
            if (walk_distance <= 20) {
                const shortcut = getDistance(nodes, node, x1, y1, walk_distance);
                if (shortcut >= limit) {
                    count += 1;
                }
            }
        }
    }

    return count;
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

    var nodes = Nodes.init(allocator);
    var start: Coord = undefined;
    var end: Coord = undefined;
    var width: usize = 0;
    var y: usize = 1;

    var buf: [256]u8 = undefined;
    if (try stream.readUntilDelimiterOrEof(&buf, '\n')) |line| {
        // always wall
        width = line.len;
    }
    while (try stream.readUntilDelimiterOrEof(&buf, '\n')) |line| : (y += 1) {
        for (line, 0..) |c, x| {
            if (c != '#') {
                const pos = Coord{@intCast(x), @intCast(y)};
                const node = try allocator.create(Node);
                node.* = Node{.pos = pos};
                try nodes.put(pos, node);
                if (c == 'S') {
                    start = pos;
                } else if (c == 'E') {
                    end = pos;
                }
            }
        }
    }
    const height = y;

    var it = nodes.valueIterator();
    while (it.next()) |nodepp| {
        var node = nodepp.*;
        var i: usize = 0;
        if (nodes.get(eastOf(node.pos))) |other| {
            node.next[i] = other;
            i += 1;
        }
        if (nodes.get(southOf(node.pos))) |other| {
            node.next[i] = other;
            i += 1;
        }
        if (nodes.get(northOf(node.pos))) |other| {
            node.next[i] = other;
            i += 1;
        }
        if (nodes.get(westOf(node.pos))) |other| {
            node.next[i] = other;
            i += 1;
        }
    }

    const end_node = nodes.get(end).?;
    const start_node = nodes.get(start).?;
    {
        var prev = start_node;
        var node = start_node;
        std.debug.assert(node.next[0] != null);
        std.debug.assert(node.next[1] == null);
        var i: usize = 0;
        while (true) : (i += 1) {
            node.distance = i;
            if (node == end_node) {
                break;
            }
            if (node.next[0].? == prev) {
                std.mem.swap(?*Node, &node.next[0], &node.next[1]);
            }
            prev = node;
            node = node.next[0].?;
        }
    }

    var result1: usize = 0;
    var result2: usize = 0;
    {
        var node = start_node;
        while (node != end_node) {
            //std.debug.print(".", .{});
            // part 1
            if (node.pos[1] > 1) {
                if (nodes.get(north2Of(node.pos))) |other| {
                    if (other.distance > node.distance + 2) {
                        const saved = other.distance - node.distance - 2;
                        //std.debug.print("Skip {d} at {}\n", .{saved, node.pos});
                        if (saved >= 100) {
                            result1 += 1;
                        }
                    }
                }
            }
            if (node.pos[0] > 1) {
                if (nodes.get(west2Of(node.pos))) |other| {
                    if (other.distance > node.distance + 2) {
                        const saved = other.distance - node.distance - 2;
                        //std.debug.print("Skip {d} at {}\n", .{saved, node.pos});
                        if (saved >= 100) {
                            result1 += 1;
                        }
                    }
                }
            }
            if (node.pos[0] < width - 2) {
                if (nodes.get(east2Of(node.pos))) |other| {
                    if (other.distance > node.distance + 2) {
                        const saved = other.distance - node.distance - 2;
                        //std.debug.print("Skip {d} at {}\n", .{saved, node.pos});
                        if (saved >= 100) {
                            result1 += 1;
                        }
                    }
                }
            }
            if (node.pos[1] < height - 2) {
                if (nodes.get(south2Of(node.pos))) |other| {
                    if (other.distance > node.distance + 2) {
                        const saved = other.distance - node.distance - 2;
                        //std.debug.print("Skip {d} at {}\n", .{saved, node.pos});
                        if (saved >= 100) {
                            result1 += 1;
                        }
                    }
                }
            }
            // part 2
            result2 += part2(&nodes, node, width, height, 100);

            node = node.next[0].?;
        }
    }

    std.debug.print("Total nodes: {d}\n", .{end_node.distance});

    try stdout.print("Result1: {d}\n", .{result1});
    try stdout.print("Result2: {d}\n", .{result2});
}
