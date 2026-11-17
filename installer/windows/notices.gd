extends SceneTree
## Writes THIRD-PARTY-NOTICES.txt for a release: the Godot Engine license,
## every third-party component compiled into the engine, and the font license.
##   godot --headless -s installer/windows/notices.gd -- <out.txt> <OFL.txt>

func _init() -> void:
	var args := OS.get_cmdline_user_args()
	var out := FileAccess.open(args[0], FileAccess.WRITE)
	var rule := "=".repeat(72)
	var info := Engine.get_version_info()
	out.store_line("Isles of Resistance: third-party notices")
	out.store_line(rule)
	out.store_line("")
	out.store_line("Isles of Resistance is built with the Godot Engine %s (https://godotengine.org)." % info["string"])
	out.store_line("Its user interface uses the Chakra Petch typeface. Their licenses follow.")
	out.store_line("")
	out.store_line(rule)
	out.store_line("Godot Engine")
	out.store_line(rule)
	out.store_line(Engine.get_license_text())
	out.store_line("")
	out.store_line(rule)
	out.store_line("Third-party components of the Godot Engine")
	out.store_line(rule)
	for c in Engine.get_copyright_info():
		out.store_line("")
		out.store_line(c["name"])
		for part in c["parts"]:
			for line in part["copyright"]:
				out.store_line("  Copyright: " + line)
			out.store_line("  License: " + part["license"])
	var licenses := Engine.get_license_info()
	var names := licenses.keys()
	names.sort()
	for name in names:
		out.store_line("")
		out.store_line(rule)
		out.store_line("License: " + name)
		out.store_line(rule)
		out.store_line(licenses[name])
	out.store_line("")
	out.store_line(rule)
	out.store_line("Chakra Petch typeface")
	out.store_line(rule)
	out.store_line(FileAccess.get_file_as_string(args[1]))
	out.close()
	quit()
