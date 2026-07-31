extends SceneTree

func _init():
    var t = Thread.new()
    print("Method exists: ", t.has_method("is_alive"))
    print("Method exists: ", t.has_method("is_started"))
    quit()
