const std = @import("std");
const fmt = std.fmt;
const mem = std.mem;
const testing = std.testing;

const GateType = enum {
    AND,
    OR,
    XOR,
};

const Gate = struct {
    const Self = @This();

    a: [3]u8,
    b: [3]u8,
    y: [3]u8,
    type: GateType,

    fn getOutput(self: *const Self, input1: u1, input2: u1) u1 {
        return switch (self.type) {
            .AND => input1 & input2,
            .OR => input1 | input2,
            .XOR => input1 ^ input2,
        };
    }

    fn init(line: []u8) !Self {
        const t: GateType = switch (line[4]) {
            'A' => GateType.AND,
            'O' => GateType.OR,
            'X' => GateType.XOR,
            else => return error.InvalidGate,
        };
        const n: usize = switch(t) {
            .OR => 7,
            else => 8,
        };
        const m = n + 7;
        return Self{
            .a = line[0..3].*,
            .b = line[n..][0..3].*,
            .y = line[m..][0..3].*,
            .type = t,
        };
    }
};

const InputsSet = std.AutoHashMap([3]u8, u1);
const GateList = std.ArrayList(Gate);

fn setSignal(inputs: *InputsSet, gates: *GateList, name: [3]u8, value: u1) !void {
    try inputs.put(name, value);
    for (gates.items) |gate| {
        if (mem.eql(u8, &gate.a, &name)) {
            if (inputs.get(gate.b)) |other| {
                const res = gate.getOutput(value, other);
                try setSignal(inputs, gates, gate.y, res);
            }
        } else if (mem.eql(u8, &gate.b, &name)) {
            if (inputs.get(gate.a)) |other| {
                const res = gate.getOutput(other, value);
                try setSignal(inputs, gates, gate.y, res);
            }
        }
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

    var gate_list = GateList.init(allocator);

    var buf: [32]u8 = undefined;
    var count_initial_inputs: u32 = 0;
    while (try stream.readUntilDelimiterOrEof(&buf, '\n')) |line| {
        // seek over initial signals
        if (line.len == 0) {
            break;
        }
        count_initial_inputs += 1;
    }
    while (try stream.readUntilDelimiterOrEof(&buf, '\n')) |line| {
        try gate_list.append(try Gate.init(line));
    }

    var inputs_set = InputsSet.init(allocator);
    try inputs_set.ensureTotalCapacity(@intCast(gate_list.items.len + count_initial_inputs));

    try file.seekTo(0);
    while (try stream.readUntilDelimiterOrEof(&buf, '\n')) |line| {
        if (line.len == 0) {
            break;
        }
        const name = line[0..3];
        const value: u1 = @intCast(line[5] - '0');
        try setSignal(&inputs_set, &gate_list, name.*, value);
    }

    var result1: u64 = 0;
    var it = inputs_set.iterator();
    while (it.next()) |entry| {
        if (entry.key_ptr[0] == 'z' and entry.value_ptr.* == 1) {
            const bitpos = try fmt.parseInt(u6, entry.key_ptr[1..], 10);
            result1 |= (@as(u64, 1) << bitpos);
        }
    }

    try stdout.print("Result1: {d}\n", .{result1});
}
