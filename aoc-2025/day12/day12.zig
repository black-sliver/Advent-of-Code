const std = @import("std");
const builtin = @import("builtin");

const Piece = [3][3]bool; // [y][x]
const Tree = struct {
    width: u32,
    height: u32,
    pieces: [6]u8,
};

fn canFit(width: u32, height: u32, remaining_pieces: [6]u8, shapes: *const [6] Piece, tiles: *const [6]u8) !bool {
    var remaining_piece_count: u32 = 0;
    var remaining_tiles: u32 = 0;
    for (remaining_pieces, 0..) |count, index| {
        remaining_piece_count += count;
        remaining_tiles += @as(u32, count) * tiles[index];
    }
    // if the total tiles are less than the remaining tiles: can never fit
    if (remaining_tiles > width * height) {
        return false;
    }
    // if the size fits all 3x3 outlines: can always fit
    if ((width / 3) * (height / 3) >= remaining_piece_count) {
        return true;
    }
    // TODO: actually fit
    // this is not required for actual input.txt :thinking:
    // there was this whole plan of splitting the grid into rows and columns and recursing into it...
    // another option would be to guess from the fill factor of pre-merged shapes (e.g. 3 + 5 + 3 has 100%)
    _ = shapes;
    std.debug.print("maybe fits\n", .{});
    return error.NotImplemented;
}

fn part1(trees: []const Tree, shapes: *const [6] Piece) !usize {
    var shape_tile_count: [shapes.len]u8 = undefined;
    for (0..shapes.len) |i| shape_tile_count[i] = countTiles(shapes[i]);
    var sum: usize = 0;
    for (trees) |tree| {
        sum += if (try canFit(
            tree.width,
            tree.height,
            tree.pieces,
            shapes,
            &shape_tile_count,
        )) 1 else 0;
    }
    return sum;
}

fn countTiles(piece: Piece) u8 {
    var sum: u8 = 0;
    for (0..3) |y| {
        for (0..3) |x| {
            sum += if (piece[y][x]) 1 else 0;
        }
    }
    return sum;
}

fn readInput(allocator: std.mem.Allocator, trees: *std.ArrayList(Tree), shapes: *[6] Piece) !void {
    var file_buffer: [4096]u8 = undefined;
    const file = try std.fs.cwd().openFile("input.txt", .{});
    defer file.close();
    var reader = file.reader(&file_buffer);
    var current_piece: usize = 0;
    var line_of_piece: usize = 0;
    while (try reader.interface.takeDelimiter('\n')) |line| {
        if (current_piece < shapes.len) {
            if (line_of_piece >= 1 and line_of_piece <= 3) {
                const y = line_of_piece - 1;
                for (0..shapes[current_piece][y].len) |x| {
                    shapes[current_piece][y][x] = line[x] == '#';
                }
            }
            line_of_piece += 1;
            if (line_of_piece == 5) {
                line_of_piece = 0;
                current_piece += 1;
            }
        } else {
            // a tree
            var it = std.mem.tokenizeAny(u8, line, "x: ");
            const tree: Tree = .{
                .width = try std.fmt.parseUnsigned(u32, it.next() orelse return error.InvalidInput, 10),
                .height = try std.fmt.parseUnsigned(u32, it.next() orelse return error.InvalidInput, 10),
                .pieces = .{
                    try std.fmt.parseUnsigned(u8, it.next() orelse return error.InvalidInput, 10),
                    try std.fmt.parseUnsigned(u8, it.next() orelse return error.InvalidInput, 10),
                    try std.fmt.parseUnsigned(u8, it.next() orelse return error.InvalidInput, 10),
                    try std.fmt.parseUnsigned(u8, it.next() orelse return error.InvalidInput, 10),
                    try std.fmt.parseUnsigned(u8, it.next() orelse return error.InvalidInput, 10),
                    try std.fmt.parseUnsigned(u8, it.next() orelse return error.InvalidInput, 10),
                },
            };
            try trees.append(allocator, tree);
        }
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

    var trees: std.ArrayList(Tree) = .empty;
    var pieces: [6]Piece = std.mem.zeroes([6]Piece);
    defer trees.deinit(allocator);

    try readInput(allocator, &trees, &pieces);

    const res1 = try part1(trees.items, &pieces);
    try stdout.print("{}\n", .{res1});
}

const test_pieces = [_]Piece {
    .{
        // 0:
        .{ true, true, true },
        .{ true, true, false },
        .{ true, true, false },
    },
    .{
        // 1:
        .{ true, true, true },
        .{ true, true, false },
        .{ false, true, true },
    },
    .{
        // 2:
        .{ false, true, true },
        .{ true, true, true },
        .{ true, true, false },
    },
    .{
        // 3:
        .{ true, true, false },
        .{ true, true, true },
        .{ true, true, false },
    },
    .{
        // 4:
        .{ true, true, true },
        .{ true, false, false },
        .{ true, true, true },
    },
    .{
        // 5:
        .{ true, true, true },
        .{ false, true, false },
        .{ true, true, true },
    },
};

const test_trees = [_]Tree {
    .{
        .width = 4,
        .height = 4,
        .pieces = .{ 0, 0, 0, 0, 2, 0 },
    },
    .{
        .width = 12,
        .height = 5,
        .pieces = .{ 1, 0, 1, 0, 2, 2 },
    },
    .{
        .width = 12,
        .height = 5,
        .pieces = .{ 1, 0, 1, 0, 3, 2 },
    }
};

const test_tiles = [_]u8{
    countTiles(test_pieces[0]),
    countTiles(test_pieces[1]),
    countTiles(test_pieces[2]),
    countTiles(test_pieces[3]),
    countTiles(test_pieces[4]),
    countTiles(test_pieces[5]),
};

test "part1.0" {
    try std.testing.expect(try canFit(
        test_trees[0].width,
        test_trees[0].height,
        test_trees[0].pieces,
        &test_pieces,
        &test_tiles,
    ));
}

test "part1.1" {
    try std.testing.expect(try canFit(
        test_trees[1].width,
        test_trees[1].height,
        test_trees[1].pieces,
        &test_pieces,
        &test_tiles,
    ));
}

test "part1.2" {
    try std.testing.expect(!try canFit(
        test_trees[2].width,
        test_trees[2].height,
        test_trees[2].pieces,
        &test_pieces,
        &test_tiles,
    ));
}
