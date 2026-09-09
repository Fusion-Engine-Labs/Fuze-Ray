const gui = @import("zGUI");
const std = @import("std");
const ray = @import("ray");

const toolbar_height = 44;
const side_panel_width = 300;
const side_panel_padding = 12;
const body_padding = 8;
const body_gap = 8;
const wheel_diameter = side_panel_width - side_panel_padding * 2;

pub const chrome_width = side_panel_width + body_gap + body_padding * 2;
pub const chrome_height = toolbar_height + body_padding * 2;

const background = gui.Color.rgba(14, 16, 22, 255);
const surface_color = gui.Color.rgba(22, 25, 32, 255);
const panel_color = gui.Color.rgba(28, 32, 42, 255);
const border_color = gui.Color.rgba(58, 68, 88, 255);
const text_color = gui.Color.rgba(226, 232, 242, 255);
const muted_text_color = gui.Color.rgba(150, 162, 182, 255);
const accent_color = gui.Color.rgba(62, 101, 176, 255);

pub const initial_fill = gui.Color.rgba(62, 140, 220, 255);

/// The picker speaks `gui.Color` and the tracer core speaks `ray.Rgba`; this is
/// the only place the two representations meet.
fn toRgba(color: gui.Color) ray.Rgba {
    return .{ .r = color.r, .g = color.g, .b = color.b, .a = color.a };
}

/// Seed for `Renderer.fill`, so the starting colour is stated exactly once.
pub fn initialFill() ray.Rgba {
    return toRgba(initial_fill);
}

pub const Stats = struct {
    fps: ?f32,
    last_render_ns: ?i96,
    width: u32,
    height: u32,

    /// A render is only ever timed into the buffer once it has drawn one, so
    /// the timing doubles as the "is there an image yet" answer.
    fn hasImage(self: Stats) bool {
        return self.last_render_ns != null;
    }
};

const Nodes = struct {
    viewport: gui.NodeId,
    image: gui.NodeId,
    side_panel: gui.NodeId,
    start_button: gui.NodeId,
    render_label: gui.NodeId,
    fps_label: gui.NodeId,
    status_label: gui.NodeId,
};

const Fit = struct {
    width: f32 = 0,
    height: f32 = 0,
    left: f32 = 0,
    top: f32 = 0,
};

pub const Panel = struct {
    nodes: Nodes,
    picker: gui.ColorPicker,
    color: gui.Color,
    fit: Fit = .{},

    pub fn init(
        allocator: std.mem.Allocator,
        state: *gui.Ui,
        texture: gui.TextureHandle,
    ) !Panel {
        const nodes = try build(state, texture);
        const picker = try gui.ColorPicker.init(allocator, state, nodes.side_panel, initial_fill, .{
            .wheel_diameter = wheel_diameter,
        });
        return .{ .nodes = nodes, .picker = picker, .color = initial_fill };
    }

    pub fn deinit(self: *Panel, state: *gui.Ui) void {
        self.picker.deinit(state);
        self.* = undefined;
    }

    pub fn fill(self: *const Panel) ray.Rgba {
        return toRgba(self.color);
    }

    pub fn update(self: *Panel, state: *gui.Ui) !void {
        _ = try self.picker.update(state, &self.color);
    }

    pub fn startClicked(self: *const Panel, state: *gui.Ui) bool {
        return state.clicked(self.nodes.start_button);
    }

    pub fn fitViewport(self: *Panel, state: *gui.Ui, width: u32, height: u32) !void {
        const area = state.bounds(self.nodes.viewport) orelse return;
        const buffer_width: f32 = @floatFromInt(width);
        const buffer_height: f32 = @floatFromInt(height);
        if (buffer_width <= 0 or buffer_height <= 0 or area.w <= 0 or area.h <= 0) {
            return;
        }

        const scale = @min(area.w / buffer_width, area.h / buffer_height);
        const drawn_width = @floor(buffer_width * scale);
        const drawn_height = @floor(buffer_height * scale);
        const fit: Fit = .{
            .width = drawn_width,
            .height = drawn_height,
            .left = @floor((area.w - drawn_width) / 2),
            .top = @floor((area.h - drawn_height) / 2),
        };
        if (std.meta.eql(fit, self.fit)) {
            return;
        }
        self.fit = fit;

        try state.setStyle(self.nodes.image, .{
            .width = .{ .px = fit.width },
            .height = .{ .px = fit.height },
            .margin = gui.Edges{ .left = fit.left, .top = fit.top },
        });
    }

    pub fn sync(self: *const Panel, state: *gui.Ui, stats: Stats) !void {
        try state.setText(
            self.nodes.start_button,
            if (stats.hasImage()) "Re-render" else "Render",
        );

        var render_buf: [64]u8 = undefined;
        try state.setText(self.nodes.render_label, if (stats.last_render_ns) |ns|
            try std.fmt.bufPrint(&render_buf, "{d:.2} ms", .{millis(ns)})
        else
            "Not rendered");

        var fps_buf: [32]u8 = undefined;
        try state.setText(self.nodes.fps_label, if (stats.fps) |value|
            try std.fmt.bufPrint(&fps_buf, "{d:.0} FPS", .{value})
        else
            "-- FPS");

        var status_buf: [32]u8 = undefined;
        try state.setText(self.nodes.status_label, try std.fmt.bufPrint(
            &status_buf,
            "{d}x{d}",
            .{ stats.width, stats.height },
        ));
    }
};

fn millis(ns: i96) f64 {
    return @as(f64, @floatFromInt(ns)) / @as(f64, std.time.ns_per_ms);
}

/// The side panel has exactly two text roles; naming them keeps a restyle a
/// one-line edit instead of four near-identical blocks kept in agreement.
fn heading(state: *gui.Ui, parent: gui.NodeId, text: []const u8) !gui.NodeId {
    return gui.widgets.label(state, parent, text, .{
        .width = .fill,
        .foreground = text_color,
        .font_size = 16,
    });
}

fn stat(state: *gui.Ui, parent: gui.NodeId, text: []const u8) !gui.NodeId {
    return gui.widgets.label(state, parent, text, .{
        .width = .fill,
        .foreground = muted_text_color,
        .font_size = 14,
    });
}

fn build(state: *gui.Ui, texture: gui.TextureHandle) !Nodes {
    const root = state.rootNode();
    try state.setStyle(root, .{
        .width = .fill,
        .height = .fill,
        .direction = .column,
        .background = background,
    });

    const toolbar = try gui.widgets.toolbar(state, root, .{
        .width = .fill,
        .height = .{ .px = toolbar_height },
        .direction = .row,
        .gap = 12,
        .padding = gui.Edges{ .left = 14, .right = 14, .top = 8, .bottom = 8 },
        .background = panel_color,
        .border_color = border_color,
        .border_width = 1,
    });

    _ = try gui.widgets.label(state, toolbar, "Fusion Raytracer", .{
        .width = .{ .px = 120 },
        .height = .fill,
        .padding = gui.Edges{ .top = 3 },
        .foreground = text_color,
        .font_size = 18,
    });

    const status_label = try gui.widgets.label(state, toolbar, "", .{
        .width = .fill,
        .height = .fill,
        .padding = gui.Edges{ .top = 6 },
        .foreground = muted_text_color,
        .font_size = 14,
    });

    const body = try gui.widgets.panel(state, root, .{
        .width = .fill,
        .height = .fill,
        .direction = .row,
        .gap = body_gap,
        .padding = gui.Edges.all(body_padding),
        .background = background,
    });

    const viewport = try gui.widgets.panel(state, body, .{
        .width = .fill,
        .height = .fill,
        .direction = .column,
        .background = surface_color,
        .border_color = border_color,
        .border_width = 1,
    });

    const image = try gui.widgets.image(state, viewport, .{
        .texture = texture,
        .style = .{ .width = .fill, .height = .fill },
    });

    const side_panel = try gui.widgets.panel(state, body, .{
        .width = .{ .px = side_panel_width },
        .height = .fill,
        .direction = .column,
        .gap = 10,
        .padding = gui.Edges.all(side_panel_padding),
        .background = panel_color,
        .border_color = border_color,
        .border_width = 1,
    });

    _ = try heading(state, side_panel, "Render");

    const start_button = try gui.widgets.button(state, side_panel, "Render", .{
        .width = .fill,
        .height = .{ .px = 34 },
        .padding = gui.Edges{ .left = 12, .right = 12, .top = 8, .bottom = 8 },
        .background = accent_color,
        .hover_background = gui.Color.rgba(78, 122, 202, 255),
        .pressed_background = gui.Color.rgba(48, 84, 152, 255),
        .foreground = gui.Color.rgba(255, 255, 255, 255),
        .border_color = gui.Color.rgba(104, 142, 220, 255),
        .border_width = 1,
        .radius = gui.CornerRadii.all(5),
        .text_align = .center,
    });

    const render_label = try stat(state, side_panel, "Not rendered");

    const fps_label = try stat(state, side_panel, "-- FPS");

    _ = try gui.widgets.panel(state, side_panel, .{
        .width = .fill,
        .height = .{ .px = 1 },
        .background = border_color,
    });

    _ = try heading(state, side_panel, "Fill Colour");

    return .{
        .viewport = viewport,
        .image = image,
        .side_panel = side_panel,
        .start_button = start_button,
        .render_label = render_label,
        .fps_label = fps_label,
        .status_label = status_label,
    };
}
