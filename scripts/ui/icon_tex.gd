class_name IconTex
extends Texture2D
## MV-694 icons v2: a 32 px PixelLab icon that reports the old 16x16 size, so every Button.icon,
## TextureRect and draw_texture() keeps its layout while the 32 px art is drawn into that space.
## The game stretches canvas items (window/stretch/mode = canvas_items), so on a 2x+ phone screen
## the full 32 px detail stays visible (mixed pixel size on purpose, like the crew at 2/3).

const SIZE := 16

var inner: Texture2D


func _init(t: Texture2D = null) -> void:
	inner = t


func _get_width() -> int:
	return SIZE


func _get_height() -> int:
	return SIZE


func _has_alpha() -> bool:
	return true


func _is_pixel_opaque(x: int, y: int) -> bool:
	return true


func _draw(to_canvas_item: RID, pos: Vector2, modulate: Color, transpose: bool) -> void:
	inner.draw_rect(to_canvas_item, Rect2(pos, Vector2(SIZE, SIZE)), false, modulate, transpose)


func _draw_rect(to_canvas_item: RID, rect: Rect2, tile: bool, modulate: Color, transpose: bool) -> void:
	inner.draw_rect(to_canvas_item, rect, false, modulate, transpose)


func _draw_rect_region(to_canvas_item: RID, rect: Rect2, src_rect: Rect2, modulate: Color, transpose: bool, clip_uv: bool) -> void:
	var k := float(inner.get_width()) / float(SIZE)
	inner.draw_rect_region(to_canvas_item, rect, Rect2(src_rect.position * k, src_rect.size * k), modulate, transpose, clip_uv)
