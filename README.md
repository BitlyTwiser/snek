<div align="center"> 

<img src="/assets/logo.png" width="450" height="500">


# 🐍snek🐍
A simple CLI parser building CLI applications in Zig


## Note: This is currently under construction and is not yet available for public consumption (hence no releases!)
# Contents
[Usage](#usage) |
[Building the CLI](#build-your-cli) |
[Examples](#examples) |
[Optionals](#optionals) |
[Default Values](#default-values) |
[Help Menu](#help-menu) |
[What is not supported](#what-is-not-supported)

</div>


### Usage
Add snek to your Zig project with Zon:
```
zig fetch --save https://github.com/BitlyTwiser/snek/archive/refs/tags/0.1.0.tar.gz
```

Add the following to build.zig file:
```
    const snek = b.dependency("snek", .{});
    exe.root_module.addImport("snek", snek.module("snek"));
```

### Build your CLI
Snek builds dynamic (yet simple) CLI's using zigs meta programming to infer the struct fields, the expected types, then insert the incoming data from the stdin arguments and serialize that data into the given struct mapping the data values to the given fields and marshalling the data into the proper type.

```
    const T = struct {
        bool_test: bool,
        word: []const u8,
        test_opt: ?u32,
        test_default: []const u8 = "I am static if not set by user",
    };
    var snek = try Snek(T).init(std.heap.page_allocator);
    const parsed = try snek.parse();

    // Do Stuff with the fields of the struct after parsing
    std.debug.print("{any}", .{parsed});
```

When the user goes to interact with the application, they can now utilize the flags you have established to run specific commands.

#### Items to note:
1. If the user does not supply a value and the field is *not* otional, that is a failure case and a message is displayed to the user
2. If there is a default value on the field of the struct and a vale is not passed for that field, it is treated as an *optional* case and will use the static value (i.e. no error message and value is set)
3. Simple structs only for now, no recursive struct fields at the moment. (i.e. no embeded structs)
4. If the users passed the wrong *type* which differes from what is expeected (i.e. the type of the struct field), this is an error case and a message will be displayed to the user.
5. If you want to handle the errors yourself, the CliError struct is public, so you can catch errors on the `parse()` call
```
    const T = struct {
        bool_test: bool,
        word: []const u8,
        test_opt: ?u32,
        test_default: []const u8 = "I am static if not set by user",
    };
    var snek = try Snek(T).init(std.heap.page_allocator);
    // Adjust to actually use value of course
    _ = snek.parse() catch |err| {
        switch(e) {
            ... do stuff with the Errors
        }
    }

```


#### Examples

Using the above struct as a  reference, here are a few examples of calling the CLI:
##### Help
```
./<yourappname> -help

# or

./<yourappname> -h
```

Note: As you can see, the optionals are just that, *optional*. They are not required by your users and can be checked in the calling code in the standard ways that Zig handles optionals.
This is a design decisions allowing flexibility over the CLI to not lock users into using every flag etc..
##### Optionals
````
./<yourappname> -bool_test=true -word="I am a word!"
````

##### Defaults:
```
./<yourappname> -bool_test=true -word="I am a word!"

# or to override the default field


./<yourappname> -bool_test=true -word="I am a word!" -test_defaults="I am a different word!"
```

#### Optionals
Using zig optionals, you can set selected flags to be ignored on the CLI, thus giving flexibilitiy on the behalf of the CLI creator to use or not use selected flags at their whimsy

#### Default Values
You can use struct defaut values to set a static value if one is not parsed. This can be useful for certain flags for conditional logic branching later in program execution.

### Help Menu
Snek dynaically builds the help menu for your users. By calling the `help()` function, you can display how to use your CLI:
```
    const T = struct {
        bool_test: bool,
        word: []const u8,
        test_opt: ?u32,
    };
    var snek = try Snek(T).init(std.heap.page_allocator);
    const parsed = try snek.help();

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


Alternatively, if users call -help as the *first* arguments in the CLI, it will also display the help menu.
```
./<yourappname> -help

# or

./<yourappname> -h
```

This will display the help menu and skip *all other parsing*. So its important to note that this is effectively an exit case for the parser and your program. 
You should build your application to support this.


### What is *not* supported

##### Recursive struct types for sub-command fields
At this time, no recursive flags are supported, i.e. you cannot use a slice of structs as a field in the primary CLI interface struct and have those fields parsed as sub-command fields.
Perhaps, if this is requested, we could work that into the application. It seemed slightly messy and unecessray for a simple CLI builder, but perhaps expansion will be necessary there if its requested :)

[Top](#usage)