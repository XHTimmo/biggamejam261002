extends RefCounted

const IDS := ["hydrogen", "oxygen", "carbon", "iron"]
const NAMES := ["氢", "氧", "碳", "铁"]
const TINTS := [Color("#b7f1f5"), Color("#8aceda"), Color("#dfbd7d"), Color("#b3bac8")]
const WEAPONS := ["压缩气枪 · 氢瓶", "压缩气枪 · 氧瓶", "固体发射器 · 石墨匣", "固体发射器 · 铁芯匣"]
const NORMAL_NAMES := ["氢泡弹", "氧气弹", "石墨散粒", "铁丸"]
const CHARGED_NAMES := ["聚束氢环", "压缩氧核", "压制碳块", "致密铁芯"]
const NORMAL_DAMAGE := [8.0, 12.0, 12.0, 18.0]
const CHARGED_DAMAGE := [20.0, 70.0, 26.0, 55.0]
const MAGAZINE_CAPACITY := [12, 12, 6, 6]
const RELOAD_SECONDS := [1.2, 1.2, 0.8, 0.8]

static func index_of(element: String) -> int:
	return IDS.find(element)

static func is_gas(element: String) -> bool:
	return element == "hydrogen" or element == "oxygen"
