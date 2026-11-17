class_name HowToPlayPanel
extends Modal
## Rules reference.

const TEXT := """[b][color=#ff8fc7]THE SETTING[/color][/b]
The [b]Republic of Tessera[/b] is an island democracy that makes nearly every advanced chip on Earth. Across the Lantern Strait, the rising [b]Celestine Commonwealth[/b] calls it a lost province and has declared a “Peace Enforcement Quarantine.” Far to the west, the [b]Hesperian Federation[/b] keeps its fleet “visible but not present.” You command Tessera's Air Defense Command. The full world bible is in docs/WORLD.md, and the [b]Intel Archive[/b] [I] collects dossiers and documents as the story unfolds.

[b][color=#ff8fc7]DIRECTIVES[/color][/b]
Between waves, ministers, admirals, CEOs, hackers and back channels bring you decisions. Every option lists its concrete consequences. Some change supplies or research, some make the next waves stronger or weaker, some change what the enemy knows, and all of them change how the war ends. You must answer a directive before ending your turn.

[b][color=#ff8fc7]RESOLVE & COMMITMENT[/color][/b]
[b]Public Resolve[/b] is Tessera's will to fight: Defiant adds income, Shaken and Breaking cut it. Losing cities hurts it; repelling waves and sinking carriers raise it. [b]Hesperian Commitment[/b] decides whether the Federation sends arms shipments after each repelled wave.

[b][color=#ff8fc7]THE FOUNDRY & THE GLASS SHIELD[/color][/b]
[b]Silica Point[/b] hosts TLW's Fab 18 and produces extra supplies and research. While the [b]Glass Shield[/b] holds, Commonwealth planners will not target it, because they need the chips too. Some decisions crack the shield. Then the Foundry becomes their favorite target.

[b][color=#ff8fc7]CYBER OPERATIONS[/color][/b]
Spend research points on hacks [O]: make the enemy forget your sites, scramble their IFF, reveal and weaken the next wave, or roll their logistics back a day.

[b][color=#4fd1c5]OBJECTIVE[/color][/b]
The Commonwealth's carrier groups are launching wave after wave of aircraft at the archipelago. [b]Protect your Capital[/b]. If it falls, the war is lost. You win by surviving every wave, or by finding and [b]sinking every enemy carrier[/b].

[b][color=#4fd1c5]TURNS[/color][/b]
Each turn you collect supplies and research, then build, research, move units and launch operations. Press [b]END TURN[/b] (Space). In the enemy phase, aircraft fly toward their targets and your defenses [b]fire automatically[/b] at anything in range. Battle animations can be skipped with Space.

[b][color=#4fd1c5]RESOURCES[/color][/b]
[color=#ffd166]Supplies[/color] come from your Capital (+12), Cities (+5 each) and Harbors (+6). Losing a city cuts your income. [color=#99bfff]Research[/color] comes from the Capital (+3) and Research Labs (+4). Balance new defenses, research and counterattacks.

[b][color=#4fd1c5]TERRAIN[/color][/b]
[b]Hills[/b]: weapons gain +1 range, structures +1 vision.  [b]Forest[/b]: camouflage. The enemy only spots structures here from an adjacent hex.  [b]Mountains[/b]: radar only (+2 vision); low-flying aircraft must fly around them.  [b]Coast[/b]: Harbors must touch the sea. Frigates sail any water.

[b][color=#4fd1c5]ALTITUDE MATTERS[/color][/b]
[b]Flak[/b] shreds [i]low[/i] flyers (drones, gunships, cruise missiles) but barely scratches [i]high[/i] bombers. [b]SAM Sites[/b] are the opposite. [b]Lasers[/b] hit everything. [b]Radar coverage[/b] adds accuracy to every weapon firing into it. Hover a structure in the build menu to see its numbers.

[b][color=#4fd1c5]THE ADAPTIVE ENEMY[/color][/b]
The enemy only knows what its aircraft have seen, plus any defense that has fired at them. It routes around known air defenses, remembers where it took losses, picks a new approach vector, and re-balances each wave to counter your favorite weapons. Watch the [color=#8cb8ff]HQ Intelligence[/color] reports. Red dashed [b]intent lines[/b] show where spotted aircraft are heading.

[b][color=#4fd1c5]FOG OF WAR & RECON[/color][/b]
You only see what your structures and units can see. Radar Stations see far, Frigates patrol the sea, and a [b]Recon Flight[/b] (15 supplies, once per turn) reveals any area within 12 hexes of your Capital or an Airbase. Research Improved Radar, Coastwatchers, Phased Array (detects [b]stealth bombers[/b]) and Satellite Uplink.

[b][color=#4fd1c5]AIR POWER[/color][/b]
Airbases train [b]Interceptor[/b] squadrons. Move them (within 6 hexes of an Airbase) next to an enemy and attack, or leave them idle: idle squadrons [b]patrol[/b] and engage the first enemy within 2 hexes during the enemy phase. Beware fighter escorts.

[b][color=#4fd1c5]COUNTERATTACK[/color][/b]
Enemy carriers hide in the eastern deep. Spot one, then hit it with an [b]Air Strike[/b] from an Airbase (range 10) or a [b]Cruise Missile[/b] from a Missile Battery (range 12). Every carrier sunk shrinks future waves; sinking them all wins the war.

[b][color=#4fd1c5]CONTROLS[/color][/b]
Left click: select / build / order  ·  Shift+click: keep building  ·  Right click or Esc: cancel  ·  WASD, arrows or right-drag: pan  ·  Mouse wheel or Q/E: zoom  ·  1-0: quick build  ·  R: research  ·  V: coverage overlay  ·  Tab: next ready unit  ·  H: center on Capital  ·  I: Intel Archive  ·  O: Cyber Ops  ·  Space: end turn / skip animations"""


func _init() -> void:
	super(Vector2(820, 0))
	title("HOW TO PLAY")
	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(780, 560)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	content.add_child(scroll)
	var r := RichTextLabel.new()
	r.bbcode_enabled = true
	r.fit_content = true
	r.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	r.add_theme_font_size_override("normal_font_size", 15)
	r.add_theme_font_size_override("bold_font_size", 15)
	r.add_theme_font_size_override("italics_font_size", 15)
	r.text = TEXT
	scroll.add_child(r)
	var done := UITheme.button("Close", 160, 40)
	done.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	done.pressed.connect(func(): Audio.play("click"); close())
	content.add_child(done)
