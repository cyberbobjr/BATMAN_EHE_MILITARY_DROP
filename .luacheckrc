-- Luacheck : Lua 5.1, le langage de Kahlua (Project Zomboid).
std = "lua51"
-- Les signatures vanilla imposent souvent des paramètres inutilisés.
unused_args = false
codes = true
max_line_length = 130
-- Sources B41 conservées pour référence pendant le portage (non publiées).
exclude_files = { "legacy-b41/**" }

-- Code du mod : MilitaryDrop et le gestionnaire batterie commun à Artemis.
-- Les scripts désignent aussi MilitaryDrop.Recipe.* par nom. La
-- lecture des globales du jeu (Events, getText, ISButton…), trop nombreuses pour
-- être listées, reste libre (113, 143).
globals = { "MilitaryDrop", "BatmanBeltRadioBattery", "BatmanRadioSupport" }
ignore = { "113", "143" }

-- Les tests simulent l'API du jeu par des globales.
files["tests"] = { global = false }
