-- game_common_version.lua — this copy of game-common: its version and the
-- shared modules it provides by name. Read by module_guard.lua (by path),
-- which uses it to make sure no plugin runs on modules older than its own.
--
-- Bump `version` with every release (it must match CHANGELOG.md's top entry,
-- test_module_guard_spec.lua checks), and list every new module in `modules`
-- (the spec checks the list against the directory too).
return {
    lib     = "game-common",
    version = "1.15.0",
    modules = {
        "daily_seed", "game_categories", "games_menu", "gen_progress",
        "grid_utils", "grid_widget_base", "hint", "i18n", "keyboard_widget",
        "menu_helper", "party", "plugin_base", "score_tracker", "screen_base",
        "seen_history", "settings_dialog", "stats_exporter", "timer",
        "undo_stack",
    },
    -- Also shipped, verbatim, by sudoku-common: its copy is as good as ours.
    shared = { stats_exporter = true },
}
