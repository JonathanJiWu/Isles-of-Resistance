extends SceneTree
## Compiles every script in the project and reports failures.
func _init():
	await process_frame
	var bad := 0
	var files := []
	_collect("res://Scripts", files)
	_collect("res://tests", files)
	for f in files:
		var s = load(f)
		if s == null or not s.can_instantiate():
			print("BROKEN: ", f)
			bad += 1
	print("checked %d scripts, %d broken" % [files.size(), bad])
	quit(1 if bad > 0 else 0)

func _collect(dir: String, out: Array) -> void:
	for f in DirAccess.get_files_at(dir):
		if f.ends_with(".gd"):
			out.append(dir + "/" + f)
	for d in DirAccess.get_directories_at(dir):
		_collect(dir + "/" + d, out)
