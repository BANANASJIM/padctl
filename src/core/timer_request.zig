pub const TimerRequest = union(enum) {
    arm: u32, // timeout_ms
    disarm: void,
};
