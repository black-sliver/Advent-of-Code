const std = @import("std");

pub fn findInstruction(input: []const u8, next: usize) ?usize {
    const p_mul = std.mem.indexOfPos(u8, input, next, "mul(") orelse std.math.maxInt(usize);
    const p_do = std.mem.indexOfPos(u8, input, next, "do()") orelse std.math.maxInt(usize);
    const p_dont = std.mem.indexOfPos(u8, input, next, "don't()") orelse std.math.maxInt(usize);
    const p_min = @min(p_mul, p_do, p_dont);
    if (p_min != std.math.maxInt(usize))
        return p_min;
    return null;
}

pub fn main() !void {
    // Note: I want to use/learn zig std, not regex.

    const stdout = std.io.getStdOut().writer();

    var file = try std.fs.cwd().openFile("input.txt", .{});
    defer file.close();

    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    const allocator = gpa.allocator();

    const input = try file.readToEndAlloc(allocator, 0xffffff);

    var total_sum: i32 = 0;
    var valid_sum: i32 = 0;

    var enabled = true;
    var next: usize = 0;
    while (findInstruction(input, next)) |p_start| {
        next = p_start + 4;
        if (std.mem.startsWith(u8, input[p_start..], "do()")) {
            enabled = true;
            continue;
        } else if (std.mem.startsWith(u8, input[p_start..], "don't()")) {
            enabled = false;
            continue;
        }

        // nul()

        const p_comma = std.mem.indexOfPos(u8, input, p_start + 4, ",") orelse continue;
        const p_end = std.mem.indexOfPos(u8, input, p_comma + 1, ")") orelse continue;
        const number1 = std.fmt.parseInt(i32, input[p_start+4..p_comma], 10) catch {
            continue;
        };
        const number2 = std.fmt.parseInt(i32, input[p_comma+1..p_end], 10) catch {
            continue;
        };
        total_sum += number1 * number2;
        if (enabled)
            valid_sum += number1 * number2;
        next = p_end + 1;
    }

    try stdout.print("Result 1: {d}\n", .{total_sum});
    try stdout.print("Result 2: {d}\n", .{valid_sum});
}

test "intParse" {
    // should be fine for what we need it to do
    try std.testing.expectError(error.InvalidCharacter, std.fmt.parseInt(i32, "2)", 10));
    try std.testing.expectError(error.InvalidCharacter, std.fmt.parseInt(i32, " 2", 10));
}
