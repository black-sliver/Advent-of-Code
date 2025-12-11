const std = @import("std");
const builtin = @import("builtin");

const ID = [3]u8;
const Nodes = std.AutoHashMap(ID, std.ArrayList(ID));
const CacheKey = struct {
    start: ID,
    dac_visited: bool,
    fft_visited: bool,
};
const Cache = std.AutoHashMap(CacheKey, usize);

fn parseLine(allocator: std.mem.Allocator, line: []const u8, nodes: *Nodes) !void {
    var connections: std.ArrayList(ID) = .empty;
    errdefer connections.deinit(allocator);
    var part_it = std.mem.splitScalar(u8, line[5..], ' ');
    while (part_it.next()) |part| {
        try connections.append(allocator, part[0..3].*);
    }
    try nodes.put(line[0..3].*, connections);
}

fn readInput(allocator: std.mem.Allocator, nodes: *Nodes) !void {
    var file_buffer: [4096]u8 = undefined;
    const file = try std.fs.cwd().openFile("input.txt", .{});
    defer file.close();
    var reader = file.reader(&file_buffer);
    while (try reader.interface.takeDelimiter('\n')) |line| {
        try parseLine(allocator, line, nodes);
    }
}

fn part1(nodes: *Nodes, start: ID) usize {
    const connections = nodes.getPtr(start) orelse return 0;
    var sum: usize = 0;
    for (connections.items) |next| {
        sum += if (std.mem.eql(u8, &next, "out")) 1 else part1(nodes, next);
    }
    return sum;
}

fn part2(nodes: *Nodes, cache: *Cache, start: ID, dac_visited_in: bool, fft_visited_in: bool) !usize {
    var dac_visited = dac_visited_in;
    var fft_visited = fft_visited_in;
    if (std.mem.eql(u8, &start, "dac")) {
        dac_visited = true;
    } else if (std.mem.eql(u8, &start, "fft")) {
        fft_visited = true;
    }
    const connections = nodes.getPtr(start) orelse return 0;
    var sum: usize = 0;
    for (connections.items) |next| {
        const key: CacheKey = .{.start = next, .dac_visited = dac_visited, .fft_visited = fft_visited};
        if (std.mem.eql(u8, &next, "out")) {
            if (dac_visited and fft_visited) {
                sum += 1;
            }
        } else if (cache.get(key)) |sub| {
            sum += sub;
        } else {
            const sub = try part2(nodes, cache, next, dac_visited, fft_visited);
            try cache.put(key, sub);
            sum += sub;
        }
    }
    return sum;
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

    var nodes: Nodes = .init(allocator);
    defer nodes.deinit();
    defer {
        var it = nodes.valueIterator();
        while (it.next()) |dest| dest.deinit(allocator);
    }

    try readInput(allocator, &nodes);

    const res1 = part1(&nodes, "you".*);
    try stdout.print("{}\n", .{res1});
    try stdout.flush();

    var cache: Cache = .init(allocator);
    defer cache.deinit();
    const res2 = try part2(&nodes, &cache, "svr".*, false, false);
    try stdout.print("{}\n", .{res2});
}

const test_data =
    \\aaa: you hhh
    \\you: bbb ccc
    \\bbb: ddd eee
    \\ccc: ddd eee fff
    \\ddd: ggg
    \\eee: out
    \\fff: out
    \\ggg: out
    \\hhh: ccc fff iii
    \\iii: out
;

test "part1" {
    const allocator = std.testing.allocator;
    var nodes: Nodes = .init(allocator);
    defer nodes.deinit();
    defer {
        var it = nodes.valueIterator();
        while (it.next()) |dest| dest.deinit(allocator);
    }
    var line_it = std.mem.splitScalar(u8, test_data, '\n');
    while (line_it.next()) |line| {
        try parseLine(allocator, line, &nodes);
    }
    try std.testing.expectEqual(5, part1(&nodes, "you".*));
}
