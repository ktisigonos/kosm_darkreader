# kosm_darkreader

Dark Reader for kosm: its theme colors and font.

Dark Reader keeps its live settings in the browser's extension storage, which nothing outside
the browser can write safely. So the app edits a settings file Dark Reader exported, and you
import that file again:

1. Once: in Dark Reader, Settings > Advanced > Export Settings, saved as
   `~/.config/darkreader/Dark-Reader-Settings.json` (or set `file`).
2. After an apply that changed it: Settings > Advanced > Import Settings, picking the same file.

Only the values you set change in the file; every other setting stays as exported, byte for
byte. A missing export fails the apply and says how to make one. `kosm_darkreader.App{}` sets
nothing and needs no export.

## Fields

| Field | Default |
|---|---|
| `file` | `~/.config/darkreader/Dark-Reader-Settings.json` |
| `format` | `.{}`: the JSON adapter's, then `#rrggbb` |
| `theme.dark_scheme_background_color` | null: left as exported; `from`: black |
| `theme.dark_scheme_text_color` | null; `from`: white |
| `theme.light_scheme_background_color` | null; `from`: white |
| `theme.light_scheme_text_color` | null; `from`: black |
| `theme.scrollbar_color` | null; `from`: the theme's `lightness.bright` of the foreground role |
| `theme.selection_color` | null; `from`: the theme's `state.selected` of the background role |
| `theme.use_font` | null: whether every page is shown in `theme.font_family` |
| `theme.font_family` | null |
| `extra` | `&.{}`: any other setting by its path in the export, e.g. `theme.brightness`; the export must already hold it |

The package brings the `json` adapter of `kosm_json` along (`kosm_darkreader.json_adapter`), so a
config needs only `kosm_darkreader`.
