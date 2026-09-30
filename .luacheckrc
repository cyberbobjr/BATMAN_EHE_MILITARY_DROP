-- Luacheck : Lua 5.1, le langage de Kahlua (Project Zomboid).
std = "lua51"
-- Les globales du jeu (Events, getText, ISButton…) sont trop nombreuses pour être
-- listées : on ne contrôle pas les globales.
global = false
-- Les signatures vanilla imposent souvent des paramètres inutilisés.
unused_args = false
codes = true
max_line_length = 130
-- Sources B41 conservées pour référence pendant le portage (non publiées).
exclude_files = { "legacy-b41/**" }
