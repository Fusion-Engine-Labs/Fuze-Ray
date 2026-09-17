const std = @import("std");
const ray = @import("ray");

const Renderer = @This();

allocator: std.mem.Allocator,
io: std.Io,
buffer: ray.Buffer,
clear_color: ray.Rgba = .{ .r = 18, .g = 20, .b = 26, .a = 255 },
thread: ?std.Thread = null,
running: std.atomic.Value(bool) = .init(false),
cancel: std.atomic.Value(bool) = .init(false),
elapsed_ns: i96 = 0,

pub fn init(allocator: std.mem.Allocator, io: std.Io, scene: *const ray.Scene) !Renderer {
    var buffer = try ray.Buffer.init(allocator, scene.width, scene.height);
    errdefer buffer.deinit();

    var self: Renderer = .{ .allocator = allocator, .io = io, .buffer = buffer };
    self.buffer.clear(self.clear_color);
    return self;
}

pub fn deinit(self: *Renderer) void {
    self.stop();
    self.wait();
    self.buffer.deinit();
    self.* = undefined;
}

pub fn start(self: *Renderer, scene: *const ray.Scene) !void {
    if (self.isRendering()) {
        return;
    }
    self.wait();

    var snapshot = try scene.clone(self.allocator);
    errdefer snapshot.deinit(self.allocator);

    try self.buffer.resize(snapshot.width, snapshot.height);
    self.buffer.clear(self.clear_color);

    self.cancel.store(false, .release);
    self.running.store(true, .release);
    self.thread = std.Thread.spawn(.{}, work, .{ self, snapshot }) catch |err| {
        self.running.store(false, .release);
        return err;
    };
}

pub fn stop(self: *Renderer) void {
    self.cancel.store(true, .release);
}

pub fn wasCanceled(self: *const Renderer) bool {
    return self.cancel.load(.acquire);
}

pub fn isRendering(self: *const Renderer) bool {
    return self.running.load(.acquire);
}

pub fn wait(self: *Renderer) void {
    if (self.thread) |thread| {
        thread.join();
        self.thread = null;
    }
}

fn work(self: *Renderer, scene: ray.Scene) void {
    var owned = scene;
    defer owned.deinit(self.allocator);

    const start_ns = nowNs(self.io);
    ray.render(self.io, &self.buffer, &owned, &self.cancel) catch |err| {
        std.debug.print("ray: render error: {}\n", .{err});
    };
    self.elapsed_ns = nowNs(self.io) - start_ns;
    self.running.store(false, .release);
}

fn nowNs(io: std.Io) i96 {
    return std.Io.Clock.awake.now(io).toNanoseconds();
}
