const controls = @import("controls.zig");
const gui = @import("zGUI");
const std = @import("std");
const ray = @import("ray");

const v = ray.vector;

pub const Inspector = struct {
    root: gui.NodeId,
    output: OutputSection,
    camera: CameraSection,
    entities: EntitySection,

    pub fn init(
        allocator: std.mem.Allocator,
        ui: *gui.Ui,
        parent: gui.NodeId,
        scene: *const ray.Scene,
    ) !Inspector {
        const root = try gui.widgets.column(ui, parent, .{
            .width = .fill,
            .height = .fill,
            .gap = ui.theme.space.md,
            .padding = .{ .bottom = ui.theme.space.md },
            .overflow_y = .scroll,
        });
        errdefer ui.destroySubtree(root);

        var output = try OutputSection.init(allocator, ui, root, scene);
        errdefer output.deinit(ui);

        var camera = try CameraSection.init(allocator, ui, root, &scene.camera);
        errdefer camera.deinit(ui);

        const entities = try EntitySection.init(allocator, ui, root);

        return .{
            .root = root,
            .output = output,
            .camera = camera,
            .entities = entities,
        };
    }

    pub fn deinit(self: *Inspector, ui: *gui.Ui) void {
        self.entities.deinit(ui);
        self.camera.deinit(ui);
        self.output.deinit(ui);
        ui.destroySubtree(self.root);
        self.* = undefined;
    }

    /// Applies a frame of input to `scene`. Returns true when something the
    /// tracer reads has changed.
    pub fn update(self: *Inspector, ui: *gui.Ui, scene: *ray.Scene) !bool {
        var changed = try self.output.update(ui, scene);
        changed = try self.camera.update(ui, &scene.camera) or changed;
        changed = try self.entities.update(ui, scene) or changed;
        return changed;
    }
};

const OutputSection = struct {
    section: gui.Collapsible,
    width: controls.Count,
    height: controls.Count,
    samples: controls.Count,
    max_depth: controls.Count,

    const resolution_options: gui.NumericOptions = .{ .min = 16, .max = 7680, .step = 16 };
    const samples_options: gui.NumericOptions = .{ .min = 1, .max = 10_000, .step = 10 };
    const depth_options: gui.NumericOptions = .{ .min = 1, .max = 500, .step = 1 };

    fn init(
        allocator: std.mem.Allocator,
        ui: *gui.Ui,
        parent: gui.NodeId,
        scene: *const ray.Scene,
    ) !OutputSection {
        var section = try gui.Collapsible.init(ui, parent, "Output", .{});
        errdefer section.deinit(ui);
        const body = section.body();

        const size_row = try controls.row(ui, body, "Size");
        var width = try controls.Count.init(allocator, ui, size_row, scene.width, resolution_options);
        errdefer width.deinit(ui);
        var height = try controls.Count.init(allocator, ui, size_row, scene.height, resolution_options);
        errdefer height.deinit(ui);

        const samples_row = try controls.row(ui, body, "Samples");
        var samples = try controls.Count.init(
            allocator,
            ui,
            samples_row,
            scene.camera.samples_per_pixel,
            samples_options,
        );
        errdefer samples.deinit(ui);

        const depth_row = try controls.row(ui, body, "Bounces");
        const max_depth = try controls.Count.init(
            allocator,
            ui,
            depth_row,
            scene.camera.max_depth,
            depth_options,
        );

        return .{
            .section = section,
            .width = width,
            .height = height,
            .samples = samples,
            .max_depth = max_depth,
        };
    }

    fn deinit(self: *OutputSection, ui: *gui.Ui) void {
        self.max_depth.deinit(ui);
        self.samples.deinit(ui);
        self.height.deinit(ui);
        self.width.deinit(ui);
        self.section.deinit(ui);
        self.* = undefined;
    }

    fn update(self: *OutputSection, ui: *gui.Ui, scene: *ray.Scene) !bool {
        _ = try self.section.update(ui);

        var changed = try self.width.update(ui, &scene.width);
        changed = try self.height.update(ui, &scene.height) or changed;
        changed = try self.samples.update(ui, &scene.camera.samples_per_pixel) or changed;
        changed = try self.max_depth.update(ui, &scene.camera.max_depth) or changed;
        return changed;
    }
};

/// Where the camera stands, what it looks at, and how it focuses.
const CameraSection = struct {
    section: gui.Collapsible,
    lookfrom: controls.Vector,
    lookat: controls.Vector,
    vup: controls.Vector,
    vfov: controls.Scalar,
    defocus_angle: controls.Scalar,
    focus_dist: controls.Scalar,

    const position_options: gui.NumericOptions = .{ .step = 0.1 };
    const vfov_options: gui.NumericOptions = .{ .min = 1, .max = 179, .step = 1 };
    const defocus_options: gui.NumericOptions = .{ .min = 0, .max = 90, .step = 0.5 };
    const focus_options: gui.NumericOptions = .{ .min = 0.01, .max = 1000, .step = 0.1 };

    fn init(
        allocator: std.mem.Allocator,
        ui: *gui.Ui,
        parent: gui.NodeId,
        camera: *const ray.Camera.Settings,
    ) !CameraSection {
        var section = try gui.Collapsible.init(ui, parent, "Camera", .{});
        errdefer section.deinit(ui);
        const body = section.body();

        var lookfrom = try vectorRow(allocator, ui, body, "Position", camera.lookfrom, position_options);
        errdefer lookfrom.deinit(ui);
        var lookat = try vectorRow(allocator, ui, body, "Target", camera.lookat, position_options);
        errdefer lookat.deinit(ui);
        var vup = try vectorRow(allocator, ui, body, "Up", camera.vup, position_options);
        errdefer vup.deinit(ui);

        var vfov = try scalarRow(allocator, ui, body, "FOV", camera.vfov, vfov_options);
        errdefer vfov.deinit(ui);
        var defocus_angle = try scalarRow(allocator, ui, body, "Aperture", camera.defocus_angle, defocus_options);
        errdefer defocus_angle.deinit(ui);
        const focus_dist = try scalarRow(allocator, ui, body, "Focus", camera.focus_dist, focus_options);

        return .{
            .section = section,
            .lookfrom = lookfrom,
            .lookat = lookat,
            .vup = vup,
            .vfov = vfov,
            .defocus_angle = defocus_angle,
            .focus_dist = focus_dist,
        };
    }

    fn deinit(self: *CameraSection, ui: *gui.Ui) void {
        self.focus_dist.deinit(ui);
        self.defocus_angle.deinit(ui);
        self.vfov.deinit(ui);
        self.vup.deinit(ui);
        self.lookat.deinit(ui);
        self.lookfrom.deinit(ui);
        self.section.deinit(ui);
        self.* = undefined;
    }

    fn update(self: *CameraSection, ui: *gui.Ui, camera: *ray.Camera.Settings) !bool {
        _ = try self.section.update(ui);

        var changed = try self.lookfrom.update(ui, &camera.lookfrom);
        changed = try self.lookat.update(ui, &camera.lookat) or changed;
        changed = try self.vup.update(ui, &camera.vup) or changed;
        changed = try self.vfov.update(ui, &camera.vfov) or changed;
        changed = try self.defocus_angle.update(ui, &camera.defocus_angle) or changed;
        changed = try self.focus_dist.update(ui, &camera.focus_dist) or changed;
        return changed;
    }
};

const EntitySection = struct {
    allocator: std.mem.Allocator,
    section: gui.Collapsible,
    list: gui.NodeId,
    add_button: gui.NodeId,
    entities: std.ArrayList(Entity) = .empty,

    fn init(allocator: std.mem.Allocator, ui: *gui.Ui, parent: gui.NodeId) !EntitySection {
        var section = try gui.Collapsible.init(ui, parent, "Spheres", .{});
        errdefer section.deinit(ui);
        const body = section.body();

        const list = try gui.widgets.column(ui, body, .{
            .width = .fill,
            .height = .hug,
            .gap = ui.theme.space.sm,
        });
        const add_button = try controls.button(ui, body, "Add Sphere", .{
            .height = ui.theme.metrics.compact_control_height,
            .font_size = ui.theme.font.small,
            .background = .transparent,
            .foreground = .text_muted,
            .border = .stroke_soft,
        });

        return .{
            .allocator = allocator,
            .section = section,
            .list = list,
            .add_button = add_button,
        };
    }

    fn deinit(self: *EntitySection, ui: *gui.Ui) void {
        for (self.entities.items) |*entity| entity.deinit(ui);
        self.entities.deinit(self.allocator);
        self.section.deinit(ui);
        self.* = undefined;
    }

    fn update(self: *EntitySection, ui: *gui.Ui, scene: *ray.Scene) !bool {
        _ = try self.section.update(ui);
        try self.grow(ui, scene.spheres.items);

        var changed = false;
        var removed: ?usize = null;
        for (self.entities.items, scene.spheres.items, 0..) |*entity, *sphere, index| {
            const result = try entity.update(ui, sphere);
            changed = changed or result.changed;
            if (result.removed) {
                removed = index;
            }
        }

        if (removed) |index| {
            scene.remove(index);
            // Rows are bound by index, so every widget after the gap would
            // otherwise keep showing the value of the sphere it used to hold.
            try self.rebuild(ui, scene.spheres.items);
            return true;
        }

        if (ui.input.hovered == self.add_button) {
            ui.requestCursor(.hand);
        }
        if (ui.clicked(self.add_button)) {
            try scene.add(self.allocator, .{});
            try self.grow(ui, scene.spheres.items);
            return true;
        }

        return changed;
    }

    /// Brings the widget pool in line with the scene, building or tearing down
    /// only at the tail.
    fn grow(self: *EntitySection, ui: *gui.Ui, spheres: []const ray.SphereDesc) !void {
        while (self.entities.items.len > spheres.len) {
            var entity = self.entities.pop().?;
            entity.deinit(ui);
        }
        while (self.entities.items.len < spheres.len) {
            const index = self.entities.items.len;
            var entity = try Entity.init(self.allocator, ui, self.list, index, spheres[index]);
            errdefer entity.deinit(ui);
            try self.entities.append(self.allocator, entity);
        }
    }

    fn rebuild(self: *EntitySection, ui: *gui.Ui, spheres: []const ray.SphereDesc) !void {
        try self.grow(ui, &.{});
        try self.grow(ui, spheres);
    }
};

const Entity = struct {
    section: gui.Collapsible,
    center: controls.Vector,
    radius: controls.Scalar,
    kind: controls.Segmented,
    albedo: controls.Color,
    albedo_row: gui.NodeId,
    fuzz: controls.Scalar,
    fuzz_row: gui.NodeId,
    refraction_index: controls.Scalar,
    refraction_row: gui.NodeId,
    remove_button: gui.NodeId,
    shown_kind: ray.MaterialKind,

    const Result = struct {
        changed: bool = false,
        removed: bool = false,
    };

    const center_options: gui.NumericOptions = .{ .step = 0.1 };
    const radius_options: gui.NumericOptions = .{ .min = 0, .max = 10_000, .step = 0.1 };
    const fuzz_options: gui.NumericOptions = .{ .min = 0, .max = 1, .step = 0.05 };
    const refraction_options: gui.NumericOptions = .{ .min = 0.1, .max = 4, .step = 0.05 };

    fn init(
        allocator: std.mem.Allocator,
        ui: *gui.Ui,
        parent: gui.NodeId,
        index: usize,
        sphere: ray.SphereDesc,
    ) !Entity {
        var title_buf: [32]u8 = undefined;
        const title = try std.fmt.bufPrint(&title_buf, "Sphere {d}", .{index + 1});

        var section = try gui.Collapsible.init(ui, parent, title, .{
            .initially_expanded = false,
            .surface = .panel_soft,
        });
        errdefer section.deinit(ui);
        const body = section.body();

        var center = try vectorRow(allocator, ui, body, "Position", sphere.center, center_options);
        errdefer center.deinit(ui);
        var radius = try scalarRow(allocator, ui, body, "Radius", sphere.radius, radius_options);
        errdefer radius.deinit(ui);

        const kind_row = try controls.row(ui, body, "Material");
        var kind = try controls.Segmented.init(allocator, ui, kind_row, &ray.material_kind_names);
        errdefer kind.deinit(ui);

        const albedo_row = try controls.row(ui, body, "Albedo");
        var albedo = try controls.Color.init(allocator, ui, albedo_row, sphere.material.albedo);
        errdefer albedo.deinit(ui);

        const fuzz_row = try controls.row(ui, body, "Fuzz");
        var fuzz = try controls.Scalar.init(allocator, ui, fuzz_row, sphere.material.fuzz, fuzz_options);
        errdefer fuzz.deinit(ui);

        const refraction_row = try controls.row(ui, body, "IOR");
        var refraction_index = try controls.Scalar.init(
            allocator,
            ui,
            refraction_row,
            sphere.material.refraction_index,
            refraction_options,
        );
        errdefer refraction_index.deinit(ui);

        const remove_button = try controls.button(ui, body, "Remove", .{
            .height = ui.theme.metrics.compact_control_height,
            .font_size = ui.theme.font.small,
            .background = .transparent,
            .foreground = .danger,
            .border = .stroke_soft,
        });

        var entity: Entity = .{
            .section = section,
            .center = center,
            .radius = radius,
            .kind = kind,
            .albedo = albedo,
            .albedo_row = albedo_row,
            .fuzz = fuzz,
            .fuzz_row = fuzz_row,
            .refraction_index = refraction_index,
            .refraction_row = refraction_row,
            .remove_button = remove_button,
            .shown_kind = sphere.material.kind,
        };
        try entity.applyKind(ui, sphere.material.kind);
        return entity;
    }

    fn deinit(self: *Entity, ui: *gui.Ui) void {
        self.refraction_index.deinit(ui);
        self.fuzz.deinit(ui);
        self.albedo.deinit(ui);
        self.kind.deinit(ui);
        self.radius.deinit(ui);
        self.center.deinit(ui);
        self.section.deinit(ui);
        self.* = undefined;
    }

    fn update(self: *Entity, ui: *gui.Ui, sphere: *ray.SphereDesc) !Result {
        _ = try self.section.update(ui);

        var changed = try self.center.update(ui, &sphere.center);
        changed = try self.radius.update(ui, &sphere.radius) or changed;

        const material = &sphere.material;
        if (try self.kind.update(ui, @intFromEnum(material.kind))) |picked| {
            material.kind = @enumFromInt(picked);
            changed = true;
        }
        if (self.shown_kind != material.kind) {
            try self.applyKind(ui, material.kind);
        }

        switch (material.kind) {
            .lambertian => {
                changed = try self.albedo.update(ui, &material.albedo) or changed;
            },
            .metal => {
                changed = try self.albedo.update(ui, &material.albedo) or changed;
                changed = try self.fuzz.update(ui, &material.fuzz) or changed;
            },
            .dielectric => {
                changed = try self.refraction_index.update(ui, &material.refraction_index) or changed;
            },
        }

        if (ui.input.hovered == self.remove_button) {
            ui.requestCursor(.hand);
        }
        return .{ .changed = changed, .removed = ui.clicked(self.remove_button) };
    }

    fn applyKind(self: *Entity, ui: *gui.Ui, kind: ray.MaterialKind) !void {
        try ui.setVisible(self.albedo_row, kind.tintsLight());
        try ui.setVisible(self.fuzz_row, kind == .metal);
        try ui.setVisible(self.refraction_row, kind == .dielectric);
        self.shown_kind = kind;
    }
};

fn vectorRow(
    allocator: std.mem.Allocator,
    ui: *gui.Ui,
    parent: gui.NodeId,
    name: []const u8,
    value: v.Vec3,
    options: gui.NumericOptions,
) !controls.Vector {
    return controls.Vector.init(allocator, ui, try controls.row(ui, parent, name), value, options);
}

fn scalarRow(
    allocator: std.mem.Allocator,
    ui: *gui.Ui,
    parent: gui.NodeId,
    name: []const u8,
    value: f64,
    options: gui.NumericOptions,
) !controls.Scalar {
    return controls.Scalar.init(allocator, ui, try controls.row(ui, parent, name), value, options);
}
