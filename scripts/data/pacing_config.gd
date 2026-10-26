class_name PacingConfig
extends Resource
## Tunable pacing of the shift, in one place (data/pacing.tres; editable in
## the Godot inspector). The Director derives every scheduled time from
## these values and Scenario's order list, so the timeline stays
## deterministic (saves resume exactly) and nothing else hard-codes delays.
##
## Times are seconds of play. Orders arrive at shrinking intervals: the
## gap goes from `interval_start` to `interval_end` along `escalation_curve`
## (1 = linear, >1 = pressure rises late, <1 = early).

## SILENT FRONT beat times are multiplied by this (1.0 = the original 9 min).
@export_range(0.3, 1.5, 0.05) var silent_front_scale := 0.6
## Pause between the end of the SILENT FRONT and the first order.
@export_range(0.0, 120.0, 1.0) var first_order_gap := 15.0
## Gap before the second order, and before the last one.
@export_range(30.0, 400.0, 5.0) var interval_start := 135.0
@export_range(30.0, 400.0, 5.0) var interval_end := 80.0
@export_range(0.3, 3.0, 0.1) var escalation_curve := 1.2
## Reply deadline as a share of the gap to the next order (at least the minimum).
@export_range(0.3, 1.0, 0.05) var reply_deadline_fraction := 0.9
@export_range(20.0, 300.0, 5.0) var reply_deadline_min := 60.0
## Delayed consequences land this long after the order that triggers them.
@export_range(0.0, 120.0, 1.0) var consequence_offset := 32.0
## Minimum spacing between two notification cues (printer, bell, radio,
## alert), so close events never stack on screen at once.
@export_range(2.0, 40.0, 0.5) var min_cue_gap := 9.0
## Assessment (and ending) this long after the last order arrives.
@export_range(30.0, 400.0, 5.0) var assessment_after_last := 115.0
## Distant rumble / light flicker as the front deteriorates.
@export var pressure_ambience := true
## Seconds between rumbles at the start of the order phase and at its end.
@export_range(20.0, 600.0, 5.0) var rumble_every_start := 150.0
@export_range(10.0, 600.0, 5.0) var rumble_every_end := 55.0


## Gap that follows order `i` (0-based) of `n`.
func interval(i: int, n: int) -> float:
	var f := 0.0 if n <= 2 else clampf(float(i) / float(n - 2), 0.0, 1.0)
	return lerpf(interval_start, interval_end, pow(f, escalation_curve))
