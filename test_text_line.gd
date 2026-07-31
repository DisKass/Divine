extends SceneTree

func _init():
    var font = ThemeDB.fallback_font
    var tl = TextLine.new()
    var success = tl.add_string("Test String", font, 11)
    print("Success: ", success)
    print("Size: ", tl.get_size())
    quit()
