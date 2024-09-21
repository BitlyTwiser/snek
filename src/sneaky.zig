// Sneaky Snek

const std = @import("std");
const builtin = @import("builtin");

// cli tool that supports arguments like -cooamdn=asdasd
// Supports optional arguments (use optionals in struct to determine if they are required or not)
// Supports default arguments if there is an existing value in the struct.
// If the stdin args do not match or are missing (no optional) throw an error
// Actually the return data IS the input struct. Like yamlz. I.e. the struct will hold default fields if non are parsed (has to  be optionals)
// in the end we just return the struct
// no sub-commands as of now i.e. thing -thing=asdasd etc.. just flat commands for now
// Dagger - A tool for building robust CLI tools in Zig

const CliError = error{ InvalidArg, InvalidNumberOfArgs, CliArgumentNotFound, InvalidCommand };

/// Snek - the primary CLI interface returning the anonnymous struct type for serializing all CLI arguments
pub fn Snek(comptime CliInterface: type) type {
    return struct {
        allocator: std.mem.Allocator,
        // Using @This() allows for destructuring of whatever this type is (i.e. allowing for metadata parsing of the cli struct)
        const Self = @This();

        // ## Public API Functions ##

        /// General Init function for curating CliInterface type
        pub fn init(allocator: std.mem.Allocator) !Self {
            return .{
                .allocator = allocator,
            };
        }

        /// Help - Prints out the fields and their expected types to the user for a simple help menu for the CLI
        pub fn help(self: *Self) !void {
            if (!self.isStruct()) {
                std.debug.print("A valid struct must be passed to help function. Type: {any} found", .{@TypeOf(CliInterface)});
                return;
            }

            const interface: CliInterface = undefined;

            // Help is easy, we do not need to set nor care about the value
            const cli_reflected = @typeInfo(@TypeOf(interface));

            if (cli_reflected == .Struct) {
                const field_size = cli_reflected.Struct.fields.len;

                var command_slice = try self.allocator.alloc([]u8, field_size);

                var index: usize = 0;
                inline for (cli_reflected.Struct.fields) |field| {
                    comptime var field_type: std.builtin.Type = undefined;
                    var optional_field: bool = false; // Assumed false until proven otherwise

                    const field_name = field.name;

                    const temp_field_type = @typeInfo(field.type);
                    // What is the type of the optional field
                    switch (temp_field_type) {
                        .Optional => {
                            optional_field = true;
                            field_type = temp_field_type;
                        },
                        else => {
                            field_type = temp_field_type;
                        },
                    }

                    const command_string = try std.fmt.allocPrint(self.allocator, "-{s}={s} (optional: {any})\n", .{ field_name, @tagName(field_type), optional_field });
                    command_slice[index] = command_string;

                    index += 1;
                }

                // Iterate and print commands in small help menu
                std.debug.print("CLI Flags Help Menu\n", .{});
                std.debug.print("---------\n", .{});
                for (command_slice) |command| {
                    std.debug.print("{s}", .{command});
                }
                std.debug.print("---------\n", .{});
            } else {
                std.debug.print("A valid struct was not passed into snek. Please ensure struct is valid and try again", .{});
                return;
            }
        }

        /// Deinitializes memory - Caller is responsible for this
        pub fn deinit(self: *Self) void {
            _ = self;
        }

        /// Primary CLI parser for pasing the incoming args from stdin and the incoming CliInterface to parse out the individual commands/fields
        /// The return is the struct that is passed. Must be a struct
        pub fn parse(self: *Self) !CliInterface {
            if (!self.isStruct()) {
                std.debug.print("Struct must be passed to parse function. Type: {any} found", .{@TypeOf(CliInterface)});
                return;
            }

            const interface: CliInterface = undefined;

            // Help is easy, we do not need to set nor care about the value
            const cli_reflected = @typeInfo(@TypeOf(interface));
            _ = cli_reflected;
        }

        // ## Helper Functions ##

        // Get args from stdin
        fn collectArgs(self: *Self) !void {
            var args = try std.process.argsWithAllocator(self.allocator);
            defer deinit(self);
            defer self.flushCliArgMap();
            // Skip first line, its always the name of the calling function
            _ = args.skip();

            while (args.next()) |arg| {
                if (arg[0] != '-') {
                    return CliError.InvalidCommand;
                }

                const split_arg = std.mem.split(u8, arg, "=");
                const arg_key = split_arg.next() orelse "";
                const arg_val = split_arg.next() orelse "";

                const arg_key_d = try self.allocator.dupe(u8, arg_key);
                const arg_val_d = try self.allocator.dupe(u8, arg_val);

                _ = arg_key_d;
                _ = arg_val_d;

                // Now do all the parsing with the struct to insert the value
            }
        }

        // Ensures passed in value is a struct. It cannot be anything else so strict checking is applied to public functions
        fn isStruct(self: *Self) bool {
            _ = self;
            const cli_reflected = @typeInfo(CliInterface);
            if (cli_reflected != .Struct) return false;

            return true;
        }

        fn parseStdinArgs() !void {}

        fn parseCliInterface() !void {}
    };
}

test "Test struct with optional fields" {}

test "test struct with default fields" {}

test "test struct with both optionals and defaults fields" {}

test "test struct with all general fields" {
    const T = struct {
        bool_test: bool,
        word: []const u8,
        test_opt: ?u32,
    };
    var snek = try Snek(T).init(std.heap.page_allocator);
    try snek.help();
}
