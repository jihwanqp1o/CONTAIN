class_name SpecimenIcon
extends Control

var specimen_code: String = ""
var accent_color: Color   = Color.WHITE
var revealed: bool        = false

func setup(code: String, color: Color, show: bool) -> void:
	specimen_code = code
	accent_color  = color
	revealed      = show
	queue_redraw()

func _draw() -> void:
	if size.x < 4 or size.y < 4: return
	var cx: float = size.x * 0.5
	var cy: float = size.y * 0.5
	var r:  float = min(cx, cy) * 0.88

	draw_rect(Rect2(0, 0, size.x, size.y), Color(0.04, 0.03, 0.03, 1.0))

	if not revealed:
		_draw_silhouette(cx, cy, r)
	else:
		match specimen_code:
			"ACU-07": _draw_echo(cx, cy, r)
			"AMB-03": _draw_crawler(cx, cy, r)
			"TRK-11": _draw_hound(cx, cy, r)
			"TER-02": _draw_warden(cx, cy, r)
			"KIN-05": _draw_ram(cx, cy, r)
			"HVE-01": _draw_brood(cx, cy, r)
			"RSN-04": _draw_caller(cx, cy, r)
			"APEX":   _draw_colossus(cx, cy, r)
			_:        _draw_silhouette(cx, cy, r)

	draw_rect(Rect2(0, 0, size.x, size.y), accent_color * Color(1, 1, 1, 0.22), false, 1.0)

func _fill(pts: PackedVector2Array, col: Color) -> void:
	draw_polygon(pts, PackedColorArray([col]))

func _draw_silhouette(cx: float, cy: float, r: float) -> void:
	var pts = PackedVector2Array()
	for i in 8:
		var a = TAU * i / 8.0
		pts.append(Vector2(cx + cos(a) * r * 0.72, cy + sin(a) * r * 0.72))
	_fill(pts, Color(0.16, 0.14, 0.16, 0.80))
	draw_line(Vector2(cx - r * 0.18, cy), Vector2(cx + r * 0.18, cy), Color(0.28, 0.26, 0.28, 0.5), 1.5)

func _draw_echo(cx: float, cy: float, r: float) -> void:
	var col = accent_color
	draw_arc(Vector2(cx, cy), r * 0.88, 0.0, TAU, 48, col * Color(1, 1, 1, 0.14), 1.5)
	draw_arc(Vector2(cx, cy), r * 0.62, 0.0, TAU, 36, col * Color(1, 1, 1, 0.44), 2.0)
	draw_arc(Vector2(cx, cy), r * 0.34, 0.0, TAU, 20, col * Color(1, 1, 1, 0.85), 2.5)
	draw_circle(Vector2(cx, cy), r * 0.10, col)
	draw_circle(Vector2(cx - r * 0.18, cy - r * 0.10), r * 0.06, col * Color(1, 1, 1, 0.75))
	draw_circle(Vector2(cx + r * 0.18, cy - r * 0.10), r * 0.06, col * Color(1, 1, 1, 0.75))

func _draw_crawler(cx: float, cy: float, r: float) -> void:
	var col = accent_color
	var diamond = PackedVector2Array([
		Vector2(cx, cy - r * 0.50),
		Vector2(cx + r * 0.90, cy),
		Vector2(cx, cy + r * 0.50),
		Vector2(cx - r * 0.90, cy),
	])
	_fill(diamond, col * Color(1, 1, 1, 0.22))
	draw_polyline(PackedVector2Array([diamond[0], diamond[1], diamond[2], diamond[3], diamond[0]]),
		col, 2.0)
	for i in 3:
		var a = (0.28 + i * 0.18) * TAU
		draw_line(Vector2(cx, cy + r * 0.50),
			Vector2(cx + cos(a) * r * 0.52, cy + sin(a) * r * 0.44),
			col * Color(1, 1, 1, 0.65), 1.5)

func _draw_hound(cx: float, cy: float, r: float) -> void:
	var col = accent_color
	var pts = PackedVector2Array()
	for i in 6:
		var a = TAU * i / 6.0 - PI * 0.5
		pts.append(Vector2(cx + cos(a) * r * 0.84, cy + sin(a) * r * 0.84))
	_fill(pts, col * Color(1, 1, 1, 0.10))
	draw_polyline(PackedVector2Array([pts[0], pts[1], pts[2], pts[3], pts[4], pts[5], pts[0]]),
		col, 2.0)
	draw_circle(Vector2(cx - r * 0.20, cy - r * 0.06), r * 0.10, col)
	draw_circle(Vector2(cx + r * 0.20, cy - r * 0.06), r * 0.10, col)
	draw_arc(Vector2(cx, cy), r * 0.14, 0.0, TAU, 12, col * Color(1, 1, 1, 0.40), 1.5)

func _draw_warden(cx: float, cy: float, r: float) -> void:
	var col = accent_color
	var hw = r * 0.52
	draw_rect(Rect2(cx - hw, cy - hw, hw * 2.0, hw * 2.0), col * Color(1, 1, 1, 0.16))
	draw_rect(Rect2(cx - hw, cy - hw, hw * 2.0, hw * 2.0), col, false, 2.0)
	for i in 4:
		var a = TAU * i / 4.0 + PI * 0.25
		draw_line(
			Vector2(cx + cos(a) * r * 0.58, cy + sin(a) * r * 0.58),
			Vector2(cx + cos(a) * r * 0.92, cy + sin(a) * r * 0.92),
			col * Color(1, 1, 1, 0.72), 2.0)
	draw_circle(Vector2(cx, cy), r * 0.14, col)

func _draw_ram(cx: float, cy: float, r: float) -> void:
	var col = accent_color
	var tri = PackedVector2Array([
		Vector2(cx + r * 0.84, cy),
		Vector2(cx - r * 0.52, cy - r * 0.64),
		Vector2(cx - r * 0.52, cy + r * 0.64),
	])
	_fill(tri, col * Color(1, 1, 1, 0.68))
	draw_polyline(PackedVector2Array([tri[0], tri[1], tri[2], tri[0]]), col, 2.0)
	for i in 3:
		var yoff = (i - 1.0) * r * 0.26
		draw_line(
			Vector2(cx - r * 0.14, cy + yoff),
			Vector2(cx - r * 0.80, cy + yoff),
			col * Color(1, 1, 1, 0.30 + i * 0.18), 1.5)

func _draw_brood(cx: float, cy: float, r: float) -> void:
	var col = accent_color
	draw_arc(Vector2(cx, cy), r * 0.44, 0.0, TAU, 32, col, 3.0)
	draw_circle(Vector2(cx, cy), r * 0.38, col * Color(1, 1, 1, 0.12))
	for i in 3:
		var a = TAU * i / 3.0 - PI * 0.5
		var oc = Vector2(cx + cos(a) * r * 0.78, cy + sin(a) * r * 0.78)
		draw_arc(oc, r * 0.17, 0.0, TAU, 16, col * Color(1, 1, 1, 0.76), 1.5)
	draw_circle(Vector2(cx, cy), r * 0.13, col)

func _draw_caller(cx: float, cy: float, r: float) -> void:
	var col = accent_color
	var spread = 0.13
	for i in 5:
		var a = TAU * i / 5.0 - PI * 0.5
		var spike = PackedVector2Array([
			Vector2(cx + cos(a - spread) * r * 0.26, cy + sin(a - spread) * r * 0.26),
			Vector2(cx + cos(a) * r * 0.90, cy + sin(a) * r * 0.90),
			Vector2(cx + cos(a + spread) * r * 0.26, cy + sin(a + spread) * r * 0.26),
		])
		_fill(spike, col * Color(1, 1, 1, 0.52))
	draw_circle(Vector2(cx, cy), r * 0.24, col)
	draw_arc(Vector2(cx, cy), r * 0.38, 0.0, TAU, 24, col * Color(1, 1, 1, 0.32), 1.5)

func _draw_colossus(cx: float, cy: float, r: float) -> void:
	var col = accent_color
	var bw = r * 0.42
	var bh = r * 0.70
	draw_rect(Rect2(cx - bw, cy - bh, bw * 2.0, bh * 2.0), col * Color(1, 1, 1, 0.18))
	draw_rect(Rect2(cx - bw, cy - bh, bw * 2.0, bh * 2.0), col, false, 2.5)
	draw_rect(Rect2(cx - r * 0.98, cy - r * 0.30, r * 0.52, r * 0.62),
		col * Color(1, 1, 1, 0.36))
	draw_rect(Rect2(cx + r * 0.46, cy - r * 0.30, r * 0.52, r * 0.62),
		col * Color(1, 1, 1, 0.36))
	draw_circle(Vector2(cx - r * 0.18, cy - r * 0.30), r * 0.10,
		Color(1.0, 0.14, 0.08, 0.92))
	draw_circle(Vector2(cx + r * 0.18, cy - r * 0.30), r * 0.10,
		Color(1.0, 0.14, 0.08, 0.92))
