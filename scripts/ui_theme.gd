extends RefCounted
class_name UITheme
## Arcane Trade Empire — obsidian, royal-violet and antique-gold UI theme.
## Glassmorphic, depth-layered, mobile-first. StyleBoxFlat only — depth is faked
## with lightened top borders (top-lighting), Shadow-Navy drop shadows and a
## standardized corner-radius scale.

# ── palette (final hex set) ───────────────────────────────────────────────────
const BG0      := Color(0.025, 0.016, 0.035)   # Obsidian
const BG1      := Color(0.075, 0.043, 0.105)   # Midnight plum
const PANEL    := Color(0.105, 0.067, 0.137)   # Smoked amethyst
const PANEL2   := Color(0.153, 0.098, 0.196)   # Raised amethyst
const BORDER   := Color(0.330, 0.235, 0.365)   # Rune hairline
const INK      := Color(0.969, 0.941, 0.875)   # Parchment
const MUTED    := Color(0.650, 0.590, 0.680)   # Lavender ash
const ACCENT   := Color(0.608, 0.333, 0.780)   # Royal arcane violet
const ACCENT_D := Color(0.365, 0.165, 0.510)   # Deep arcane violet
const GREEN    := Color(0.275, 0.780, 0.576)   # Alchemy mint
const GREEN_D  := Color(0.110, 0.475, 0.337)
const GOLD     := Color(0.941, 0.737, 0.345)   # Antique gold
const GOLD_D   := Color(0.635, 0.408, 0.125)
const CYAN     := Color(0.255, 0.765, 0.780)   # Mana teal
const VIOLET   := Color(0.694, 0.427, 0.914)   # Prestige violet
const PRESTIGE := Color(0.608, 0.420, 1.000)   # Prestige  (== Violet)
const ORANGE   := Color(1.000, 0.478, 0.180)   # Orange    #FF7A2E
const RED      := Color(1.000, 0.353, 0.373)   # Coral     #FF5A5F
const PINK     := Color(1.000, 0.435, 0.710)   # Magenta   #FF6FB5

# ── premium-depth constants ───────────────────────────────────────────────────
const SHADOW   := Color(0.025, 0.012, 0.035)   # Enchanted shadow
const GLOSS    := Color(1.0, 1.0, 1.0, 0.16)   # top-edge highlight layer (fx shimmer ref)
const AMBER    := Color(0.961, 0.651, 0.137)   # Amber #F5A623 (cargo / value family)

# ── corner-radius scale (single source of truth) ──────────────────────────────
const R_CHIP   := 12
const R_BTN    := 14
const R_CARD   := 18
const R_POPUP  := 24

# ── type ramp (expose so labels stop using ad-hoc sizes) ──────────────────────
const FS_DISPLAY := 32
const FS_H1      := 24
const FS_H2      := 20
const FS_BODY    := 16
const FS_CAPTION := 13

# ── category → color map (single source of truth so the palette never drifts) ─
const CAT := {
	"fleet":   ACCENT,
	"cities":  CYAN,
	"talents": VIOLET,
	"value":   AMBER,
	"cargo":   AMBER,
	"shop":    CYAN,
	"money":   GOLD,
	"events":  ORANGE,
}

## Resolve a category key to its accent color. Falls back to ACCENT.
static func cat_color(key: String) -> Color:
	if CAT.has(key):
		var c: Color = CAT[key]
		return c
	return ACCENT

static func font(weight := "SemiBold") -> FontFile:
	return load("res://assets/fonts/Poppins-%s.ttf" % weight)

static func build() -> Theme:
	var t := Theme.new()
	t.default_font = font("SemiBold"); t.default_font_size = 26
	t.set_stylebox("normal",   "Button", _btn(ACCENT))
	t.set_stylebox("hover",    "Button", _btn(ACCENT.lightened(0.10)))
	t.set_stylebox("pressed",  "Button", _btn(ACCENT_D))
	t.set_stylebox("disabled", "Button", _btn(PANEL2))
	t.set_stylebox("focus",    "Button", StyleBoxEmpty.new())
	t.set_color("font_color",          "Button", Color.WHITE)
	t.set_color("font_hover_color",    "Button", Color.WHITE)
	t.set_color("font_pressed_color",  "Button", Color(0.84, 0.90, 1.0))
	t.set_color("font_disabled_color", "Button", MUTED)
	t.set_font("font", "Button", font("Bold")); t.set_font_size("font_size", "Button", FS_H1)
	t.set_stylebox("panel", "PanelContainer", _panel(PANEL, R_CARD))
	t.set_stylebox("panel", "Panel", _panel(PANEL, R_CARD))
	t.set_color("font_color", "Label", INK)
	t.set_color("font_color", "CheckButton", INK)
	t.set_font_size("font_size", "CheckButton", FS_H1)
	t.set_stylebox("normal", "CheckButton", StyleBoxEmpty.new())
	return t

# ── base helpers ─────────────────────────────────────────────────────────────

## Shadow-Navy drop shadow with tunable alpha (premium, never pure black).
static func _shadow(s: StyleBoxFlat, alpha: float, size: int, off := Vector2(0, 4)) -> void:
	s.shadow_color = Color(SHADOW.r, SHADOW.g, SHADOW.b, alpha)
	s.shadow_size = size
	s.shadow_offset = off

## Colored glow shadow (for emissive / accent elements).
static func _glow(s: StyleBoxFlat, col: Color, alpha: float, size: int, off := Vector2(0, 4)) -> void:
	s.shadow_color = Color(col.r, col.g, col.b, alpha)
	s.shadow_size = size
	s.shadow_offset = off

## 1px top inner-highlight that fakes consistent top-lighting on a surface.
static func _top_light(s: StyleBoxFlat, base: Color, amount := 0.22) -> void:
	s.border_color = base.lightened(amount)
	s.border_width_top = 1

static func _btn(bg: Color) -> StyleBoxFlat:
	var s := StyleBoxFlat.new(); s.bg_color = bg; s.set_corner_radius_all(R_BTN)
	s.content_margin_left = 18; s.content_margin_right = 18
	s.content_margin_top = 13; s.content_margin_bottom = 13
	s.border_color = bg.lightened(0.30); s.border_width_top = 2
	_shadow(s, 0.45, 8)
	return s

static func _panel(bg: Color, radius: int) -> StyleBoxFlat:
	var s := StyleBoxFlat.new(); s.bg_color = bg; s.set_corner_radius_all(radius)
	s.set_content_margin_all(16)
	# Hairline frame + brighter top edge for top-lighting.
	s.border_color = BORDER; s.set_border_width_all(1)
	s.border_width_top = 1
	_shadow(s, 0.38, 8)
	return s

## Build a vertical 2-stop gradient as a small GradientTexture2D (for TextureRect
## fills where a StyleBox cannot express a gradient). top -> bottom.
static func vgrad_tex(c_top: Color, c_bot: Color, height := 64) -> GradientTexture2D:
	var g := Gradient.new()
	g.set_color(0, c_top)
	g.set_color(1, c_bot)
	var tex := GradientTexture2D.new()
	tex.gradient = g
	tex.fill_from = Vector2(0, 0)
	tex.fill_to = Vector2(0, 1)
	tex.width = 4
	tex.height = height
	return tex

## StyleBoxFlat approximation of a vertical gradient: mid fill + lightened top
## border (gloss cap) + darkened drop edge. Use where a real gradient isn't
## available. `radius` defaults to the card scale.
static func gradient_box(c_top: Color, c_bot: Color, radius := R_CARD) -> StyleBoxFlat:
	var mid := c_top.lerp(c_bot, 0.5)
	var s := StyleBoxFlat.new(); s.bg_color = mid; s.set_corner_radius_all(radius)
	s.set_content_margin_all(12)
	s.border_color = c_top.lightened(0.10)
	s.border_width_top = 2
	s.border_width_left = 0; s.border_width_right = 0; s.border_width_bottom = 0
	_shadow(s, 0.40, 8)
	return s

# ── public style functions ────────────────────────────────────────────────────

## Frosted-glass panel (for HUD overlay on the map).
static func glass() -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = Color(PANEL.r, PANEL.g, PANEL.b, 0.86); s.set_corner_radius_all(R_POPUP)
	s.set_content_margin_all(14)
	s.border_color = Color(GOLD.r, GOLD.g, GOLD.b, 0.30); s.set_border_width_all(1)
	# Bright frosted top rim.
	s.border_color = Color(1.0, 0.86, 0.58, 0.42)
	s.border_width_top = 1
	_shadow(s, 0.50, 16, Vector2(0, 6))
	return s

## Card with accent-tinted background, left category rail and glowing border.
static func action_card(accent: Color) -> StyleBoxFlat:
	var base := PANEL2.lerp(accent, 0.12)
	var s := StyleBoxFlat.new(); s.bg_color = base; s.set_corner_radius_all(R_CARD)
	s.set_content_margin_all(12)
	s.content_margin_left = 14
	# Tint dialed 0.55 -> 0.35: at 0.55 the full 1px frame lerped so far toward the
	# accent that warm cards (amber/green) framed visibly brighter than cool ones
	# (blue/cyan), so a stack didn't read as one card family. 0.35 keeps accent
	# identity (it still lives in the 3px left rail + icon badge) but evens the frame.
	s.border_color = lerp(BORDER, accent, 0.35); s.set_border_width_all(1)
	# Brighter top edge (top-light) + 3px left accent rail for instant scanning.
	s.border_width_top = 1
	s.border_width_left = 3
	_glow(s, accent, 0.28, 12, Vector2(0, 5))
	return s

## Full-width action button (buy / unlock) with fintech faux-gradient look.
static func action_btn(color: Color) -> StyleBoxFlat:
	var s := StyleBoxFlat.new(); s.bg_color = color; s.set_corner_radius_all(R_BTN)
	s.content_margin_left = 12; s.content_margin_right = 12
	s.content_margin_top = 12; s.content_margin_bottom = 12
	# Lighter top border + darker base edge = vertical-gradient illusion.
	s.border_color = color.lightened(0.34); s.border_width_top = 2
	_glow(s, color, 0.42, 10, Vector2(0, 4))
	return s

## "Buyable now" variant: brighter rim + stronger colored bloom to pull the eye.
static func action_btn_affordable(color: Color) -> StyleBoxFlat:
	var s := action_btn(color)
	s.bg_color = color.lightened(0.06)
	s.border_color = color.lightened(0.45); s.border_width_top = 2
	_glow(s, color, 0.55, 16, Vector2(0, 4))
	return s

## Disabled buy button: keep cost legible (dim panel + muted text upstream).
static func action_btn_disabled() -> StyleBoxFlat:
	var s := StyleBoxFlat.new(); s.bg_color = PANEL2.darkened(0.12); s.set_corner_radius_all(R_BTN)
	s.content_margin_left = 12; s.content_margin_right = 12
	s.content_margin_top = 12; s.content_margin_bottom = 12
	s.border_color = BORDER; s.set_border_width_all(1)
	_shadow(s, 0.25, 4)
	return s

## Segmented control button (x1 / x10 / x100 / Max).
static func seg(active: bool) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = ACCENT if active else PANEL2; s.set_corner_radius_all(R_BTN)
	s.content_margin_left = 10; s.content_margin_right = 10
	s.content_margin_top = 11; s.content_margin_bottom = 11
	if active:
		s.border_color = ACCENT.lightened(0.34); s.border_width_top = 2
		_glow(s, ACCENT, 0.42, 10)
	else:
		# was a flat BORDER frame — the only raised chip in the theme without the
		# 1px top-light rim, so inactive segments read as dead holes next to Max.
		# Match stat_chip/pill: a subtle white top gloss so they read as raised toggles.
		s.border_color = Color(1.0, 1.0, 1.0, 0.08); s.border_width_top = 1
	return s

## Bottom-panel background (rounded top, flat bottom).
static func bottom_panel() -> StyleBoxFlat:
	var s := StyleBoxFlat.new(); s.bg_color = Color(BG1.r, BG1.g, BG1.b, 0.94)
	s.corner_radius_top_left = R_POPUP; s.corner_radius_top_right = R_POPUP
	s.set_content_margin_all(0)
	s.border_color = Color(GOLD.r, GOLD.g, GOLD.b, 0.22); s.border_width_top = 1
	# Shadow casts upward (nav floats above content).
	_shadow(s, 0.50, 18, Vector2(0, -6))
	return s

## Nav bar item – active or inactive.
static func nav_item(active: bool) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = Color(GOLD.r, GOLD.g, GOLD.b, 0.11 if active else 0.0)
	s.set_corner_radius_all(R_CARD); s.set_content_margin_all(6)
	if active:
		s.border_color = Color(GOLD.r, GOLD.g, GOLD.b, 0.42)
		s.border_width_top = 1
		_glow(s, GOLD, 0.22, 10, Vector2(0, 2))
	return s

## Generic solid colour box (popups, badges, etc.).
static func solid(bg: Color, radius := R_BTN) -> StyleBoxFlat:
	var s := StyleBoxFlat.new(); s.bg_color = bg; s.set_corner_radius_all(radius)
	s.content_margin_left = 14; s.content_margin_right = 14
	s.content_margin_top = 10; s.content_margin_bottom = 10
	s.border_color = bg.lightened(0.26); s.border_width_top = 2
	_shadow(s, 0.32, 5, Vector2(0, 3))
	return s

## Kept for compat (aliases action_card).
static func card(accent: Color) -> StyleBoxFlat: return action_card(accent)

## Kept for compat — glossy full-radius pill.
static func pill(bg := PANEL) -> StyleBoxFlat:
	var s := StyleBoxFlat.new(); s.bg_color = bg; s.set_corner_radius_all(R_POPUP)
	s.content_margin_left = 14; s.content_margin_right = 16
	s.content_margin_top = 8; s.content_margin_bottom = 8
	s.border_color = BORDER; s.set_border_width_all(1)
	# 1px white top-rim = glossy pill highlight.
	s.border_color = Color(1.0, 1.0, 1.0, 0.10)
	s.border_width_top = 1
	return s

## Glossy HUD stat chip: 1px white top-rim, subtle navy drop.
static func stat_chip(accent := ACCENT) -> StyleBoxFlat:
	var s := StyleBoxFlat.new(); s.bg_color = PANEL2; s.set_corner_radius_all(R_CHIP)
	s.content_margin_left = 12; s.content_margin_right = 12
	s.content_margin_top = 7; s.content_margin_bottom = 7
	s.border_color = Color(1.0, 1.0, 1.0, 0.12); s.border_width_top = 1
	_glow(s, accent, 0.16, 6, Vector2(0, 3))
	return s

## Hero variant of stat_chip — bigger padding + stronger glow, reserved for the
## HUD's primary currency (credits) so it visually outranks the secondary chips.
static func hero_chip(accent := GOLD) -> StyleBoxFlat:
	var s := stat_chip(accent)
	s.content_margin_left = 16; s.content_margin_right = 16
	s.content_margin_top = 10; s.content_margin_bottom = 10
	_glow(s, accent, 0.32, 12, Vector2(0, 4))
	return s

## Toast: glass body + left accent border + accent leading glow.
static func toast(accent := ACCENT) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = Color(0.102, 0.141, 0.251, 0.94); s.set_corner_radius_all(R_BTN)
	s.set_content_margin_all(14)
	s.content_margin_left = 16
	s.border_color = accent; s.border_width_left = 4
	s.border_width_top = 1
	_glow(s, accent, 0.30, 14, Vector2(0, 4))
	return s

## Popup / holo-frame: raised body, glowing accent top-border, navy bloom
## (instead of flat black) so popups read as lit holo surfaces.
static func popup_frame(accent := ACCENT) -> StyleBoxFlat:
	var s := StyleBoxFlat.new(); s.bg_color = PANEL2; s.set_corner_radius_all(R_POPUP)
	s.set_content_margin_all(18)
	s.border_color = BORDER; s.set_border_width_all(1)
	# Glowing accent top-border.
	s.border_color = Color(accent.r, accent.g, accent.b, 0.65)
	s.border_width_top = 2
	_glow(s, accent, 0.28, 22, Vector2(0, 6))
	return s

## Uppercase letter-spaced section header rule background (thin hairline divider).
static func section_rule() -> StyleBoxFlat:
	var s := StyleBoxFlat.new(); s.bg_color = BORDER
	s.set_corner_radius_all(2)
	s.content_margin_top = 1; s.content_margin_bottom = 1
	return s

## Prestige shop / prestige info card — violet rim + faint star-field tone.
static func prestige_card() -> StyleBoxFlat:
	var base := PANEL2.lerp(VIOLET, 0.16)
	var s := StyleBoxFlat.new(); s.bg_color = base; s.set_corner_radius_all(R_CARD)
	s.set_content_margin_all(12)
	s.border_color = Color(PRESTIGE.r, PRESTIGE.g, PRESTIGE.b, 0.60); s.set_border_width_all(1)
	s.border_width_top = 1
	_glow(s, PRESTIGE, 0.28, 12, Vector2(0, 5))
	return s

## Event banner (colored left border + tinted glass).
static func event_banner(col: Color) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = Color(col.r, col.g, col.b, 0.16); s.set_corner_radius_all(R_BTN)
	s.set_content_margin_all(12)
	s.content_margin_left = 14
	s.border_color = col; s.border_width_left = 4
	s.border_width_top = 1
	s.border_color = col
	_glow(s, col, 0.22, 10, Vector2(0, 3))
	return s

## Achievement card.
static func achievement_card(done: bool) -> StyleBoxFlat:
	var bg := PANEL2 if not done else PANEL2.lerp(GREEN, 0.16)
	var s := _panel(bg, R_BTN); s.set_content_margin_all(10)
	if done:
		s.border_color = Color(GREEN.r, GREEN.g, GREEN.b, 0.55); s.set_border_width_all(1)
		s.border_width_top = 1
		_glow(s, GREEN, 0.20, 8, Vector2(0, 3))
	else:
		s.border_color = BORDER; s.set_border_width_all(1)
	return s

## Progress bar background (trough).
static func prog_bg() -> StyleBoxFlat:
	var s := StyleBoxFlat.new(); s.bg_color = PANEL.darkened(0.10); s.set_corner_radius_all(R_CHIP)
	s.border_color = BORDER; s.set_border_width_all(1)
	return s

## Progress bar fill (colour = accent/green/gold based on context).
## Flat 3px radius: R_CHIP made sub-pixel fills render as floating glow dots.
static func prog_fill(col: Color) -> StyleBoxFlat:
	var s := StyleBoxFlat.new(); s.bg_color = col; s.set_corner_radius_all(3)
	s.border_color = col.lightened(0.30); s.border_width_top = 1
	_glow(s, col, 0.55, 9, Vector2(0, 0))
	return s

## Daily reward card.
static func daily_card(claimed: bool, current: bool) -> StyleBoxFlat:
	var bg: Color
	if claimed:   bg = PANEL2.lerp(GREEN, 0.16)
	elif current: bg = PANEL2.lerp(GOLD, 0.18)
	else:         bg = PANEL2
	var s := _panel(bg, R_BTN); s.set_content_margin_all(8)
	if current:
		s.border_color = GOLD; s.set_border_width_all(2)
		_glow(s, GOLD, 0.45, 12, Vector2(0, 4))
	elif claimed:
		s.border_color = Color(GREEN.r, GREEN.g, GREEN.b, 0.45); s.set_border_width_all(1)
	else:
		s.border_color = BORDER; s.set_border_width_all(1)
	return s

## Quiet outline variant for destructive triggers that should not scream.
static func danger_outline() -> StyleBoxFlat:
	var s := StyleBoxFlat.new(); s.bg_color = Color(0, 0, 0, 0)
	s.set_corner_radius_all(R_BTN)
	s.content_margin_left = 18; s.content_margin_right = 18
	s.content_margin_top = 13; s.content_margin_bottom = 13
	s.border_color = RED; s.set_border_width_all(1)
	return s

## Danger / destructive button (prestige confirm, wipe).
static func danger_btn() -> StyleBoxFlat:
	var s := StyleBoxFlat.new(); s.bg_color = RED.darkened(0.38); s.set_corner_radius_all(R_BTN)
	s.content_margin_left = 16; s.content_margin_right = 16
	s.content_margin_top = 12; s.content_margin_bottom = 12
	s.border_color = RED.lightened(0.22); s.border_width_top = 2
	_glow(s, RED, 0.42, 10, Vector2(0, 4))
	return s

## Circular icon backdrop for a row's leading icon: an accent-tinted disc with
## a glow, sized so a smaller icon sits centered inside it via content margin
## (the "icon chip" AAA mobile games use instead of a bare floating glyph).
static func icon_badge(accent: Color, sz: int, icon_sz: int) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = PANEL2.lerp(accent, 0.30); s.set_corner_radius_all(sz / 2)
	var pad := float(sz - icon_sz) / 2.0
	s.content_margin_left = pad; s.content_margin_right = pad
	s.content_margin_top = pad; s.content_margin_bottom = pad
	s.border_color = Color(accent.r, accent.g, accent.b, 0.55); s.set_border_width_all(1)
	s.border_width_top = 1
	_glow(s, accent, 0.26, 8, Vector2(0, 2))
	return s

## Glowing "ready to prestige" button (gets shimmer + breathe from fx).
static func prestige_btn_ready() -> StyleBoxFlat:
	var s := StyleBoxFlat.new(); s.bg_color = VIOLET.darkened(0.30); s.set_corner_radius_all(R_CARD)
	s.content_margin_left = 18; s.content_margin_right = 18
	s.content_margin_top = 14; s.content_margin_bottom = 14
	s.border_color = PRESTIGE.lightened(0.28); s.border_width_top = 2
	_glow(s, PRESTIGE, 0.55, 18, Vector2(0, 4))
	return s
