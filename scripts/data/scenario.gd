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

const SILENT_FRONT_END := 540.0
const ASSESSMENT_T := 1900.0
const ORDER_DEADLINE := 190.0

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

## SILENT FRONT beats. type: traffic / call / radio / notice_cue / phase.
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

## Orders after the SILENT FRONT: [time, catalog index].
const ORDER_TIMES := [
	[560.0, 0], [760.0, 1], [980.0, 2], [1160.0, 3], [1340.0, 4], [1520.0, 5], [1720.0, 6],
]

## Consequence checks (Director.consequence): [time, id].
const CONSEQUENCES := [
	[900.0, "C1"], [1100.0, "C2"], [1250.0, "C3"], [1450.0, "C4"], [1650.0, "C5"], [1850.0, "C6"],
]
