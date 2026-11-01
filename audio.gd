extends Node

const MENU_SONGS := [
	"res://SDaudio/menu1.ogg",
	"res://SDaudio/menu2.ogg",
	"res://SDaudio/menu3.ogg",
]
const BATTLE_SONGS := [
	"res://SDaudio/battle1.ogg",
	"res://SDaudio/battle2.ogg",
	"res://SDaudio/battle3.ogg",
]
const CLICK_SFX := ["res://SDaudio/button1.wav"]
const BATTLEBUTTON_SFX := ["res://SDaudio/button2.wav"]
const COUNTDOWN_SFX := ["res://SDaudio/countdown.wav"]
const ULTIMATE_SFX := ["res://SDaudio/ultimate.wav"]
const WIN_SFX := ["res://SDaudio/win.wav"]
const LOSE_SFX := ["res://SDaudio/lose.wav"]

var music: AudioStreamPlayer
var sfx_players: Array[AudioStreamPlayer] = []
var playlist: Array = []
var current_track := ""
var music_volume := 0.8
var sfx_volume := 1.0
var _cache := {}

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	music = AudioStreamPlayer.new()
	add_child(music)
	music.finished.connect(_next_song)
	for i in 8:
		var p := AudioStreamPlayer.new()
		add_child(p)
		sfx_players.append(p)
	set_music_volume(music_volume)
	get_tree().node_added.connect(_on_node_added)

# ---------- Music playlists ----------

func play_menu_music() -> void:
	_play_list(MENU_SONGS)

func play_battle_music() -> void:
	_play_list(BATTLE_SONGS)

func _play_list(songs: Array) -> void:
	music.stream_paused=false
	if music.playing and playlist == songs:
		return
	playlist = songs
	_next_song()

func _next_song() -> void:
	if playlist.is_empty():
		return
	var choices: Array = playlist.duplicate()
	if choices.size() > 1:
		choices.erase(current_track)
	var path: String = choices.pick_random()
	var s := _load(path)
	if s == null:
		return
	current_track = path
	music.stream = s
	music.play()

func stop_music() -> void:
	playlist = []
	music.stop()
	current_track = ""

func set_music_volume(v: float) -> void:
	music_volume = clampf(v, 0.0, 1.0)
	music.volume_db = linear_to_db(maxf(music_volume, 0.0001))
	
func pause_music() -> void:
	music.stream_paused = true

func resume_music() -> void:
	music.stream_paused = false

# ---------- Sound effects ----------

## Accepts one path (String) or a list of paths (Array, a random one is played).
func play_sfx(sound, pitch := 1.0) -> void:
	var path := ""
	if sound is Array:
		if sound.is_empty():
			return
		path = sound.pick_random()
	else:
		path = str(sound)
	var s := _load(path)
	if s == null:
		return
	for p in sfx_players:
		if not p.playing:
			p.stream = s
			p.pitch_scale = pitch
			p.volume_db = linear_to_db(maxf(sfx_volume, 0.0001))
			p.play()
			return

func click() -> void:
	play_sfx(CLICK_SFX, randf_range(0.97, 1.03))

# ---------- Every button clicks automatically ----------

func _on_node_added(n: Node) -> void:
	if n is Button:
		n.pressed.connect(func(): _button_sound(n))

func _button_sound(b: Button) -> void:
	var snd = b.get_meta("sfx", CLICK_SFX)
	play_sfx(snd, randf_range(0.97, 1.03))

func _load(path: String) -> AudioStream:
	if _cache.has(path):
		return _cache[path]
	if not ResourceLoader.exists(path):
		push_warning("Audio file not found: " + path)
		return null
	var s: AudioStream = load(path)
	_cache[path] = s
	return s
