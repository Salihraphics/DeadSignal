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
- [ ] Add lighting, materials, and environmental details.
- [ ] Implement communications and incoming orders.
- [ ] Add fictional map and radar interfaces.
- [ ] Develop the missile launch sequence.
- [ ] Implement battlefield simulation and decision consequences.
- [ ] Add endings, statistics, and sound design.
- [ ] Optimise and test on Android.

Running the Prototype (Stage 1)

The current build is the command room and the seated camera only. Screens and controls are placeholders; nothing is interactive yet except the camera.

Controls

| Action | Touch (Android) | Desktop |
| --- | --- | --- |
| Look around (limited) | Drag anywhere | Left-mouse drag |
| Turn to comms / status station | `< COMMS` / `STATUS >` buttons | `A` / `D` or arrow keys |
| Face the main console again | `CONSOLE` button or double-tap | Double-click, `R`, `Space` or `Home` |

The view turns about 80° to either side and tilts slightly up and down. The operator cannot stand, walk or turn around.

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
scripts/main_console.gd  Main desk and slanted control panel
scripts/crt_monitor.gd   CRT monitor (bezel, tube, live screen)
scripts/screen_content.gd Placeholder CRT content: map / control / radar
scripts/comms_station.gd Left: telephone, radio, printer, reports, clock
scripts/status_station.gd Right: gauges, power meters, readiness, warnings
scripts/operator_camera.gd Seated camera limits, views, touch/mouse/keys
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
