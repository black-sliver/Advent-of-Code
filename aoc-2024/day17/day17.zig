const std = @import("std");
const fmt = std.fmt;
const math = std.math;
const mem = std.mem;
const testing = std.testing;

const Register = u64;

const ComboOperandTag = enum {
    literal,
    register,
};

const ComboOperand = union(ComboOperandTag) {
    const Self = @This();

    literal: u2,
    register: u2,

    fn init(data: u8) Self {
        if (data >> 2 != 0) {
            std.debug.assert(data & 3 < 3); // no register D
            return Self{.register = @intCast(data & 3)};
        } else {
            return Self{.literal = @intCast(data & 3)};
        }
    }
};

const LiteralOperatnd = u3;

const InstructionTag = enum(u3) {
    adv = 0,
    bxl = 1,
    bst = 2,
    jnz = 3,
    bxc = 4,
    out = 5,
    bdv = 6,
    cdv = 7,
};

const Instruction = union(InstructionTag) {
    const Self = @This();

    adv: ComboOperand,
    bxl: LiteralOperatnd,
    bst: ComboOperand,
    jnz: LiteralOperatnd,
    bxc: void,
    out: ComboOperand,
    bdv: ComboOperand,
    cdv: ComboOperand,

    fn init(data: []const u8) Self {
        const runtime_tag: InstructionTag = @enumFromInt(data[0]);

        return switch(runtime_tag) {
            inline else => |tag| // unrolls into all cases with comptime tag
                // union.fields requires fields to be in correct order, but
                // @FieldType(Self, @tagName(tag)) // is n/a in 0.13
                switch (@typeInfo(Self).Union.fields[@intFromEnum(tag)].type) {
                    LiteralOperatnd => @unionInit(Self, @tagName(tag), @intCast(data[1])),
                    ComboOperand => @unionInit(Self, @tagName(tag), ComboOperand.init(data[1])),
                    void => @unionInit(Self, @tagName(tag), undefined),
                    else => @compileError("Unhandled op arg type " ++
                        @typeName(@typeInfo(Self).Union.fields[@intFromEnum(tag)].type)),
                }
        };
    }
};

const Machine = struct {
    const Self = @This();

    allocator: mem.Allocator,
    program: []Instruction,
    pc: u8 = 0,
    registers: [3]Register = [_]Register{0} ** 3,

    fn compile(allocator: mem.Allocator, program: []const u8) ![]Instruction {
        if (program.len & 1 != 0) {
            return error.InvalidProgram;
        }
        var res = try allocator.alloc(Instruction, program.len / 2);
        for (0..program.len / 2) |i| {
            res[i] = Instruction.init(program[i*2..i*2+2]);
        }
        return res;
    }

    pub fn init(allocator: mem.Allocator, program: []const u8, a: Register, b: Register, c: Register) !Self {
        return Self{
            .allocator = allocator,
            .program = try Self.compile(allocator, program),
            .registers = [_]Register{a, b, c},
        };
    }

    pub fn deinit(self: *Self) void {
        self.allocator.free(self.program);
    }

    pub fn getValue(self: *const Self, operand: ComboOperand) Register {
        switch (operand) {
            .literal => |value| return value,
            .register => |index| return self.registers[index],
        }
    }

    pub fn reset(self: *Self, a: Register, b: Register, c: Register) void {
        self.pc = 0;
        self.registers = [_]Register{a, b, c};
    }

    pub fn run(self: *Self) ?u8 {
        const instr = self.program[self.pc / 2];
        self.pc += 2;
        switch (instr) {
            .adv => |operand| {
                self.registers[0] = self.registers[0] / (@as(Register, 1) << @intCast(self.getValue(operand)));
            },
            .bxl => |operand| {
                self.registers[1] = self.registers[1] ^ operand;
            },
            .bst => |operand| {
                self.registers[1] = self.getValue(operand) & 7;
            },
            .jnz => |operand| {
                if (self.registers[0] != 0) {
                    self.pc = operand;
                }
            },
            .bxc => {
                self.registers[1] = self.registers[1] ^ self.registers[2];
            },
            .out => |operand| {
                return @intCast(self.getValue(operand) & 7);
            },
            .bdv => |operand| {
                self.registers[1] = self.registers[0] / (@as(Register, 1) << @intCast(self.getValue(operand)));
            },
            .cdv => |operand| {
                self.registers[2] = self.registers[0] / (@as(Register, 1) << @intCast(self.getValue(operand)));
            },
        }
        return null;
    }

    pub fn done(self: *const Self) bool {
        return self.pc >= self.program.len * 2;
    }
};

fn printOutput(out: []const u8, len: usize) void {
    std.debug.assert(len>0);
    std.debug.print("{d}", .{out[0]});
    for (1..len) |i| {
        std.debug.print(", {d}", .{out[i]});
    }
    std.debug.print("\n", .{});
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

    var program = try std.ArrayList(u8).initCapacity(allocator, 16);
    defer program.deinit();

    var initial_register = [_]Register{0} ** 3;

    var buf: [256]u8 = undefined;
    while (try stream.readUntilDelimiterOrEof(&buf, '\n')) |line| {
        if (line.len == 0) {
            continue;
        }
        var relevant = line[9..];
        switch (relevant[0]) {
            'A'...'C' => |c| {
                initial_register[c-'A'] = try fmt.parseInt(Register, relevant[3..], 10);
            },
            else => {
                var it = std.mem.splitScalar(u8, relevant, ',');
                while (it.next()) |c| {
                    try program.append(try fmt.parseInt(u8, c, 10));
                }
            }
        }
    }

    var machine = try Machine.init(allocator, program.items,
        initial_register[0], initial_register[1], initial_register[2]);
    defer machine.deinit();

    // part 1:
    try stdout.print("Result1: ", .{});
    var first = true;
    while (!machine.done()) {
        if (machine.run()) |v| {
            try stdout.print("{s}{d}", .{if (first) "" else ",", v});
            first = false;
        }
    }
    try stdout.print("\n", .{});

    // part 2:
    // first A with 16 output symbols is 8^15 = 35184372088832 (A >= 8^(len-1))
    // last output symbol depends on 3 most significant bits of A
    // each previous symbol depends on next 3 bits + 7 higher bits
    // so, to solve this in a semi-bruteforce way for min A with expected output, we can
    // 1. increase 3 msbit until last symbol is correct
    // 2. increase 6 msbit until second to last sumbol is correct,
    //    but if last symbol changes go back to 1
    // 3, increase 9 msbit until third to last symbol is correct,
    //     etc...
    // there is definitely also a way to analyze the program and loop backwards,
    // however that seems hard to do generically and is more work.
    var a: u64 = @as(u64, 1) << @intCast(3 * (program.items.len - 1));
    std.debug.assert(program.items.len != 16 or a == 35184372088832);
    var step: u64 = a;
    if (program.items.len > 16) {
        // we use a fixed-size buffer, so limit to that
        try stdout.print("Not implemented for program len > 16\n", .{});
        return error.NotImplemented;
    }
    const last_symbol_index = program.items.len - 1;
    var symbol_pos: usize = last_symbol_index; // start by looking for the last symbol
    solver: while (true) {
        var out: [16]u8 = [_]u8{0} ** 16;
        var out_pos: usize = 0;
        machine.reset(a, initial_register[1], initial_register[2]);
        while (!machine.done()) {
            if (machine.run()) |value| {
                if (out_pos == out.len) {
                    // did not find an A that produces the output -> unsolvable
                    std.debug.print("Output too long for A = {d}\n", .{a});
                    try stdout.print("Result2: Unsolvable\n", .{});
                    return error.LogicError;
                }
                out[out_pos] = value;
                out_pos += 1;
                // we could exit early here if outpot_pos > symbol_pos, however the while loop below breaks then
            }
        }
        // check which symbols are now correct/incorrect (one step can change multiple)
        while (true) {
            // if symbol at previous pos is incorrect, move to previous
            if (symbol_pos < last_symbol_index and out[symbol_pos+1] != program.items[symbol_pos+1]) {
                //std.debug.print("Modified symbol {d}, moving back\n", .{symbol_pos + 1});
                step <<= 3;
                symbol_pos += 1;
            }
            // if symbol at pos is correct, move to next
            else if (out[symbol_pos] == program.items[symbol_pos]) {
                //std.debug.print("Found symbol {d} at A = {d}: ", .{symbol_pos, a});
                //printOutput(&out, out_pos);
                if (symbol_pos == 0) {
                    // we done
                    break :solver;
                }
                // otherwise find next symbol
                step >>= 3;
                if (step == 0) {
                    std.debug.print("Wrong step size {d} at {d}\n", .{step, symbol_pos});
                    return error.LogicError;
                }
                symbol_pos -= 1;
            }
            // otherwise continue with next step
            else {
                break;
            }
        }
        a += step;
    }

    try stdout.print("Result2: {d}\n", .{a});
}

test "sample" {
    const program = [_]u8{0, 1, 5, 4, 3, 0};
    var out = [_]u8{0} ** 16;
    var out_pos: usize = 0;
    var machine = try Machine.init(testing.allocator, &program, 729, 0, 0);
    defer machine.deinit();
    while (!machine.done()) {
        if (machine.run()) |value| {
            out[out_pos] = value;
            out_pos += 1;
        }
    }
    const expected = [_]u8{4, 6, 3, 5, 6, 3, 5, 2, 1, 0};
    try testing.expectEqualSlices(u8, &expected, out[0..out_pos]);
    std.debug.print("{any}\n", .{machine});
}

test "reverse_sample_forward" {
    const program = [_]u8{0,3,5,4,3,0};
    var out = [_]u8{0} ** 16;
    var out_pos: usize = 0;
    var machine = try Machine.init(testing.allocator, &program, 117440, 0, 0);
    defer machine.deinit();
    while (!machine.done()) {
        if (machine.run()) |value| {
            out[out_pos] = value;
            out_pos += 1;
        }
    }
    const expected = program;
    try testing.expectEqualSlices(u8, &expected, out[0..out_pos]);
    std.debug.print("{any}\n", .{machine});
}
