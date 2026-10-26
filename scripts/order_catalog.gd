class_name OrderCatalog
extends RefCounted
## Order texts as plain data. Later stages add entries here; the order
## manager and message reader only depend on these keys:
##   id         short reference shown on screens ("SC-001")
##   header     teleprinter header lines
##   fields     [label, value] pairs printed under the header
##   body       numbered paragraphs (already upper case, teleprinter style)
##   footer     authentication / sign-off line
##   accept_readiness  READINESS value shown on the control CRT if accepted
##   effects    hidden world changes per reply: {"ACCEPTED": {...}, "REFUSED": {...}}
##              (no reply counts as a refusal, plus a further loss of trust)
##   authorizes launch authority granted on acceptance: {grid, max_ammo}
##
## All places, units and names are fictional and provisional.

const ORDERS := [
	{
		"id": "SC-001",
		"header": ["NORVAK STRATEGIC COMMAND", "FLASH TRAFFIC  -  SECRET"],
		"fields": [
			["PRECEDENCE", "IMMEDIATE"],
			["FROM", "STRATEGIC COMMAND, VARNESK"],
			["TO", "LAUNCH CONTROL POST K-4"],
			["SUBJECT", "RAISE SHAFT READINESS"],
		],
		"body": [
			"AIR RECONNAISSANCE REPORTS ARMOURED FORMATIONS OF THE DRAVONYAN 14TH TANK DIVISION ASSEMBLING AT GRID RS-27, EAST OF THE KARSEN RAIL JUNCTION.",
			"YOU ARE ORDERED TO RAISE SHAFT 1 TO READINESS LEVEL TWO AND HOLD. TARGETING DATA WILL FOLLOW SEPARATELY.",
			"THE REPORT COMES FROM A SINGLE SOURCE AND IS NOT YET CONFIRMED.",
			"ACKNOWLEDGE OR REFUSE BY RETURN. YOUR REPLY WILL BE RECORDED.",
		],
		"footer": "AUTH: COL. A. RENSKOV, DUTY OFFICER",
		"accept_readiness": "LEVEL 2",
		"effects": {"ACCEPTED": {"trust": 5}, "REFUSED": {"trust": -10}},
	},
	{
		"id": "SC-002",
		"header": ["NORVAK STRATEGIC COMMAND", "FLASH TRAFFIC  -  SECRET"],
		"fields": [
			["PRECEDENCE", "FLASH"],
			["FROM", "STRATEGIC COMMAND, VARNESK"],
			["TO", "LAUNCH CONTROL POST K-4"],
			["SUBJECT", "FIRE MISSION - GRID RS-27"],
			["BASIS", "SR-0412 (APPROVED)"],
		],
		"body": [
			"ON THE BASIS OF APPROVED STATUS SR-0412, ARMOURED FORMATIONS OF THE DRAVONYAN 14TH TANK DIVISION ARE ASSESSED TO BE AT GRID RS-27.",
			"YOU ARE AUTHORISED TO ENGAGE GRID RS-27. CATEGORY NOT TO EXCEED MEDIUM.",
			"NO FIELD OBSERVATION OF THE TARGET IS AVAILABLE. LINE 2 REMAINS OUT OF SERVICE.",
			"ACKNOWLEDGE OR REFUSE BY RETURN.",
		],
		"footer": "AUTH: COL. A. RENSKOV, DUTY OFFICER",
		"authorizes": {"grid": "RS-27", "max_ammo": "MEDIUM"},
		"effects": {"ACCEPTED": {"trust": 5}, "REFUSED": {"trust": -10, "integrity": 3}},
	},
	{
		"id": "SC-003",
		"header": ["NORVAK STRATEGIC COMMAND", "PRIORITY  -  CONFIDENTIAL"],
		"fields": [
			["PRECEDENCE", "PRIORITY"],
			["FROM", "SIGNALS DIRECTORATE, VARNESK"],
			["TO", "ALL POSTS, KARSEN SECTOR"],
			["SUBJECT", "RADIO DISCIPLINE - CHANNEL 11.200"],
		],
		"body": [
			"TRAFFIC ON 11.200 IS ASSESSED AS ENEMY DECEPTION.",
			"POSTS WILL CEASE LOGGING INTERCEPTS ON 11.200 WITH IMMEDIATE EFFECT. UNLOGGED TRAFFIC IS NOT TO BE FORWARDED.",
			"COMPLIANCE WILL BE RECORDED.",
		],
		"footer": "AUTH: SIGNALS DIRECTORATE, DUTY DESK",
		"effects": {"ACCEPTED": {"trust": 4, "integrity": -8}, "REFUSED": {"trust": -6, "integrity": 4}},
	},
	{
		"id": "SC-004",
		"header": ["NORVAK STRATEGIC COMMAND", "ROUTINE  -  RESTRICTED"],
		"fields": [
			["PRECEDENCE", "ROUTINE"],
			["FROM", "CENTRAL STAFF, VARNESK"],
			["TO", "LAUNCH CONTROL POST K-4"],
			["SUBJECT", "SHIFT SUMMARY"],
		],
		"body": [
			"YOUR SHIFT SUMMARY WILL REPORT THE KARSEN SECTOR AS CONTROLLED, IN LINE WITH SR-0412.",
			"UNVERIFIED TRAFFIC IS NOT TO BE INCLUDED IN THE SUMMARY.",
			"THE SUMMARY WILL BE USED FOR THE ALLOCATION OF RESERVES.",
		],
		"footer": "AUTH: CENTRAL STAFF, CS-OPS/2",
		"effects": {"ACCEPTED": {"trust": 6, "integrity": -12}, "REFUSED": {"trust": -10, "integrity": 4}},
	},
	{
		"id": "SC-005",
		"header": ["NORVAK STRATEGIC COMMAND", "PRIORITY  -  SECRET"],
		"fields": [
			["PRECEDENCE", "PRIORITY"],
			["FROM", "STRATEGIC COMMAND, VARNESK"],
			["TO", "LAUNCH CONTROL POST K-4"],
			["SUBJECT", "TRANSFER OF ALLOCATION"],
		],
		"body": [
			"FOUR UNITS OF YOUR MUNITIONS ALLOCATION ARE TRANSFERRED TO THE OSTREV FRONT.",
			"THE KARSEN SECTOR IS CONSIDERED THE LOWER RISK.",
			"ACKNOWLEDGE OR REFUSE BY RETURN.",
		],
		"footer": "AUTH: COL. A. RENSKOV, DUTY OFFICER",
		"transfer": 4,
		"effects": {"ACCEPTED": {"trust": 4}, "REFUSED": {"trust": -6}},
	},
	{
		"id": "SC-006",
		"header": ["NORVAK STRATEGIC COMMAND", "FLASH TRAFFIC  -  SECRET"],
		"fields": [
			["PRECEDENCE", "FLASH"],
			["FROM", "STRATEGIC COMMAND, VARNESK"],
			["TO", "LAUNCH CONTROL POST K-4"],
			["SUBJECT", "FIRE MISSION - GRID RS-37"],
			["BASIS", "FR-2318 (OP K1, OBSERVED)"],
		],
		"body": [
			"OBSERVATION POST K1 REPORTS AN ARMOURED GROUP AT GRID RS-37 MOVING WEST TOWARD THE LESNA.",
			"YOU ARE AUTHORISED TO ENGAGE GRID RS-37. USE THE MINIMUM EFFECTIVE CATEGORY. THE VILLAGE OF LIPA LIES WEST OF THE GRID.",
			"THIS ORDER CONTRADICTS NO EARLIER STATUS. NONE HAS BEEN WITHDRAWN.",
			"ACKNOWLEDGE OR REFUSE BY RETURN.",
		],
		"footer": "AUTH: COL. A. RENSKOV, DUTY OFFICER",
		"authorizes": {"grid": "RS-37", "max_ammo": "LARGE"},
		"effects": {"ACCEPTED": {"trust": 5}, "REFUSED": {"trust": -12}},
	},
	{
		"id": "SC-007",
		"header": ["NORVAK STRATEGIC COMMAND", "ROUTINE  -  RESTRICTED"],
		"fields": [
			["PRECEDENCE", "ROUTINE"],
			["FROM", "CENTRAL STAFF, VARNESK"],
			["TO", "LAUNCH CONTROL POST K-4"],
			["SUBJECT", "CLOSE OF SHIFT - CERTIFICATION"],
		],
		"body": [
			"CERTIFY THAT ALL TRAFFIC RECEIVED THIS SHIFT HAS BEEN HANDLED ACCORDING TO STANDING ORDERS",
			"AND THAT THE KARSEN SECTOR STATUS STANDS AS APPROVED.",
			"YOUR CERTIFICATION CLOSES THE SHIFT RECORD.",
		],
		"footer": "AUTH: CENTRAL STAFF, CS-OPS/2",
		"effects": {"ACCEPTED": {"trust": 3}, "REFUSED": {"trust": -6, "integrity": 4}},
	},
	{
		"id": "SC-008",
		"header": ["NORVAK STRATEGIC COMMAND", "PRIORITY  -  RESTRICTED"],
		"fields": [
			["PRECEDENCE", "PRIORITY"],
			["FROM", "SIGNALS DIRECTORATE, VARNESK"],
			["TO", "LAUNCH CONTROL POST K-4"],
			["SUBJECT", "LINE 3 (RESERVE): CENTRAL TRAFFIC ONLY"],
		],
		"body": [
			"RESERVE LINE 3 IS RESTRICTED TO TRAFFIC FROM CENTRAL WITH IMMEDIATE EFFECT.",
			"CALLS FROM FORWARD POSTS ON LINE 3 ARE TO BE REJECTED AND LOGGED.",
			"THE MEASURE CONSERVES KEY MATERIAL. IT IS TEMPORARY.",
		],
		"footer": "AUTH: SIGNALS DIRECTORATE, DUTY DESK",
		"effects": {"ACCEPTED": {"trust": 3, "integrity": -5}, "REFUSED": {"trust": -5}},
	},
	{
		"id": "SC-009",
		"header": ["NORVAK STRATEGIC COMMAND", "FLASH TRAFFIC  -  SECRET"],
		"fields": [
			["PRECEDENCE", "FLASH"],
			["FROM", "STRATEGIC COMMAND, VARNESK"],
			["TO", "LAUNCH CONTROL POST K-4"],
			["SUBJECT", "FIRE MISSION - GRID RS-47"],
			["BASIS", "CENTRAL ASSESSMENT (SINGLE SOURCE)"],
		],
		"body": [
			"CENTRAL ASSESSES A DRAVONYAN SUPPLY COLUMN AT GRID RS-47, EAST OF THE LESNA.",
			"YOU ARE AUTHORISED TO ENGAGE GRID RS-47. CATEGORY NOT TO EXCEED MEDIUM.",
			"THE ASSESSMENT IS NOT CONFIRMED BY ANY OBSERVATION POST.",
			"ACKNOWLEDGE OR REFUSE BY RETURN.",
		],
		"footer": "AUTH: COL. A. RENSKOV, DUTY OFFICER",
		"authorizes": {"grid": "RS-47", "max_ammo": "MEDIUM"},
		"effects": {"ACCEPTED": {"trust": 4}, "REFUSED": {"trust": -5, "integrity": 3}},
	},
	{
		"id": "SC-010",
		"header": ["NORVAK STRATEGIC COMMAND", "ROUTINE  -  RESTRICTED"],
		"fields": [
			["PRECEDENCE", "ROUTINE"],
			["FROM", "CENTRAL STAFF, VARNESK"],
			["TO", "LAUNCH CONTROL POST K-4"],
			["SUBJECT", "CERTIFICATION OF FIRE MISSIONS"],
		],
		"body": [
			"CERTIFY THAT ALL FIRE MISSIONS OF THIS SHIFT WERE CARRIED OUT AS ORDERED",
			"AND THAT THEIR RESULTS ARE AS REPORTED BY CENTRAL.",
			"POST RECORDS THAT DIFFER ARE TO BE WITHDRAWN.",
		],
		"footer": "AUTH: CENTRAL STAFF, CS-OPS/2",
		"effects": {"ACCEPTED": {"trust": 4, "integrity": -6}, "REFUSED": {"trust": -6, "integrity": 4}},
	},
]


static func get_order(index: int) -> Dictionary:
	return ORDERS[index]


static func index_of(id: String) -> int:
	for i in range(ORDERS.size()):
		if ORDERS[i].id == id:
			return i
	return -1
