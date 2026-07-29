extends Control

## Scratch scene only — instances a real screen and captures it at the configured
## mobile viewport for visual verification. Not wired into navigation. Run with
## --capture-target=<res:// path> --capture-out=<res:// path> --capture cmdline args.

func _ready() -> void:
	var args := OS.get_cmdline_user_args()
	var target_path := "res://scenes/home/home.tscn"
	var out_path := "res://scratch_mobile_capture.png"
	for arg in args:
		if arg.begins_with("--capture-target="):
			target_path = arg.substr("--capture-target=".length())
		elif arg.begins_with("--capture-out="):
			out_path = arg.substr("--capture-out=".length())

	var screen: Node = load(target_path).instantiate()
	add_child(screen)

	if "--capture" in args:
		await get_tree().process_frame
		await get_tree().process_frame
		await get_tree().process_frame
		var img := get_viewport().get_texture().get_image()
		img.save_png(out_path)
		get_tree().quit()
