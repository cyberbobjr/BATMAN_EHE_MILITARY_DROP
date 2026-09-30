-- Luacheck : Lua 5.1, le langage de Kahlua (Project Zomboid).
std = "lua51"
-- Les signatures vanilla imposent souvent des paramètres inutilisés.
unused_args = false
codes = true
max_line_length = 130
-- Sources B41 conservées pour référence pendant le portage (non publiées).
exclude_files = { "legacy-b41/**" }

-- Code du mod : aucune écriture de globale hors de la table MilitaryDrop (seule
-- globale voulue : les scripts désignent MilitaryDrop.Recipe.* par nom). La
-- lecture des globales du jeu (Events, getText, ISButton…), trop nombreuses pour
-- être listées, reste libre (113, 143).
globals = { "MilitaryDrop" }
ignore = { "113", "143" }

-- Les tests simulent l'API du jeu par des globales.
files["tests"] = { global = false }
