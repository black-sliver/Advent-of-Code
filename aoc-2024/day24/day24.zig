const std = @import("std");
const fmt = std.fmt;
const math = std.math;
const mem = std.mem;


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

    pub fn format(
        self: *Self,
        comptime _: []const u8,
        _: std.fmt.FormatOptions,
        writer: anytype,
    ) !void {
        try writer.writeAll("Gate{ ");
        _ = try writer.print(".a=\"{s}\", ", .{self.a});
        _ = try writer.print(".b=\"{s}\", ", .{self.b});
        _ = try writer.print(".y=\"{s}\", ", .{self.y});
        _ = try writer.print(".type={} }}", .{self.type});
    }
};

const InputsSet = std.AutoHashMap([3]u8, u1);
const GateList = std.ArrayList(Gate);

fn setSignal(inputs: *InputsSet, gates: []Gate, name: [3]u8, value: u1) !void {
    try inputs.put(name, value);
    for (gates) |gate| {
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

fn setSignalsFromInt(inputs: *InputsSet, gates: []Gate, x: u45, y: u45) !void {
    var name: [3]u8 = undefined;
    var x1 = x;
    var y1 = y;
    for (0..45) |bitpos| {
        name[1] = @intCast('0' + bitpos / 10);
        name[2] = @intCast('0' + bitpos % 10);
        name[0] = 'x';
        try setSignal(inputs, gates, name, @intCast(x1 & 1));
        x1 >>= 1;
        name[0] = 'y';
        try setSignal(inputs, gates, name, @intCast(y1 & 1));
        y1 >>= 1;
    }
}

fn getSignalAsInt(inputs: *InputsSet) !u64 {
    var res: u64 = 0;
    var it = inputs.iterator();
    while (it.next()) |entry| {
        if (entry.key_ptr[0] == 'z' and entry.value_ptr.* == 1) {
            const bitpos = try fmt.parseInt(u6, entry.key_ptr[1..], 10);
            res |= (@as(u64, 1) << bitpos);
        }
    }
    return res;
}

fn runWithIntsForInt(inputs: *InputsSet, gates: []Gate, x: u45, y: u45) !u64 {
    inputs.clearRetainingCapacity();
    try setSignalsFromInt(inputs, gates, x, y);
    return try getSignalAsInt(inputs);
}

fn gateSorter(_: void, lhs: Gate, rhs: Gate) bool {
    const lhs_a_lt_b = mem.order(u8, &lhs.a, &lhs.b).compare(math.CompareOperator.lt);
    const rhs_a_lt_b = mem.order(u8, &rhs.a, &rhs.b).compare(math.CompareOperator.lt);
    const lhs_lesser: *const [3]u8 = if (lhs_a_lt_b) &lhs.a else &lhs.b;
    const rhs_lesser: *const [3]u8 = if (rhs_a_lt_b) &rhs.a else &rhs.b;
    var comp: math.Order = mem.order(u8, lhs_lesser, rhs_lesser);
    if (comp.compare(math.CompareOperator.lt)) {
        return true;
    } else if (comp.compare(math.CompareOperator.gt)) {
        return false;
    }
    return (@intFromEnum(lhs.type) < @intFromEnum(rhs.type));
}

fn wireSorter(_: void, lhs: [3]u8, rhs: [3]u8) bool {
    for (0..3) |i| {
        if (lhs[i] < rhs[i])
            return true;
        if (lhs[i] > rhs[i])
            return false;
    }
    return false;
}

fn swapGateOutputs(g1: *Gate, g2: *Gate) void {
    mem.swap(
        [3]u8,
        &g1.y,
        &g2.y,
    );
}

fn findGateForInputs(gates: []Gate, x_name: [3]u8, y_name: [3]u8, t: ?GateType) !*Gate {
    for (0..gates.len) |i| {
        const gate: *Gate = &gates[i];
        if ((t == null or t.? == gate.type) and (
        (mem.eql(u8, &gate.a, &x_name) and mem.eql(u8, &gate.b, &y_name)) or
            (mem.eql(u8, &gate.b, &x_name) and mem.eql(u8, &gate.a, &y_name))
        )) {
            return gate;
        }
    }
    return error.NoSuchGate;
}

fn findGateForAnInput(gates: []Gate, name: [3]u8, t: ?GateType) !*Gate {
    for (0..gates.len) |i| {
        const gate: *Gate = &gates[i];
        if ((t == null or t.? == gate.type) and (mem.eql(u8, &gate.a, &name) or mem.eql(u8, &gate.b, &name))) {
            return gate;
        }
    }
    return error.NoSuchGate;
}

fn findGateForOutput(gates: []Gate, z_name: [3]u8, t: ?GateType) !*Gate {
    for (0..gates.len) |i| {
        const gate: *Gate = &gates[i];
        if ((t == null or t.? == gate.type) and mem.eql(u8, &gate.y, &z_name)) {
            return gate;
        }
    }
    return error.NoSuchGate;
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

    // Optional: sort the gates for easier debugging
    //mem.sortUnstable(Gate, gate_list.items, {}, gateSorter);

    var inputs_set = InputsSet.init(allocator);
    try inputs_set.ensureTotalCapacity(@intCast(gate_list.items.len + count_initial_inputs));

    try file.seekTo(0);
    while (try stream.readUntilDelimiterOrEof(&buf, '\n')) |line| {
        if (line.len == 0) {
            break;
        }
        // run signals for part1
        const name = line[0..3];
        const value: u1 = @intCast(line[5] - '0');
        try setSignal(&inputs_set, gate_list.items, name.*, value);
    }

    // part1: calculate output
    const result1: u64 = try getSignalAsInt(&inputs_set);
    try stdout.print("Result1: {d}\n", .{result1});

    // part2: validate layout
    // x0 and y0 should go to an xor that goes to z0
    // xn and yn should go to an xor that goes to an xor that goes to zn
    // 2nd input of the output-xor should go to the previous carry

    var swapped = try std.ArrayList([3]u8).initCapacity(allocator, 8);
    defer swapped.deinit();

    var xor_in: [45]*Gate = undefined;
    var out_gate: [45]*Gate = undefined;
    var carry_out_gate: [45]*Gate = undefined;
    for (0..45) |i| {
        const x_name = [3]u8{'x', @intCast('0' + i/10), @intCast('0' + i%10)};
        const y_name = [3]u8{'y', @intCast('0' + i/10), @intCast('0' + i%10)};
        const z_name = [3]u8{'z', @intCast('0' + i/10), @intCast('0' + i%10)};
        xor_in[i] = try findGateForInputs(gate_list.items, x_name, y_name, GateType.XOR);
        out_gate[i] = findGateForOutput(gate_list.items, z_name, GateType.XOR) catch actual_out: {
            const gate = try findGateForAnInput(gate_list.items, xor_in[i].y, GateType.XOR);
            try swapped.append(z_name);
            try swapped.append(gate.y);
            //std.debug.print("Swapped: {s} <-> {s}\n", .{z_name, gate.y});
            break :actual_out gate;
        };
        if (i > 0) {
            var carry_in_name: [3]u8 = undefined;
            if (mem.eql(u8, &xor_in[i].y, &out_gate[i].a)) {
                carry_in_name = out_gate[i].b;
            } else if (mem.eql(u8, &xor_in[i].y, &out_gate[i].b)) {
                carry_in_name = out_gate[i].a;
            } else {
                //std.debug.print("No connection for {} -> {}\n", .{xor_in[i], out_gate[i]});
                // this means xor_in[i].y is either swapped with out_gate[i].a or out_gate[i].b
                // -> find the one that connects to carry, and the other one is swapped
                const e= findGateForOutput(
                        gate_list.items,
                        out_gate[i].a,
                        GateType.OR);
                if (e) |_| {
                    try swapped.append(xor_in[i].y);
                    try swapped.append(out_gate[i].b);
                    //std.debug.print("Swapped: {s} <-> {s}\n", .{xor_in[i].y, out_gate[i].b});
                } else |_| {
                    try swapped.append(xor_in[i].y);
                    try swapped.append(out_gate[i].a);
                    //std.debug.print("Swapped: {s} <-> {s}\n", .{xor_in[i].y, out_gate[i].a});
                }
                continue;
            }
            // find or gate that provides carry in
            carry_out_gate[i-1] = findGateForOutput(
                    gate_list.items,
                    carry_in_name,
                    GateType.OR) catch { //}actual_carry: {
                // already got my answer, so didn't do this
                //std.debug.print("No carry for {} -> {}\n", .{xor_in[i], out_gate[i]});
                continue; // TODO: find actual carry
            };
        }
    }

    // swap gates for validation
    for (0..swapped.items.len/2) |i| {
        const wire1 = swapped.items[i*2 + 0];
        const wire2 = swapped.items[i*2 + 1];
        //std.debug.print("Swapping {s} <-> {s}\n", .{wire1, wire2});
        swapGateOutputs(try findGateForOutput(gate_list.items, wire1, null),
            try findGateForOutput(gate_list.items, wire2, null));
    }

    // validate
    const x: u45 = 0b0;
    var y: u45 = 0b1;
    var ok = swapped.items.len == 8;
    for (0..45) |bitpos| {
        const actual1: u64 = try runWithIntsForInt(&inputs_set, gate_list.items, x, y);
        const actual2: u64 = try runWithIntsForInt(&inputs_set, gate_list.items, y, y);
        const expected1 = @as(u46, x) + @as(u46, y);
        const expected2 = @as(u46, y) + @as(u46, y);
        if (actual1 != expected1) {
            std.debug.print("{d:>2}: {x} instead of {x}\n", .{bitpos, actual1, expected1});
            ok = false;
        }
        if (actual2 != expected2) {
            std.debug.print("{d:>2}: {x} instead of {x}\n", .{bitpos, actual2, expected2});
            ok = false;
        }
        y<<=1;
    }

    if (!ok) {
        return error.DidNotSolvePart2;
    }

    // print result in the correct (sorted) format
    mem.sortUnstable([3]u8, swapped.items, {}, wireSorter);
    try stdout.print("Result2: ", .{});
    for (swapped.items, 0..) |wire, i| {
        if (i != 0) {
            try stdout.print(",", .{});
        }
        try stdout.print("{s}", .{wire});
    }
    try stdout.print("\n", .{});
}
