extends Node
## Loads res://translations/taptico.csv at startup and picks the language from the device.
## Same approach as Oil Due 1.0.3: the CSV is imported with importer="keep" (see
## taptico.csv.import), so it ships as plain text and Godot's CSV translation importer
## never turns it into .translation files that nothing loads.
## Must be the FIRST autoload so every other autoload/scene sees translations.

const CSV_PATH := "res://translations/taptico.csv"
const SUPPORTED := ["en", "de", "fr", "es", "pt_BR", "it", "ja", "ko", "zh_TW"]

var loaded_locales: PackedStringArray = PackedStringArray()


func _enter_tree() -> void:
	_install_translations()
	TranslationServer.set_locale(locale_id_for(OS.get_locale()))


func is_english() -> bool:
	return TranslationServer.get_locale() == "en"


static func locale_id_for(os_locale: String) -> String:
	# Language decides; region only matters for Chinese script. Anything else -> English.
	var raw := os_locale.strip_edges().replace("-", "_")
	var up := raw.to_upper()
	var lang: String = raw.split("_")[0].to_lower() if raw != "" else ""
	match lang:
		"de", "fr", "it", "ja", "ko", "es":
			return lang
		"pt":
			return "pt_BR"
		"zh":
			if up.contains("HANT") or up.ends_with("_TW") or up.ends_with("_HK") or up.ends_with("_MO") or up.contains("_TW_") or up.contains("_HK_") or up.contains("_MO_"):
				return "zh_TW"
			return "en"
	return "en"


func _install_translations() -> void:
	var text := FileAccess.get_file_as_string(CSV_PATH)
	if text.strip_edges() == "":
		push_error("Locale: %s missing from the export; staying English" % CSV_PATH)
		return
	var lines := text.split("\n")
	var header := _csv_fields(lines[0])
	if header.size() < 2:
		return
	var books: Array[Translation] = []
	for i in range(1, header.size()):
		var book := Translation.new()
		book.locale = str(header[i]).strip_edges()
		books.append(book)
		loaded_locales.append(book.locale)
	for line_i in range(1, lines.size()):
		var line := str(lines[line_i])
		if line.strip_edges() == "":
			continue
		var cols := _csv_fields(line)
		if cols.is_empty():
			continue
		var key := str(cols[0])
		var en_value: String = str(cols[1]).replace("\\n", "\n") if cols.size() > 1 else key
		for i in range(books.size()):
			var value: String = en_value
			if i + 1 < cols.size() and str(cols[i + 1]) != "":
				value = str(cols[i + 1]).replace("\\n", "\n")
			books[i].add_message(key, value)
	for book in books:
		TranslationServer.add_translation(book)


static func _csv_fields(line: String) -> PackedStringArray:
	var out := PackedStringArray()
	var cur := ""
	var quoted := false
	var raw := line.replace("\r", "")
	var i := 0
	while i < raw.length():
		var c := raw[i]
		if quoted:
			if c == "\"":
				if i + 1 < raw.length() and raw[i + 1] == "\"":
					cur += "\""
					i += 1
				else:
					quoted = false
			else:
				cur += c
		else:
			if c == "\"":
				quoted = true
			elif c == ",":
				out.append(cur)
				cur = ""
			else:
				cur += c
		i += 1
	out.append(cur)
	return out
