extends RefCounted
## Load bytes explicitly: sandboxed macOS font discovery can return inaccessible descriptors.
static func create_font(pixelated: bool = false) -> Font:
	var latin_path: String = "/System/Library/Fonts/Menlo.ttc"
	var cjk_path: String = "/System/Library/Fonts/Supplemental/Arial Unicode.ttf"
	if FileAccess.file_exists(latin_path):
		var latin: FontFile = FontFile.new()
		latin.data = FileAccess.get_file_as_bytes(latin_path)
		if pixelated:
			latin.oversampling = 1.0
			latin.antialiasing = TextServer.FONT_ANTIALIASING_NONE
			latin.subpixel_positioning = TextServer.SUBPIXEL_POSITIONING_DISABLED
		if FileAccess.file_exists(cjk_path):
			var cjk: FontFile = FontFile.new()
			cjk.data = FileAccess.get_file_as_bytes(cjk_path)
			if pixelated:
				cjk.oversampling = 1.0
				cjk.antialiasing = TextServer.FONT_ANTIALIASING_NONE
				cjk.subpixel_positioning = TextServer.SUBPIXEL_POSITIONING_DISABLED
			latin.fallbacks = [cjk]
		return latin
	return ThemeDB.fallback_font
