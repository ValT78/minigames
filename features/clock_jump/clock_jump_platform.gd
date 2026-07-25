class_name ClockJumpPlatform
extends StaticBody2D

# Référence unique à la forme afin que chaque plateforme puisse avoir sa propre taille.
@onready var collision_shape: CollisionShape2D = %CollisionShape2D
@onready var platform_visual: Node2D = %PlatformVisual
@onready var platform_body: Polygon2D = %PlatformBody
@onready var platform_highlight: Line2D = %PlatformHighlight
@onready var left_rivet: Polygon2D = %LeftRivet
@onready var right_rivet: Polygon2D = %RightRivet
@onready var brick_horizontal_joint: Line2D = %BrickHorizontalJoint
@onready var brick_vertical_joint: Line2D = %BrickVerticalJoint

var platform_size := Vector2(240.0, 24.0)
var platform_color := Color("c7903f")
var is_one_way := true


func setup(new_size: Vector2, one_way: bool, new_color: Color) -> void:
	# Les plateformes normales sont traversables par-dessous, contrairement aux briques.
	platform_size = new_size
	is_one_way = one_way
	platform_color = new_color
	var rectangle_shape := RectangleShape2D.new()
	rectangle_shape.size = platform_size
	collision_shape.shape = rectangle_shape
	collision_shape.one_way_collision = is_one_way
	collision_shape.one_way_collision_margin = 12.0

	# La scène porte le dessin ; le script ne fait que l'adapter à la taille et au type demandés.
	platform_visual.scale = Vector2(platform_size.x / 240.0, platform_size.y / 24.0)
	platform_body.color = platform_color
	platform_highlight.default_color = platform_color.lightened(0.35)
	left_rivet.visible = is_one_way
	right_rivet.visible = is_one_way
	brick_horizontal_joint.visible = not is_one_way
	brick_vertical_joint.visible = not is_one_way
