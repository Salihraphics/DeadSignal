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
	},
]


static func get_order(index: int) -> Dictionary:
	return ORDERS[index]
