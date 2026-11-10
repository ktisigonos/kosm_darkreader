//! Dark Reader: its theme colors and font, set in the settings file Dark Reader exports and imports.

const std = @import("std");

/// Dark Reader's theme; build one with `from`.
pub const App = @import("App.zig");
/// Colors from the theme.
pub const from = App.from;
/// The adapter the app edits the export with, so a config needs only this package.
pub const json_adapter = @import("kosm_json").adapter;

test {
    std.testing.refAllDecls(@This());
    std.testing.refAllDecls(App);
}
