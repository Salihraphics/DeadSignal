DEAD SIGNAL

<p align="center">
  <img src="./logo_20261025_230756_0000.png" alt="Dead Signal Logo" width="420">
</p><p align="center">
  <strong>One room. One decision. A nation's fate.</strong>
</p><p align="center">
  A stylized 3D Cold War command-room game set in a fictional world around 1985.
</p><p align="center">
  <img src="https://img.shields.io/badge/Platform-Android-3DDC84?logo=android&logoColor=white" alt="Platform Android">
  <img src="https://img.shields.io/badge/Engine-Godot_4-478CBF?logo=godotengine&logoColor=white" alt="Engine Godot 4">
  <img src="https://img.shields.io/badge/Language-GDScript-355570" alt="Language GDScript">
  <img src="https://img.shields.io/badge/Graphics-3D-8A63D2" alt="Graphics 3D">
  <img src="https://img.shields.io/badge/Status-In_Development-E67E22" alt="Status In Development">
</p>---

About

DEAD SIGNAL is an atmospheric, Cold War-inspired strategy and decision-making game.

You are an operator in an underground military command facility belonging to Norvak. Surrounded by CRT monitors, analogue controls, and unreliable communications, you must make critical decisions while a war unfolds beyond your walls.

You have the authority to launch missiles without waiting for another person's approval. But authority does not guarantee certainty, and every decision can carry consequences.

Will you follow orders, question them, or decide for yourself?

Features

- Immersive command room — A confined underground facility with a gritty, stylized 3D aesthetic.
- Military communications — Receive orders, reports, and warnings.
- Battlefield monitoring — Inspect a fictional tactical map and radar information.
- Strategic decisions — Make choices under uncertainty.
- Missile launch sequences — Witness launches through the reinforced observation window.
- Consequential gameplay — Influence the battlefield and the fate of Norvak.
- Multiple endings — Your performance and decisions shape the outcome.

These are planned features. Not all are implemented yet.

The World

The game takes place around 1985 in a fictional world where Norvak is fighting an alliance of three neighbouring powers.

- Norvak — A northern industrial republic.
- Dravonya — An eastern power with a massive army and heavy artillery.
- Ostrev — A mountainous nation with a focus on air superiority.
- Merovia — A western coastal power with a strong navy.

The world and its history will be expanded as development progresses.

Art Direction

DEAD SIGNAL combines stylized 3D environments with a gritty retro military aesthetic.

- Worn concrete and scratched metal.
- Green phosphor CRT displays.
- Amber indicators and red critical warnings.
- Analogue switches, military telephones, and mechanical gauges.
- Controlled darkness, strong shadows, and subtle environmental effects.

The goal is to create an oppressive atmosphere without sacrificing readability on mobile devices.

Technology

- Engine: Godot 4
- Language: GDScript
- Target platform: Android
- Rendering: 3D
- Development approach: Small, testable iterations

Roadmap

- [x] Create the initial Godot project.
- [x] Build the 3D command room. *(Stage 1 prototype)*
- [x] Implement limited seated camera movement. *(Stage 1 prototype)*
- [ ] Create CRT displays and analogue control panels. *(placeholders in place)*
- [x] Basic placeholder interactions and focus mode.
- [ ] Add lighting, materials, and environmental details.
- [ ] Implement communications and incoming orders. *(first order playable)*
- [x] Add fictional map and radar interfaces. *(tactical map; radar placeholder)*
- [x] Develop the missile launch sequence. *(prototype)*
- [ ] Implement battlefield simulation and decision consequences.
- [ ] Add endings, statistics, and sound design.
- [ ] Optimise and test on Android.

Running the Prototype

The current build is the command room, the seated camera, the first playable order, a tactical map driven by physical desk controls, and a first launch prototype. There is no campaign, battlefield simulation or ending yet. All mechanics are fictional and abstract.

First order (Stage 3)

About ten seconds after the room loads, order **SC-001** arrives on the teleprinter:

1. The teleprinter prints and its lamp blinks, a pulsing `! ORDER SC-001 - READ` notice appears top right, and the strategic-control CRT shows `SC-001 PENDING`.
2. Tap the notice or the teleprinter to read the order on a paper sheet. `CLOSE`, `Esc` or Android back returns to the room; the order stays pending.
3. Reply with `ACCEPT` or `REFUSE`. Each needs a second tap (`CONFIRM ...`) so a stray touch cannot decide; tapping the other button or closing the sheet disarms it.
4. The decision is stamped on the sheet with its time, confirmed on screen, recorded by the order manager and shown on the CRT (`SC-001 ACCEPTED` with readiness `LEVEL 2`, or `SC-001 REFUSED`). It cannot be changed.
5. Tap the teleprinter at any time afterwards to reread the order with its stamp.

Decisions are kept for the current session only. The unit, place and officer names in the order are fictional and provisional.

Tactical map and launch (Stage 4-5 prototype)

1. **Read the order**, then tap the left CRT to lean in over the map and the **MAP NAVIGATION** unit beside it.
2. **Navigate with the knobs** (touching the map itself does nothing): circle `CURSOR X` / `CURSOR Y` with a finger to move the reticle, `ZOOM` to zoom, roll the `PAN` trackball to move the view. `LAYER` selects one of nine layers and `ON / OFF` shows or hides it.
3. **Confirm a grid** with `CONFIRM GRID`: the 4 km cell under the cursor (e.g. `RS-27`) becomes the target and stays fixed while you keep moving the map.
4. **Choose ammunition** with the `S` / `M` / `L` push buttons on the desk (or the CRT focus buttons). Costs come out of 10 resource points.
5. **Review the launch summary** on the centre CRT: grid, classification, intelligence confidence, cost, and warnings for known friendly or civilian presence in the effect area.
6. **Turn the KEY** to arm, tap the red **MASTER** cover to lift it, then tap MASTER again. A 5 s countdown follows; `ABORT`, the key or `ABORT` on the CRT stop it.
7. At T-0 the missile rises through the shaft window. From that moment the launch is irreversible and recorded once. A fictional report follows on the centre CRT; the event appears on the map and in the log, and the shaft reloads.

Map conventions: one fixed fictional sheet (160 x 120 km, north up). Grid squares are 40 km (`P`-`S` west to east, `R`-`T` north to south) split into 4 km cells numbered by easting then northing (counted from the square's south edge). `RS-27` is the cell 88-92 km east, 48-52 km south, 12 km east of Karsen Junction. Varnesk lies off this sheet to the west. Reported intelligence is shown dashed in amber and is not confirmed; what is really there is only revealed by events.

Controls

| Action | Touch (Android) | Desktop |
| --- | --- | --- |
| Look around (limited) | Drag anywhere | Left-mouse drag |
| Turn to comms / status station | `< COMMS` / `STATUS >` buttons | `A` / `D` or arrow keys |
| Face the main console again | `CONSOLE` button or double-tap empty space | Double-click, `R`, `Space` or `Home` |
| Use a control / lean in to a screen or panel | Tap it | Click it |
| Turn a desk knob | Circle it with a finger | Circle it with the mouse |
| Leave a focused view | `< BACK`, double-tap empty space, or Android back | `Esc`, `R`, `Space` |

The view turns about 80° to either side and tilts slightly up and down. The operator cannot stand, walk or turn around. A press that moves is always a look-drag; only a short tap interacts, and on-screen buttons never turn the view.

Interactive objects

| Where | Object | Response |
| --- | --- | --- |
| Main desk | Three CRT screens | Lean in (focus). Map: physical controls only. Control: `SMALL` `MEDIUM` `LARGE` `ABORT` `CLEAR`. Radar: `RANGE` |
| Main desk | Map navigation unit | Cursor X/Y, zoom, pan trackball, layer selector and on/off, confirm grid |
| Main desk | Five toggle switches | Lever flips, status message |
| Main desk | Six push buttons | `S` `M` `L` select ammunition (lit = selected), `ABORT`, two spares |
| Main desk | Three counter knobs | Knob turns, steps the amber counter (placeholder) |
| Main desk | KEY and red MASTER | Key arms / safes; MASTER lifts its cover, then starts the launch sequence |
| Comms | Telephone | Handset lifts / hangs up, off-hook lamp |
| Comms | Radio transceiver | Cycles placeholder channels |
| Comms | Teleprinter | Opens the current order (before one arrives: paper feeds, "no new messages") |
| Comms | Communication lines panel | Lean in; six line switches toggle their lamps |
| Status | Facility status panel | Lean in; breakers CB-1..4 open/close and move their power meters |

Small or distant controls (the comms line switches and the status breakers) only work after leaning in to their panel, so every touch target stays comfortably large.

Getting the APK onto a phone (no desktop needed)

1. Every push to this repository runs the "Android APK" GitHub Actions workflow.
2. On GitHub, open the **Actions** tab → the latest **Android APK** run → download **DeadSignal-debug-apk** under *Artifacts*.
3. Unzip it on the phone and open `DeadSignal-debug.apk`. Android will ask you to allow installing from that app (browser or file manager) once.
4. If an update refuses to install over an older build, uninstall the old one first (debug builds may be signed with different keys).

Opening the project in an editor

- **Android:** install the official *Godot Engine 4* editor (4.5 or newer) from Google Play, clone or download this repository to the phone, then *Import* the folder containing `project.godot`.
- **Desktop:** Godot 4.5+ → *Import* → select `project.godot` → press *Run* (F5).

The renderer is *Compatibility* (OpenGL ES 3) for the widest range of Android phones.

Project Structure

```
project.godot            Engine settings (landscape, Compatibility renderer)
export_presets.cfg       Android export preset (debug APK, arm64 + armv7)
scenes/main.tscn         The room: shell, three stations, camera, HUD
scenes/hud.tscn          Touch buttons, control hint, FPS readout
scripts/build_kit.gd     Shared geometry helpers + material/colour palette
scripts/command_room.gd  Walls, observation window, launch shaft, lights
scripts/main_console.gd  Main desk, control panel, ammunition / key / MASTER
scripts/crt_monitor.gd   CRT monitor (bezel, tube, live screen)
scripts/screen_content.gd Right CRT: radar sweep
scripts/map/map_grid.gd  The one map coordinate system and grid references
scripts/map/map_data.gd  Fixed fictional geography, military overlay, hidden truth
scripts/map/map_query.gd What is known about a cell (never the hidden truth)
scripts/map/tactical_map.gd Left CRT: map renderer, layers, cursor, target
scripts/map_control_unit.gd Physical map knobs, trackball, layer and confirm
scripts/strategic_state.gd Shared state: view, cursor, target, ammo, launch, events
scripts/strategic_display.gd Centre CRT: status, ammunition, summary, report
scripts/ammunition.gd    Fictional ammunition categories (cost, effect radius)
scripts/launch_controller.gd Countdown, ignition, report delay, reload
scripts/outcome_model.gd Abstract fictional launch outcomes
scripts/missile_launch.gd Missile, flame, smoke and hatch in the shaft
scripts/comms_station.gd Left: telephone, radio, printer, reports, clock
scripts/status_station.gd Right: gauges, power meters, readiness, warnings
scripts/operator_camera.gd Seated camera limits, views, focus lean, touch/mouse/keys
scripts/interactable.gd  Invisible tap target / focus zone used by props
scripts/interaction.gd   Turns taps into hits, manages focus mode and back
scripts/order_catalog.gd Order texts as data (add future orders here)
scripts/order_manager.gd Current order state, arrival, recorded decisions
scripts/message_reader.gd Paper view of an order with ACCEPT / REFUSE
scenes/message_reader.tscn Layout of the paper order sheet
shaders/crt.gdshader     Scanlines, curvature and vignette for CRTs
assets/flags/            Approved country flags (unchanged originals)
assets/textures/         Low-res worn textures (tools/gen_textures.py)
```

Room geometry is generated by small scripts at load time, so positions of whole stations and monitors can still be moved in the editor via their nodes in `main.tscn`.

Project Status

Early development.

The current priority is a working 3D command-room prototype. Gameplay systems will be introduced gradually after the environment and camera are functional.

License

No license has been selected yet. All rights are reserved by the project owner unless stated otherwise.

---

<p align="center">
  <em>DEAD SIGNAL — The order is yours. The consequences are not.</em>
</p>
