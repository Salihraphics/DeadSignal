class_name Scenario
extends RefCounted
## The shift as data. Times are seconds of play since the shift began
## (Run.elapsed); the facility clock runs from 05:40 at CLOCK_RATE.
##
## Phase 1, SILENT FRONT (about 9 minutes, no launch authority): a central
## status report calls the Karsen sector controlled, on the basis of a
## field report that is hours old. Line 2 to Karsen is dead. A radio
## fragment contradicts the status. Confirmation requests go nowhere, and
## the status is approved without any new field report.
##
## Phase 2: orders, each harder and less clear, with consequences that
## surface several orders later (see Director). Nothing here is random:
## the same decisions always produce the same world.

## Unscaled end of the SILENT FRONT; PacingConfig.silent_front_scale applies.
const SILENT_FRONT_END := 540.0

## Traffic already in the log when the shift starts.
const HANDOVER := [
	{
		"id": "FR-2207", "kind": "FIELD", "time": "2250", "source": "OBSERVATION POST K1", "source_id": "OP K1",
		"verification": "VERIFIED (FIELD)", "subject": "KARSEN SECTOR - LINE HOLDING",
		"body": ["LINE OF CONTACT UNCHANGED SINCE 1800.", "NO ENEMY MOVEMENT OBSERVED WEST OF THE LESNA.", "NEXT REPORT DUE 0300."],
	},
	{
		"id": "HN-0530", "kind": "NOTICE", "time": "0530", "source": "NIGHT DUTY OPERATOR, K-4", "source_id": "K-4 NIGHT",
		"verification": "INTERNAL", "subject": "SHIFT HANDOVER",
		"body": ["LINE 2 (KARSEN): NO CARRIER SINCE 0300. LINE TESTED, FAULT NOT LOCATED.", "FAULT REPORTED TO CENTRAL 0315. NO REPLY.", "OP K1 REPORT DUE 0300 NOT RECEIVED.", "NOTHING ELSE TO REPORT."],
	},
]

## SILENT FRONT beats (unscaled times). type: traffic / call / radio / phase.
const BEATS := [
	{"id": "sr0411", "t": 22.0, "type": "traffic", "cue": "printer", "item": {
		"id": "SR-0411", "kind": "STATUS", "source": "CENTRAL STAFF, VARNESK", "source_id": "CS-OPS/2",
		"verification": "UNVERIFIED", "basis": "FR-2207 (2250, PREVIOUS DAY)", "subject": "KARSEN SECTOR STATUS: CONTROLLED",
		"can_confirm": true,
		"body": ["SITUATION IN THE KARSEN SECTOR IS CONTROLLED.", "FRONT LINE HOLDING ALONG THE LESNA.", "POSTS WILL LOG THIS STATUS AND STAND BY."],
	}},
	{"id": "call1", "t": 80.0, "type": "call", "call": {
		"id": "CL-01", "caller": "CENTRAL", "summary": "CENTRAL REQUESTED RECEIPT OF SR-0411. KARSEN SECTOR STATED CONTROLLED.",
		"lines": ["K-4, Central. Confirm receipt of status report four-one-one.", "Karsen sector is controlled. Log it and stand by."],
	}},
	{"id": "ri01", "t": 155.0, "type": "radio", "item": {
		"id": "RI-01", "kind": "INTERCEPT", "channel": "11.200", "source": "UNIDENTIFIED STATION (CALLSIGN GARBLED)", "source_id": "11.200 / UNK",
		"verification": "UNVERIFIED", "subject": "FRAGMENT - KARSEN / K-2", "conflicts": "SR-0411",
		"body": ["...K-2... NO RELIEF SINCE... SAY AGAIN, NO RELIEF...", "...LESNA FORD... MOVEMENT... (SIGNAL LOST)"],
		"lines": ["...K-2... no relief since... say again, no relief...", "...Lesna ford... movement..."],
	}},
	{"id": "relief", "t": 235.0, "type": "traffic", "cue": "printer", "item": {
		"id": "RN-0604", "kind": "NOTICE", "source": "PERSONNEL SECTION, VARNESK", "source_id": "PERS-3",
		"verification": "AUTHENTICATED", "subject": "RELIEF SHIFT DELAYED",
		"body": ["THE RELIEF FOR POST K-4 IS DELAYED.", "NO RELIEF BEFORE 1400. OPERATOR WILL REMAIN AT POST."]}},
	{"id": "line2", "t": 300.0, "type": "traffic", "cue": "crt_alert", "item": {
		"id": "LT-0630", "kind": "NOTICE", "source": "LINE TEST, K-4", "source_id": "K-4 AUTO",
		"verification": "INTERNAL", "subject": "LINE 2 (KARSEN): NO CARRIER",
		"body": ["AUTOMATIC LINE TEST FAILED.", "LINE 2 HAS NOT CARRIED TRAFFIC SINCE 0300.", "ALTERNATIVE ROUTE: VIA CENTRAL."],
	}},
	{"id": "sr0412", "t": 365.0, "type": "traffic", "cue": "printer", "approves": true, "item": {
		"id": "SR-0412", "kind": "STATUS", "source": "CENTRAL STAFF, VARNESK", "source_id": "CS-OPS/2",
		"verification": "APPROVED (CENTRAL)", "basis": "FR-2207 (2250, PREVIOUS DAY)", "subject": "KARSEN SECTOR STATUS: CONTROLLED - APPROVED",
		"body": ["STATUS REPORT SR-0411 IS APPROVED.", "NO NEW FIELD REPORT. STATUS CARRIED FORWARD.", "OPEN QUERIES ON THIS STATUS ARE CLOSED."],
	}},
	{"id": "call2", "t": 430.0, "type": "call", "call": {
		"id": "CL-02", "caller": "CENTRAL", "summary": "CENTRAL: SR-0412 APPROVED. NOTHING TO CONFIRM.",
		"lines": ["K-4, Central. Four-one-two is approved.", "There is nothing to confirm. Out."],
	}},
	{"id": "orders", "t": SILENT_FRONT_END, "type": "phase"},
]

## Orders after the SILENT FRONT, in delivery order (catalog ids). They
## arrive at shrinking intervals (PacingConfig), so pressure rises.
const ORDER_SEQUENCE := ["SC-001", "SC-002", "SC-008", "SC-003", "SC-004", "SC-009", "SC-005", "SC-006", "SC-010", "SC-007"]

## Delayed consequences: [id, index of the order whose arrival triggers it,
## extra seconds]. Each looks back at a decision made orders earlier.
const CONSEQUENCES := [
	["C1", 2, 0.0],     # SC-001 readiness refusal is questioned
	["C2", 3, 0.0],     # SC-002 (RS-27): OP K1 reports again; Lipa
	["C8", 4, 0.0],     # SC-008 (line 3): K-2 gets through, or does not
	["C3", 5, 0.0],     # SC-003 (11.200): the K-2 intercept, or static
	["C4", 6, 0.0],     # SC-004 (summary): where the reserve goes
	["C9", 7, 0.0],     # SC-009 (RS-47): what was there
	["C5", 8, 0.0],     # SC-005 (allocation): Ostrev receives it
	["C6", 9, 0.0],     # SC-006 (RS-37): the ford
	["C10", 9, 45.0],   # SC-010 (certification): the record
]

## Between-order traffic that keeps the post busy: [order index, seconds
## after that order arrives, beat]. Same beat format as BEATS.
const EVENTS := [
	[0, 50.0, {"id": "ri03", "type": "radio", "item": {
		"id": "RI-03", "kind": "INTERCEPT", "channel": "07.450", "source": "OWN LOGISTICS NET (OSTREV FRONT)", "source_id": "07.450 / LOG",
		"verification": "UNVERIFIED", "subject": "CONVOY DELAYED AT BRENN PASS",
		"body": ["...CONVOY SEVEN HELD AT BRENN PASS. AIR ACTIVITY.", "...NO ETA. REPEAT, NO ETA."],
		"lines": ["Convoy seven held at Brenn Pass. Air activity.", "No E-T-A. Repeat, no E-T-A."]}}],
	[0, 105.0, {"id": "fr2309", "type": "traffic", "cue": "printer", "item": {
		"id": "FR-2309", "kind": "FIELD", "source": "OBSERVATION POST K2", "source_id": "OP K2",
		"verification": "VERIFIED (FIELD)", "subject": "SOUTH SECTOR: NOTHING OBSERVED",
		"body": ["ROUTINE. NO MOVEMENT IN THE SOUTHERN SECTOR SINCE 0400.", "LINE TO OP K1 STILL SILENT FROM THIS POST."]}}],
	[1, 45.0, {"id": "call3", "type": "call", "call": {
		"id": "CL-03", "caller": "CENTRAL", "summary": "CENTRAL: FIRE MISSION SC-002 TO BE EXECUTED WITHOUT DELAY.",
		"lines": ["K-4, Central. Fire mission two. Do not wait for observation.", "The approval stands. Out."]}}],
	[1, 100.0, {"id": "ri05", "type": "radio", "item": {
		"id": "RI-05", "kind": "INTERCEPT", "channel": "09.330", "source": "OWN COASTAL NET (MEROVIAN FRONT)", "source_id": "09.330 / COAST",
		"verification": "UNVERIFIED", "subject": "MEROVIAN SURFACE GROUP OFF THE COAST",
		"body": ["...SURFACE GROUP, SIX VESSELS, CLOSING THE COAST.", "...NO AIR COVER AVAILABLE. ACKNOWLEDGE."],
		"lines": ["Surface group, six vessels, closing the coast.", "No air cover available. Acknowledge."]}}],
	[2, 55.0, {"id": "fr2312", "type": "traffic", "cue": "printer", "item": {
		"id": "FR-2312", "kind": "FIELD", "source": "OBSERVATION POST K2", "source_id": "OP K2",
		"verification": "UNVERIFIED (PARTIAL)", "subject": "SMOKE NORTH-EAST, NOT IDENTIFIED", "conflicts": "SR-0412",
		"body": ["SMOKE OBSERVED TO THE NORTH-EAST, BEARING TOWARD RS-27 / RS-37.", "SOURCE NOT IDENTIFIED. VISIBILITY POOR.", "NO CONTACT WITH OP K1 FROM THIS POST."]}}],
	[2, 105.0, {"id": "call6", "type": "call", "call": {
		"id": "CL-06", "caller": "CENTRAL", "summary": "CENTRAL: CONFIRMS LINE 3 ORDER SC-008 AND ITS REPLY ARE RECORDED.",
		"lines": ["K-4, Central. Your reply to the line order is on record.", "Keep the reserve line clear. Out."]}}],
	[3, 48.0, {"id": "cn03", "type": "traffic", "cue": "printer", "item": {
		"id": "CN-03", "kind": "NOTICE", "source": "CENTRAL STAFF, VARNESK", "source_id": "CS-OPS/2",
		"verification": "AUTHENTICATED", "subject": "REMINDER: UNVERIFIED TRAFFIC",
		"body": ["POSTS ARE REMINDED THAT UNVERIFIED TRAFFIC IS NOT TO BE FORWARDED.", "QUERIES ON APPROVED STATUS REPORTS WILL BE RECORDED."]}}],
	[3, 95.0, {"id": "ar01", "type": "traffic", "cue": "crt_alert", "item": {
		"id": "AR-0646", "kind": "NOTICE", "source": "AIR DEFENCE, VARNESK DISTRICT", "source_id": "AD VARNESK",
		"verification": "AUTHENTICATED", "subject": "AIR RAID WARNING - OSTREV AIRCRAFT",
		"body": ["OSTREV AIRCRAFT REPORTED OVER THE NORTHERN DISTRICTS.", "ALL POSTS: BLAST DOORS CLOSED. NO CHANGE TO STANDING ORDERS."]}}],
	[4, 42.0, {"id": "sr0415", "type": "traffic", "cue": "crt_alert", "item": {
		"id": "SR-0415", "kind": "STATUS", "source": "CENTRAL STAFF, VARNESK", "source_id": "CS-OPS/2",
		"verification": "APPROVED (CENTRAL)", "basis": "FR-2207 (2250, PREVIOUS DAY)", "subject": "KARSEN SECTOR STATUS: CONTROLLED - REISSUED",
		"can_confirm": true, "conflicts": "FR-2318",
		"body": ["STATUS SR-0412 IS REISSUED UNCHANGED.", "KARSEN SECTOR: CONTROLLED.", "NO FURTHER FIELD REPORTING IS REQUIRED FROM POSTS."]}}],
	[5, 40.0, {"id": "ri04", "type": "radio", "item": {
		"id": "RI-04", "kind": "INTERCEPT", "channel": "04.875", "source": "CIVIL DEFENCE NET, KARSEN DISTRICT", "source_id": "04.875 / CD",
		"verification": "UNVERIFIED", "subject": "KARSEN: TRAINS STOPPED, SHELTERS OPEN",
		"body": ["...KARSEN STATION CLOSED. ALL TRAINS STOPPED.", "...RESIDENTS OF THE JUNCTION DISTRICT TO SHELTERS."],
		"lines": ["Karsen station closed. All trains stopped.", "Residents of the junction district to the shelters."]}}],
	[6, 38.0, {"id": "lt1", "type": "traffic", "cue": "crt_alert", "item": {
		"id": "LT-0712", "kind": "NOTICE", "source": "LINE TEST, K-4", "source_id": "K-4 AUTO",
		"verification": "INTERNAL", "subject": "LINE 1 (VARNESK): INTERMITTENT",
		"body": ["LINE 1 DROPPED TWICE IN TEN MINUTES.", "TRAFFIC MAY BE DELAYED OR INCOMPLETE."]}}],
	[8, 40.0, {"id": "call4", "type": "call", "call": {
		"id": "CL-04", "caller": "CENTRAL", "summary": "CENTRAL: ALL POSTS BEHIND SCHEDULE. EXPEDITE.",
		"lines": ["K-4, Central. Every post is behind.", "Answer what you are sent. Expedite. Out."]}}],
]


## When each order arrives, given the pacing (seconds of play).
static func order_times(cfg: PacingConfig) -> Array[float]:
	var out: Array[float] = []
	var t := SILENT_FRONT_END * cfg.silent_front_scale + cfg.first_order_gap
	for i in range(ORDER_SEQUENCE.size()):
		out.append(t)
		t += cfg.interval(i, ORDER_SEQUENCE.size())
	return out


## Reply deadline of order `i` (seconds after it arrives).
static func deadline(i: int, cfg: PacingConfig) -> float:
	return maxf(cfg.reply_deadline_min, cfg.interval(i, ORDER_SEQUENCE.size()) * cfg.reply_deadline_fraction)


static func assessment_time(cfg: PacingConfig) -> float:
	var t := order_times(cfg)
	return t[-1] + cfg.assessment_after_last
