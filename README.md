# Branchy

Procedural L-System tree generator built with Godot 4.6. Generates 3D trees with physics-driven branches that sway in procedural wind.

## Live Demo

[https://xn--1xap.com/branchy](https://xn--1xap.com/branchy)

## Features

- **L-System generation** with editable Rule X and real-time syntax validation
- **Randomise button** that generates valid random rules (auto-rerolls if branch count is < 30 or > 3000, or produces 0 branches)
- **Physics simulation** using Godot's Jolt physics with spring joints per branch
- **Procedural wind** via FastNoiseLite driving forces on rigid body branch tips
- **Collision shapes** switchable between Capsule and Sphere primitives
- **Debug visualisation** with translucent wireframe collision shapes, toggleable at runtime
- **Auto-framing camera** that zooms to fit the full tree after randomisation or parameter changes
- **Full parameter control** via UI sliders for iterations, segment length, branch angle, thickness, stiffness, damping, wind strength/scale/speed, and more

## Controls

| Key | Action |
|-----|--------|
| W / S | Forward / Back |
| A / D | Strafe Left / Right |
| Q / E | Down / Up |
| ← / → | Orbit |
| Scroll | Zoom |

## Building

Requires Godot 4.6 (non-Mono) with Web export templates installed.

```bash
godot --headless --export-release "Web" "build/web/index.html"
```

## Web Server Config

For LiteSpeed/Apache, the included `build/web/.htaccess` sets required CSP headers for WebAssembly execution and cross-origin isolation.
