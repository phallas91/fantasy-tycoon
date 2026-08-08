extends Node
## Local re-engagement notifications (autoload: Notifications) via the
## NotificationScheduler plugin. The #1 retention lever for an idle game: while the
## player is away, remind them when their offline warehouse fills up and when a
## fresh daily reward unlocks — then clear those reminders the moment they return.
##
## Guarded: only active on Android with the native plugin present. In the editor,
## on desktop, or in a build without the plugin, every method no-ops. Needs NO
## Play Console setup — only the runtime POST_NOTIFICATIONS permission (Android 13+),
## which is requested once and, if denied, simply means no reminders show (no crash).
##
## Respects the "Notifications" toggle in Settings (Fx.notifications_enabled).

const CHANNEL_ID := "reminders"
const ID_WAREHOUSE := 1001
const ID_DAILY := 1002
const MIN_WAREHOUSE_DELAY := 600   # don't nag for a warehouse that fills in <10 min

var _sched: NotificationScheduler
var _active := false

func _ready() -> void:
	if OS.get_name() != "Android":
		return
	_sched = NotificationScheduler.new()
	add_child(_sched)
	_sched.initialization_completed.connect(_on_init)
	_sched.initialize()

func _on_init() -> void:
	_active = true
	var ch := NotificationChannel.new()
	ch.set_id(CHANNEL_ID)
	ch.set_name(tr("Lembretes"))
	ch.set_importance(NotificationChannel.Importance.DEFAULT)
	_sched.create_notification_channel(ch)
	if not _sched.has_post_notifications_permission():
		_sched.request_post_notifications_permission()   # fire-and-forget; denial is fine
	_cancel_all()   # the player is here right now — nothing pending

## Player is leaving — arm the reminders (unless disabled in Settings).
func _schedule_reminders() -> void:
	if not _active:
		return
	_cancel_all()
	if not Fx.notifications_enabled:
		return
	# 1) offline warehouse fills up at the offline cap → come back to not waste time
	var cap := int(GameState.offline_cap())
	if cap >= MIN_WAREHOUSE_DELAY and GameState.income_per_sec() > 0.0:
		var n := NotificationData.new()
		n.set_id(ID_WAREHOUSE)
		n.set_channel_id(CHANNEL_ID)
		n.set_title(tr("🦅 Cofre comercial cheio!"))
		n.set_content(tr("Os teus grifos completaram as entregas. Volta para recolher os lucros!"))
		n.set_delay(cap)
		_sched.schedule(n)
	# 2) a fresh daily reward unlocks at the next local midnight
	var secs := _seconds_to_next_midnight()
	if secs > 0:
		var d := NotificationData.new()
		d.set_id(ID_DAILY)
		d.set_channel_id(CHANNEL_ID)
		d.set_title(tr("🎁 Recompensa diária pronta"))
		d.set_content(tr("A tua recompensa diária está à espera. Entra e reclama!"))
		d.set_delay(secs)
		_sched.schedule(d)

func _cancel_all() -> void:
	if _active:
		_sched.cancel(ID_WAREHOUSE)
		_sched.cancel(ID_DAILY)

## Seconds from now until the next local 00:00.
func _seconds_to_next_midnight() -> int:
	var t := Time.get_datetime_dict_from_system()
	var remaining := (23 - int(t["hour"])) * 3600 + (59 - int(t["minute"])) * 60 + (60 - int(t["second"]))
	return maxi(remaining, 60)

func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_PAUSED or what == NOTIFICATION_WM_CLOSE_REQUEST:
		_schedule_reminders()   # backgrounded/closing — set the hooks
	elif what == NOTIFICATION_APPLICATION_RESUMED:
		_cancel_all()           # back in the app — clear them
