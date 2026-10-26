class_name DialogueLines
extends RefCounted
## The operator's line library. English subtitle text; the spoken line is
## meant to be recorded in Russian and placed at
##   res://assets/audio/voice/ru/<id>.ogg
## (no recordings exist yet: every line falls back to its subtitle).
##
## Keys:
##   id        unique; also the voice file name
##   event     what can trigger it (see Dialogue.trigger)
##   text      English subtitle
##   once      true: never spoken again in this run (default true)
##   cooldown  seconds before a repeatable line may return
##   min_t     earliest run time (s) - details are revealed gradually
##   cond      extra requirements, checked against the trigger context
##
## Character: tired, restrained, observant, now and then dry. Lines are
## sparse. Personal details stay consistent: his mother lives in Karsen
## and writes; his father smoked the same brand; he has served at this
## post long enough to know its noises.

const SPEAKER := "OPERATOR"
const VOICE_DIR := "res://assets/audio/voice/ru/"

const LINES := [
	# Beer and cigarettes.
	{"id": "op_beer_first", "event": "beer", "text": "Here's to another quiet shift.", "cond": {"first": true}},
	{"id": "op_beer_third", "event": "beer", "text": "Third one. Purely for morale.", "cond": {"third": true}},
	{"id": "op_beer_second", "event": "beer", "text": "Excellent. The war is still here.", "cond": {"consecutive": true}},
	{"id": "op_beer_second_b", "event": "beer", "text": "That one didn't help either.", "cond": {"consecutive": true}, "min_t": 900},
	{"id": "op_beer_warm", "event": "beer", "text": "Warm. Of course it's warm."},
	{"id": "op_beer_supply", "event": "beer", "text": "Supply sends beer and no carbon paper. Priorities.", "min_t": 600},
	{"id": "op_cig_first", "event": "cigarette", "text": "One thing they haven't rationed.", "cond": {"first": true}},
	{"id": "op_cig_father", "event": "cigarette", "text": "Father smoked these. Said they tasted of tar. They still do.", "min_t": 400},
	{"id": "op_cig_ashtray", "event": "cigarette", "text": "The ashtray fills faster than the log.", "min_t": 900},
	{"id": "op_cig_minutes", "event": "cigarette", "text": "Two minutes with nothing to decide.", "min_t": 300},
	{"id": "op_cig_updown", "event": "cigarette", "text": "Smoke goes up. Orders come down.", "min_t": 700},

	# Too much beer. Never graphic, never a joke at length.
	{"id": "op_drunk", "event": "drunk", "text": "The room is moving. The room should not move."},
	{"id": "op_drunk_b", "event": "drunk", "text": "Steady. The missile isn't going anywhere. Hopefully.", "min_t": 600},
	{"id": "op_vomit", "event": "vomit", "text": "...Nobody saw that."},
	{"id": "op_vomit_b", "event": "vomit", "text": "Right. That is enough of that."},

	# Isolation and silence.
	{"id": "op_company", "event": "isolation", "text": "Could use some company."},
	{"id": "op_generator", "event": "isolation", "text": "Even the generator says more than they do.", "min_t": 700},
	{"id": "op_stairs", "event": "isolation", "text": "Nobody has come down those stairs since the handover.", "min_t": 1300},
	{"id": "op_quiet", "event": "isolation", "text": "Quiet. Not the good kind.", "min_t": 1800},
	{"id": "op_hello", "event": "isolation", "text": "Hello? ...Just checking the line still works.", "min_t": 900},

	# Communications that go unanswered.
	{"id": "op_nothing", "event": "unanswered", "text": "Of course. Nothing."},
	{"id": "op_still_waiting", "event": "unanswered", "text": "Still waiting. Like everyone else."},
	{"id": "op_keeping", "event": "unanswered", "text": "If they read these, they keep it to themselves."},
	{"id": "op_forwarded", "event": "unanswered", "text": "Forwarded to Central. Where questions go to rest."},
	{"id": "op_rejected", "event": "rejected", "text": "Forty-one seconds. Someone at K-2 counted them too."},
	{"id": "op_one_at_a_time", "event": "pressure", "text": "One at a time. They never send them one at a time."},
	{"id": "op_read_sign", "event": "pressure", "text": "Read, decide, sign. Read, decide, sign."},
	{"id": "op_behind", "event": "pressure", "text": "Every post is behind. Every post is told so.", "min_t": 900},

	# Reports and orders.
	{"id": "op_shift_start", "event": "shift_start", "text": "Another shift. Same chair."},
	{"id": "op_stale", "event": "stale_report", "text": "Seven hours. Seven hours and nobody has walked that ground."},
	{"id": "op_approved", "event": "approved", "text": "Approved. On the strength of what?"},
	{"id": "op_conflict", "event": "conflicting", "text": "Two reports, one sector. They can't both be true."},
	{"id": "op_board", "event": "disturbing", "text": "That's not what the board said this morning."},
	{"id": "op_paper", "event": "order", "text": "Paper again.", "once": false, "cooldown": 600},
	{"id": "op_sign", "event": "accepted", "text": "Easy to sign. Harder to read twice.", "min_t": 600},
	{"id": "op_written", "event": "refused", "text": "Someone will write that down."},
	{"id": "op_away", "event": "launch", "text": "...There it goes."},
	{"id": "op_listened", "event": "hope", "text": "Maybe somebody listened."},
	{"id": "op_of_course", "event": "disappointment", "text": "Of course they did."},
	{"id": "op_no_reply_order", "event": "order_expired", "text": "No answer is an answer too. They'll read it as one."},

	# Ambient: memories, fatigue, the room, the procedures. Revealed slowly.
	{"id": "op_mother_letters", "event": "ambient", "text": "Mother still writes from Karsen. Every letter says the trains are on time.", "min_t": 240},
	{"id": "op_room_lamp", "event": "ambient", "text": "That lamp on the comms desk has buzzed since March.", "min_t": 330},
	{"id": "op_form", "event": "ambient", "text": "Form 7-B, in triplicate, to report that Form 7-B has run out.", "min_t": 450},
	{"id": "op_coffee", "event": "ambient", "text": "Coffee's gone cold again.", "min_t": 560},
	{"id": "op_station_clock", "event": "ambient", "text": "The clock at Karsen station ran four minutes fast. Everyone knew. Nobody fixed it.", "min_t": 700},
	{"id": "op_desk_date", "event": "ambient", "text": "Someone scratched a date under this desk. Nineteen seventy-one.", "min_t": 850},
	{"id": "op_procedure", "event": "ambient", "text": "There is a procedure for everything. Except for when nobody answers.", "min_t": 1000},
	{"id": "op_same_line", "event": "ambient", "text": "I keep reading the same line.", "min_t": 1150},
	{"id": "op_mother_karsen", "event": "ambient", "text": "Her street is two kilometres from the junction. I measured it once. On this map.", "min_t": 1300},
	{"id": "op_letter", "event": "ambient", "text": "I should have answered her last letter.", "min_t": 1600},
	{"id": "op_clock_hand", "event": "ambient", "text": "The second hand sticks at the forty. Every time.", "min_t": 1900},
	{"id": "op_third_night", "event": "ambient", "text": "The clock says morning. Feels like the third night.", "min_t": 1150},
]


static func voice_path(id: String) -> String:
	return VOICE_DIR + id + ".ogg"
