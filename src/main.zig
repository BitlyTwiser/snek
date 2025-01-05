const std = @import("std");
const snek = @import("lib.zig").Snek;

// Binary is also compiled for showcasing how to use the API
const T = struct {
    name: []const u8,
    location: u32,
    optional_location: ?u32,
    opt_int: ?usize,
    exists: bool,
    necessary: ?bool,
    filled_optional: ?[]const u8,
    default_name: []const u8 = "test default name",
};

// Example command after compilation:
// ./zig-out/bin/snek -name="test mctest" -location=420 -exists=true
pub fn main() !void {
    var cli = try snek(T).init(std.heap.page_allocator);
    const parsed_cli = try cli.parse();

    // Necessary is skipped here to showcase optional values being ignored
    std.debug.print("Name: {s}\n Location: {d}\n Exists: {any}\n Defualt value: {s}\n Filled Optional: {s}\n Optional int: {d}\n Necessary: {any}", .{ parsed_cli.name, parsed_cli.location, parsed_cli.exists, parsed_cli.default_name, parsed_cli.filled_optional orelse "badvalue", parsed_cli.opt_int orelse 420, parsed_cli.necessary orelse false });
}
