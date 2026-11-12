//! Dark Reader's theme, set in a settings file Dark Reader exported. The extension keeps its
//! live settings in the browser's own storage, which nothing outside the browser can write
//! safely, so the app edits the export and the user imports it. Only the set values change;
//! every other setting in the file stays as exported.

const App = @This();

const std = @import("std");
const kosm = @import("kosm");

/// The export to edit, made once with Dark Reader's Settings > Advanced > Export Settings.
/// Default: `~/.config/darkreader/Dark-Reader-Settings.json`.
file: []const u8 = "~/.config/darkreader/Dark-Reader-Settings.json",
/// How values are spelled. Null fields take the JSON adapter's, then kosm's `#rrggbb`.
format: kosm.Format = .{},
/// Dark Reader's `theme` settings.
theme: Theme = .{},
/// Settings the app doesn't cover, by their path in the export:
/// `.{ .path = "theme.brightness", .value = .{ .integer = 110 } }`. The export must hold the
/// path already. Default: none.
extra: []const kosm.Setting = &.{},

/// The `theme` object of Dark Reader's settings. Field names are Dark Reader's, in Zig casing;
/// null leaves the exported value alone.
pub const Theme = struct {
    /// `darkSchemeBackgroundColor`: page backgrounds in the dark scheme. `from`: black.
    dark_scheme_background_color: ?kosm.Color = null,
    /// `darkSchemeTextColor`: page text in the dark scheme. `from`: white.
    dark_scheme_text_color: ?kosm.Color = null,
    /// `lightSchemeBackgroundColor`: page backgrounds in the light scheme. `from`: white.
    light_scheme_background_color: ?kosm.Color = null,
    /// `lightSchemeTextColor`: page text in the light scheme. `from`: black.
    light_scheme_text_color: ?kosm.Color = null,
    /// `scrollbarColor`: scrollbars. `from`: the theme's `lightness.bright` of the foreground.
    scrollbar_color: ?kosm.Color = null,
    /// `selectionColor`: the background of selected text. `from`: the theme's `state.selected`
    /// of the background.
    selection_color: ?kosm.Color = null,
    /// `useFont`: show every page in `font_family`.
    use_font: ?bool = null,
    /// `fontFamily`: the font pages are shown in while `use_font` is on.
    font_family: ?[]const u8 = null,
};

/// Colors from the theme: each scheme's background and text from black and white, and the
/// scrollbar and selection from the foreground and background roles. The font is left alone.
pub fn from(theme: kosm.Theme) App {
    const palette = theme.palette;
    const foreground = theme.roles.foreground;
    const background = theme.roles.background;
    return .{ .theme = .{
        .dark_scheme_background_color = palette.black,
        .dark_scheme_text_color = palette.white,
        .light_scheme_background_color = palette.white,
        .light_scheme_text_color = palette.black,
        .scrollbar_color = theme.variations.lightness.bright.apply(foreground),
        .selection_color = theme.variations.state.selected.apply(background),
    } };
}

/// Sets every set value, then the extras, in the export. With nothing set, the file is not
/// looked for. A missing export fails the apply, saying how to make one.
pub fn apply(self: App, output: *kosm.Output) !void {
    var settings: std.ArrayList(kosm.Setting) = .empty;
    const fields = @typeInfo(Theme).@"struct";
    inline for (fields.field_names, fields.field_types) |name, Field| {
        if (@field(self.theme, name)) |value| try settings.append(output.allocator, .{
            .path = "theme." ++ comptime camelCase(name),
            .value = switch (@typeInfo(Field).optional.child) {
                kosm.Color => .{ .color = value },
                bool => .{ .boolean = value },
                []const u8 => .{ .string = value },
                else => comptime unreachable,
            },
        });
    }
    try settings.appendSlice(output.allocator, self.extra);
    if (settings.items.len == 0) return;

    var selection = output.edit(.{ .files = self.file, .lang = "json", .format = self.format }) catch |err| switch (err) {
        error.NoFile => return output.fail(self.file, "does not exist; export Dark Reader's settings to it once (Settings > Advanced > Export Settings), then import it again after each apply", .{}),
        else => |other| return other,
    };
    for (settings.items) |setting| try selection.set(setting.path, setting.value);
}

/// `dark_scheme_text_color` as Dark Reader spells it: `darkSchemeTextColor`.
fn camelCase(comptime snake: []const u8) []const u8 {
    comptime var camel: []const u8 = "";
    comptime var upper = false;
    inline for (snake) |character| {
        if (character == '_') {
            upper = true;
            continue;
        }
        camel = camel ++ &[_]u8{if (upper) std.ascii.toUpper(character) else character};
        upper = false;
    }
    return camel;
}

const testing = std.testing;
const json = @import("kosm_json");

const Fixture = struct {
    tmp: testing.TmpDir,
    arena: std.heap.ArenaAllocator,
    plan: kosm.Plan,
    diagnostics: kosm.Diagnostics = .{},
    warnings: kosm.Warnings = undefined,
    home_buffer: [std.Io.Dir.max_path_bytes]u8 = undefined,
    output: kosm.Output = undefined,

    /// `export_file` is what the export holds; null leaves it missing.
    fn init(fixture: *Fixture, export_file: ?[]const u8) !void {
        fixture.* = .{ .tmp = testing.tmpDir(.{}), .arena = .init(testing.allocator), .plan = .init(testing.allocator, testing.io) };
        if (export_file) |text| {
            try fixture.tmp.dir.createDirPath(testing.io, ".config/darkreader");
            try fixture.tmp.dir.writeFile(testing.io, .{ .sub_path = ".config/darkreader/Dark-Reader-Settings.json", .data = text });
        }
        fixture.warnings = .init(fixture.arena.allocator());
        const length = try fixture.tmp.dir.realPath(testing.io, &fixture.home_buffer);
        fixture.output = .{
            .allocator = fixture.arena.allocator(),
            .home = fixture.home_buffer[0..length],
            .adapters = &.{json.adapter},
            .plan = &fixture.plan,
            .diagnostics = &fixture.diagnostics,
            .warnings = &fixture.warnings,
            .app = "darkreader",
        };
    }

    fn deinit(fixture: *Fixture) void {
        fixture.plan.deinit();
        fixture.arena.deinit();
        fixture.tmp.cleanup();
    }
};

/// The start of a real export, as Dark Reader writes it.
const exported =
    \\{
    \\    "schemeVersion": 2,
    \\    "enabled": true,
    \\    "theme": {
    \\        "mode": 1,
    \\        "brightness": 100,
    \\        "useFont": true,
    \\        "fontFamily": "system-ui",
    \\        "darkSchemeBackgroundColor": "#181a1b",
    \\        "darkSchemeTextColor": "#e8e6e3",
    \\        "lightSchemeBackgroundColor": "#dcdad7",
    \\        "lightSchemeTextColor": "#181a1b",
    \\        "scrollbarColor": "",
    \\        "selectionColor": "auto"
    \\    },
    \\    "syncSettings": true
    \\}
    \\
;

const test_theme = kosm.Theme.from(.{ .palette = .{ .black = kosm.hex("041c26"), .white = kosm.hex("a3c5cc") }, .mode = .dark });

test "from sets both schemes' colors in the export and leaves every other setting as exported" {
    var fixture: Fixture = undefined;
    try fixture.init(exported);
    defer fixture.deinit();
    var app = from(test_theme);
    app.theme.scrollbar_color = kosm.hex("b7dce5");
    app.theme.selection_color = kosm.hex("082e3f");
    app.theme.font_family = "Maple Mono";
    app.extra = &.{.{ .path = "theme.brightness", .value = .{ .integer = 110 } }};
    try app.apply(&fixture.output);
    try testing.expectEqualStrings(
        \\{
        \\    "schemeVersion": 2,
        \\    "enabled": true,
        \\    "theme": {
        \\        "mode": 1,
        \\        "brightness": 110,
        \\        "useFont": true,
        \\        "fontFamily": "Maple Mono",
        \\        "darkSchemeBackgroundColor": "#041c26",
        \\        "darkSchemeTextColor": "#a3c5cc",
        \\        "lightSchemeBackgroundColor": "#a3c5cc",
        \\        "lightSchemeTextColor": "#041c26",
        \\        "scrollbarColor": "#b7dce5",
        \\        "selectionColor": "#082e3f"
        \\    },
        \\    "syncSettings": true
        \\}
        \\
    , fixture.plan.files.items[0].new);
}

test "a missing export fails the apply, naming the file and how to make it" {
    var fixture: Fixture = undefined;
    try fixture.init(null);
    defer fixture.deinit();
    try testing.expectError(error.AppFailed, from(test_theme).apply(&fixture.output));
    try testing.expectEqualStrings("~/.config/darkreader/Dark-Reader-Settings.json", fixture.diagnostics.file);
    try testing.expectStringStartsWith(fixture.diagnostics.message(), "does not exist; export Dark Reader's settings to it once");
    try testing.expectEqual(0, fixture.plan.files.items.len);
}

test "App{} sets nothing, so it needs no export, and a setting the export lacks fails naming it" {
    var fixture: Fixture = undefined;
    try fixture.init(null);
    defer fixture.deinit();
    const empty: App = .{};
    try empty.apply(&fixture.output);
    try testing.expectEqual(0, fixture.plan.files.items.len);

    var other: Fixture = undefined;
    try other.init("{ \"theme\": { \"mode\": 1 } }\n");
    defer other.deinit();
    const app: App = .{ .theme = .{ .use_font = false } };
    try testing.expectError(error.NoMatch, app.apply(&other.output));
    try testing.expect(std.mem.find(u8, other.diagnostics.message(), "theme.useFont") != null);
}
