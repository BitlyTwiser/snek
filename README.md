<div align="center"> 

<img src="/assets/logo.png" width="450" height="500">
</div>


# snek
Snek - A simple CLI parser to build CLI applications in Zig


## Note: This is currently under construction and is not yet available for public consumption (hence no releases!)


### Usage:
Add snek to your zig project:
```
zig fetch --save https://github.com/BitlyTwiser/snek/archive/refs/tags/0.1.0.tar.gz
```

Add to build file:
```
    const snek = b.dependency("snek", .{});
    exe.root_module.addImport("snek", snek.module("snek"));
```

### Build your CLI:
Snek builds dynamic (yet simple) CLI's using metadata programming to infer the struct fields, the expected types, then insert the incoming data from the stdin arguments and serialize that data into the given struct.

```
    const T = struct {
        bool_test: bool,
        word: []const u8,
        test_opt: ?u32,
    };
    var snek = try Snek(T).init(std.heap.page_allocator);
    try snek.help();
```

#### Optionals:
Using zig optionals, you can set selected flags to be ignored if they are not present.

#### Default Values:
You can use struct defaut values to set a static value if one is not parsed.


### Help Menu:
Snek dynaically builds the help menu for your users. By calling the `help()` function, you can display how to use your CLI:
```
    const T = struct {
        bool_test: bool,
        word: []const u8,
        test_opt: ?u32,
    };
    var snek = try Snek(T).init(std.heap.page_allocator);
    try snek.parse();

    // Print the values from the serialized struct data
    std.debug.print("{any}", .{T.bool_test});
```
Output:
```
CLI Flags Help Menu
---------
-bool_test=Bool (optional: false)
-word=Pointer (optional: false)
-test_opt=Optional (optional: true)
---------
```


