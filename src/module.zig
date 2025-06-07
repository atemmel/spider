pub const Modules = enum {
    Browser,
    Todo,
};

pub const Result = struct {
    running: bool,
    used_input: bool,
};
