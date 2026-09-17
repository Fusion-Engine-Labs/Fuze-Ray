const Renderer = @import("renderer.zig");
const gui_glfw = @import("zGUI_glfw");
const ui = @import("ui/ui.zig");
const gui = @import("zGUI");
const ray = @import("ray");
const std = @import("std");

/// The window opens showing the default scene at two thirds of its resolution,
/// which the viewport then keeps fitting as the user resizes either one.
const initial_viewport_scale = 2.0 / 3.0;

/// The window never opens shorter than this, so the inspector starts with room
/// to show its sections rather than immediately needing to be scrolled.
const min_window_height: f32 = 820;

const fps_window_ns: i96 = std.time.ns_per_s / 4;

pub fn main(init: std.process.Init) !void {
    const gpa = init.gpa;
    const io = init.io;

    var scene = try ray.Scene.initDefault(gpa);
    defer scene.deinit(gpa);

    const window_size = initialWindowSize(&scene);
    var platform = try gui_glfw.GlfwPlatform.init(gpa, window_size.width, window_size.height, "ray");
    defer platform.deinit();
    platform.makeContextCurrent();

    var gl = try gui.OpenGlRenderer.init(gpa, gui_glfw.GlfwPlatform.getProcAddress);
    defer gl.deinit();

    const font_bytes = @embedFile("app_font");
    var font_atlas = try gui.FontAtlas.init(gpa, font_bytes, 1024, 1024);
    defer font_atlas.deinit();

    var state = try gui.Ui.init(gpa);
    defer state.deinit();

    const raster_scale = framebufferScale(platform.getWindowSize(), platform.getFramebufferSize());
    const theme_font_sizes = state.theme.font.sizes();
    try font_atlas.prewarmAscii(&theme_font_sizes, raster_scale);
    try gl.syncFontAtlas(&font_atlas);
    state.setFontAtlas(&font_atlas);

    var renderer = try Renderer.init(gpa, io, &scene);
    defer renderer.deinit();

    var texture = try gl.createTextureRgba(
        renderer.buffer.width,
        renderer.buffer.height,
        renderer.buffer.bytes(),
    );
    defer gl.destroyTexture(&texture);

    var panel = try ui.Panel.init(gpa, &state, texture, &scene);
    defer panel.deinit(&state);

    var last_cursor: ?gui.CursorKind = null;
    var last_frame_ns = nowNs(io);
    var last_render_ns: ?i96 = null;
    var render_pending = false;
    var scene_edited = false;
    var fps: ?f32 = null;
    var fps_window_start_ns = last_frame_ns;
    var fps_window_frames: u32 = 0;

    while (!platform.shouldClose()) {
        const frame_start_ns = nowNs(io);
        const dt = std.math.clamp(
            nanosToSeconds(frame_start_ns - last_frame_ns),
            1.0 / 10_000.0,
            0.25,
        );
        last_frame_ns = frame_start_ns;

        fps_window_frames += 1;
        const fps_elapsed_ns = frame_start_ns - fps_window_start_ns;
        if (fps_elapsed_ns >= fps_window_ns) {
            const frames: f32 = @floatFromInt(fps_window_frames);
            fps = frames / nanosToSeconds(fps_elapsed_ns);
            fps_window_start_ns = frame_start_ns;
            fps_window_frames = 0;
        }

        const platform_events = platform.pollEvents();
        const size = platform.getWindowSize();
        const framebuffer_size = platform.getFramebufferSize();

        try state.beginFrame(.{
            .events = platform_events,
            .window_size = size,
            .dt = dt,
            .clipboard = platform.clipboard(),
        });

        const frame = try panel.update(&state, &scene);
        scene_edited = scene_edited or frame.scene_edited;

        // While a render is in flight it owns the pixel buffer, so the action
        // stops it rather than resizing the image out from under it; the next
        // press starts a fresh one.
        if (frame.render_toggled) {
            if (renderer.isRendering()) {
                renderer.stop();
            } else {
                try renderer.start(&scene);
                scene_edited = false;
                render_pending = true;
            }
        }

        try panel.fitViewport(&state, renderer.buffer.width, renderer.buffer.height);

        if (render_pending) {
            const finished = !renderer.isRendering();
            try gl.uploadTextureRgba(
                texture,
                renderer.buffer.width,
                renderer.buffer.height,
                renderer.buffer.bytes(),
            );
            if (finished) {
                last_render_ns = renderer.elapsed_ns;
                render_pending = false;
            }
        }

        try panel.sync(&state, .{
            .fps = fps,
            .last_render_ns = last_render_ns,
            .width = renderer.buffer.width,
            .height = renderer.buffer.height,
            .rendering = renderer.isRendering(),
            .canceled = renderer.wasCanceled(),
            .edited = scene_edited,
        });

        const cursor = state.requestedCursor();
        if (last_cursor == null or last_cursor.? != cursor) {
            platform.setCursor(cursor);
            last_cursor = cursor;
        }

        state.setTextRasterScale(framebufferScale(size, framebuffer_size));
        try state.endFrame();
        try gl.syncFontAtlas(&font_atlas);

        const framebuffer_width: u32 = @intFromFloat(@max(1, framebuffer_size.x));
        const framebuffer_height: u32 = @intFromFloat(@max(1, framebuffer_size.y));
        try gl.beginFrameLogical(framebuffer_width, framebuffer_height, size.x, size.y);
        try gl.render(state.drawData());
        try gl.endFrame();
        platform.swapBuffers();
    }
}

const WindowSize = struct { width: u32, height: u32 };

fn initialWindowSize(scene: *const ray.Scene) WindowSize {
    const width: f32 = @floatFromInt(scene.width);
    const height: f32 = @floatFromInt(scene.height);
    return .{
        .width = @intFromFloat(@round(width * initial_viewport_scale) + @as(f32, ui.chrome_width)),
        .height = @intFromFloat(@max(
            min_window_height,
            @round(height * initial_viewport_scale) + @as(f32, ui.chrome_height),
        )),
    };
}

fn nowNs(io: std.Io) i96 {
    return std.Io.Clock.awake.now(io).toNanoseconds();
}

fn nanosToSeconds(ns: i96) f32 {
    return @as(f32, @floatFromInt(ns)) / @as(f32, @floatFromInt(std.time.ns_per_s));
}

fn framebufferScale(window_size: gui.Vec2, framebuffer_size: gui.Vec2) f32 {
    const x = framebuffer_size.x / @max(1, window_size.x);
    const y = framebuffer_size.y / @max(1, window_size.y);
    return @max(0.25, @max(x, y));
}

test {
    _ = ui;
}
