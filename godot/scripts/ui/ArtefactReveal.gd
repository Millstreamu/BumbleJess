extends CanvasLayer
class_name ArtefactReveal

const SPROUT_DATA_PATH := "res://data/sprouts.json"

@onready var _icon: TextureRect = $"Panel/VBox/Header/Icon"
@onready var _title: Label = $"Panel/VBox/Header/Title"
@onready var _desc: RichTextLabel = $"Panel/VBox/Desc"
@onready var _sprout_icon: TextureRect = $"Panel/VBox/SproutRow/SproutIcon"
@onready var _sprout_name: Label = $"Panel/VBox/SproutRow/SproutName"
@onready var _ok_button: Button = $"Panel/VBox/Footer/OkBtn"

var _payload: Dictionary = {}

static var _sprout_cache: Dictionary = {}
static var _sprout_cache_loaded := false

func _ready() -> void:
        visible = false
        _ok_button.pressed.connect(_on_ok_pressed)
        _ensure_sprout_cache()

func open(payload: Dictionary) -> void:
        _payload = payload.duplicate(true)
        _apply_payload()
        visible = true

func _apply_payload() -> void:
        _apply_header()
        _apply_description()
        _apply_sprout_preview()

func _apply_header() -> void:
        if _title != null:
                _title.text = String(_payload.get("title", "Artefact Discovered"))
        if _icon != null:
                _icon.texture = null
                var icon_path := String(_payload.get("icon", ""))
                if not icon_path.is_empty() and ResourceLoader.exists(icon_path):
                        var texture := ResourceLoader.load(icon_path)
                        if texture is Texture2D:
                                _icon.texture = texture

func _apply_description() -> void:
        if _desc == null:
                return
        var desc_text := String(_payload.get("desc", "Something stirs beneath the soil."))
        if desc_text.is_empty():
                desc_text = "Something stirs beneath the soil."
        _desc.clear()
        _desc.append_text(desc_text)

func _apply_sprout_preview() -> void:
        if _sprout_icon != null:
                _sprout_icon.texture = null
        if _sprout_name != null:
                _sprout_name.text = "Unknown sprout"
        var sid := String(_payload.get("reveals_sprout_id", ""))
        if sid.is_empty():
                if _sprout_name != null:
                        _sprout_name.text = "No sprout linked to this artefact."
                return
        var sprout_def := _sprout_def(sid)
        var display_name := sid
        if sprout_def.has("name"):
                display_name = String(sprout_def["name"])
        if _sprout_name != null:
                _sprout_name.text = "Unlocked: %s" % display_name
        var icon_path := String(sprout_def.get("icon", ""))
        if not icon_path.is_empty() and ResourceLoader.exists(icon_path):
                var texture := ResourceLoader.load(icon_path)
                if texture is Texture2D and _sprout_icon != null:
                        _sprout_icon.texture = texture

func _sprout_def(id: String) -> Dictionary:
        _ensure_sprout_cache()
        var stored := _sprout_cache.get(id, {})
        if stored is Dictionary:
                return stored
        return {}

func _ensure_sprout_cache() -> void:
        if _sprout_cache_loaded:
                return
        var entries := DataLite.load_json_array(SPROUT_DATA_PATH)
        for entry in entries:
                if not (entry is Dictionary):
                        continue
                var def: Dictionary = (entry as Dictionary)
                var sid := String(def.get("id", ""))
                if sid.is_empty():
                        continue
                _sprout_cache[sid] = def.duplicate(true)
        _sprout_cache_loaded = true

func _on_ok_pressed() -> void:
        queue_free()
