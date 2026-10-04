extends RefCounted
class_name Tex

# 마인크래프트식 도트 텍스처를 코드로 만든다. 이미지 파일은 안 쓴다.
# 32x32 픽셀에 NEAREST 필터. 삼면 투영(triplanar)으로 붙이므로 UV 는 신경 안 써도 된다.

const SIZE := 32

enum Kind { CONCRETE, BRICK, WINDOWS, ASPHALT, PAVEMENT, GRASS, BARK, LEAF, METAL, PANEL }

static var _cache := {}


static func get_tex(kind: int) -> ImageTexture:
	if _cache.has(kind):
		return _cache[kind]
	var img := Image.create(SIZE, SIZE, false, Image.FORMAT_RGBA8)
	var rng := RandomNumberGenerator.new()
	# 종류마다 고정 시드. 판을 새로 만들어도 같은 무늬가 나와야 한다.
	rng.seed = 1000 + kind
	match kind:
		Kind.CONCRETE: _concrete(img, rng)
		Kind.BRICK: _brick(img, rng)
		Kind.WINDOWS: _windows(img, rng)
		Kind.ASPHALT: _asphalt(img, rng)
		Kind.PAVEMENT: _pavement(img, rng)
		Kind.GRASS: _grass(img, rng)
		Kind.BARK: _bark(img, rng)
		Kind.LEAF: _leaf(img, rng)
		Kind.METAL: _metal(img, rng)
		_: _panel(img, rng)
	var t := ImageTexture.create_from_image(img)
	_cache[kind] = t
	return t


# 창문만 따로: 밤에 빛나는 칸을 흰색, 나머지는 검은색으로 뽑은 발광용 마스크
static func get_window_emission() -> ImageTexture:
	if _cache.has(-1):
		return _cache[-1]
	var img := Image.create(SIZE, SIZE, false, Image.FORMAT_RGBA8)
	var rng := RandomNumberGenerator.new()
	rng.seed = 7777
	img.fill(Color(0, 0, 0, 1))
	for gy in 4:
		for gx in 4:
			if rng.randf() > 0.32:
				continue
			var lit := Color(1.0, 0.86, 0.55)
			for y in range(gy * 8 + 1, gy * 8 + 7):
				for x in range(gx * 8 + 1, gx * 8 + 7):
					img.set_pixel(x, y, lit)
	var t := ImageTexture.create_from_image(img)
	_cache[-1] = t
	return t


static func _noise(img: Image, rng: RandomNumberGenerator, base: float, amp: float) -> void:
	for y in SIZE:
		for x in SIZE:
			var v: float = base + rng.randf_range(-amp, amp)
			img.set_pixel(x, y, Color(v, v, v))


static func _concrete(img: Image, rng: RandomNumberGenerator) -> void:
	_noise(img, rng, 0.86, 0.07)
	# 콘크리트 패널 이음새
	for y in SIZE:
		for x in SIZE:
			if x % 16 == 0 or y % 16 == 0:
				var c := img.get_pixel(x, y)
				img.set_pixel(x, y, c.darkened(0.22))


static func _brick(img: Image, rng: RandomNumberGenerator) -> void:
	# 벽돌 8x4, 한 줄 걸러 반 칸 어긋나게
	for y in SIZE:
		var row: int = y / 4
		var off: int = 0 if row % 2 == 0 else 4
		for x in SIZE:
			var mortar: bool = (y % 4 == 0) or ((x + off) % 8 == 0)
			if mortar:
				img.set_pixel(x, y, Color(0.80, 0.78, 0.74))
			else:
				var v: float = 0.88 + rng.randf_range(-0.10, 0.06)
				img.set_pixel(x, y, Color(v, v * 0.93, v * 0.90))


static func _windows(img: Image, rng: RandomNumberGenerator) -> void:
	# 8x8 칸 4x4개. 칸마다 밝기가 다르다.
	img.fill(Color(0.74, 0.74, 0.78))
	for gy in 4:
		for gx in 4:
			var v: float = rng.randf_range(0.18, 0.46)
			var col := Color(v * 0.85, v * 0.95, v * 1.15)
			for y in range(gy * 8 + 1, gy * 8 + 7):
				for x in range(gx * 8 + 1, gx * 8 + 7):
					# 유리 윗부분이 밝게 반사되는 느낌
					var hl: float = 1.0 + (0.45 if y % 8 <= 2 else 0.0)
					img.set_pixel(x, y, Color(col.r * hl, col.g * hl, col.b * hl))


static func _asphalt(img: Image, rng: RandomNumberGenerator) -> void:
	for y in SIZE:
		for x in SIZE:
			var v: float = 0.80 + rng.randf_range(-0.10, 0.10)
			if rng.randf() < 0.03:
				v -= 0.18   # 자갈 알갱이
			img.set_pixel(x, y, Color(v, v, v * 1.02))


static func _pavement(img: Image, rng: RandomNumberGenerator) -> void:
	for y in SIZE:
		for x in SIZE:
			var v: float = 0.92 + rng.randf_range(-0.05, 0.05)
			if x % 8 == 0 or y % 8 == 0:
				v -= 0.16   # 보도블록 줄눈
			img.set_pixel(x, y, Color(v, v, v))


static func _grass(img: Image, rng: RandomNumberGenerator) -> void:
	for y in SIZE:
		for x in SIZE:
			var v: float = 0.92 + rng.randf_range(-0.16, 0.10)
			img.set_pixel(x, y, Color(v * 0.86, v, v * 0.72))


static func _bark(img: Image, rng: RandomNumberGenerator) -> void:
	for y in SIZE:
		for x in SIZE:
			# 세로 결
			var v: float = 0.88 + sin(float(x) * 1.7) * 0.07 + rng.randf_range(-0.07, 0.07)
			img.set_pixel(x, y, Color(v, v * 0.93, v * 0.86))


static func _leaf(img: Image, rng: RandomNumberGenerator) -> void:
	for y in SIZE:
		for x in SIZE:
			var v: float = 0.90 + rng.randf_range(-0.20, 0.12)
			img.set_pixel(x, y, Color(v * 0.80, v, v * 0.70))


static func _metal(img: Image, rng: RandomNumberGenerator) -> void:
	_noise(img, rng, 0.90, 0.05)


static func _panel(img: Image, rng: RandomNumberGenerator) -> void:
	_noise(img, rng, 0.90, 0.04)
	for y in SIZE:
		for x in SIZE:
			if y % 8 == 0:
				img.set_pixel(x, y, img.get_pixel(x, y).darkened(0.18))
