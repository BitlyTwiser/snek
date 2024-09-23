// Sneaky Snek

const std = @import("std");
const builtin = @import("builtin");
const assert = std.debug.assert;

pub const CliError = error{ InvalidArg, InvalidNumberOfArgs, CliArgumentNotFound, InvalidCommand, HelpCommand, IncorrectArgumentType, RequiredArgumentNotFound, UnexpectedCliType, NonStructPassed, OutOfMemory, UnrecognizedSimpleType, Overflow, InvalidCharacter, NotBoolean };

const ArgMetadata = struct {
    key: []const u8,
    value: []const u8,
    optional: bool,
};

/// Snek - the primary CLI interface returning the anonnymous struct type for serializing all CLI arguments
pub fn Snek(comptime CliInterface: type) type {
    return struct {
        allocator: std.mem.Allocator,
        arg_metadata: std.StringHashMap(ArgMetadata),
        // Using @This() allows for destructuring of whatever this type is (i.e. allowing for metadata parsing of the cli struct)
        const Self = @This();

        // ## Public API Functions ##

        /// General Init function for curating CliInterface type
        pub fn init(allocator: std.mem.Allocator) !Self {
            return .{
                .allocator = allocator,
                .arg_metadata = std.StringHashMap(ArgMetadata).init(allocator),
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

        pub fn deinit(self: *Self) void {
            _ = self;
        }

        /// deinitMem deinitializes abitrary memory
        pub fn deinitMem(self: *Self, mem: anytype) void {
            self.allocator.free(mem);
        }

        /// Primary CLI parser for parsing the incoming args from stdin and the incoming CliInterface to parse out the individual commands/fields
        pub fn parse(self: *Self) CliError!CliInterface {
            if (!self.isStruct()) {
                std.debug.print("Struct must be passed to parse function. Type: {any} found", .{@TypeOf(CliInterface)});
                return CliError.NonStructPassed;
            }

            var interface: CliInterface = undefined;

            const cli_reflected = @typeInfo(@TypeOf(interface));

            // Collect and do some initial checking on passed in flags/values
            self.collectArgs() catch |e| {
                switch (e) {
                    CliError.HelpCommand => {
                        try self.help();

                        std.process.exit(0);
                    },
                    CliError.InvalidCommand => {
                        std.debug.print("Invalid cli command was passed. Please use -help or -h to check help menu for available commands", .{});

                        std.process.exit(0);
                    },
                    else => {
                        return e;
                    },
                }
            };

            unwrap_for: inline for (cli_reflected.Struct.fields) |field| {
                const arg = self.arg_metadata.get(field.name) orelse null;

                // If arg does NOT exist and the field is NOT optional, its an error case, so handle accordingly
                if (arg == null) {
                    switch (@typeInfo(field.type)) {
                        .Optional => {
                            break :unwrap_for;
                        },
                        else => {
                            // Check if there is a default value, if there is, move on (same case as an optional). Else, error case
                            if (field.default_value == null) break :unwrap_for;

                            std.debug.print("Required arugment {s} was not found in CLI flags. Check -help menu for required flags", .{field.name});
                            return CliError.RequiredArgumentNotFound;
                        },
                    }
                }

                // Write data to struct field based on typ witin arg. Arg, at this point, should never be null since we capture that case above
                comptime var field_type: std.builtin.Type = undefined;
                const serialized_arg = arg.?;
                // handle child case of optional type to get true base type for optional support
                if (@typeInfo(field.type) == .Optional) {
                    const i = @typeInfo(field.type);
                    field_type = @typeInfo(i.Optional.child);
                } else {
                    field_type = @typeInfo(field.type);
                }

                switch (field_type) {
                    .Bool => {
                        @field(&interface, field.name) = try self.parseBool(serialized_arg.key);
                    },
                    .Int => {
                        @field(&interface, field.name) = try self.parseNumeric(field.type, serialized_arg.key);
                    },
                    .Float => {
                        @field(&interface, field.name) = try self.parseNumeric(field.type, serialized_arg.key);
                    },
                    .Pointer => {
                        // .Pointer is for strings since the underlying type is []const u8 which is a .Pointer type
                        if (field_type.Pointer.size == .Slice and field_type.Pointer.child == u8) {
                            // At this point, just store the string.
                            @field(&interface, field.name) = serialized_arg.key;
                        }
                    },
                    .Struct => {
                        return CliError.UnexpectedCliType;
                    },
                    else => {
                        return CliError.UnexpectedCliType;
                    },
                }
            }

            return interface;
        }

        // ## Helper Functions ##

        fn collectArgs(self: *Self) !void {
            var args = try std.process.argsWithAllocator(self.allocator);
            defer deinit(self);

            // Skip first line, its always the name of the calling function
            _ = args.skip();

            const interface: CliInterface = undefined;

            const cli_reflected = @typeInfo(@TypeOf(interface));

            while (args.next()) |arg| {
                if (arg[0] != '-') {
                    return CliError.InvalidCommand;
                }

                // Remove the - without calling std.mem
                const arg_stripped = arg[1..];

                // Help command is treated as an exit case to display the help menu. This is the same way that Go does it in the Flag package
                // https://cs.opensource.google/go/go/+/refs/tags/go1.23.1:src/flag/flag.go;l=1111
                if (std.mem.eql(u8, arg_stripped, "help") or std.mem.eql(u8, arg_stripped, "h")) return CliError.HelpCommand;

                // Split on all data *after* the initial - and curate a roster of key/value arguments seerated by the =
                var split_arg = std.mem.split(u8, arg_stripped, "=");
                const arg_key = split_arg.next() orelse "";
                const arg_val = split_arg.next() orelse "";

                // Dupe memory to avoid issues with string pointer storage
                const arg_key_d = try self.allocator.dupe(u8, arg_key);
                const arg_val_d = try self.allocator.dupe(u8, arg_val);

                // Check dedup map, if it is true, it was already found, skip adding and key check
                if (self.arg_metadata.get(arg_key_d)) |_| {
                    std.debug.print("Warn: Duplicate key {s} passed. Using previous argument!", .{arg_key_d});

                    continue;
                }

                // No struct field of this name was found. Send error instead of moving on
                if (!self.hasKey(arg_key_d)) return CliError.InvalidCommand;

                inline for (cli_reflected.Struct.fields) |field| {
                    if (std.mem.eql(u8, field.name, arg_key_d)) {
                        switch (@typeInfo(field.type)) {
                            // Extract the type of the child since that is what we are after
                            .Optional => {
                                try self.arg_metadata.put(arg_key_d, .{ .key = arg_key_d, .value = std.mem.trim(u8, arg_val_d, " "), .optional = true });
                            },
                            // For all other cases just record the type
                            else => {
                                try self.arg_metadata.put(arg_key_d, .{ .key = arg_key_d, .value = std.mem.trim(u8, arg_val_d, " "), .optional = false });
                            },
                        }
                    }
                }
            }
        }

        fn hasKey(self: *Self, key: []const u8) bool {
            _ = self;

            inline for (std.meta.fields(CliInterface)) |field| {
                if (std.mem.eql(u8, key, field.name)) return true;
            }

            return false;
        }

        // Ensures passed in value is a struct. It cannot be anything else so strict checking is applied to public functions
        fn isStruct(self: *Self) bool {
            _ = self;
            const cli_reflected = @typeInfo(CliInterface);
            if (cli_reflected != .Struct) return false;

            return true;
        }

        // ## Parser Functions ##

        fn parseBool(self: Self, parse_value: []const u8) !bool {
            _ = self;
            if (std.mem.eql(u8, parse_value, "True") or std.mem.eql(u8, parse_value, "true") or std.mem.eql(u8, parse_value, "On") or std.mem.eql(u8, parse_value, "on")) {
                return true;
            } else if (std.mem.eql(u8, parse_value, "False") or std.mem.eql(u8, parse_value, "false") or std.mem.eql(u8, parse_value, "Off") or std.mem.eql(u8, parse_value, "off")) {
                return false;
            }

            return error.NotBoolean;
        }

        fn parseNumeric(self: Self, comptime T: type, parse_value: []const u8) !T {
            _ = self;
            switch (@typeInfo(T)) {
                .Int => {
                    return std.fmt.parseInt(T, parse_value, 10);
                },
                .Float => {
                    return std.fmt.parseFloat(T, parse_value);
                },
                else => {
                    return error.UnrecognizedSimpleType;
                },
            }
        }

        // Unused - Keep around in case of more advanced string parsing
        fn parseString(self: Self, parse_value: []const u8) !void {
            _ = self;
            _ = parse_value;
        }
    };
}

test "Test struct with optional fields" {
    const T = struct {
        test_one: ?[]const u8,
        test_two: ?u32,
        test_three: ?f64,
    };

    var snek = try Snek(T).init(std.heap.page_allocator);
    _ = try snek.parse();
}

test "test struct with default fields" {
    // Obviously stdin arguments are initially all strings. The datatype used in the struct will be used for the coercion of the type during parsing.
    // If the coercian step fails to parse the respective value, an error will commence.
    // This will display the help menu to the user
    // const test_args = [_][]const u8{ "test", "123", "3.14" };

    const T = struct {
        default_string: []const u8 = "",
        default_int: u32 = 420,
        optional_value: ?f64,
        default_bool: bool = true, // Technically the bool would have a false default generically due to the nature of bools, but non the less we can either specify or override.
    };

    var snek = try Snek(T).init(std.heap.page_allocator);
    _ = try snek.parse();

    //  Validate that hte given default values will not change after parsing unless they are present in the stdin arguments.

    // Validate that the values will change to the incoming stdin arguments
}

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
