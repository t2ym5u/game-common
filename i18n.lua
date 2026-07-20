-- i18n.lua — Plugin translation module
--
-- Drop-in replacement for `local _ = require("gettext")` in plugin screens.
-- Priority: custom table → KOReader gettext → original string.
--
-- To add a language, extend each entry:
--   ["English key"] = { fr = "Traduction", de = "Übersetzung", es = "Traducción" }
--
-- Usage:
--   local _ = require("i18n")   -- works exactly like _() from gettext
--   local i18n = require("i18n")
--   i18n.lang()                  -- returns "fr", "en", etc.
--
-- Plugin-owned translations:
--   Only strings genuinely shared by several plugins belong in the table
--   below. A plugin's own UI strings should live in that plugin's own
--   `i18n_fr.lua` (returning the same `{ ["key"] = { fr = "..." } }` shape)
--   and get merged in from main.lua:
--     require("i18n").extend(lrequire("i18n_fr"))

local koreader_t = require("gettext")

local function lang()
    return (G_reader_settings and G_reader_settings:readSetting("language") or "en"):sub(1, 2)
end

-- ---------------------------------------------------------------------------
-- Translation table
-- Key   = English source string (as written in _("...") calls)
-- Value = table mapping language code → translated string
-- ---------------------------------------------------------------------------
local S = {

    -- -----------------------------------------------------------------------
    -- Common buttons
    -- -----------------------------------------------------------------------
    ["New game"]    = { fr = "Nouvelle partie" },
    ["New"]         = { fr = "Nouveau" },
    ["Close"]       = { fr = "Fermer" },
    ["Rules"]       = { fr = "Règles" },
    ["Check"]       = { fr = "Vérifier" },
    ["Undo"]        = { fr = "Annuler" },
    ["Erase"]       = { fr = "Effacer" },
    ["Clear"]       = { fr = "Effacer tout" },
    ["Reveal"]      = { fr = "Révéler" },
    ["Solve"]       = { fr = "Résoudre" },
    ["Submit"]      = { fr = "Valider" },
    ["Validate"]    = { fr = "Valider" },
    ["Roll dice"]   = { fr = "Lancer les dés" },
    ["Show"]        = { fr = "Afficher" },
    ["Hide"]        = { fr = "Masquer" },
    ["Done"]        = { fr = "Terminé" },
    ["Settings"]    = { fr = "Réglages" },
    ["Show result"] = { fr = "Voir la solution" },
    ["Hide result"] = { fr = "Masquer la solution" },

    -- -----------------------------------------------------------------------
    -- Note / Flag / Fill modes
    -- -----------------------------------------------------------------------
    ["Note: On"]    = { fr = "Notes : actif" },
    ["Note: Off"]   = { fr = "Notes : inactif" },
    ["Note: ON"]    = { fr = "Notes : ON" },
    ["Note: OFF"]   = { fr = "Notes : OFF" },

    -- -----------------------------------------------------------------------
    -- Difficulty levels
    -- -----------------------------------------------------------------------
    ["Easy"]    = { fr = "Facile" },
    ["Medium"]  = { fr = "Moyen" },
    ["Hard"]    = { fr = "Difficile" },
    ["Expert"]  = { fr = "Expert" },

    -- -----------------------------------------------------------------------
    -- Directions (crossword / kakuro)
    -- -----------------------------------------------------------------------

    -- -----------------------------------------------------------------------
    -- Menus
    -- -----------------------------------------------------------------------
    ["Select difficulty"]   = { fr = "Choisir la difficulté" },
    ["Select grid size"]    = { fr = "Choisir la taille de la grille" },
    ["Language"]            = { fr = "Langue" },
    ["English"]             = { fr = "Anglais" },
    ["Difficulty"]          = { fr = "Difficulté" },
    ["Grid size"]           = { fr = "Taille de la grille" },
    ["Auto-save"]           = { fr = "Sauvegarde automatique" },
    ["Gameplay"]            = { fr = "Jeu" },
    ["Game"]                = { fr = "Jeu" },
    ["Time"]                = { fr = "Temps" },
    ["Size: %1"]            = { fr = "Taille : %1" },
    ["Grid: %1"]            = { fr = "Grille : %1" },
    ["Diff: %1"]            = { fr = "Difficulté : %1" },
    ["Difficulty: %1"]      = { fr = "Difficulté : %1" },
    ["On"]                  = { fr = "Actif" },
    ["Off"]                 = { fr = "Inactif" },
    ["Select"]              = { fr = "Sélectionner" },
    ["Select size"]         = { fr = "Choisir la taille" },

    -- -----------------------------------------------------------------------
    -- Common status — victories
    -- -----------------------------------------------------------------------
    ["Congratulations! Puzzle solved."]       = { fr = "Félicitations ! Puzzle résolu." },
    ["Congratulations! Puzzle solved!"]       = { fr = "Félicitations ! Puzzle résolu !" },
    ["Puzzle solved!"]                        = { fr = "Puzzle résolu !" },
    ["Puzzle complete!"]                      = { fr = "Puzzle terminé !" },
    ["Puzzle %1 solved!"]                     = { fr = "Puzzle %1 résolu !" },

    -- -----------------------------------------------------------------------
    -- Common status — errors / validation
    -- -----------------------------------------------------------------------
    ["Keep going!"]                          = { fr = "Continuez !" },
    ["No errors found!"]                     = { fr = "Aucune erreur trouvée !" },
    ["No violations found so far."]          = { fr = "Aucune violation pour l'instant." },
    ["Everything looks good!"]               = { fr = "Tout est correct !" },
    ["Some cells are incorrect."]            = { fr = "Certaines cases sont incorrectes." },
    ["Some cells have errors."]              = { fr = "Certaines cases contiennent des erreurs." },
    ["Wrong cells marked."]                  = { fr = "Cases incorrectes marquées." },
    ["Check: %1 violation(s) found."]        = { fr = "Vérification : %1 violation(s) trouvée(s)." },
    ["Check done. %1 cell(s) remaining."]    = { fr = "Vérification effectuée. %1 case(s) restante(s)." },
    ["Check done. Empty: %1"]               = { fr = "Vérification effectuée. Vides : %1" },
    ["Checking…"]                            = { fr = "Vérification…" },

    -- -----------------------------------------------------------------------
    -- Common status — undo / moves
    -- -----------------------------------------------------------------------
    ["Last move undone."]       = { fr = "Dernier coup annulé." },
    ["Nothing to undo."]        = { fr = "Rien à annuler." },
    ["Invalid move."]           = { fr = "Coup invalide." },
    ["Board cleared."]          = { fr = "Plateau effacé." },
    ["New game started."]       = { fr = "Nouvelle partie lancée." },
    ["Started a %1 game."]      = { fr = "Partie %1 lancée." },

    -- -----------------------------------------------------------------------
    -- Common status — game over
    -- -----------------------------------------------------------------------

    -- -----------------------------------------------------------------------
    -- Common status — cells / selection
    -- -----------------------------------------------------------------------
    ["Cannot edit a given cell."]                = { fr = "Impossible de modifier une case donnée." },
    ["Tap a cell first."]                        = { fr = "Appuyez d'abord sur une case." },
    ["Cell %1,%2 selected."]                     = { fr = "Case %1,%2 sélectionnée." },
    ["Selected: %1,%2  ·  Empty cells: %3"]      = { fr = "Sélection : %1,%2  ·  Cases vides : %3" },
    ["Selected: %1,%2  \xC2\xB7  Empty cells: %3"] = { fr = "Sélection : %1,%2  ·  Cases vides : %3" },

    -- -----------------------------------------------------------------------
    -- Common status — solution display
    -- -----------------------------------------------------------------------
    ["Solution shown."]                          = { fr = "Solution affichée." },
    ["Solution revealed."]                       = { fr = "Solution révélée." },
    ["Showing the solution."]                    = { fr = "Affichage de la solution." },
    ["Solution is shown; editing is disabled."]  = { fr = "Solution affichée ; modification désactivée." },
    ["Result is being shown; editing is disabled."] = { fr = "Résultat affiché ; modification désactivée." },

    -- -----------------------------------------------------------------------
    -- Board error messages (board.lua)
    -- -----------------------------------------------------------------------
    ["Clear the cell before adding notes."] = { fr = "Effacez la case avant d'ajouter des notes." },

    -- -----------------------------------------------------------------------
    -- Note mode status
    -- -----------------------------------------------------------------------
    ["Note mode enabled."]   = { fr = "Mode notes activé." },
    ["Note mode disabled."]  = { fr = "Mode notes désactivé." },
    ["Note mode is ON."]     = { fr = "Mode notes : ACTIF." },

    -- -----------------------------------------------------------------------
    -- Word games (Boggle, Anagram, Wordle, Wordsearch, Hangman, Cryptogram)
    -- -----------------------------------------------------------------------
    ["Not enough letters!"]               = { fr = "Pas assez de lettres !" },
    ["Lost! Word: %1  W:%2 L:%3"]         = { fr = "Perdu ! Mot : %1  V:%2 D:%3" },
    ["Entering: %1 (tap another digit or Erase)"] = { fr = "Saisie : %1 (autre chiffre ou Effacer)" },

    -- -----------------------------------------------------------------------
    -- Fillomino / Hidato / Numbrix (shared grid-status template)
    -- -----------------------------------------------------------------------
    ["Value %1 out of range (1-%2)."] = { fr = "Valeur %1 hors plage (1-%2)." },
    ["%1\xC3\x97%2 \xC2\xB7 %3 \xC2\xB7 Empty: %4"] = { fr = "%1×%2 · %3 · Vides : %4" },
    ["  \xC2\xB7 Empty: %1"]           = { fr = "  · Vides : %1" },

    -- -----------------------------------------------------------------------
    -- Pickomino (dice game)
    -- -----------------------------------------------------------------------
    ["Roll the dice first."]             = { fr = "Lancez les dés d'abord." },

    -- -----------------------------------------------------------------------
    -- Gomoku / Othello (player-specific messages already in FR for some)
    -- -----------------------------------------------------------------------
    ["%1/%2"]                        = { fr = "%1/%2" },

    -- -----------------------------------------------------------------------
    -- Cave / Path games (Hitori / Nurikabe)
    -- -----------------------------------------------------------------------
    ["%1\xC3\x97%2 \xC2\xB7 %3 \xC2\xB7 Unknown: %4"] = { fr = "%1×%2 · %3 · Inconnues : %4" },

    -- -----------------------------------------------------------------------
    -- KenKen / Cages / Killer Sudoku
    --
    -- sudokukiller.koplugin is sudoku_common-family (vendors its own
    -- common/), not game-common-family, so it has no reliable package.path
    -- to this module and can't use i18n.extend() — its strings stay here.
    -- -----------------------------------------------------------------------
    ["  \xC2\xB7 Cage: %1/%2 cells, sum %3/%4"] = { fr = "  · Cage : %1/%2 cases, somme %3/%4" },

    -- -----------------------------------------------------------------------
    -- Generic settings / skeleton placeholders (remove in real plugins)
    -- -----------------------------------------------------------------------
    ["My Game v1.0"]          = { fr = "Mon Jeu v1.0" },
    ["My Game — Settings"]    = { fr = "Mon Jeu — Réglages" },

    -- -----------------------------------------------------------------------
    -- Dashboard / Binairo (orphaned or shared with other plugins)
    -- -----------------------------------------------------------------------
    ["Home button → Dashboard"]              = { fr = "Bouton Home → Dashboard" },
    ["Binairo — Settings"]                   = { fr = "Binairo — Réglages" },

    -- -----------------------------------------------------------------------
    -- Misc status messages
    -- -----------------------------------------------------------------------
    ["%1/%2"]                        = { fr = "%1/%2" },
    ["Roll"]                         = { fr = "Lancer" },
}

-- ---------------------------------------------------------------------------
-- Public API
-- ---------------------------------------------------------------------------

local function translate(s)
    local l = lang()
    if l ~= "en" then
        local entry = S[s]
        if entry and entry[l] then return entry[l] end
    end
    return koreader_t(s)
end

-- Merge a plugin-owned translation table (same shape as S) into the shared
-- table. `require("i18n")` is cached process-wide by Lua's module loader, so
-- calling this once from a plugin's main.lua makes its strings available
-- everywhere for the rest of the KOReader session.
local function extend(tbl)
    for k, v in pairs(tbl) do
        S[k] = v
    end
end

-- Allow `local _ = require("i18n")` — callable as _("string")
-- Also expose:  require("i18n").lang()   — current 2-letter language code
--               require("i18n").extend(tbl) — merge in plugin-owned strings
return setmetatable({ lang = lang, extend = extend }, {
    __call = function(_, s) return translate(s) end,
})
