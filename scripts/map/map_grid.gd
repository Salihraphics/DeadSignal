class_name MapGrid
extends RefCounted
## The single coordinate convention for the tactical map.
##
## Logical map coordinates are kilometres: x grows east, y grows south
## (north-up drawing). The sheet is 160 x 120 km.
##
## Military grid: 40 km major squares named by a column letter (P..S,
## west to east) and a row letter (R..T, north to south), divided into
## 4 km cells named by an easting digit (0-9, west to east) and a northing
## digit (0-9, counted from the square's SOUTH edge, as on real grids).
##   "RS-27" = square column R, row S; easting 2, northing 7
##          = x 88..92 km, y 48..52 km.
## Cells are also addressed by integer indices (cx 0..39, cy 0..29).

const EXTENT := Vector2(160.0, 120.0)
const MAJOR := 40.0
const CELL := 4.0
const COLS := "PQRS"
const ROWS := "RST"
const CELLS := Vector2i(40, 30)


static func cell_of(km: Vector2) -> Vector2i:
	return Vector2i(clampi(floori(km.x / CELL), 0, CELLS.x - 1), clampi(floori(km.y / CELL), 0, CELLS.y - 1))


static func cell_rect(cell: Vector2i) -> Rect2:
	return Rect2(Vector2(cell) * CELL, Vector2(CELL, CELL))


static func cell_center(cell: Vector2i) -> Vector2:
	return (Vector2(cell) + Vector2(0.5, 0.5)) * CELL


static func ref_of_cell(cell: Vector2i) -> String:
	var col := COLS[cell.x / 10]
	var row := ROWS[cell.y / 10]
	return "%s%s-%d%d" % [col, row, cell.x % 10, 9 - cell.y % 10]


static func ref_of(km: Vector2) -> String:
	return ref_of_cell(cell_of(km))


## "RS-27" -> cell indices; Vector2i(-1, -1) if malformed.
static func parse(ref: String) -> Vector2i:
	if ref.length() != 5 or ref[2] != "-":
		return Vector2i(-1, -1)
	var c := COLS.find(ref[0])
	var r := ROWS.find(ref[1])
	if c < 0 or r < 0 or not ref[3].is_valid_int() or not ref[4].is_valid_int():
		return Vector2i(-1, -1)
	return Vector2i(c * 10 + int(ref[3]), r * 10 + (9 - int(ref[4])))


static func in_extent(km: Vector2) -> bool:
	return km.x >= 0.0 and km.y >= 0.0 and km.x <= EXTENT.x and km.y <= EXTENT.y
