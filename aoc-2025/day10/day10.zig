// to build/test, append -lc -lz3 to the command line
const std = @import("std");
const builtin = @import("builtin");

const z3 = struct {
    const c = @cImport(
        @cInclude("z3.h"),
    );

    const Ast = c.Z3_ast;
    const Config = c.Z3_config;
    const Context = c.Z3_context;
    const Model = c.Z3_model;
    const Optimize = c.Z3_optimize;
    const Sort = c.Z3_sort;

    const mkConfig = c.Z3_mk_config;
    const delConfig = c.Z3_del_config;

    const mkContext = c.Z3_mk_context;
    const delContext = c.Z3_del_context;

    const mkOptimize = c.Z3_mk_optimize;
    const optimizeIncRef = c.Z3_optimize_inc_ref;
    const optimizeDecRef = c.Z3_optimize_dec_ref;
    const optimizeAssert = c.Z3_optimize_assert;
    const optimizeMinimize = c.Z3_optimize_minimize;
    const optimizeCheck = c.Z3_optimize_check;
    const optimizeGetModel = c.Z3_optimize_get_model;

    const modelEval = c.Z3_model_eval;

    fn mkAdd(ctx: Context, args: []const Ast) Ast {
        return c.Z3_mk_add(ctx, @intCast(args.len), args.ptr);
    }
    const mkEq = c.Z3_mk_eq;
    const mkGe = c.Z3_mk_ge;

    const mkIntSort = c.Z3_mk_int_sort;
    const mkStringSymbol = c.Z3_mk_string_symbol;
    const mkConst = c.Z3_mk_const;
    const mkInt = c.Z3_mk_int;

    const getNumeralInt = c.Z3_get_numeral_int;
};

fn mkIntVar(ctx: z3.Context, name: [*c]const u8) z3.Ast {
    const ty = z3.mkIntSort(ctx);
    const s = z3.mkStringSymbol(ctx, name);
    return z3.mkConst(ctx, s, ty);
}

fn mkIntConst(ctx: z3.Context, value: i32) z3.Ast {
    const ty = z3.mkIntSort(ctx);
    return z3.mkInt(ctx, value, ty);
}

const ButtonMask = u32;

const Machine = struct {
    target_lights: u32,
    button_masks: std.ArrayList(ButtonMask),
    joltage: std.ArrayList(i32),
    joltage_buttons: std.ArrayList(std.ArrayList(u8)), // 1 list of buttons for each digit

    fn deinit(self: *Machine, allocator: std.mem.Allocator) void {
        self.button_masks.deinit(allocator);
        for (self.joltage_buttons.items) |*buttons| {
            buttons.deinit(allocator);
        }
        self.joltage_buttons.deinit(allocator);
        self.joltage.deinit(allocator);
    }
};

fn solve1(buttons: []const ButtonMask, mask: u32) usize {
    for (0..buttons.len) |i| {
        const new_mask = mask ^ buttons[i];
        if (new_mask == 0)
            return 1;
    }
    // TODO: BFS instead
    var min: usize = 0xffff;
    for (0..buttons.len) |i| {
        const new_mask = mask ^ buttons[i];
        const sub = solve1(buttons[i + 1 ..], new_mask);
        min = @min(min, sub);
        if (sub == 1)
            break;
    }
    return min + 1;
}

fn part1(machines: []Machine) usize {
    var res: usize = 0;
    for (machines) |machine| {
        // TODO: BFS
        res += solve1(machine.button_masks.items, machine.target_lights);
    }
    return res;
}

fn solve2(button_count: usize, joltage_buttons: []const std.ArrayList(u8), joltage: []i32) !usize {
    const cfg = z3.mkConfig();
    const ctx = z3.mkContext(cfg);
    defer z3.delContext(ctx);
    z3.delConfig(cfg);
    const o = z3.mkOptimize(ctx);
    z3.optimizeIncRef(ctx, o);
    defer z3.optimizeDecRef(ctx, o);

    var buf: [1024]u8 = undefined;
    var fba = std.heap.FixedBufferAllocator.init(&buf);
    var allocator = fba.allocator();

    const zero = mkIntConst(ctx, 0);
    var vars: []z3.Ast = try allocator.alloc(z3.Ast, button_count);
    for (0..button_count) |i| {
        const name = try std.fmt.allocPrintSentinel(allocator, "p{}", .{i}, 0);
        vars[i] = mkIntVar(ctx, name);
        const con = z3.mkGe(ctx, vars[i], zero);
        z3.optimizeAssert(ctx, o, con);
    }

    for (0..joltage.len) |i| {
        const res = mkIntConst(ctx, joltage[i]);
        const relevant_buttons = joltage_buttons[i].items;
        var args: []z3.Ast = try allocator.alloc(z3.Ast, relevant_buttons.len);
        for (relevant_buttons, 0..) |button_index, j| {
            args[j] = vars[button_index];
        }
        const add = z3.mkAdd(ctx, args);
        const con = z3.mkEq(ctx, add, res);
        z3.optimizeAssert(ctx, o, con);
    }

    const total_presses = z3.mkAdd(ctx, vars);
    _ = z3.optimizeMinimize(ctx, o, total_presses);
    const solved = z3.optimizeCheck(ctx, o, 0, null);
    if (solved < 1) {
        return error.NoSolution;
    }
    var out: z3.Ast = undefined;
    const model = z3.optimizeGetModel(ctx, o);
    _ = z3.modelEval(ctx, model, total_presses, true, &out);
    var integer_result: c_int = -1;
    _ = z3.getNumeralInt(ctx, out, &integer_result);
    return @intCast(integer_result);
}

fn part2(machines: []Machine) !usize {
    var res: usize = 0;
    for (machines) |machine| {
        const one = try solve2(
            machine.button_masks.items.len,
            machine.joltage_buttons.items,
            machine.joltage.items,
        );
        res += one;
    }
    return res;
}

fn parseLine(allocator: std.mem.Allocator, line: []const u8) !Machine {
    var machine: Machine = .{
        .target_lights = 0,
        .button_masks = .empty,
        .joltage = .empty,
        .joltage_buttons = .empty,
    };
    var part_it = std.mem.splitScalar(u8, line, ' ');
    while (part_it.next()) |part| {
        const values = part[1 .. part.len - 1];
        var comma_it = std.mem.splitScalar(u8, values, ',');
        // TODO: maybe validate the ')', ']', '}'
        switch (part[0]) {
            '[' => {
                for (0..values.len) |i| {
                    if (values[i] == '#') {
                        machine.target_lights |= (@as(u32, 1) << @intCast(i));
                    }
                }
            },
            '(' => {
                var button_mask: ButtonMask = 0;
                const buttonIndex = machine.button_masks.items.len;
                while (comma_it.next()) |s| {
                    const v = try std.fmt.parseUnsigned(u5, s, 10);
                    button_mask ^= (@as(u32, 1) << v);
                    while (machine.joltage_buttons.items.len <= v) {
                        try machine.joltage_buttons.append(allocator, .empty);
                    }
                    try machine.joltage_buttons.items[v].append(allocator, @intCast(buttonIndex));
                }
                try machine.button_masks.append(allocator, button_mask);
            },
            '{' => {
                while (comma_it.next()) |n| {
                    try machine.joltage.append(allocator, try std.fmt.parseUnsigned(i32, n, 10));
                }
            },
            else => return error.BadFormat,
        }
    }
    return machine;
}

fn readInput(allocator: std.mem.Allocator, machines: *std.ArrayList(Machine)) !void {
    var file_buffer: [4096]u8 = undefined;
    const file = try std.fs.cwd().openFile("input.txt", .{});
    defer file.close();
    var reader = file.reader(&file_buffer);
    while (try reader.interface.takeDelimiter('\n')) |line| {
        try machines.append(allocator, try parseLine(allocator, line));
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

    var machines: std.ArrayList(Machine) = .empty;
    defer machines.deinit(allocator);
    defer for (machines.items) |*machine| machine.deinit(allocator);

    try readInput(allocator, &machines);

    const res1 = part1(machines.items);
    try stdout.print("{}\n", .{res1});
    const res2 = try part2(machines.items);
    try stdout.print("{}\n", .{res2});
}

const test_data =
    \\[.##.] (3) (1,3) (2) (2,3) (0,2) (0,1) {3,5,4,7}
    \\[...#.] (0,2,3,4) (2,3) (0,4) (0,1,2) (1,2,3,4) {7,5,12,7,2}
    \\[.###.#] (0,1,2,3,4) (0,3,4) (0,1,2,4,5) (1,2) {10,11,11,5,10,5}
;

test "part1" {
    const allocator = std.testing.allocator;
    var machines: std.ArrayList(Machine) = .empty;
    defer machines.deinit(allocator);
    defer for (machines.items) |*machine| machine.deinit(allocator);
    var line_it = std.mem.splitScalar(u8, test_data, '\n');
    while (line_it.next()) |line| {
        try machines.append(allocator, try parseLine(allocator, line));
    }
    try std.testing.expectEqual(7, part1(machines.items));
}

test "part2" {
    const allocator = std.testing.allocator;
    var machines: std.ArrayList(Machine) = .empty;
    defer machines.deinit(allocator);
    defer for (machines.items) |*machine| machine.deinit(allocator);
    var line_it = std.mem.splitScalar(u8, test_data, '\n');
    while (line_it.next()) |line| {
        try machines.append(allocator, try parseLine(allocator, line));
    }
    try std.testing.expectEqual(33, try part2(machines.items));
}
