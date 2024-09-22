const std = @import("std");
const snek = @import("lib.zig").Snek;

// Binary is also compiled for showcasing how to use the API
const T = struct {
    name: []const u8,
    location: u32,
    exists: bool,
    necessary: ?bool,
    filled_optional: ?[]const u8,
    default_name: []const u8 = "test default name",
};

pub fn main() !void {
    var cli = try snek(T).init(std.heap.page_allocator);
    const parsed_cli = try cli.parse();

    // Necessary is skipped here
    std.debug.print("{s} {d} {any} {s} {s}", .{ parsed_cli.name, parsed_cli.location, parsed_cli.exists, parsed_cli.default_name, if (parsed_cli.filled_optional) |filled| filled orelse "badvalue" });
}
