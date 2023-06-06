pub const Modules = enum {
    Browser,
    Todo,
    Web,
};

pub const Result = struct {
    running: bool,
    used_input: bool,
};
