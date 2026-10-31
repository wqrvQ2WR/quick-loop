extends Control
class_name GameMenu

signal closed()
signal quit_shift()

const TABS := ["스토리", "튜토리얼", "구역", "업그레이드", "도전과제", "설정"]
const DISTRICT_TAB := 2
const UPGRADE_TAB := 3
const SETTINGS_TAB := 5

var game: Node = null
var tab := 2
var row := 0
var confirm_idx := -1

var _tab_bar: HBoxContainer
var _scroll: ScrollContainer
var _selected_node: Control = null
var _body: VBoxContainer
var _wallet: Label
var _wallet_sub: Label
var _footer: Label
var _tab_labels: Array[Label] = []


func setup(g: Node) -> void:
	game = g
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE

	var bg := ColorRect.new()
	bg.color = Color(0.05, 0.04, 0.12, 0.93)
	add_child(bg)
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	var root := VBoxContainer.new()
	add_child(root)
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.offset_left = 90
	root.offset_right = -90
	root.offset_top = 46
	root.offset_bottom = -40
	root.add_theme_constant_override("separation", 14)

	var head := HBoxContainer.new()
	head.add_theme_constant_override("separation", 26)
	root.add_child(head)
	var title := _mk("메뉴", 40, Color(1, 1, 1))
	head.add_child(title)
	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(spacer)
	var wallet_col := VBoxContainer.new()
	wallet_col.alignment = BoxContainer.ALIGNMENT_END
	wallet_col.add_theme_constant_override("separation", 0)
	head.add_child(wallet_col)
	_wallet = _mk("", 30, Color(1, 0.95, 0.4))
	_wallet.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	wallet_col.add_child(_wallet)
	_wallet_sub = _mk("", 19, Color(0.78, 0.82, 0.95))
	_wallet_sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	wallet_col.add_child(_wallet_sub)

	_tab_bar = HBoxContainer.new()
	_tab_bar.add_theme_constant_override("separation", 24)
	root.add_child(_tab_bar)
	for i in TABS.size():
		var l := _mk(TABS[i], 28, Color(0.6, 0.6, 0.7))
		l.mouse_filter = Control.MOUSE_FILTER_STOP
		l.gui_input.connect(_on_tab_input.bind(i))
		_tab_bar.add_child(l)
		_tab_labels.append(l)

	var line := ColorRect.new()
	line.color = Color(1, 1, 1, 0.22)
	line.custom_minimum_size = Vector2(0, 2)
	root.add_child(line)

	_scroll = ScrollContainer.new()
	_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	root.add_child(_scroll)
	_body = VBoxContainer.new()
	_body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_body.add_theme_constant_override("separation", 8)
	_scroll.add_child(_body)

	_footer = _mk("", 20, Color(0.75, 0.78, 0.9))
	root.add_child(_footer)
	visible = false


func _mk(text: String, size: int, color: Color) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	l.add_theme_color_override("font_outline_color", Color(0.03, 0.02, 0.08, 0.9))
	l.add_theme_constant_override("outline_size", 5)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return l


func open() -> void:
	visible = true
	row = 0
	confirm_idx = -1
	refresh()


func close() -> void:
	visible = false
	closed.emit()


func handle_key(key: int) -> void:
	match key:
		KEY_A, KEY_LEFT:
			tab = (tab - 1 + TABS.size()) % TABS.size()
			row = 0
			confirm_idx = -1
		KEY_D, KEY_RIGHT:
			tab = (tab + 1) % TABS.size()
			row = 0
			confirm_idx = -1
		KEY_W, KEY_UP:
			if _row_count() > 0:
				row = maxi(0, row - 1)
				confirm_idx = -1
			else:
				_scroll.scroll_vertical -= 70
				return
		KEY_S, KEY_DOWN:
			if _row_count() > 0:
				row = mini(_row_count() - 1, row + 1)
				confirm_idx = -1
			else:
				_scroll.scroll_vertical += 70
				return
		KEY_SPACE, KEY_ENTER:
			if tab == DISTRICT_TAB:
				game.select_district(row)
			elif tab == UPGRADE_TAB:
				game.buy_upgrade(row)
			elif tab == SETTINGS_TAB:
				_activate_setting(row)
				return
		KEY_Q:
			quit_shift.emit()
			return
		KEY_ESCAPE, KEY_L:
			close()
			return
	refresh()


func refresh() -> void:
	if game == null:
		return
	var goal: float = game.GOAL
	var pct: int = int(clampf(game.score / goal, 0.0, 1.0) * 100.0)
	_wallet.text = "보유 %s원  ·  1일차 목표 %s원 (%d%%)" % [
		game._won(game.score), game._won(goal), pct]
	if _wallet_sub != null:
		_wallet_sub.text = "남은 금액 %s원  ·  누적 수익 %s원" % [
			game._won(maxf(0.0, goal - game.score)), game._won(roundf(game.career_earnings))]
	for i in _tab_labels.size():
		var on := i == tab
		_tab_labels[i].add_theme_color_override("font_color",
			Color(1, 0.9, 0.35) if on else Color(0.55, 0.55, 0.66))
		_tab_labels[i].text = ("▸ " if on else "  ") + TABS[i]
	for c in _body.get_children():
		c.queue_free()
	_selected_node = null
	match tab:
		0: _draw_story()
		1: _draw_tutorial()
		2: _draw_districts()
		3: _draw_upgrades()
		4: _draw_achievements()
		5: _draw_settings()
	var act := "SPACE 선택"
	if tab == UPGRADE_TAB:
		act = "SPACE 구매"
	elif tab == SETTINGS_TAB:
		act = "SPACE 실행"
	elif _row_count() == 0:
		act = "W / S 스크롤"
	_footer.text = "마우스 클릭 · A / D 탭 이동 · W / S 이동 · %s · ESC 닫기 · Q 퇴근" % act
	if _selected_node != null:
		await get_tree().process_frame
		if is_instance_valid(_selected_node) and is_instance_valid(_scroll):
			_scroll.ensure_control_visible(_selected_node)


func _row_count() -> int:
	if tab == DISTRICT_TAB:
		return City.THEMES.size()
	if tab == UPGRADE_TAB:
		return game.UPGRADES.size()
	if tab == SETTINGS_TAB:
		return 5
	return 0


func _activate_setting(idx: int) -> void:
	# 되돌릴 수 없는 동작만 두 번 눌러야 실행된다 (0=튜토리얼, 3=소지금은 그냥 실행)
	if idx != 0 and idx != 3 and idx != 4 and idx != 5 and confirm_idx != idx:
		confirm_idx = idx
		refresh()
		return
	confirm_idx = -1
	match idx:
		0:
			close()
			game.start_tutorial()
		1:
			game.restart_day()
		2:
			game.reset_save()
			refresh()
		3:
			game.grant_test_money()
			refresh()
		4:
			game.cycle_shake_level()
			refresh()
		_:
			close()
			game.replay_unlock_cutscenes()


func _on_setting_input(event: InputEvent, idx: int) -> void:
	if event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		if mb.pressed and mb.button_index == MOUSE_BUTTON_LEFT:
			row = idx
			_activate_setting(idx)


func _on_setting_hover(idx: int) -> void:
	if row != idx:
		row = idx
		confirm_idx = -1
		refresh()


func _draw_settings() -> void:
	var items := [
		{
			"name": "튜토리얼 다시 보기",
			"desc": "조작 안내를 인게임에서 단계별로 다시 띄운다. 진행 중인 판은 그대로다.",
			"warn": "",
		},
		{
			"name": "이번 판 다시 시작",
			"desc": "수익 · 업그레이드 · 배달 기록을 버리고 1일차를 처음부터. 도전과제는 유지된다.",
			"warn": "한 번 더 누르면 지금 판이 사라집니다",
		},
		{
			"name": "기록 초기화",
			"desc": "최고 기록과 도전과제 달성 기록을 전부 삭제한다.",
			"warn": "되돌릴 수 없습니다. 한 번 더 누르면 삭제됩니다",
		},
			{
			"name": "테스트용 소지금 1,000만원",
			"desc": "소지금을 10,000,000원으로 맞추고 구역 해금을 갱신한다. 테스트용이다.",
			"warn": "",
		},
		{
			"name": "화면 흔들림: %s" % ["끔", "약하게", "강하게"][game.shake_level],
			"desc": "충돌·격파 때 화면이 흔들리고 순간 멎는 정도. 멀미가 나면 줄이거나 끈다.",
			"warn": "",
		},
		{
			"name": "해금 연출 다시 보기",
			"desc": "배그 전장(총 구매)과 마초 트럭장(펀치 기계 구매) 연출을 차례로 보여준다.",
			"warn": "",
		},
]
	for i in items.size():
		var it: Dictionary = items[i]
		var slot := VBoxContainer.new()
		slot.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		slot.mouse_filter = Control.MOUSE_FILTER_STOP
		slot.add_theme_constant_override("separation", 2)
		slot.gui_input.connect(_on_setting_input.bind(i))
		slot.mouse_entered.connect(_on_setting_hover.bind(i))
		_body.add_child(slot)
		if i == row:
			_selected_node = slot
		slot.add_child(_mk("%s %s" % ["▶" if i == row else "  ", String(it["name"])], 28,
			Color(1, 0.9, 0.35) if i == row else Color(0.88, 0.9, 1.0)))
		var d := _mk("        " + String(it["desc"]), 20, Color(0.72, 0.76, 0.9))
		d.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		d.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		slot.add_child(d)
		if confirm_idx == i:
			slot.add_child(_mk("        " + String(it["warn"]), 22, Color(1.0, 0.4, 0.4)))
		else:
			slot.add_child(_mk("        SPACE 또는 클릭", 20, Color(0.5, 0.52, 0.65)))
		var gap := Control.new()
		gap.custom_minimum_size = Vector2(0, 16)
		gap.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_body.add_child(gap)

	var note := _mk("현재 최고 기록 %s원  ·  도전과제 %d / %d" % [
		game._won(game.best_score), _achieved_count(), game.ACHIEVEMENTS.size()], 22,
		Color(0.65, 0.7, 0.85))
	_body.add_child(note)


func _achieved_count() -> int:
	var n := 0
	for a in game.ACHIEVEMENTS:
		if game.achieved.get(a["key"], false):
			n += 1
	return n


func _on_tab_input(event: InputEvent, idx: int) -> void:
	if event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		if mb.pressed and mb.button_index == MOUSE_BUTTON_LEFT:
			if tab != idx:
				tab = idx
				row = 0
				confirm_idx = -1
				refresh()


func _on_row_input(event: InputEvent, idx: int) -> void:
	if event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		if mb.pressed and mb.button_index == MOUSE_BUTTON_LEFT:
			row = idx
			game.buy_upgrade(idx)
			refresh()


func _on_row_hover(idx: int) -> void:
	if row != idx:
		row = idx
		refresh()


func _on_district_input(event: InputEvent, idx: int) -> void:
	if event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		if mb.pressed and mb.button_index == MOUSE_BUTTON_LEFT:
			row = idx
			game.select_district(idx)
			refresh()


func _on_district_hover(idx: int) -> void:
	if row != idx:
		row = idx
		refresh()


func _draw_story() -> void:
	for lineText in game.STORY:
		var l := _mk(String(lineText).replace("\n", " "), 24, Color(0.92, 0.94, 1.0))
		l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		_body.add_child(l)


func _draw_tutorial() -> void:
	var sections := [
		["조작 및 사격", [
			"W  가속        S  브레이크 / 후진",
			"A / D  조향",
			"마우스 좌클릭  총알 발사 (경쟁사 배달차 격추)",
			"E  부스터 (게이지를 태워 최고속을 올린다)",
			"SHIFT  드리프트. 게이지가 차면 떼는 순간 부스터",
			"SPACE  로켓 점프",
			"H  경적 (아무 소용 없다)",
			"R  제자리 복귀 (시간은 안 돌려준다)",
			"V  시점 전환 (추격 · 본넷 · 운전석 · 탑뷰 · 측면 · 무지개 환각)",
			"마우스 좌클릭  배그 전장은 사격, 마초 트럭장은 주먹",
			"마우스 우클릭  배그 전장은 1인칭 레드닷(1.5배). 물고 있는 동안 마우스로 시선 이동",
			"F  주먹 (마초 트럭장 전용)",
			"게임패드  좌스틱 조향 · RT 가속 · LT 브레이크 · A 점프 · X 부스터",
		]],
		["경쟁사 배달차 & 사격", [
			"도시 도로를 돌아다니며 배달을 가로채는 적 배달차가 있습니다.",
			"마우스로 조준하고 좌클릭으로 사격하여 맞히면 데미지를 줍니다.",
			"격추 시 폭발과 함께 고액의 현금 다발을 떨어뜨립니다.",
			"한 대를 처리하면 한 대가 다시 나타납니다. 아무리 잡아도 수는 줄지 않습니다.",
			"총은 배그 전장에서만 쓸 수 있습니다. 파스텔 지구와 마초 트럭장은 사격 금지 구역입니다.",
			"마초 트럭장에서는 총 대신 트럭들이 서로 주먹다짐을 하니 멀리서 구경하세요.",
		]],
		["구역 해금 (누적 수익)", [
			"게임을 진행하며 번 모든 돈은 누적 수익으로 영구 보존됩니다.",
			"누적 수익이 기준치를 넘으면 상위 구역이 자동으로 열립니다.",
			"상위 구역일수록 배달 기본 보수와 팁이 대폭 증가합니다 (최대 4.0배).",
			"ESC 메뉴의 [구역] 탭에서 원하는 구역을 언제든 선택해 출근할 수 있습니다.",
		]],
		["주먹질 (마초 트럭장 전용)", [
			"마초 트럭장에서는 내 트럭에도 권투 글러브가 달린다.",
			"좌클릭 · 우클릭 · F 로 휘두른다. 쿨다운 0.55초.",
			"앞쪽 8유닛 안에 있는 트럭만 맞는다. 뒤통수는 못 때린다.",
			"한 대에 데미지 2. 마초 트럭(hp 6)은 세 대면 KO.",
			"맞은 트럭은 뒤로 밀려난다.",
			"배그 전장에서는 주먹을 못 쓴다. 거기는 총으로만 싸운다.",
		]],
		["내 트럭 체력 (마초 · 배그 전용)", [
			"이 두 구역에서만 체력이 생긴다. 좌하단에 체력 바가 뜬다.",
			"총알 -11, 마초 주먹 -16, 자기장 밖 초당 -9.",
			"회복은 초당 +7. 배그는 자기장 안, 마초는 3초간 안 맞으면 찬다.",
			"체력이 0이 되면 차가 대파되고 보유 금액의 7% 를 잃는다.",
			"평화 구역에는 체력 개념이 없다. 배달만 하면 된다.",
		]],
		["배그 패러디 구역 (자기장 & 3렙 뚝배기)", [
			"배그 전장에서는 플레이어 차량에 3렙 뚝배기(헬멧)가 장착됩니다.",
			"시간이 흐르면 맵 외곽에서 보라색 자기장 벽이 점차 좁혀옵니다.",
			"자기장 밖에서는 제한시간이 아니라 체력이 깎입니다. 안전지대로 피하세요.",
			"경쟁사 트럭도 총을 쏩니다. 다행히 조준은 형편없습니다.",
		]],
		["배달", [
			"초록 기둥으로 가서 음식을 받는다.",
			"주황 기둥의 고객에게 가져다준다.",
			"목표를 잡을 때마다 제한시간이 새로 주어진다. 누적되지 않는다.",
			"기본 60초에서 배달 1건당 1.5초씩 줄어들어 30초에서 멈춘다.",
		]],
		["음식이 식으면", [
			"제한시간이 0을 지나도 게임은 끝나지 않는다.",
			"대신 그 구간의 배달 보수가 거의 0이 된다.",
			"다음 목표에서 제한시간이 초기화되므로 그 다음 건은 정상 보수다.",
		]],
		["충돌", [
			"긁힘  —  속도만 깎이고 잔소리를 듣는다.",
			"대형사고  —  공중제비를 돌고 연속 배달이 끊긴다.",
			"연속 배달이 높을수록 보수가 크게 오른다. 박지 마라.",
		]],
		["팁", [
			"제한시간을 많이 남기고 배달할수록 팁이 붙는다.",
			"75% 이상 남기면 +30%, 55% 이상 +18%, 35% 이상 +8%.",
			"식은 배달에는 팁이 없다.",
		]],
		["스턴트", [
			"로켓 점프로 0.8초 이상 떠 있다가 착지하면 에어타임 보너스.",
			"콘이나 소 옆을 빠르게 스쳐 지나가면 아슬아슬 보너스.",
			"식은 상태에서는 스턴트 보수가 들어오지 않는다.",
		]],
		["주문 유형", [
			"배달 구간의 34% 확률로 특수 주문이 붙는다. 상단에 표시된다.",
			"VIP 주문  —  보수 2배, 제한시간 30% 삭감",
			"곱빼기  —  보수 1.4배, 차가 무거워져 느려짐",
			"국물 요리  —  보수 1.5배, 충돌 시 시간 손해 2배",
			"폭우 배송  —  보수 1.6배, 빗길에 심하게 미끄러진다. 차 방향과 진행 방향이 어긋난다",
		]],
		["RTX 5090", [
			"5의 배수번째 배달은 음식이 아니라 RTX 5090이다.",
			"보수가 훨씬 크지만 대형사고를 낼 때마다 값이 깎인다.",
			"배달통과 목표 기둥이 검정 + 형광 초록으로 바뀐다.",
		]],
	]
	for sec in sections:
		var h := _mk(String(sec[0]), 28, Color(0.4, 1.0, 0.65))
		_body.add_child(h)
		for lineText in sec[1]:
			var l := _mk("    " + String(lineText), 22, Color(0.9, 0.92, 1.0))
			l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			_body.add_child(l)
		var gap := Control.new()
		gap.custom_minimum_size = Vector2(0, 10)
		_body.add_child(gap)


func _draw_districts() -> void:
	var items: Array = City.THEMES
	row = clampi(row, 0, items.size() - 1)
	for i in items.size():
		var th: Dictionary = items[i]
		var cost: int = int(th.get("unlock_cost", 0))
		var unlocked: bool = game.is_district_unlocked(i)
		var is_current: bool = (game.selected_district == i)
		var mult: float = float(th.get("pay_mult", 1.0))

		var slot := VBoxContainer.new()
		slot.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		slot.mouse_filter = Control.MOUSE_FILTER_STOP
		slot.add_theme_constant_override("separation", 2)
		slot.gui_input.connect(_on_district_input.bind(i))
		slot.mouse_entered.connect(_on_district_hover.bind(i))
		_body.add_child(slot)
		if i == row:
			_selected_node = slot

		var prefix := "▶" if i == row else "  "
		var status_str := " [선택 중]" if is_current else (" [해금됨]" if unlocked else " [잠김]")
		var name_col := Color(1, 0.9, 0.35) if i == row else (Color(0.9, 0.95, 1.0) if unlocked else Color(0.55, 0.55, 0.65))
		slot.add_child(_mk("%s %s%s   (보수 %.1f배)" % [
			prefix, String(th["name"]), status_str, mult], 28, name_col))

		var desc_str := String(th.get("desc", ""))
		var sub := _mk("        %s" % desc_str, 20, Color(0.72, 0.76, 0.9) if unlocked else Color(0.45, 0.45, 0.55))
		sub.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		sub.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		slot.add_child(sub)

		var req_text := ""
		var req_col := Color(0.45, 1.0, 0.6)
		if is_current:
			req_text = "        현재 출근 중인 구역입니다"
			req_col = Color(0.3, 1.0, 0.6)
		elif unlocked:
			req_text = "        SPACE 또는 클릭하여 이 구역으로 출근"
			req_col = Color(1.0, 0.9, 0.35)
		else:
			var prog: float = clampf(game.career_earnings / float(maxi(1, cost)), 0.0, 1.0) * 100.0
			req_text = "        해금 조건: 누적 수익 %s원 (현재 %.0f%% 달성)" % [game._won(float(cost)), prog]
			req_col = Color(1.0, 0.45, 0.45)
		slot.add_child(_mk(req_text, 22, req_col))

		var gap := Control.new()
		gap.custom_minimum_size = Vector2(0, 12)
		gap.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_body.add_child(gap)


func _draw_upgrades() -> void:
	var items: Array = game.UPGRADES
	row = clampi(row, 0, items.size() - 1)
	for i in items.size():
		var u: Dictionary = items[i]
		var lv: int = game.upgrade_levels.get(u["key"], 0)
		var maxlv: int = u["cost"].size()
		var maxed: bool = lv >= maxlv
		var cost: int = 0 if maxed else int(u["cost"][lv])
		var afford: bool = not maxed and game.score >= float(cost)
		var pips := ""
		for k in maxlv:
			pips += "■" if k < lv else "□"

		var slot := VBoxContainer.new()
		slot.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		slot.mouse_filter = Control.MOUSE_FILTER_STOP
		slot.add_theme_constant_override("separation", 2)
		slot.gui_input.connect(_on_row_input.bind(i))
		slot.mouse_entered.connect(_on_row_hover.bind(i))
		_body.add_child(slot)
		if i == row:
			_selected_node = slot

		slot.add_child(_mk("%s %s   Lv.%d / %d   %s" % [
			"▶" if i == row else "  ", String(u["name"]), lv, maxlv, pips], 28,
			Color(1, 0.9, 0.35) if i == row else Color(0.88, 0.9, 1.0)))
		var sub := _mk("        %s  ·  %s" % [String(u["desc"]), String(u["extra"])], 20,
			Color(0.72, 0.76, 0.9))
		sub.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		sub.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		slot.add_child(sub)
		var price_text := "        최대 레벨 도달 (Lv.%d)" % maxlv
		var price_col := Color(0.45, 1.0, 0.6)
		if not maxed:
			price_text = "        Lv.%d 로 올리기 — %s원" % [lv + 1, game._won(float(cost))]
			price_col = Color(1, 0.9, 0.35) if afford else Color(1.0, 0.45, 0.45)
		slot.add_child(_mk(price_text, 22, price_col))

		var gap := Control.new()
		gap.custom_minimum_size = Vector2(0, 10)
		gap.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_body.add_child(gap)


func _draw_achievements() -> void:
	var items: Array = game.ACHIEVEMENTS
	var got := 0
	for a in items:
		if game.achieved.get(a["key"], false):
			got += 1
	_body.add_child(_mk("달성 %d / %d" % [got, items.size()], 26, Color(1, 0.9, 0.35)))
	var gap0 := Control.new()
	gap0.custom_minimum_size = Vector2(0, 10)
	_body.add_child(gap0)
	for a in items:
		var on: bool = game.achieved.get(a["key"], false)
		var mark := "달성" if on else "잠김"
		var l := _mk("[%s]  %s" % [mark, String(a["name"]) if on else "???"], 25,
			Color(0.4, 1.0, 0.65) if on else Color(0.5, 0.5, 0.62))
		_body.add_child(l)
		var d := _mk("        " + String(a["desc"]), 20,
			Color(0.85, 0.88, 1.0) if on else Color(0.42, 0.42, 0.55))
		_body.add_child(d)
