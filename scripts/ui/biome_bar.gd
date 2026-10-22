class_name BiomeBar
extends Control
## Route progress strip: one segment per biome, checkpoint locks, blinking truck marker. Pixel-drawn.

const COLORS := {"industrial": Color("dc8236"), "desert": Color("f6ae4e"), "forest": Color("64a040"),
	"swamp": Color("9ec42c"), "tundra": Color("a4bcd4"), "metro": Color("e04ac4")}
var _t := 0.0


func _ready() -> void:
	custom_minimum_size = Vector2(120, 14)
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func _process(delta: float) -> void:
	_t += delta
	if int(_t * 10.0) % 2 == 0:
		queue_redraw()


func _draw() -> void:
	if Game.s.is_empty():
		return
	var w := floorf(size.x)
	var bar := Rect2(1, 4, w - 2, 5)
	draw_rect(bar.grow(1), Color("0c0c0e"))
	var total := Data.total_route_km()
	var x := bar.position.x
	for i in Data.BIOMES.size():
		var b: Dictionary = Data.BIOMES[i]
		var bw := floorf(bar.size.x * float(b.length) / total)
		if i == Data.BIOMES.size() - 1:
			bw = bar.end.x - x
		var col: Color = COLORS.get(b.id, Color.GRAY)
		var locked: bool = int(b.req) > int(Game.s.vault_level)
		var r := Rect2(x, bar.position.y, bw - 1, bar.size.y)
		draw_rect(r, col.darkened(0.75 if locked else 0.55))
		if i < int(Game.s.biome):
			draw_rect(r, col)
		elif i == int(Game.s.biome):
			var p := clampf((float(Game.s.km) - Data.biome_start_km(i)) / float(b.length), 0.0, 1.0)
			draw_rect(Rect2(r.position, Vector2(floorf(r.size.x * p), r.size.y)), col)
		if locked:
			draw_rect(Rect2(x - 1, bar.position.y - 2, 1, bar.size.y + 4), UIKit.C_RED)
		x += bw
	var mx := floorf(bar.position.x + bar.size.x * clampf(float(Game.s.km) / total, 0.0, 1.0))
	var on := Game.speed_factor() <= 0.0 or int(_t * 4.0) % 2 == 0
	if on:
		draw_rect(Rect2(mx - 1, 0, 3, 3), UIKit.C_WHITE)
		draw_rect(Rect2(mx, 3, 1, 8), UIKit.C_WHITE)
