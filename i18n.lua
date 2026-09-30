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
    ["New game"]    = { fr = "Nouvelle partie", es = "Nueva partida", de = "Neues Spiel" },
    ["New"]         = { fr = "Nouveau", es = "Nuevo", de = "Neu" },
    ["Close"]       = { fr = "Fermer", es = "Cerrar", de = "Schließen" },
    ["Rules"]       = { fr = "Règles", es = "Reglas", de = "Regeln" },
    ["Check"]       = { fr = "Vérifier", es = "Comprobar", de = "Prüfen" },
    ["Hint"]        = { fr = "Astuce", es = "Pista", de = "Tipp" },
    ["Undo"]        = { fr = "Annuler", es = "Deshacer", de = "Rückgängig" },
    ["Erase"]       = { fr = "Effacer", es = "Borrar", de = "Löschen" },
    ["Clear"]       = { fr = "Effacer tout", es = "Borrar todo", de = "Alles löschen" },

    -- Hint button (common/screen_base.lua :onHint). R/C are row/column,
    -- localised to L/C in French and Z/S in German.
    ["Hints are not available here."] = { fr = "Les astuces ne sont pas disponibles ici.", es = "Aquí no hay pistas disponibles.", de = "Hier gibt es keine Tipps." },
    ["No hint is available here."] = { fr = "Aucune astuce n'est disponible ici.", es = "Aquí no hay ninguna pista disponible.", de = "Hier ist kein Tipp verfügbar." },
    ["Nothing left to fill in."] = { fr = "Il ne reste rien à remplir.", es = "No queda nada por rellenar.", de = "Es ist nichts mehr auszufüllen." },
    ["Hide the solution to keep playing."] = { fr = "Masquez la solution pour continuer à jouer.", es = "Oculte la solución para seguir jugando.", de = "Lösung ausblenden, um weiterzuspielen." },
    ["R%1C%2 is wrong. Tap Hint again to clear it."] = { fr = "L%1C%2 est incorrecte. Touchez à nouveau Astuce pour l'effacer.", es = "F%1C%2 es incorrecta. Toque Pista otra vez para borrarla.", de = "Z%1S%2 ist falsch. Tippen Sie erneut auf Tipp, um sie zu leeren." },
    ["R%1C%2 can be worked out. Tap Hint again to fill it in."] = { fr = "L%1C%2 peut être déduite. Touchez à nouveau Astuce pour la remplir.", es = "F%1C%2 se puede deducir. Toque Pista otra vez para rellenarla.", de = "Z%1S%2 lässt sich herleiten. Tippen Sie erneut auf Tipp, um sie zu füllen." },
    ["Cleared R%1C%2."] = { fr = "L%1C%2 effacée.", es = "F%1C%2 borrada.", de = "Z%1S%2 geleert." },
    ["Filled in R%1C%2."] = { fr = "L%1C%2 remplie.", es = "F%1C%2 rellenada.", de = "Z%1S%2 gefüllt." },
    ["Cleared R%1C%2. Hints used: %3."] = { fr = "L%1C%2 effacée. Astuces utilisées : %3.", es = "F%1C%2 borrada. Pistas usadas: %3.", de = "Z%1S%2 geleert. Verwendete Tipps: %3." },
    ["%1 Hints used: %2."] = { fr = "%1 Astuces utilisées : %2.", es = "%1 Pistas usadas: %2.", de = "%1 Verwendete Tipps: %2." },
    ["Filled in R%1C%2. Hints used: %3."] = { fr = "L%1C%2 remplie. Astuces utilisées : %3.", es = "F%1C%2 rellenada. Pistas usadas: %3.", de = "Z%1S%2 gefüllt. Verwendete Tipps: %3." },
    ["Reveal"]      = { fr = "Révéler", es = "Revelar", de = "Aufdecken" },
    ["Solve"]       = { fr = "Résoudre", es = "Resolver", de = "Lösen" },
    ["Submit"]      = { fr = "Valider", es = "Enviar", de = "Bestätigen" },
    ["Validate"]    = { fr = "Valider", es = "Validar", de = "Bestätigen" },
    ["Roll dice"]   = { fr = "Lancer les dés", es = "Lanzar dados", de = "Würfeln" },
    ["Show"]        = { fr = "Afficher", es = "Mostrar", de = "Anzeigen" },
    ["Hide"]        = { fr = "Masquer", es = "Ocultar", de = "Ausblenden" },
    ["Done"]        = { fr = "Terminé", es = "Hecho", de = "Fertig" },
    ["Settings"]    = { fr = "Réglages", es = "Ajustes", de = "Einstellungen" },
    ["Show result"] = { fr = "Voir la solution", es = "Ver la solución", de = "Lösung anzeigen" },
    ["Hide result"] = { fr = "Masquer la solution", es = "Ocultar la solución", de = "Lösung ausblenden" },

    -- -----------------------------------------------------------------------
    -- Note / Flag / Fill modes
    -- -----------------------------------------------------------------------
    ["Note: On"]    = { fr = "Notes : actif", es = "Notas: activadas", de = "Notizen: an" },
    ["Note: Off"]   = { fr = "Notes : inactif", es = "Notas: desactivadas", de = "Notizen: aus" },
    ["Note: ON"]    = { fr = "Notes : ON", es = "Notas: ON", de = "Notizen: AN" },
    ["Note: OFF"]   = { fr = "Notes : OFF", es = "Notas: OFF", de = "Notizen: AUS" },

    -- -----------------------------------------------------------------------
    -- Difficulty levels
    -- -----------------------------------------------------------------------
    ["Easy"]    = { fr = "Facile", es = "Fácil", de = "Leicht" },
    ["Medium"]  = { fr = "Moyen", es = "Medio", de = "Mittel" },
    ["Hard"]    = { fr = "Difficile", es = "Difícil", de = "Schwer" },
    ["Expert"]  = { fr = "Expert", es = "Experto", de = "Experte" },

    -- -----------------------------------------------------------------------
    -- Directions (crossword / kakuro)
    -- -----------------------------------------------------------------------

    -- -----------------------------------------------------------------------
    -- Menus
    -- -----------------------------------------------------------------------
    ["Select difficulty"]   = { fr = "Choisir la difficulté", es = "Elegir la dificultad", de = "Schwierigkeit wählen" },
    ["Select grid size"]    = { fr = "Choisir la taille de la grille", es = "Elegir el tamaño de la cuadrícula", de = "Rastergröße wählen" },
    ["Language"]            = { fr = "Langue", es = "Idioma", de = "Sprache" },
    ["English"]             = { fr = "Anglais", es = "Inglés", de = "Englisch" },
    ["Difficulty"]          = { fr = "Difficulté", es = "Dificultad", de = "Schwierigkeit" },
    ["Grid size"]           = { fr = "Taille de la grille", es = "Tamaño de la cuadrícula", de = "Rastergröße" },
    ["Auto-save"]           = { fr = "Sauvegarde automatique", es = "Guardado automático", de = "Automatisches Speichern" },
    ["Gameplay"]            = { fr = "Jeu", es = "Juego", de = "Spielablauf" },
    ["Game"]                = { fr = "Jeu", es = "Juego", de = "Spiel" },
    ["Time"]                = { fr = "Temps", es = "Tiempo", de = "Zeit" },
    ["Size: %1"]            = { fr = "Taille : %1", es = "Tamaño: %1", de = "Größe: %1" },
    ["Grid: %1"]            = { fr = "Grille : %1", es = "Cuadrícula: %1", de = "Raster: %1" },
    ["Diff: %1"]            = { fr = "Difficulté : %1", es = "Dif.: %1", de = "Schw.: %1" },
    ["Difficulty: %1"]      = { fr = "Difficulté : %1", es = "Dificultad: %1", de = "Schwierigkeit: %1" },
    ["On"]                  = { fr = "Actif", es = "Activado", de = "An" },
    ["Off"]                 = { fr = "Inactif", es = "Desactivado", de = "Aus" },
    ["Select"]              = { fr = "Sélectionner", es = "Seleccionar", de = "Auswählen" },
    ["Select size"]         = { fr = "Choisir la taille", es = "Elegir el tamaño", de = "Größe wählen" },

    -- -----------------------------------------------------------------------
    -- Common status — victories
    -- -----------------------------------------------------------------------
    ["Congratulations! Puzzle solved."]       = { fr = "Félicitations ! Puzzle résolu.", es = "¡Felicidades! Puzle resuelto.", de = "Glückwunsch! Rätsel gelöst." },
    ["Congratulations! Puzzle solved!"]       = { fr = "Félicitations ! Puzzle résolu !", es = "¡Felicidades! ¡Puzle resuelto!", de = "Glückwunsch! Rätsel gelöst!" },
    ["Puzzle solved!"]                        = { fr = "Puzzle résolu !", es = "¡Puzle resuelto!", de = "Rätsel gelöst!" },
    ["Puzzle complete!"]                      = { fr = "Puzzle terminé !", es = "¡Puzle completado!", de = "Rätsel vollständig!" },
    ["Puzzle %1 solved!"]                     = { fr = "Puzzle %1 résolu !", es = "¡Puzle %1 resuelto!", de = "Rätsel %1 gelöst!" },

    -- -----------------------------------------------------------------------
    -- Common status — errors / validation
    -- -----------------------------------------------------------------------
    ["Keep going!"]                          = { fr = "Continuez !", es = "¡Sigue así!", de = "Weiter so!" },
    ["No errors found!"]                     = { fr = "Aucune erreur trouvée !", es = "¡No se encontraron errores!", de = "Keine Fehler gefunden!" },
    ["No violations found so far."]          = { fr = "Aucune violation pour l'instant.", es = "No se han encontrado infracciones por ahora.", de = "Bisher keine Verstöße gefunden." },
    ["Everything looks good!"]               = { fr = "Tout est correct !", es = "¡Todo está correcto!", de = "Alles sieht gut aus!" },
    ["Some cells are incorrect."]            = { fr = "Certaines cases sont incorrectes.", es = "Algunas casillas son incorrectas.", de = "Einige Zellen sind falsch." },
    ["Some cells have errors."]              = { fr = "Certaines cases contiennent des erreurs.", es = "Algunas casillas tienen errores.", de = "Einige Zellen enthalten Fehler." },
    ["Wrong cells marked."]                  = { fr = "Cases incorrectes marquées.", es = "Casillas incorrectas marcadas.", de = "Falsche Zellen markiert." },
    ["Check: %1 violation(s) found."]        = { fr = "Vérification : %1 violation(s) trouvée(s).", es = "Comprobación: %1 infracción(es) encontrada(s).", de = "Prüfung: %1 Verstoß/Verstöße gefunden." },
    ["Check done. %1 cell(s) remaining."]    = { fr = "Vérification effectuée. %1 case(s) restante(s).", es = "Comprobación realizada. %1 casilla(s) restante(s).", de = "Prüfung abgeschlossen. %1 Zelle(n) verbleibend." },
    ["Check done. Empty: %1"]               = { fr = "Vérification effectuée. Vides : %1", es = "Comprobación realizada. Vacías: %1", de = "Prüfung abgeschlossen. Leer: %1" },
    ["Checking…"]                            = { fr = "Vérification…", es = "Comprobando…", de = "Wird geprüft…" },

    -- -----------------------------------------------------------------------
    -- Common status — undo / moves
    -- -----------------------------------------------------------------------
    ["Last move undone."]       = { fr = "Dernier coup annulé.", es = "Última jugada deshecha.", de = "Letzter Zug rückgängig gemacht." },
    ["Nothing to undo."]        = { fr = "Rien à annuler.", es = "Nada que deshacer.", de = "Nichts rückgängig zu machen." },
    ["Invalid move."]           = { fr = "Coup invalide.", es = "Jugada no válida.", de = "Ungültiger Zug." },
    ["Board cleared."]          = { fr = "Plateau effacé.", es = "Tablero borrado.", de = "Spielfeld geleert." },
    ["New game started."]       = { fr = "Nouvelle partie lancée.", es = "Nueva partida iniciada.", de = "Neues Spiel gestartet." },
    ["Started a %1 game."]      = { fr = "Partie %1 lancée.", es = "Partida %1 iniciada.", de = "%1-Spiel gestartet." },

    -- -----------------------------------------------------------------------
    -- Common status — game over
    -- -----------------------------------------------------------------------

    -- -----------------------------------------------------------------------
    -- Common status — cells / selection
    -- -----------------------------------------------------------------------
    ["Cannot edit a given cell."]                = { fr = "Impossible de modifier une case donnée.", es = "No se puede editar una casilla dada.", de = "Eine vorgegebene Zelle kann nicht bearbeitet werden." },
    ["Tap a cell first."]                        = { fr = "Appuyez d'abord sur une case.", es = "Toque primero una casilla.", de = "Zuerst eine Zelle antippen." },
    ["Cell %1,%2 selected."]                     = { fr = "Case %1,%2 sélectionnée.", es = "Casilla %1,%2 seleccionada.", de = "Zelle %1,%2 ausgewählt." },
    ["Selected: %1,%2  ·  Empty cells: %3"]      = { fr = "Sélection : %1,%2  ·  Cases vides : %3", es = "Seleccionada: %1,%2  ·  Casillas vacías: %3", de = "Ausgewählt: %1,%2  ·  Leere Zellen: %3" },
    ["Selected: %1,%2  \xC2\xB7  Empty cells: %3"] = { fr = "Sélection : %1,%2  ·  Cases vides : %3", es = "Seleccionada: %1,%2  ·  Casillas vacías: %3", de = "Ausgewählt: %1,%2  ·  Leere Zellen: %3" },

    -- -----------------------------------------------------------------------
    -- Common status — solution display
    -- -----------------------------------------------------------------------
    ["Solution shown."]                          = { fr = "Solution affichée.", es = "Solución mostrada.", de = "Lösung angezeigt." },
    ["Solution revealed."]                       = { fr = "Solution révélée.", es = "Solución revelada.", de = "Lösung aufgedeckt." },
    ["Showing the solution."]                    = { fr = "Affichage de la solution.", es = "Mostrando la solución.", de = "Lösung wird angezeigt." },
    ["Solution is shown; editing is disabled."]  = { fr = "Solution affichée ; modification désactivée.", es = "Solución mostrada; edición deshabilitada.", de = "Lösung wird angezeigt; Bearbeitung deaktiviert." },
    ["Result is being shown; editing is disabled."] = { fr = "Résultat affiché ; modification désactivée.", es = "Resultado mostrado; edición deshabilitada.", de = "Ergebnis wird angezeigt; Bearbeitung deaktiviert." },

    -- -----------------------------------------------------------------------
    -- Board error messages (board.lua)
    -- -----------------------------------------------------------------------
    ["Clear the cell before adding notes."] = { fr = "Effacez la case avant d'ajouter des notes.", es = "Borre la casilla antes de añadir notas.", de = "Zelle leeren, bevor Notizen hinzugefügt werden." },

    -- -----------------------------------------------------------------------
    -- Note mode status
    -- -----------------------------------------------------------------------
    ["Note mode enabled."]   = { fr = "Mode notes activé.", es = "Modo de notas activado.", de = "Notizmodus aktiviert." },
    ["Note mode disabled."]  = { fr = "Mode notes désactivé.", es = "Modo de notas desactivado.", de = "Notizmodus deaktiviert." },
    ["Note mode is ON."]     = { fr = "Mode notes : ACTIF.", es = "El modo de notas está ACTIVADO.", de = "Notizmodus ist AN." },

    -- -----------------------------------------------------------------------
    -- Word games (Boggle, Anagram, Wordle, Wordsearch, Hangman, Cryptogram)
    -- -----------------------------------------------------------------------
    ["Not enough letters!"]               = { fr = "Pas assez de lettres !", es = "¡No hay suficientes letras!", de = "Nicht genug Buchstaben!" },
    ["Lost! Word: %1  W:%2 L:%3"]         = { fr = "Perdu ! Mot : %1  V:%2 D:%3", es = "¡Perdiste! Palabra: %1  G:%2 P:%3", de = "Verloren! Wort: %1  S:%2 N:%3" },
    ["Entering: %1 (tap another digit or Erase)"] = { fr = "Saisie : %1 (autre chiffre ou Effacer)", es = "Introduciendo: %1 (toque otra cifra o Borrar)", de = "Eingabe: %1 (weitere Ziffer oder Löschen antippen)" },

    -- -----------------------------------------------------------------------
    -- Fillomino / Hidato / Numbrix (shared grid-status template)
    -- -----------------------------------------------------------------------
    ["Value %1 out of range (1-%2)."] = { fr = "Valeur %1 hors plage (1-%2).", es = "Valor %1 fuera de rango (1-%2).", de = "Wert %1 außerhalb des Bereichs (1-%2)." },
    ["%1\xC3\x97%2 \xC2\xB7 %3 \xC2\xB7 Empty: %4"] = { fr = "%1×%2 · %3 · Vides : %4", es = "%1×%2 · %3 · Vacías: %4", de = "%1×%2 · %3 · Leer: %4" },
    ["  \xC2\xB7 Empty: %1"]           = { fr = "  · Vides : %1", es = "  · Vacías: %1", de = "  · Leer: %1" },

    -- -----------------------------------------------------------------------
    -- Pickomino (dice game)
    -- -----------------------------------------------------------------------
    ["Roll the dice first."]             = { fr = "Lancez les dés d'abord.", es = "Lance los dados primero.", de = "Zuerst würfeln." },

    -- -----------------------------------------------------------------------
    -- Gomoku / Othello (player-specific messages already in FR for some)
    -- -----------------------------------------------------------------------
    ["%1/%2"]                        = { fr = "%1/%2", es = "%1/%2", de = "%1/%2" },

    -- -----------------------------------------------------------------------
    -- Cave / Path games (Hitori / Nurikabe)
    -- -----------------------------------------------------------------------
    ["%1\xC3\x97%2 \xC2\xB7 %3 \xC2\xB7 Unknown: %4"] = { fr = "%1×%2 · %3 · Inconnues : %4", es = "%1×%2 · %3 · Desconocidas: %4", de = "%1×%2 · %3 · Unbekannt: %4" },

    -- -----------------------------------------------------------------------
    -- KenKen / Cages / Killer Sudoku
    --
    -- sudokukiller.koplugin is sudoku_common-family (vendors its own
    -- common/), not game-common-family, so it has no reliable package.path
    -- to this module and can't use i18n.extend() — its strings stay here.
    -- -----------------------------------------------------------------------
    ["  \xC2\xB7 Cage: %1/%2 cells, sum %3/%4"] = { fr = "  · Cage : %1/%2 cases, somme %3/%4", es = "  · Jaula: %1/%2 casillas, suma %3/%4", de = "  · Käfig: %1/%2 Zellen, Summe %3/%4" },

    -- -----------------------------------------------------------------------
    -- Generic settings / skeleton placeholders (remove in real plugins)
    -- -----------------------------------------------------------------------
    ["My Game v1.0"]          = { fr = "Mon Jeu v1.0", es = "Mi Juego v1.0", de = "Mein Spiel v1.0" },
    ["My Game — Settings"]    = { fr = "Mon Jeu — Réglages", es = "Mi Juego — Ajustes", de = "Mein Spiel — Einstellungen" },

    -- -----------------------------------------------------------------------
    -- Dashboard / Binairo (orphaned or shared with other plugins)
    -- -----------------------------------------------------------------------
    ["Home button → Dashboard"]              = { fr = "Bouton Home → Dashboard", es = "Botón Inicio → Panel", de = "Home-Taste → Übersicht" },
    ["Binairo — Settings"]                   = { fr = "Binairo — Réglages", es = "Binairo — Ajustes", de = "Binairo — Einstellungen" },

    -- -----------------------------------------------------------------------
    -- Misc status messages
    -- -----------------------------------------------------------------------
    ["%1/%2"]                        = { fr = "%1/%2", es = "%1/%2", de = "%1/%2" },
    ["Roll"]                         = { fr = "Lancer", es = "Lanzar", de = "Würfeln" },
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
