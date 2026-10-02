extends SceneTree

const MAIN_SCENE := preload("res://main.tscn")
const RUST_CRAWLER := preload("res://scripts/enemies/rust_crawler.gd")
const OXYGEN_WISP := preload("res://scripts/enemies/oxygen_wisp.gd")
const IRON_SENTINEL := preload("res://scripts/enemies/iron_sentinel.gd")

var failures: Array[String] = []

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var world := MAIN_SCENE.instantiate()
	root.add_child(world)
	await _frames(8)
	var crawler := world.get_node("Zone0/RustCrawler_0A")
	var wisp := world.get_node("Zone1/OxygenWisp_1A")
	var sentinel := world.get_node("Zone2/IronSentinel_2A")
	_expect(crawler is RUST_CRAWLER, "Rust crawler was not spawned in Zone 0")
	_expect(wisp is OXYGEN_WISP, "Oxygen wisp was not spawned in Zone 1")
	_expect(sentinel is IRON_SENTINEL, "Iron sentinel was not spawned in Zone 2")
	_expect(crawler.health == 155.0, "Rust crawler health profile is incorrect")
	_expect(wisp.health == 90.0, "Oxygen wisp health profile is incorrect")
	_expect(sentinel.shield == 80.0, "Iron sentinel shield profile is incorrect")
	crawler.take_element_damage(10.0, "oxygen")
	_expect(is_equal_approx(crawler.health, 147.5), "Rust crawler oxygen weakness is incorrect")
	_expect(crawler.hit_time > 0.0, "Rust crawler did not enter hit reaction")
	wisp.take_element_damage(10.0, "carbon")
	_expect(is_equal_approx(wisp.health, 77.5), "Oxygen wisp carbon weakness is incorrect")
	_expect(wisp.hit_time > 0.0, "Oxygen wisp did not enter hit reaction")
	sentinel.take_element_damage(10.0, "iron")
	_expect(is_equal_approx(sentinel.shield, 74.5), "Iron sentinel shield did not absorb iron damage")
	_expect(sentinel.hit_time > 0.0, "Iron sentinel did not enter hit reaction")
	_expect(world.zone_enemy_remaining[0] == 3 and world.zone_enemy_remaining[1] == 4 and world.zone_enemy_remaining[2] == 6, "Enemy counts do not include the new trio and final boss")
	crawler._defeat()
	wisp._defeat()
	sentinel._defeat()
	await _frames(50)
	_expect(world.get_node_or_null("Zone0/RustCrawler_0A") == null, "Rust crawler death animation did not finish")
	_expect(world.get_node_or_null("Zone1/OxygenWisp_1A") == null, "Oxygen wisp death animation did not finish")
	_expect(world.get_node_or_null("Zone2/IronSentinel_2A") == null, "Iron sentinel death animation did not finish")
	world.free()
	await process_frame
	if failures.is_empty():
		print("PASS: three new enemy types spawn, expose profiles, resist elements, and count toward objectives")
		quit(0)
	for failure in failures:
		push_error(failure)
	quit(1)

func _frames(count: int) -> void:
	for _frame in range(count):
		await physics_frame

func _expect(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)
