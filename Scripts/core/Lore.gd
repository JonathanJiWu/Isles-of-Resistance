class_name Lore
extends RefCounted
## Narrative content for the Tessera campaign. See docs/WORLD.md for the world bible.
## Pure data: Campaign.gd decides when each piece appears.

const FACTIONS := {
	"tessera": {"name": "Republic of Tessera", "short": "Tessera", "color": Color(0.31, 0.82, 0.77), "emblem": "lantern"},
	"celestine": {"name": "Celestine Commonwealth", "short": "Commonwealth", "color": Color(1.0, 0.35, 0.37), "emblem": "star"},
	"hesperia": {"name": "Hesperian Federation", "short": "Federation", "color": Color(0.55, 0.68, 1.0), "emblem": "compass"},
	"littoral": {"name": "Littoral Compact", "short": "Compact", "color": Color(0.45, 0.9, 0.6), "emblem": "rings"},
	"tlw": {"name": "Tessera Lithographic Works", "short": "TLW", "color": Color(1.0, 0.82, 0.4), "emblem": "wafer"},
	"harmony": {"name": "Harmony Grid", "short": "Harmony Grid", "color": Color(1.0, 0.45, 0.75), "emblem": "grid"},
	"null": {"name": "Null Collective", "short": "Null Collective", "color": Color(0.75, 1.0, 0.45), "emblem": "null"},
	"halberd": {"name": "Halberd Dynamics", "short": "Halberd", "color": Color(0.7, 0.75, 0.85), "emblem": "compass"},
}

const PEOPLE := {
	"ardent": {"name": "Capt. Teo Ardent", "title": "Air Defense Command", "faction": "tessera"},
	"tamsin": {"name": "Cmdr. Rhea Tamsin", "title": "Coast Guard Administration", "faction": "tessera"},
	"solenne": {"name": "President Imara Solenne", "title": "Republic of Tessera", "faction": "tessera"},
	"haldane": {"name": "Dr. Ines Haldane", "title": "CEO, Tessera Lithographic Works", "faction": "tlw"},
	"mara": {"name": "Mara Okafor-Lin", "title": "Process Engineer, Fab 18", "faction": "tlw"},
	"sol": {"name": "Auntie Sol", "title": "Strait Talk (pirate radio)", "faction": "tessera"},
	"kai": {"name": "Kai Revers", "title": "Lantern Movement", "faction": "tessera"},
	"marrane": {"name": "Hollis Marrane", "title": "Harbor Party", "faction": "tessera"},
	"morai": {"name": "First Steward Taveth Morai", "title": "Steering Council", "faction": "celestine"},
	"kost": {"name": "Marshal Idrena Kost", "title": "Eastern Theater Command", "faction": "celestine"},
	"varo": {"name": "Deputy Minister Sel Varo", "title": "Celestine Commerce Ministry", "faction": "celestine"},
	"sorei": {"name": "Flt. Lt. Ilan Sorei", "title": "Monsoon-2, Celestine Aerospace Force", "faction": "celestine"},
	"haskar": {"name": "Director Lume Haskar", "title": "Harmony Grid", "faction": "harmony"},
	"ashdale": {"name": "President Corwin Ashdale", "title": "Hesperian Federation", "faction": "hesperia"},
	"whitlow": {"name": "Adm. Constance Whitlow", "title": "Task Force Palisade", "faction": "hesperia"},
	"marchetti": {"name": "Under-Sec. Delphine Marchetti", "title": "Hesperian Commerce", "faction": "hesperia"},
	"halvorsen": {"name": "Sen. Rook Halvorsen", "title": "Hesperian Assembly", "faction": "hesperia"},
	"pryce": {"name": "Brannock Pryce", "title": "CEO, Halberd Dynamics", "faction": "halberd"},
	"kemalu": {"name": "Sec. Rasa Kemalu", "title": "Littoral Compact", "faction": "littoral"},
	"segfault": {"name": "segfault", "title": "Null Collective", "faction": "null"},
}

const CAPITAL_NAMES := ["Lumen"]
const FOUNDRY_CITY := "Silica Point"
const CITY_NAMES := [
	"Saltmere", "Kestrel Bay", "Old Customs", "Nine Lanterns", "Tidewater", "Copperline", "Harrow Quay",
	"Sable Cove", "Driftwood", "Emberly", "Lowtide", "Windrest", "Gullhaven", "Seastone", "Fairhollow",
	"Orrin's Reach", "Mosaic Heights", "Stepper's End",
]
const CARRIER_NAMES := ["CCS Patient Tide", "CCS Unbroken Promise", "CCS Recompletion"]
const POWER_NAMES := ["Tidewater Power Station", "Kestrel Bay Power Station", "Saltmere LNG Power Station"]
const CABLE_NAMES := ["Lantern-1 Cable Landing", "Seabright Cable Landing", "Old Customs Cable Landing"]
## Neon signage on Tesseran cities (environmental storytelling).
const SIGNS := ["NOODLES", "KARAOKE", "7G FREE", "BRIGHTLINE", "PHARMACY", "SHELTER →", "OPEN 24H", "HARMONY",
	"TESSAR FX", "LANTERN", "HALBERD", "DUMPLINGS", "CYBER CAFE", "REPAIRS", "HOTEL", "FERRY", "STRAIT TALK", "VOTE"]
const SIGN_COLORS := [Color(1.0, 0.35, 0.75), Color(0.35, 0.95, 1.0), Color(1.0, 0.82, 0.4), Color(0.6, 1.0, 0.5)]

# --------------------------------------------------------------------------------------------
# Acts
# --------------------------------------------------------------------------------------------

const ACTS := [
	{
		"title": "ACT I · QUARANTINE",
		"speaker": "ardent",
		"text": "Three nights ago the Saltmere ferry and a Commonwealth cutter met in the dark, and twenty-three people drowned. Every network has its own version. This morning the Steering Council declared a Peace Enforcement Quarantine over our airspace. Their carriers are east of the Lantern Line, and the Federation is 'monitoring'. The radar is never wrong, Commander. Check it anyway.",
	},
	{
		"title": "ACT II · THE GLASS SHIELD",
		"speaker": "haldane",
		"text": "For thirty years we have told ourselves a comforting story: nobody bombs the factory the whole world depends on. So far the Commonwealth's planners have kept Silica Point off their target lists. They need Fab 18 intact as much as anyone. The Glass Shield is holding. Glass, however, has a known failure mode.",
	},
	{
		"title": "ACT III · THE LONG NIGHT",
		"speaker": "sol",
		"text": "Night twenty-something on Strait Talk. The trains still run in Saltmere, because the drivers refuse to stop. Lumen's billboards are still selling phones nobody can afford. The Federation is 'reviewing options' and the Commonwealth says it's 'almost over'. Caller, you're on the air. Go ahead. Keep it short, the generator's on its last can.",
	},
	{
		"title": "FINALE · TERMS",
		"speaker": "solenne",
		"text": "Every capital that matters is drafting the end of this war, and very few of them have asked us what it should say. The final waves are forming. Whatever terms come next, they will be written around what is still standing. Let's make sure it's us.",
	},
]

const WAVE_LINES := [
	["Contacts east of the Lantern Line. Same squadrons, new paint.", "They call it a quarantine. The bombs call it something else.", "Magpie drones first, then the heavies. They're mapping us."],
	["Monsoons in the stream. They've been studying our batteries.", "Their planners are adapting, so we adapt faster.", "The Glass Shield is a theory. The flak is a fact."],
	["Long night ahead. Keep the coffee and the radar warm.", "Inkwash signatures possible. Trust the phased array, not your eyes.", "They're tired too. Make them more tired."],
	["Everything they have left is in the air.", "This is the wave the history books will argue about.", "Hold until the terms are ours to sign."],
]

# --------------------------------------------------------------------------------------------
# Directives: political decisions with mechanical consequences.
# Effect keys: ally, resolve, supplies, rp, budget [mult, waves], leak_known, reveal_next,
#   glass ("cracked"), foundry_mult, accuracy, strike_lock (turns), no_new_types (waves),
#   convoy (supplies/turn, added), convoy_set, free_tech, flags [], gamble {chance, success, fail}
# --------------------------------------------------------------------------------------------

const DIRECTIVE_ORDER := ["palisade", "harmony_grid", "glass_shield", "back_channel", "night_shift", "null_leak", "convoy", "terms"]

const DIRECTIVES := {
	"palisade": {
		"speaker": "whitlow", "title": "Visible but Not Present",
		"text": "Admiral Whitlow, on a line that is definitely not recorded: “I can bring two destroyers inside the Lantern Line by dawn. Your people would see our flags. So would the Commonwealth, and Marshal Kost would put them on every screen as proof of foreign provocation. Or we stay over the horizon and let the Ambiguity Doctrine do what it does best. Concord wants this to be your call. I mean that literally.”",
		"options": [
			{"label": "Bring the flags in", "effects": {"ally": 12, "resolve": 10, "budget": [1.15, 2], "flags": ["palisade_close"]},
				"note": "Kost gets his footage: the next 2 waves are 15% stronger."},
			{"label": "Stay over the horizon", "effects": {"ally": -6, "resolve": -6, "budget": [0.88, 1], "flags": ["palisade_far"]},
				"note": "A quiet signal of restraint: the next wave is 12% weaker."},
		],
	},
	"harmony_grid": {
		"speaker": "haskar", "title": "Free 7G for the Island Province",
		"text": "The strait cables went dark again overnight, with 'unexplained faults' at three depths. This morning Director Lume Haskar offered to restore Tessera's bandwidth at no cost, “as a gesture between neighbors.” The Brightline alternative is fast, Hesperian and billed by the minute. Kai Revers is already livestreaming the phrase “Harmony Score pre-installed.”",
		"options": [
			{"label": "Accept the gift", "effects": {"supplies": 40, "resolve": 4, "leak_known": 3, "flags": ["harmony_accepted"]},
				"note": "The network is free. The telemetry is not: the enemy learns where 3 of your structures are."},
			{"label": "Pay Brightline", "effects": {"supplies": -30, "ally": 6, "flags": ["brightline"]},
				"note": "Nobody reads the terms of service. You will also not read them."},
			{"label": "Ask Null Collective to audit it", "effects": {"rp": -10, "resolve": -2, "reveal_next": 1, "flags": ["null_ally"]},
				"note": "segfault finds things. You get the next wave's full composition in advance."},
		],
	},
	"glass_shield": {
		"speaker": "marchetti", "title": "Line 7",
		"text": "Under-Secretary Marchetti arrives with interceptors on a pallet and a memo on a tablet. Under the Clean Compute Act, Fab 18's newest production line would be “resiliently relocated” to the Federation. The Longbows ship tomorrow if you sign. Dr. Haldane is silent for a long moment, then: “If Line 7 leaves, Silica Point stops being the one place nobody dares to hit.”",
		"options": [
			{"label": "Sign. Take the Longbows", "effects": {"free_tech": "guided_missiles", "supplies": 80, "ally": 20, "foundry_mult": 0.6, "glass": "cracked", "flags": ["line7_moved"]},
				"note": "Free SAM technology and 80 supplies. The Glass Shield cracks: Silica Point becomes a target."},
			{"label": "Refuse. Line 7 stays", "effects": {"ally": -15, "resolve": 10, "flags": ["line7_kept"]},
				"note": "Sovereignty is popular. It is also unarmed."},
			{"label": "Build Line 8 in the Littoral Compact", "effects": {"supplies": -40, "ally": -4, "convoy": 5, "flags": ["line8_compact"]},
				"note": "A hedge: costs 40 now, then Compact traders add +5 supplies every turn."},
		],
	},
	"back_channel": {
		"speaker": "varo", "title": "A Call from a Fishing Trawler",
		"text": "The call comes in over a trawler's satellite phone. Deputy Minister Sel Varo sounds like he hasn't slept: “Stop striking our carriers for three days and the Council will pause the Needle program in your sector. Nobody signs anything. If Marshal Kost hears about this call, I will be reassigned to a province without a coastline.”",
		"options": [
			{"label": "Take the deal quietly", "effects": {"strike_lock": 3, "no_new_types": 2, "ally": -8, "flags": ["back_channel"]},
				"note": "No carrier strikes for 3 turns. No Needles or Inkwash in the next 2 waves."},
			{"label": "Refuse", "effects": {"resolve": 4, "budget": [1.08, 1], "flags": ["varo_refused"]},
				"note": "The hardliners read the silence as an answer: the next wave is 8% stronger."},
			{"label": "Leak the offer to the press", "effects": {"resolve": 10, "ally": 6, "budget": [1.06, 99], "flags": ["varo_purged"]},
				"note": "Varo vanishes from the Council website. The Restorationists win the argument: every wave from now on is 6% stronger."},
		],
	},
	"night_shift": {
		"speaker": "mara", "title": "The Night Shift",
		"text": "Air Defense Command proposes drafting TLW's firmware engineers to rewrite the fire-control software on every battery. Dr. Haldane's counter-proposal is “Absolutely not.” Mara Okafor-Lin, Fab 18, Line 3, sends a third proposal at 03:12: “We could do both if nobody sleeps. Nobody is sleeping anyway.”",
		"options": [
			{"label": "Draft the night shift", "effects": {"accuracy": 0.06, "foundry_mult": 0.5, "resolve": -5, "flags": ["engineers_drafted"]},
				"note": "+6% accuracy for every weapon. Foundry output is halved."},
			{"label": "Volunteers only", "effects": {"accuracy": 0.03, "foundry_mult": 0.8, "flags": ["engineers_volunteer"]},
				"note": "+3% accuracy. The Foundry loses a fifth of its output."},
			{"label": "The fab keeps running", "effects": {"resolve": 3, "rp": 15, "flags": ["fab_running"]},
				"note": "Haldane sends a thank-you note and a box of yield reports: +15 research."},
		],
	},
	"null_leak": {
		"speaker": "segfault", "title": "git push --force",
		"text": "A message appears on every screen in Air Defense Command, all in lowercase: “hi. we have the eastern theater's maintenance logs. we also have your defense ministry's. we are going to push one of them. you get a vote. we are a democracy too. sort of.”",
		"options": [
			{"label": "Push the Commonwealth's logs", "effects": {"budget": [0.85, 1], "resolve": 4, "flags": ["kost_embarrassed"]},
				"note": "Half the Monsoon fleet is grounded by the scandal: the next wave is 15% weaker. CCB will call it a forgery."},
			{"label": "Pay to bury ours", "effects": {"supplies": -50, "flags": ["paid_null"]},
				"note": "segfault accepts tips in any currency. The logs stay private, as far as you know."},
			{"label": "Don't negotiate with hackers", "effects": {"resolve": -10, "budget": [0.9, 1], "flags": ["both_leaked"]},
				"note": "They push both. Your shelter shortages trend for a week, and so do their grounded bombers."},
		],
	},
	"convoy": {
		"speaker": "kemalu", "title": "Humanitarian Corridor",
		"text": "Secretary Kemalu can get a Littoral Compact convoy through the southern lanes. Meridian Mutual will insure it at a premium its own actuaries describe as “heroic.” There is one condition: no military cargo. “We inspect,” she says. “Mostly.”",
		"options": [
			{"label": "Food and medicine only", "effects": {"supplies": 50, "resolve": 8, "flags": ["convoy_clean"]},
				"note": "Clean cargo, clear conscience."},
			{"label": "Hide munitions under the rice", "effects": {"gamble": {"chance": 0.6,
				"success": {"supplies": 110, "resolve": 3, "flags": ["convoy_smuggled"]},
				"fail": {"supplies": 20, "resolve": -6, "ally": -8, "convoy_set": 0, "flags": ["compact_angry"]}}},
				"note": "60%: +110 supplies. 40%: the Compact finds out, the convoy is cut and reputations are dented."},
			{"label": "Decline", "effects": {"ally": 4, "flags": ["convoy_declined"]},
				"note": "The Federation appreciates your discretion. Nobody else notices."},
		],
	},
	"terms": {
		"speaker": "solenne", "title": "Terms",
		"text": "The Assembly of Tiles is in emergency session in a parking garage under Lumen. The Harbor Party wants talks under Compact mediation. The Lantern Movement wants a formal declaration tonight, on every screen. Captain Ardent wants everyone to stop talking near the radar. President Solenne turns to you: “You've seen the skies. What do we do with what's left?”",
		"options": [
			{"label": "Hold the line. Say nothing", "effects": {"resolve": 2, "flags": ["posture_hold"]},
				"note": "Strategic ambiguity. It turns out to be contagious."},
			{"label": "Open talks under Compact mediation", "effects": {"budget": [0.8, 2], "resolve": -6, "ally": -6, "flags": ["posture_talks"]},
				"note": "The final waves are 20% weaker. Kai Revers calls it surrender. Marrane calls it Tuesday."},
			{"label": "Declare the Lantern Charter", "effects": {"resolve": 18, "ally": -10, "budget": [1.25, 2], "flags": ["posture_independence"]},
				"note": "The final waves are 25% stronger. Every screen in Tessera shows lanterns."},
		],
	},
}

# --------------------------------------------------------------------------------------------
# Cyber operations (spend research points)
# --------------------------------------------------------------------------------------------

const OPS := {
	"null_pointer": {
		"name": "Operation Null Pointer", "cost": 15, "cooldown": 2,
		"ticket": "TICKET-0451 · P1 · component: eastern-theater/targeting-db",
		"desc": "Dereference their targeting database. The enemy forgets the location of up to 3 of your known structures.",
	},
	"rubber_duck": {
		"name": "Operation Rubber Duck", "cost": 10, "cooldown": 3,
		"ticket": "TICKET-0777 · P2 · component: iff/transponders",
		"desc": "Explain the situation to their IFF transponders until they confuse themselves. Every spotted enemy aircraft drops its target and re-plans. Some turn for home.",
	},
	"merge_conflict": {
		"name": "Operation Merge Conflict", "cost": 12, "cooldown": 0, "once_per_wave": true,
		"ticket": "TICKET-1024 · P1 · component: wave-planner/main",
		"desc": "Push conflicting orders to two of their squadron schedulers. The next wave's sector and composition are revealed in advance, and it launches 8% weaker.",
	},
	"rollback": {
		"name": "Operation Rollback", "cost": 30, "cooldown": 6, "min_act": 1,
		"ticket": "TICKET-1337 · P0 · component: carrier-logistics/prod",
		"desc": "Revert the carrier group's logistics database to last Tuesday. The next wave launches one turn later.",
	},
}

# --------------------------------------------------------------------------------------------
# Broadcasts. Placeholders: {city} {lost} {kills} {hits} {wave} {total} {capital} {carrier}
# --------------------------------------------------------------------------------------------

const NEWS := {
	"ccb": {
		"tag": "CCB",
		"quiet": [
			"Steering Council reaffirms that the Island Province's compatriots have nothing to fear except separatists.",
			"Harmony Grid reports 99.97% satisfaction among Island Province users. The remaining 0.03% are being contacted.",
			"First Steward Morai: “History is patient.” Markets are asked to be patient too.",
		],
		"wave": [
			"Peace Enforcement Quarantine enters a new phase of routine enforcement.",
			"Commonwealth aircraft conduct humane precision patrols over the Island Province.",
			"Marshal Kost: the Quarantine will end the moment separatist batteries stop shooting at it.",
		],
		"kills": [
			"Separatist batteries fire recklessly at peacekeeping aircraft. Losses described as “fewer than reported.”",
			"Ministry corrects foreign media: aircraft were not shot down, they “completed their missions early.”",
		],
		"city_lost": [
			"Military targets neutralized near {lost}. Civilian concerns are being addressed by the appropriate departments.",
		],
		"carrier_sunk": [
			"{carrier} enters an unscheduled period of rest. Further questions will not be taken.",
		],
	},
	"hnn": {
		"tag": "HNN",
		"quiet": [
			"President Ashdale “monitoring the situation closely” from the 9th hole. Halberd Dynamics stock up 4%.",
			"Senator Halvorsen: “Not one more Hesper for somebody else's chip factory.” Asked which phone he uses: no comment.",
			"Chip futures surge on news of chips. Analysts recommend panic, with diversification.",
		],
		"wave": [
			"BREAKING: Commonwealth launches wave {wave} of {total}. What it means for your retirement account.",
			"Federation expresses deep concern, also concern. Task Force Palisade remains visible but not present.",
		],
		"kills": [
			"Tessera downs {kills} aircraft overnight. Halberd's CEO calls it “a fantastic product demo.”",
			"Defense analyst: “Tessera's air defense is outperforming expectations, which were low and in our slides.”",
		],
		"city_lost": [
			"{lost} hit in overnight raid. Federation reviewing whether its commitment is ironclad or merely iron-adjacent.",
		],
		"carrier_sunk": [
			"STUNNING: Tessera sinks {carrier}. Markets fall 6%, recover 4%, then fall again out of habit.",
		],
	},
	"lpb": {
		"tag": "LPB",
		"quiet": [
			"Lumen Public Broadcasting reminds residents that shelters are listed on the transit app, which is working, mostly.",
			"Fab 18 confirms Line 3 is still running. A spokesperson asks people to stop sending pizza to the cleanroom door.",
			"Assembly of Tiles debate on wartime budget enters its fourteenth hour. Translators request coffee.",
		],
		"wave": [
			"Air raid sirens across {city}. Residents are advised to stay calm, which they are getting good at.",
		],
		"kills": [
			"Air Defense Command reports {kills} enemy aircraft down. Captain Ardent declines to smile on camera.",
		],
		"city_lost": [
			"{lost} is burning. Volunteers from every party are already on the trains.",
		],
		"carrier_sunk": [
			"Crowds gather on the Lumen waterfront with paper lanterns, the first since the Spring.",
		],
	},
	"sol": {
		"tag": "STRAIT TALK",
		"quiet": [
			"Auntie Sol: “Nobody asked me which superpower I prefer. I prefer my roof.”",
			"Caller from {city}: power's out, fab's still running, the cat is unbothered.",
			"Auntie Sol reads the Harmony Grid terms of service on air. It takes forty minutes. Ratings soar.",
		],
		"wave": [
			"Caller from {city}: “Third night in the subway. The vending machine is now my landlord.”",
			"Auntie Sol: “They keep calling it a quarantine. I keep calling it Tuesday.”",
		],
		"kills": [
			"Caller says she counted {kills} fireballs from her balcony and would like to file a noise complaint with both governments.",
		],
		"city_lost": [
			"Silence on Strait Talk for one full minute, for {lost}. Then the phones start ringing again.",
		],
		"carrier_sunk": [
			"Auntie Sol: “Somebody's mother was on that ship too. Light a lantern for her as well.”",
		],
	},
}

const ADS := [
	"AD · HARMONY GRID: Free 7G for the Island Province. Terms: eternal.",
	"AD · BRIGHTLINE: Your sovereignty, backed up in three regions.",
	"AD · HALBERD DYNAMICS: Peace, now as a service. Annual plans available.",
	"AD · MERIDIAN MUTUAL: War-risk premiums for the Lantern Strait now listed as “lol.”",
	"AD · TLW: Every chip a tile. Every tile its own light.",
	"AD · LANTERN MOVEMENT: Our island. Our turn. Our extremely long Assembly meetings.",
	"AD · HARBOR PARTY: Peace is cheaper. Ask your spreadsheet.",
	"COMPACT: Secretary Kemalu urges restraint and also open shipping lanes, ideally in that order.",
	"VARESK: The Kingdom doubles its defense budget, “for unrelated reasons.”",
	"AD · STEPPERS & SONS: Lithography so precise, it can read your mind. Please do not ask about that.",
]

const DECISION_NEWS := {
	"palisade:0": "HNN: Federation destroyers seen inside the Lantern Line. CCB: “Foreign provocation confirmed.”",
	"palisade:1": "CCB: Federation fleet keeps its distance, which the Council calls “wisdom.” LPB calls it “a long distance.”",
	"harmony_grid:0": "AD · HARMONY GRID: Welcome to the family, Island Province! Your Harmony Score: 412 (provisional).",
	"harmony_grid:1": "BRIGHTLINE: Thank you for choosing Sovereign Tier. Your invoice is attached, and it is also sovereign.",
	"harmony_grid:2": "NULL COLLECTIVE: audit complete. 14,000 lines of telemetry. 3 jokes. 0 tests.",
	"glass_shield:0": "HNN: Tessera agrees to relocate Line 7. Under-Secretary Marchetti: “A win for resilience, and for the Midlands.”",
	"glass_shield:1": "CCB: Island Province rejects Federation “chip colonialism.” Steering Council notes it is still not invited either.",
	"glass_shield:2": "COMPACT: Line 8 groundbreaking announced. Secretary Kemalu describes neutrality as “finally profitable.”",
	"back_channel:0": "LPB: Unusual quiet over the eastern carriers tonight. The government denies everything with great energy.",
	"back_channel:1": "CCB: Marshal Kost: “Our patience has a firmware limit.”",
	"back_channel:2": "HNN: LEAKED: Commonwealth minister offered secret truce. CCB: Deputy Minister Varo “on extended leave.”",
	"night_shift:0": "LPB: Fab engineers report to air defense batteries carrying laptops, energy drinks and opinions.",
	"night_shift:1": "STRAIT TALK: Caller is a fab engineer volunteering at a SAM site. “It's just embedded C. Angrier embedded C.”",
	"night_shift:2": "TLW: Fab 18 achieves record yield. Engineers achieve record caffeine.",
	"null_leak:0": "NULL COLLECTIVE: pushed eastern-theater/maintenance-logs to main. CCB: “A forgery, crudely formatted.”",
	"null_leak:1": "NULL COLLECTIVE: thanks for the tip. this message will self-delete. (it won't)",
	"null_leak:2": "HNN: Both sides' secrets leak. Pundits agree everyone looks bad, which is a relief.",
	"convoy:0": "COMPACT: Humanitarian convoy docks at Old Customs. Meridian Mutual describes the premium as “a learning experience.”",
	"convoy:1": "COMPACT: Convoy arrives. Inspectors report “a surprising amount of very heavy rice.”",
	"convoy:2": "HNN: Tessera declines Compact convoy. Analysts: “Bold.” Also analysts: “What?”",
	"terms:0": "LPB: President Solenne addresses the nation and says nothing at length. Approval up 3%.",
	"terms:1": "COMPACT: Mediation talks begin aboard a cargo ship, the only neutral ground left.",
	"terms:2": "LPB: The Lantern Charter is read aloud in the Assembly of Tiles. Lanterns appear in every window in Lumen.",
}

# --------------------------------------------------------------------------------------------
# Intercepted Commonwealth communications during the enemy phase.
# --------------------------------------------------------------------------------------------

const INTERCEPTS := {
	"launch": [
		["Eastern Theater", "All squadrons: the Steering Council thanks you for your patience. Patience is mandatory."],
		["Magpie Control", "Swarm deploying. Firmware is 0.9.3-beta. Whoever pushed a hotfix on a Friday, I know where you live."],
		["CCS Patient Tide", "Deck crews, launch sequence green. Tea break cancelled for the duration of history."],
		["Shrike Lead", "Briefing says the island welcomes us. Briefing also says light flak. Taking bets on which is wrong."],
	],
	"loss": [
		["Shrike Lead", "Flak is heavier than the briefing said. Somebody tell Intelligence their slide deck is shooting at us."],
		["Magpie Control", "Lost another Magpie. Filing a ticket. Ticket says WONTFIX. Who is closing these?"],
		["Mantis-6", "They moved the battery. They keep moving the batteries. Nobody told us the batteries could move."],
		["Monsoon-2 · Sorei", "Two chutes from Monsoon-5. Mark them for the rescue boats. Please mark them."],
	],
	"heavy_loss": [
		["Eastern Theater", "Losses within acceptable parameters. Parameters are being revised upward."],
		["Monsoon-2 · Sorei", "Half the squadron. Half. Somebody in the Council should come fly this route."],
	],
	"hit": [
		["Monsoon-2 · Sorei", "Payload away. Target looked like an apartment block with a radar on top. I hope it was mostly radar."],
		["Mantis-6", "Battery suppressed. Their gunners were teenagers. So are ours."],
		["Shrike Lead", "Good effect on target. Nobody cheer on the open channel, the Ministry records the tone."],
	],
	"stealth": [
		["Inkwash-1", "Inkwash flight is silent. The trick is to be quieter than the propaganda."],
	],
	"glass_cracked": [
		["Eastern Theater", "Target list amended: Silica Point is no longer a protected site. Acknowledge."],
		["Monsoon-2 · Sorei", "They're putting the chip city on the list? My phone was made there. Everybody's phone was made there."],
	],
	"varo_purged": [
		["Eastern Theater", "Reminder: all back-channel communications are now forward-channel communications. To Marshal Kost."],
	],
	"back_channel": [
		["CCS Unbroken Promise", "Needle launchers stood down per Commerce Ministry request. Marshal's office is... asking questions."],
	],
	"kost_embarrassed": [
		["Monsoon-2 · Sorei", "Half our birds grounded for 'maintenance irregularities'. So the leak was real. Good to know what we're flying."],
	],
	"generic": [
		["Monsoon-2 · Sorei", "My sister says the trains in Saltmere still run on time. Ours don't. Don't tell the Council I said that."],
		["Magpie Control", "Drone 41 has identified its own carrier as hostile. Workaround: do not be the carrier."],
		["Eastern Theater", "Reminder: the term is 'quarantine'. Pilots using the term 'war' will have their Harmony Score adjusted."],
		["Shrike-3", "Is it true the island makes the chips in our targeting pods? Asking for a targeting pod."],
		["CCS Recompletion", "Galley reports morale steady. Galley also reports we are out of noodles. Morale under review."],
	],
}

# --------------------------------------------------------------------------------------------
# One-off story beats (comms cards)
# --------------------------------------------------------------------------------------------

const BEATS := {
	"first_carrier": {"speaker": "ardent", "text": "Carrier sighted. That's a Harmony-class flat-top, Commander, with three thousand sailors aboard and most of their air wing. Sink them all and this war ends. Sink one and the whole world will have an opinion about it."},
	"first_city_lost": {"speaker": "sol", "text": "We lost a city tonight. I'm not going to read the names on air yet. I'm going to read the list of shelters that still have room. Then the names."},
	"glass_cracked": {"speaker": "haldane", "text": "The intercepts confirm it: Silica Point is on their target list. The Glass Shield was always a theory. Defend the Foundry, Commander. Without it, the world stops caring and starts calculating."},
	"varo_purged": {"speaker": "kai", "text": "Varo's gone. 'Extended leave.' We did that. I'm not sure we did the right thing, and I'm sure it was popular. Those are different, apparently."},
	"ally_shipment": {"speaker": "whitlow", "text": "Shipment's on the way: supplies, spares, and a letter from Halberd's legal department I suggest you never open."},
}

# --------------------------------------------------------------------------------------------
# Intel Archive. unlock: "start" | "act1" | "act2" | "act3" | "flag:<name>" | "kill:<kind>"
#   | "carrier_seen" | "city_lost" | "tech:<id>"
# --------------------------------------------------------------------------------------------

const CODEX := [
	{"id": "tessera", "cat": "Factions", "title": "The Republic of Tessera", "unlock": "start",
		"text": "An archipelago democracy of thirty million people and roughly as many opinions. Its emblem is a lantern over a mosaic tile, after the Lantern Spring that ended the Harbor Authority's martial law forty years ago. Politics divides three ways. The Lantern Movement wants sovereignty and suspects everyone. The Harbor Party wants peace and trade and is accused of wanting more. Tile & Wafer wants nothing near the cleanrooms to explode. Tessera wants Federation protection without Federation control, and Commonwealth trade without Commonwealth rule. On a good day it gets both."},
	{"id": "celestine", "cat": "Factions", "title": "The Celestine Commonwealth", "unlock": "start",
		"text": "The world's largest industrial economy, governed by the Steering Council. Within living memory it climbed out of the Charter Century, when foreign powers carved its coastline into “chartered” ports. It calls reunification with Tessera the Recompletion and regards the island as the last unhealed scar of that era. Restorationists believe the strategic window is closing. Pragmatists, especially in the coastal provinces where eleven million jobs depend on Tesseran-owned factories, want a deal. Technocrats think time is on their side and this war is early. The Commonwealth insists the islanders are compatriots awaiting liberation, and it is bombing their radars."},
	{"id": "hesperia", "cat": "Factions", "title": "The Hesperian Federation", "unlock": "start",
		"text": "Architect and principal beneficiary of Pax Hesperia, the eighty-year order of open sea lanes, Federation fleets and a reserve currency called the Hesper. It is sincere about sovereignty and self-determination except when the Clean Compute Act requires otherwise. Its policy toward Tessera is the Ambiguity Doctrine: never say what you'd do. Primacy hawks want to fight, restrainers want to come home, and the Market Caucus wants whatever the quarter needs. It is an election year."},
	{"id": "littoral", "cat": "Factions", "title": "The Littoral Compact", "unlock": "act1",
		"text": "A bloc of southern maritime states. They trade with the Commonwealth, exercise with the Federation and insure everybody. Their foreign ministers are the most experienced hedgers alive. Secretary Rasa Kemalu: “Neutrality is a full-time job, and the overtime is terrible.”"},
	{"id": "tlw", "cat": "Factions", "title": "Tessera Lithographic Works", "unlock": "start",
		"text": "“The Foundry.” Founded thirty years ago with eleven engineers and a borrowed cleanroom, TLW now makes nearly every advanced chip on Earth, at Fab 18 in Silica Point. CEO Ines Haldane preaches the Glass Shield: nobody bombs the factory the whole world depends on. TLW is also, quietly, building fabs abroad. Shields work better when you are sure of them, and nobody is."},
	{"id": "harmony", "cat": "Factions", "title": "Harmony Grid", "unlock": "flag:harmony_accepted",
		"text": "State champion of Celestine telecoms and AI, connecting 2.1 billion devices and, if you accepted the gift, now 2.1 billion and eleven. Every account ships with a Harmony Score widget that, the company stresses, is purely informational. The widget cannot be uninstalled. That too is purely informational."},
	{"id": "null", "cat": "Factions", "title": "Null Collective", "unlock": "act2",
		"text": "Hacktivists who leak everyone's secrets with scrupulous impartiality. Their spokes-handle is segfault. They communicate in lowercase commit messages and have no known address, flag or tests. Both governments call them a foreign operation. Both may be right."},
	{"id": "halberd", "cat": "Factions", "title": "Halberd Dynamics & Brightline", "unlock": "act1",
		"text": "Two Hesperian giants with a stake in Tessera's survival, under certain terms and conditions. Halberd sells the Longbow SAM and the Lumen laser, and its CEO, Brannock Pryce, promises “peace through superior quarterly earnings.” Brightline hosts half of Tessera's government in its cloud. Its terms of service are 212 pages long and were last read by a human in a pilot program."},
	{"id": "p_solenne", "cat": "People", "title": "President Imara Solenne", "unlock": "start",
		"text": "A former TLW process engineer, now president of a coalition that agrees on almost nothing. She is often accused of indecision. She would describe it as keeping every option alive long enough for one of them to work. “Everyone wants to decide what Tessera is. We would like a turn.”"},
	{"id": "p_ardent", "cat": "People", "title": "Captain Teo Ardent", "unlock": "start",
		"text": "Your briefing officer at Air Defense Command. Fourteen years on the radar consoles, three marriages to the job, one vending machine he considers a colleague. He trusts sensors, distrusts slides, and has never once been impressed by a press release."},
	{"id": "p_mara", "cat": "People", "title": "Mara Okafor-Lin", "unlock": "act1",
		"text": "Night shift, Fab 18, Line 3. Her grandparents fled the mainland, her partner works for a Celestine-owned shipping line, and her mother calls every night to ask why she hasn't evacuated. “The steppers don't stop for air raids. If they cool down it's four months to recalibrate. So we stay.”"},
	{"id": "p_sol", "cat": "People", "title": "Auntie Sol", "unlock": "act1",
		"text": "Saltmere fishmonger, grandmother of six, and host of Strait Talk, a pirate call-in show broadcast from behind the ice bins. She has been fined by three governments and reports none of them in particular. “Nobody asked me which superpower I prefer. I prefer my roof.”"},
	{"id": "p_kai", "cat": "People", "title": "Kai Revers", "unlock": "act2",
		"text": "Lantern Movement organizer, twenty-four, very online. He distrusts the Commonwealth on principle and the Federation from experience. “We didn't light lanterns forty years ago so somebody else could hold the match.” His mother votes Harbor Party, and Sunday lunches are tense."},
	{"id": "p_marrane", "cat": "People", "title": "Hollis Marrane", "unlock": "act2",
		"text": "Deputy Speaker and leader of the Harbor Party. His district builds ships for Commonwealth customers, and his grandfather sailed from the mainland coast. Some of his colleagues are genuine sympathizers of the Commonwealth; he is a man who has read the casualty projections. “I am called a traitor in the morning and a realist by lunch. The war doesn't care which.”"},
	{"id": "p_morai", "cat": "People", "title": "First Steward Taveth Morai", "unlock": "start",
		"text": "Chair of the Steering Council. His legacy depends on the Recompletion, and his economy depends on not getting sanctioned for it. Publicly serene, privately briefed every morning on youth unemployment in the interior. “History is patient. The Council is patient. The fiscal year is not.”"},
	{"id": "p_kost", "cat": "People", "title": "Marshal Idrena Kost", "unlock": "act1",
		"text": "Commander of the Eastern Theater and the Restorationists' most respected voice. She lost an uncle to Federation sanctions-era shortages and does not believe in windows that stay open. “Every year we wait, they pour another runway.” Her pilots say she flies the routes she orders, once."},
	{"id": "p_varo", "cat": "People", "title": "Deputy Minister Sel Varo", "unlock": "act2",
		"text": "Commerce Ministry, Pragmatist, and a graduate of Lumen University (class of the Lantern Spring, as it happens). His coastal provinces assemble the products Tessera designs. “Explain to me how bombing our best customers is a growth strategy.”"},
	{"id": "p_sorei", "cat": "People", "title": "Flight Lieutenant Ilan Sorei", "unlock": "kill:bomber",
		"text": "Monsoon-2, Celestine Aerospace Force, from the coastal province of Haveth. He joined for the education benefits and the view. His sister assembles circuit boards at a Tesseran-owned plant in Haveth. His intercepted chatter is the most-quoted transcript in your signals office, and nobody quite knows why they care."},
	{"id": "p_whitlow", "cat": "People", "title": "Admiral Constance Whitlow", "unlock": "start",
		"text": "Commander of Task Force Palisade. She is a professional, plain-spoken, and painfully aware that deterrence is a bluff that only works if nobody calls it. “My orders are to be visible but not present. I'm told that's a strategy.”"},
	{"id": "p_marchetti", "cat": "People", "title": "Under-Secretary Delphine Marchetti", "unlock": "act2",
		"text": "Author of the Clean Compute Act and the Federation's most effective negotiator, mostly because she always brings interceptors. “Resilience means the chips are made somewhere we can protect. Ideally somewhere with our postal codes.”"},
	{"id": "glass_shield", "cat": "Terms", "title": "The Glass Shield", "unlock": "start",
		"text": "The theory that Tessera is safe because everyone needs its chips. While the shield holds, Commonwealth planners keep Silica Point off their target lists. Some decisions crack it, and if it cracks, the Foundry becomes the most valuable target in the war. It is a shield made of glass, and everyone knows what glass is for."},
	{"id": "ambiguity", "cat": "Terms", "title": "The Ambiguity Doctrine", "unlock": "start",
		"text": "Federation policy: never state whether the Federation would fight for Tessera. Deterrence through uncertainty. It has kept the peace for forty years by guaranteeing that nobody, including the Federation, knows the answer."},
	{"id": "charter", "cat": "Terms", "title": "The Charter Century", "unlock": "act1",
		"text": "A century in which foreign trading powers forced 'unequal charters' on the Celestine coast. Tessera was one of the chartered ports. Celestine schoolchildren learn it as a national wound. Tesseran schoolchildren learn that their islands had peoples, names and quarrels long before any charter, and that the charter was imposed on them too. Both curricula are partly right and entirely sincere."},
	{"id": "spring", "cat": "Terms", "title": "The Lantern Spring", "unlock": "act1",
		"text": "Forty years ago, a million paper lanterns lined the Lumen waterfront and the Harbor Authority's martial law ended without a shot. The Commonwealth calls it a foreign-sponsored color revolution. The Federation calls it a triumph of democracy, having been briefly unsure at the time."},
	{"id": "doc_order1", "cat": "Documents", "title": "Eastern Theater Order No. 1", "unlock": "start",
		"text": "PEACE ENFORCEMENT QUARANTINE: GENERAL ORDER. 1. The Quarantine is not a war. 2. Personnel will refer to it as a quarantine. 3. Targets are limited to separatist military installations, and to installations that may become separatist military installations. 4. Silica Point is a protected site until further notice. 5. Further notice may be given."},
	{"id": "doc_ferry_ccb", "cat": "Documents", "title": "Saltmere Ferry Incident: CCB account", "unlock": "start",
		"text": "At 02:14 a separatist ferry, operating without lights, deliberately rammed Commonwealth Coast Guard cutter 1147 inside Commonwealth waters. Nine heroic sailors were lost. The Island Province's leadership bears full responsibility. Footage of the incident is being prepared for release."},
	{"id": "doc_ferry_lpb", "cat": "Documents", "title": "Saltmere Ferry Incident: LPB account", "unlock": "act2",
		"text": "At 02:14 the night ferry from Saltmere, lights on and on its registered route, was cut off by a Commonwealth cutter running dark on our side of the Lantern Line. Fourteen passengers drowned, including two children and a ferry cook who had worked the route for thirty years. The promised Commonwealth footage has not been released."},
	{"id": "doc_ferry_null", "cat": "Documents", "title": "Saltmere Ferry Incident: bridge recording", "unlock": "act3",
		"text": "Leaked by Null Collective. Ferry bridge, 02:13: “…cutter's lights are off, are they mad?” “Hold course, we have right of way.” Cutter bridge, 02:13: “…ferry won't yield, orders say hold the line.” “Which line?” 02:14: both radios, at once. Then nothing. Both governments call the recording a fabrication. Both have quietly stopped calling for an investigation."},
	{"id": "doc_clean_compute", "cat": "Documents", "title": "Clean Compute Act, §7(b)(iv), annotated", "unlock": "act2",
		"text": "“No advanced computing article shall be exported to a Country of Concern, or to any entity which may in future become concerning, or which a reasonable person might find concerning.” Annotation (Brightline Legal): “Everything is concerning. Please contact your account manager.”"},
	{"id": "doc_magpie", "cat": "Documents", "title": "Magpie firmware release notes 0.9.3-beta", "unlock": "kill:drone",
		"text": "NEW: Swarm formation “Plum Blossom” (experimental). FIXED: drones no longer salute radar dishes. KNOWN ISSUES: drone may identify its own carrier as hostile (workaround: do not be the carrier). Battery estimates are optimistic, as is this release."},
	{"id": "doc_sister", "cat": "Documents", "title": "Letter from Haveth", "unlock": "kill:bomber",
		"text": "Intercepted personal mail, translated. “Ilan: the plant is still open. The Tesseran managers came to the floor and said nobody is being let go, whatever the news says. Mother says to eat. I say come home. The boards I solder go into the radars you're flying at. I think about that a lot. Don't write back if it's not allowed. Write back anyway.”"},
	{"id": "doc_morai_memo", "cat": "Documents", "title": "Steering Council memo: “On Patience”", "unlock": "act3",
		"text": "Internal. Not for circulation. Interior youth unemployment rose again this quarter. The coastal provinces report export orders down 31% since the Quarantine began. Recommendation: the Quarantine must conclude before the Spring Festival, with the Recompletion achieved or, failing that, a result that can be described as the Recompletion. Drafting has begun on both."},
	{"id": "doc_lumen_eula", "cat": "Documents", "title": "Lumen laser EULA", "unlock": "tech:directed_energy",
		"text": "Halberd Dynamics End User License Agreement, Sovereign Edition. §3: Licensee may fire Lumen at hostile aircraft, missiles and drones. Licensee may not fire Lumen at Halberd shareholders, auditors or license servers. §9: Lumen requires an active connection to Halberd licensing infrastructure. Halberd is not responsible for wars that interrupt connectivity."},
	{"id": "doc_ticket", "cat": "Documents", "title": "TLW incident ticket FAB18-4471", "unlock": "flag:glass_cracked",
		"text": "Title: Facility listed as valid target by adversary. Severity: Critical. Steps to reproduce: (1) be the world's chip supply, (2) move a production line abroad, (3) observe. Expected: Glass Shield holds. Actual: Glass Shield does not hold. Assigned to: Air Defense Command. Status: IN PROGRESS. Comment (M. Okafor-Lin): “we are still running line 3. please do not close this ticket.”"},
	{"id": "doc_harmony_tos", "cat": "Documents", "title": "Harmony Grid ToS: Island Province edition", "unlock": "flag:harmony_accepted",
		"text": "By connecting, you agree that your data belongs to the network, the network belongs to the people, and the people are represented by the network. Your Harmony Score is calculated from factors including payment history, punctuality, social harmony and “vibes (provisional).” Disputes are resolved by the Harmony Grid, harmoniously."},
	{"id": "doc_brightline", "cat": "Documents", "title": "Brightline Sovereign Tier agreement", "unlock": "flag:brightline",
		"text": "Sovereign Tier guarantees your nation's data is stored in your nation, replicated in ours, and backed up in a third location selected for its stable relationship with us. Brightline will never access your data without a warrant, a subpoena or a strongly worded request. Uptime SLA: 99.99%, excluding wars."},
	{"id": "doc_null_readme", "cat": "Documents", "title": "null-collective/README.md", "unlock": "flag:null_ally",
		"text": "# null collective. we don't pick sides. sides are a data structure with too many null references. ## install: you can't. ## contributing: you already have. ## license: everyone's secrets are public domain, including ours (if you find them). ## tests: no."},
	{"id": "doc_varo", "cat": "Documents", "title": "Varo's last interview (cached)", "unlock": "flag:varo_purged",
		"text": "Cached copy of a deleted Commerce Ministry podcast. “People ask whose side I'm on. I'm on the side of the container ship. Container ships don't care about history; they care about the next port. If you want to know whether a war is wise, ask the shipping schedules. They always know first.” The episode was deleted eleven minutes after the leak."},
	{"id": "doc_sol_transcript", "cat": "Documents", "title": "Strait Talk, night 12 (transcript)", "unlock": "act2",
		"text": "SOL: You're on the air. CALLER: My son's on a flak battery in Kestrel Bay, my brother sells shrimp to the mainland, my daughter works for Brightline. Who am I supposed to be angry at? SOL: Pick a time slot for each. CALLER: That's… actually helpful. SOL: Next caller."},
	{"id": "doc_rate_card", "cat": "Documents", "title": "Meridian Mutual rate card", "unlock": "act2",
		"text": "WAR-RISK PREMIUMS, LANTERN STRAIT. Bulk carrier: 4.5% of hull value. Container ship: 6%. Ferry: please don't. Chip shipment from Silica Point: price on application, application on a prayer. Note: “lol” is a valid premium in our pricing engine and we have no plans to fix it."},
]

# --------------------------------------------------------------------------------------------
# Epilogues
# --------------------------------------------------------------------------------------------

const ENDINGS := {
	"waves": {
		"title": "The Long Ceasefire",
		"text": "The last wave turned back over the Lantern Line, and no new one came. Nobody signed a peace. The Steering Council declared the Quarantine “successfully concluded,” the Federation declared its commitment “vindicated,” and Tessera declared nothing at all, because the Assembly of Tiles could not agree on the wording.",
	},
	"talks": {
		"title": "The Mediated Peace",
		"text": "Talks aboard a Littoral Compact cargo ship produced a document that each side reads differently and all sides have signed. The Quarantine becomes a 'monitoring arrangement'. The Lantern Line is redrawn half a kilometer east in one translation and half a kilometer west in another. It is, everyone agrees, a terrible peace, and therefore probably a durable one.",
	},
	"independence": {
		"title": "The Lantern Charter",
		"text": "Tessera survived the final waves and declared itself, at last, plainly and on every screen. The Commonwealth calls the Charter null and void. The Federation calls it “a matter for the parties,” which in the Ambiguity Doctrine is practically a hug. Nothing about the strait is settled. Something about the island is.",
	},
	"fleet": {
		"title": "Burning Tide",
		"text": "The carriers are gone, along with nine thousand sailors who were mostly nineteen. The Quarantine collapsed with them, and so did global markets, twice. Tessera won the war that was fought, and it may have started the next argument, about what a small country is allowed to do to a large one. In Haveth, families wait at the harbor.",
	},
	"defeat": {
		"title": "Terms Without Us",
		"text": "Lumen fell silent. The Commonwealth announced the Recompletion. The Federation announced sanctions. The Littoral Compact announced concern. Within a week, the future of thirty million people was being negotiated in three capitals, none of them Tesseran. But the Assembly of Tiles still meets in a parking garage, Strait Talk is still on the air, and Fab 18 is still running, very slowly, very deliberately.",
	},
}

const ENDING_FLAGS := {
	"line7_moved": "Line 7 now hums in a Federation cleanroom. The Glass Shield is a memory, and Tessera's security rests on something less transparent.",
	"line7_kept": "Fab 18 still makes the world's best chips, and the world still has a reason to care about the islands.",
	"line8_compact": "Line 8 opens in the Littoral Compact: the first fab ever built to make neutrality profitable.",
	"back_channel": "Somewhere in the Commerce Ministry, a deputy minister keeps a trawler's phone number in his desk drawer.",
	"varo_purged": "Sel Varo's name has been removed from the Commerce Ministry website. His last interview is still cached on four continents.",
	"engineers_drafted": "The fire-control firmware written by Fab 18's night shift is still running. Nobody knows how it works, and nobody is allowed to touch it.",
	"harmony_accepted": "Every phone in Tessera still carries Harmony Grid's free 7G. Most people have stopped noticing the Harmony Score widget.",
	"kost_embarrassed": "Marshal Kost was 'promoted' to a training command after the maintenance logs. Her pilots say the routes got safer.",
	"compact_angry": "The Littoral Compact has not forgotten the rice. Its inspectors now weigh every sack twice.",
	"convoy_clean": "Every school in Old Customs has a mural of the Compact convoy. None of them show the insurance paperwork.",
}

const OUTLET_ENDINGS := {
	"waves": ["CCB: “Quarantine objectives achieved. Island Province compatriots thank the Council for its patience.”",
		"HNN: “Tessera holds! Halberd up 12%. Analysts: ‘This was always going to happen, per our updated slides.’”",
		"STRAIT TALK: “We're still here. The fish are still here. Caller, go ahead, it's a good night.”"],
	"talks": ["CCB: “Peaceful dialogue confirms the Council's wisdom.”",
		"HNN: “Compact-brokered deal: Ashdale campaign calls it ‘a win’, opposition calls it ‘a different win’.”",
		"STRAIT TALK: “Terrible deal. Everybody's alive. I'll take it.”"],
	"independence": ["CCB: “Separatist declaration has no legal effect and is not being discussed in any meeting.”",
		"HNN: “Tessera declares the Lantern Charter. Federation: ‘a matter for the parties’. Markets: ‘a matter for markets’.”",
		"STRAIT TALK: “Lanterns in every window. Now somebody please fix the trains.”"],
	"fleet": ["CCB: “Three ships are undergoing an extended period of rest. A national day of mourning has been declared.”",
		"HNN: “TESSERA SINKS FLEET. Markets in freefall. Senator Halvorsen ‘reconsidering everything except his position.’”",
		"STRAIT TALK: “Light a lantern for theirs too. Somebody's son was on those ships.”"],
	"defeat": ["CCB: “The Recompletion is achieved. A new chapter of harmony begins.”",
		"HNN: “Tessera falls. Federation ‘deeply concerned’, Halberd ‘reviewing guidance’, chips ‘unavailable’.”",
		"STRAIT TALK: “This is Auntie Sol. We're still on the air. As long as we're on the air, it isn't over.”"],
}

const CODAS := {
	"mara": {
		"waves": "Mara Okafor-Lin finished her shift at 06:00, as she has every day of the war. She slept for fourteen hours. Line 3 never stopped.",
		"talks": "Mara Okafor-Lin's partner got his job back at the Celestine shipping line. They argue about the peace at dinner, which is how they know it's peace.",
		"independence": "Mara Okafor-Lin hung a paper lantern in the cleanroom gowning area. It violates three contamination protocols. Nobody has taken it down.",
		"fleet": "Mara Okafor-Lin watched the carrier footage once and turned it off. Then she wrote to a TLW supplier in Haveth to ask if everyone was all right.",
		"defeat": "Mara Okafor-Lin still runs Line 3, slowly and deliberately, at exactly the yield the new administrators can't quite prove is sabotage.",
	},
	"sorei": {
		"waves": "Flight Lieutenant Ilan Sorei flew his last sortie on the final night. He applied for a transfer to search-and-rescue the next morning.",
		"talks": "Ilan Sorei's squadron was stood down the week the talks began. He took the ferry to Haveth and helped his sister move apartments.",
		"independence": "Ilan Sorei's last intercepted message was a single line: “Their lanterns are visible from altitude.” His Harmony Score has since been adjusted.",
		"fleet": "Ilan Sorei's bomber was ashore for maintenance when the carriers went down. He has not stopped writing to the families of his crew chiefs.",
		"defeat": "Ilan Sorei was decorated in the capital. He wore the medal once, for his mother, and then gave it to his sister to sell.",
	},
	"sol": {
		"waves": "Strait Talk's ratings are at an all-time high. Auntie Sol has three fines outstanding and plans to frame them.",
		"talks": "Auntie Sol now hosts a second show, Strait Talk Peace Edition, which is the same show with fewer sirens.",
		"independence": "Auntie Sol read the Lantern Charter on air, all of it, and then took calls from anyone who disagreed. The line was busy for a week.",
		"fleet": "Auntie Sol devoted an entire broadcast to callers from the mainland. Nobody in either government enjoyed it. Everybody listened.",
		"defeat": "Strait Talk is still on the air, now from a different fish market every night. You can't jam a fishmonger.",
	},
}


static func person(id: String) -> Dictionary:
	return PEOPLE.get(id, {"name": id, "title": "", "faction": "tessera"})


static func faction_color(fid: String) -> Color:
	return FACTIONS.get(fid, FACTIONS["tessera"])["color"]
