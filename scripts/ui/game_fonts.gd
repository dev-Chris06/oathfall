class_name GameFonts
extends RefCounted
## Les polices du jeu, toutes deux CC0 (voir CREDITS.md).
##   - Standard Blackletter, pour les titres. Elle n'a pas d'accents : les
##     lettres absentes sont prises dans MFB Oldstyle.
##   - MFB Oldstyle, pour le texte.

const TEXT_PATH := "res://assets/fonts/MFBOldstyle-Regular.otf"
const ITALIC_PATH := "res://assets/fonts/MFBOldstyle-Italic.otf"
const TITLE_PATH := "res://assets/fonts/StandardBlackletter.otf"

## Encre et rubriques, pour tout ce qui est écrit sur du papier.
const INK := Color(0.16, 0.11, 0.07)
const FADED_INK := Color(0.36, 0.29, 0.21)
const RUBRIC := Color(0.47, 0.1, 0.06)

static var _title: Font


static func text() -> Font:
	return load(TEXT_PATH)


static func italic() -> Font:
	return load(ITALIC_PATH)


static func title() -> Font:
	if _title == null:
		var font := (load(TITLE_PATH) as FontFile).duplicate() as FontFile
		font.fallbacks = [text()]
		_title = font
	return _title
