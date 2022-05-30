pub const Modules = enum {
    Browser,
    Todo,
};

pub const ModuleUpdateResult = struct {
    running: bool,
    used_input: bool,
};
