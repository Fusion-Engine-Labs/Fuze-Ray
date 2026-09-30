const gui = @import("zGUI");
const std = @import("std");
const ray = @import("ray");

const toolbar_height = 44;
const side_panel_width = 300;
const side_panel_padding = 12;
const body_padding = 8;
const body_gap = 8;

pub const chrome_width = side_panel_width + body_gap + body_padding * 2;
pub const chrome_height = toolbar_height + body_padding * 2;

const background = gui.Color.rgba(14, 16, 22, 255);
const surface_color = gui.Color.rgba(22, 25, 32, 255);
const panel_color = gui.Color.rgba(28, 32, 42, 255);
const border_color = gui.Color.rgba(58, 68, 88, 255);
const text_color = gui.Color.rgba(226, 232, 242, 255);
const muted_text_color = gui.Color.rgba(150, 162, 182, 255);
const accent_color = gui.Color.rgba(62, 101, 176, 255);

fn toRgba(color: gui.Color) ray.Rgba {
    return .{ .r = color.r, .g = color.g, .b = color.b, .a = color.a };
}

fn toGuiColor(color: ray.Rgba) gui.Color {
    return gui.Color.rgba(color.r, color.g, color.b, color.a);
}

pub const default_sphere: ray.Sphere = .{ .center = .{ 0, 0, -1 }, .radius = 0.5, .color = .{ .r = 62, .g = 140, .b = 220 } };

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

const position_axis_labels = [3][]const u8{ "X", "Y", "Z" };

const position_field_options: gui.NumericOptions = .{ .step = 0.1, .width = .fill };
const radius_slider_options: gui.SliderOptions = .{ .min = 0.05, .max = 2.0, .step = 0.05 };

const SphereControls = struct {
    row: gui.NodeId,
    remove_button: gui.NodeId,
    picker: gui.ColorPicker,
    color: gui.Color,
    position_fields: [3]gui.NumericField,
    position: [3]f32,
    radius_slider: gui.Slider,
    radius_value_label: gui.NodeId,
    radius: f32,

    fn init(
        allocator: std.mem.Allocator,
        state: *gui.Ui,
        parent: gui.NodeId,
        sphere: ray.Sphere,
    ) !SphereControls {
        const row = try gui.widgets.panel(state, parent, .{
            .width = .fill,
            .height = .{ .px = 198 },
            .direction = .column,
            .gap = 6,
        });
        errdefer state.destroySubtree(row);

        const remove_button = try gui.widgets.button(state, row, "Remove", .{
            .width = .fill,
            .height = .{ .px = 28 },
            .padding = gui.Edges{ .left = 12, .right = 12, .top = 6, .bottom = 6 },
            .background = panel_color,
            .border_color = border_color,
            .border_width = 1,
            .radius = gui.CornerRadii.all(5),
            .text_align = .center,
        });

        const color = toGuiColor(sphere.color);
        const color_row = try labeledRow(state, row, "C");
        var picker = try gui.ColorPicker.init(allocator, state, color_row, color, .{});
        errdefer picker.deinit(state);

        const center: [3]f64 = sphere.center;
        var position: [3]f32 = undefined;
        var position_fields: [3]gui.NumericField = undefined;
        var fields_initialized: usize = 0;
        errdefer for (position_fields[0..fields_initialized]) |*field| field.deinit(state);
        for (&position_fields, 0..) |*field, i| {
            position[i] = @floatCast(center[i]);
            const axis_row = try labeledRow(state, row, position_axis_labels[i]);
            field.* = try gui.NumericField.initF32(allocator, state, axis_row, position[i], position_field_options);
            fields_initialized += 1;
        }

        const radius_row = try labeledRow(state, row, "R");
        var radius_slider = try gui.Slider.init(state, radius_row, radius_slider_options);
        errdefer radius_slider.deinit(state);
        const radius_value_label = try gui.widgets.label(state, radius_row, "", .{
            .width = .{ .px = 40 },
            .height = .fill,
            .padding = gui.Edges{ .top = 6 },
            .foreground = muted_text_color,
            .font_size = 14,
            .text_align = .end,
        });

        return .{
            .row = row,
            .remove_button = remove_button,
            .picker = picker,
            .color = color,
            .position_fields = position_fields,
            .position = position,
            .radius_slider = radius_slider,
            .radius_value_label = radius_value_label,
            .radius = @floatCast(sphere.radius),
        };
    }

    fn deinit(self: *SphereControls, state: *gui.Ui) void {
        self.picker.deinit(state);
        for (&self.position_fields) |*field| field.deinit(state);
        self.radius_slider.deinit(state);
        state.destroySubtree(self.row);
        self.* = undefined;
    }

    fn update(self: *SphereControls, state: *gui.Ui, sphere: *ray.Sphere) !void {
        _ = try self.picker.update(state, &self.color);
        for (&self.position_fields, 0..) |*field, i| {
            _ = try field.updateF32(state, &self.position[i], position_field_options);
        }
        _ = try self.radius_slider.update(state, &self.radius, radius_slider_options);
        var radius_buf: [16]u8 = undefined;
        try state.setText(self.radius_value_label, try std.fmt.bufPrint(&radius_buf, "{d:.2}", .{self.radius}));
        sphere.center = .{ self.position[0], self.position[1], self.position[2] };
        sphere.radius = self.radius;
        sphere.color = toRgba(self.color);
    }
};

pub const Panel = struct {
    allocator: std.mem.Allocator,
    world: *ray.HittableList,
    nodes: Nodes,
    add_button: gui.NodeId,
    controls: std.ArrayList(SphereControls) = .empty,
    fit: Fit = .{},

    pub fn init(
        allocator: std.mem.Allocator,
        state: *gui.Ui,
        texture: gui.TextureHandle,
        world: *ray.HittableList,
    ) !Panel {
        const nodes = try build(state, texture);
        _ = try divider(state, nodes.side_panel);
        _ = try heading(state, nodes.side_panel, "Spheres");
        const add_button = try gui.widgets.button(state, nodes.side_panel, "Add sphere", .{
            .width = .fill,
            .height = .{ .px = 28 },
            .padding = gui.Edges{ .left = 12, .right = 12, .top = 6, .bottom = 6 },
            .background = accent_color,
            .foreground = gui.Color.rgba(255, 255, 255, 255),
            .radius = gui.CornerRadii.all(5),
            .text_align = .center,
        });

        var self: Panel = .{
            .allocator = allocator,
            .world = world,
            .nodes = nodes,
            .add_button = add_button,
        };
        errdefer self.controls.deinit(allocator);
        for (world.hittables.items) |item| {
            try self.appendControls(state, item.sphere);
        }
        return self;
    }

    pub fn deinit(self: *Panel, state: *gui.Ui) void {
        for (self.controls.items) |*controls| controls.deinit(state);
        self.controls.deinit(self.allocator);
        self.* = undefined;
    }

    fn appendControls(self: *Panel, state: *gui.Ui, sphere: ray.Sphere) !void {
        var controls = try SphereControls.init(self.allocator, state, self.nodes.side_panel, sphere);
        errdefer controls.deinit(state);
        try self.controls.append(self.allocator, controls);
    }

    pub fn update(self: *Panel, state: *gui.Ui) !void {
        if (state.clicked(self.add_button)) {
            try self.world.add(self.allocator, .{ .sphere = default_sphere });
            errdefer _ = self.world.hittables.pop();
            try self.appendControls(state, default_sphere);
        }

        var i: usize = 0;
        while (i < self.controls.items.len) {
            if (state.clicked(self.controls.items[i].remove_button)) {
                var removed = self.controls.orderedRemove(i);
                removed.deinit(state);
                _ = self.world.hittables.orderedRemove(i);
                continue;
            }
            try self.controls.items[i].update(state, &self.world.hittables.items[i].sphere);
            i += 1;
        }
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

fn divider(state: *gui.Ui, parent: gui.NodeId) !gui.NodeId {
    return gui.widgets.panel(state, parent, .{
        .width = .fill,
        .height = .{ .px = 1 },
        .background = border_color,
    });
}

fn labeledRow(state: *gui.Ui, parent: gui.NodeId, label_text: []const u8) !gui.NodeId {
    const row = try gui.widgets.panel(state, parent, .{
        .width = .fill,
        .height = .{ .px = 28 },
        .direction = .row,
        .gap = 8,
    });
    _ = try gui.widgets.label(state, row, label_text, .{
        .width = .{ .px = 16 },
        .height = .fill,
        .padding = gui.Edges{ .top = 6 },
        .foreground = muted_text_color,
        .font_size = 14,
    });
    return row;
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
        .overflow_y = .scroll,
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
