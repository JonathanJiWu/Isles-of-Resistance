class_name Situations
extends RefCounted
## Narrative data for the escalation ladder, dynamic situations and timed objectives.
## Situations are decisions that arrive between waves, chosen by the state of the war
## (escalation, season, what just happened). They use the same effect keys as directives
## (see Campaign._apply) and often matter more for what they avoid than what they win.

const LANDING_NAMES := ["Landing Group Tide-1", "Landing Group Tide-2", "Landing Group Tide-3"]

## Comms cards when the ladder moves. "up" when escalating to that level, "down" when stepping back.
const LADDER := [
	{"up": "", "down": "Through the Compact, both capitals have agreed to “reduce operational tempo”. Cutters still shadow the ferries; nobody is shooting. Gray zone, they call it. It is not gray if you live here.", "speaker": "solenne"},
	{"up": "", "down": "The blockade has eased into a “quarantine” again. Tankers are moving under Commonwealth escort, which is its own kind of message.", "speaker": "kemalu"},
	{"up": "Blockade. Their coast guard has stopped pretending this is customs work and the navy is turning ships around. Our LNG reserve is about twelve days. Every turn from now on costs a day of gas.", "down": "The missile strikes have stopped for now. The blockade hasn't. Keep the gas flowing.", "speaker": "ardent"},
	{"up": "Strikes. The Rocket Force is in it now. Ballistic missiles will open every raid, and they go for runways, radars and launchers. Only Longbows with hit-to-kill interceptors can touch them. Disperse, harden, repair.", "down": "The ballistic salvos have stopped. Somebody in the Steering Council decided the price was too high. Don't count on it lasting.", "speaker": "ardent"},
	{"up": "Assault. Landing groups are at sea. If they reach a beach, the town behind it is gone. Find them, and put everything we have into them before they arrive.", "down": "", "speaker": "ardent"},
]

const SITUATIONS := {
	"inspection": {
		"speaker": "tamsin", "title": "Customs Work", "esc": [1, 2],
		"text": "Two Commonwealth Coast Guard cutters have stopped the LNG carrier [i]Morning Lantern[/i] twelve miles out and want to inspect her papers under the new “quarantine regulations”. Their captain is very polite. The tanker's master is asking what we want her to do.",
		"options": [
			{"label": "Escort her in", "effects": {"escalation": 6, "energy": 4, "ally": 2, "resolve": 3},
				"note": "Our cutters shadow theirs all the way to the terminal. Nobody fires. Everybody films."},
			{"label": "Protest through the Compact", "effects": {"energy": -2, "ally": 3, "resolve": -2},
				"note": "Secretary Kemalu files a complaint. The tanker waits at anchor for two days."},
			{"label": "Comply under protest", "effects": {"energy": -4, "resolve": -5, "escalation": -5},
				"note": "The inspection takes nine hours. The precedent takes less."},
		],
	},
	"cable_cut": {
		"speaker": "tamsin", "title": "Anchor Drag", "esc": [1, 4], "requires_kind": "cable", "on_trigger": {"comms": 3},
		"text": "Both cables at {cable} dropped at 03:12. A trawler with a flag of convenience and no transponder spent the night dragging its anchor across the landing zone, and is now heading home at nine knots. Until the link is back, our intelligence is running on microwave relays and hope.",
		"options": [
			{"label": "Board the trawler", "effects": {"escalation": 5, "resolve": 4, "comms_set": 2},
				"note": "Boarders find a very surprised crew and a very long anchor chain. The Commonwealth calls it piracy."},
			{"label": "Send the repair ship", "effects": {"supplies": -20, "comms_set": 1},
				"note": "Tessera owns one cable ship. It is now the most important ship in the navy."},
			{"label": "Lease satellite backup from Brightline", "effects": {"rp": -10, "ally": 2, "comms_set": 0, "flags": ["brightline_backup"]},
				"note": "It works. The terms of service now cover your national emergency."},
		],
	},
	"downed_pilot": {
		"speaker": "sol", "title": "The Boy in the Water", "esc": [1, 4], "trigger": "kills", "max_times": 2,
		"text": "Fishermen out of {city} pulled a Commonwealth pilot out of the strait. He's nineteen and frightened, and he keeps asking whether his mother will see this on the news.",
		"options": [
			{"label": "Treat him; tell his family through the Compact", "effects": {"escalation": -6, "resolve": -2, "ally": 3, "flags": ["pilot_returned"]},
				"note": "A Littoral consul collects a letter for his mother. It is the only good news in either capital tonight."},
			{"label": "Put him on television", "effects": {"resolve": 6, "escalation": 6, "ally": -3},
				"note": "CCB calls it a hostage video. HNN calls it ratings."},
			{"label": "Trade him for our detained fishermen", "effects": {"escalation": -3, "resolve": 4, "flags": ["pilot_exchanged"]},
				"note": "Six fishermen come home to Saltmere. Auntie Sol cries on air and denies it."},
		],
	},
	"evacuation": {
		"speaker": "marrane", "title": "The Last Ferries", "esc": [2, 4], "requires_city": "coastal",
		"text": "Ferries can move {city}'s elderly and hospital patients to the western islands, but loading takes two turns at the docks. If a raid hits the district while they're boarding, it happens on live television.",
		"options": [
			{"label": "Run the evacuation", "effects": {"supplies": -15, "objective": "evacuate"},
				"note": "Keep {city} standing and unhit for two turns."},
			{"label": "Shelter in place", "effects": {"resolve": -4},
				"note": "The shelters are full of people who wanted ferries."},
		],
	},
	"typhoon": {
		"speaker": "ardent", "title": "Typhoon Warning", "esc": [0, 4], "seasons": ["typhoon", "plum_rain"], "max_times": 1,
		"on_trigger": {"storm_next": 1},
		"text": "Typhoon Pearl crosses the strait next turn. Nothing flies in that, not us and not them. Whatever isn't tied down will be in the sea by morning.",
		"options": [
			{"label": "Batten down every site", "effects": {"supplies": -15},
				"note": "Sandbags, chains and very tired crews."},
			{"label": "Ride it out", "effects": {"storm_damage": 2},
				"note": "Two sites lose roofs, antennas and patience."},
		],
	},
	"mobilization": {
		"speaker": "whitlow", "title": "Ferries in Three Ports", "esc": [2, 3], "max_times": 1, "confidence": true,
		"text": "Our satellites show roll-on/roll-off ferries and barge sets gathering in three mainland ports. It could be an exercise. It could be the real thing. They look the same until the day they don't.",
		"options": [
			{"label": "Mobilize the reserves", "effects": {"supplies": -25, "escalation": 5, "heal": 15, "flags": ["mobilized"]},
				"note": "Every site gets crews and spares. The Commonwealth reads it as a provocation."},
			{"label": "Watch and wait", "effects": {},
				"note": "Nothing happens. That is either wisdom or the last mistake before the big one."},
			{"label": "Share it with the Federation", "effects": {"ally": 5, "escalation": 3, "confidence": 3},
				"note": "Admiral Whitlow sends back better pictures, and a reminder about the arms package."},
		],
	},
	"disinformation": {
		"speaker": "kai", "title": "Six Fingers", "esc": [1, 4], "max_times": 2,
		"text": "A video of President Solenne announcing Tessera's surrender is all over the Harmony Grid feeds. It's fake: six fingers on her left hand, the flag backwards. Half a million people have shared it anyway.",
		"options": [
			{"label": "Rapid rebuttal", "effects": {"rp": -8, "resolve": 2},
				"note": "The President records a reply in one take, holding up five fingers."},
			{"label": "Let it burn out", "effects": {"resolve": -8},
				"note": "It doesn't."},
			{"label": "Throttle Harmony Grid", "requires_flag": "harmony_accepted", "effects": {"supplies": -20, "resolve": 3, "escalation": 2, "flags": ["harmony_throttled"]},
				"note": "Free 7G turns out to have a price after all."},
		],
	},
	"defector": {
		"speaker": "segfault", "title": "A Man with a Folder", "esc": [2, 4], "max_times": 1, "confidence": true,
		"text": "a celestine staff officer says he has next week's raid plans and wants a boat to the littoral compact. we can't verify him. his pgp key is older than his career. could be real. could be a plant.",
		"options": [
			{"label": "Bring him in", "effects": {"gamble": {"chance": 0.6,
				"success": {"reveal_next": 2, "confidence": 3, "flags": ["defector_real"]},
				"fail": {"leak_known": 4, "resolve": -3, "flags": ["defector_plant"]}}},
				"note": "Either the best intelligence of the war or the worst."},
			{"label": "Turn him away", "effects": {},
				"note": "The folder goes back across the strait with him."},
		],
	},
	"blackout": {
		"speaker": "mara", "title": "Load Shedding", "esc": [2, 4], "trigger": "energy",
		"text": "The LNG tanks are empty. The grid can carry the air-defense network or the hospitals and the fab's night shift. Not both.",
		"options": [
			{"label": "Defenses first", "effects": {"energy": 3, "resolve": -6},
				"note": "Rationing cuts homes to four hours of power a day. Radars and lasers stay on."},
			{"label": "Homes and hospitals first", "effects": {"brownout": 2, "resolve": 3},
				"note": "The lasers go dark and the radars lose range for two turns."},
		],
	},
	"fishing_fleet": {
		"speaker": "tamsin", "title": "Two Hundred Trawlers", "esc": [1, 3], "max_times": 2,
		"text": "Two hundred “fishing boats” have anchored off {city} with their lights blazing and their nets dry. Several have antennas taller than their masts.",
		"options": [
			{"label": "Move them on with the coast guard", "effects": {"escalation": 3, "forget": 2},
				"note": "They leave slowly, filming everything. Two of our sites drop off their maps."},
			{"label": "Ignore them", "effects": {"leak_known": 2},
				"note": "They count our launchers and go home with a good catch."},
			{"label": "Report them to the Compact", "effects": {"ally": 2, "leak_known": 1},
				"note": "The Compact issues a statement. The trawlers stay one more night."},
		],
	},
	"pause_offer": {
		"speaker": "kemalu", "title": "Forty-Eight Hours", "esc": [3, 4], "max_times": 1,
		"text": "Through the Compact, the Steering Council offers a forty-eight hour pause to recover the dead at sea. Both sides. No conditions, or none in writing.",
		"options": [
			{"label": "Accept the pause", "effects": {"delay_wave": 1, "escalation": -8, "resolve": -2, "flags": ["recovery_pause"]},
				"note": "Both navies pull bodies from the same water in silence."},
			{"label": "Refuse", "effects": {"resolve": 3, "escalation": 3},
				"note": "Lumen says it will not reward an aggressor with a breather. The aggressor says the same."},
		],
	},
	"insurance": {
		"speaker": "marchetti", "title": "Uninsurable", "esc": [2, 4], "max_times": 1,
		"text": "Meridian Mutual has listed the strait as “uninsurable”. Ship owners are diverting cargo to Littoral ports. Our supply lines are only as long as somebody's risk appetite.",
		"options": [
			{"label": "Underwrite shipping with a state pool", "effects": {"supplies": -30, "energy": 3, "convoy": 3},
				"note": "The Republic becomes an insurer. The actuaries are not happy."},
			{"label": "Let the market find a price", "effects": {"convoy": -3, "resolve": -3},
				"note": "The price is high, the ships are few, and the shelves notice."},
		],
	},
	"rescue": {
		"speaker": "sol", "title": "Under the Rubble", "esc": [1, 4], "trigger": "city_hit",
		"text": "Rescuers are digging people out of the rubble in {city}. They need cranes, generators and the repair crews, today.",
		"options": [
			{"label": "Send the repair crews", "effects": {"resolve": 6, "crews_busy": 1},
				"note": "No repairs elsewhere this turn. Forty-one people come out alive."},
			{"label": "Keep the crews on the defenses", "effects": {"resolve": -5},
				"note": "Auntie Sol reads the names on air."},
		],
	},
}

## Objective templates. {city} and other fields are filled in when created.
const OBJECTIVES := {
	"evacuate": {"title": "Evacuate {city}", "detail": "Keep {city} standing and unhit until turn {deadline}.", "turns": 2,
		"reward": {"resolve": 10}, "penalty": {"resolve": -12}},
	"intercept_aew": {"title": "Down the Skylark", "detail": "Shoot down the airborne radar before it leaves (turn {deadline}).", "turns": 1,
		"reward": {"confidence": 2, "resolve": 3}, "penalty": {}},
	"stop_landing": {"title": "Stop {name}", "detail": "Sink it before it reaches {city} (ETA {eta}).",
		"reward": {}, "penalty": {}},
}
