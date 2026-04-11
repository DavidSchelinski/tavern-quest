class_name ItemData
extends Resource

@export var id          : String    = ""
@export var display_name: String    = ""
@export var description : String    = ""
@export var icon        : Texture2D = null
@export var stackable   : bool      = true
@export var max_stack   : int       = 64
## Color used for the placeholder 3D mesh when no custom model is set.
@export var mesh_color  : Color     = Color.WHITE

@export_category("Equipment")
## Equipment slot type: none, helm, torso, pants, shoes, hand, two_hand, neck
@export var equip_type   : String = "none"
@export var defense_bonus: int    = 0
@export var attack_bonus : int    = 0
