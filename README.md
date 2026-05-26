# Zen Topiary (Branchy Trimming Game)

Procedural L-System tree generator converted into a highly performant 3D tree/bush/plant trimming game built with Godot 4.6. Play as the Zen Gardener, choosing motorized 3D tools to prune foliage and feed branch debris into an industrial wood chipper!

## Live Demo (GitHub Pages)

Play the interactive game directly in your browser:
[https://twobob.github.io/branchy/](https://twobob.github.io/branchy/)

## Features

- **Interactive 3D Tool Selection**: Switch in real-time between the motorized **Chainsaw**, **Mini-Saw/Handsaw**, and **Pruning Shears/Hands**. High-frequency leaf bursts, sawdust, and electric sparks spray on active cuts.
- **Hierarchical DAG Plant Trimming**: Branches are generated in a parent-child stack DAG. Slicing any branch recursively severs its entire descendant sub-tree, which falls in physical ragdoll groups.
- **Industrial Wood Chipper & Debris Vacuum**: Vacuum up physical branch debris into the wood chipper hopper, grinding them up for massive points, or let them fall to the grass ground and fade out.
- **Three Game Modes**:
  - **Topiary Master (Silhouette Matching)**: Trim branches extending outside the target holographic hologram bounds (Sphere/Cube) and maintain accuracy.
  - **Zen Garden (Deadwood Pruning)**: Prune diseased crimson/brown branches. Avoid cutting healthy green foliage.
  - **Creative Sandbox**: Custom L-System parameter sliders and tool testing for pure zen relaxation.
- **Procedural DSP Waveform Synthesizer**: Implements pure mathematical audio generation for chainsaw pitch-bends, saw buzzes, scissor snips, chipper grinds, and C-major victory chimes.
- **WebGL Performance Optimized**: Bypasses wind physics on severed debris and features optimized collision layers for stable 60 FPS gameplay.
- **No Comments Codebase**: All script files are completely stripped of comment characters for optimized Emscripten web runtime size.

## Controls

| Key | Action |
|-----|--------|
| Mouse Drag / Click | Swipe tool to cut flora |
| W / S | Forward / Back |
| A / D | Strafe Left / Right |
| Q / E | Down / Up |
| Left / Right Arrow | Orbit camera |
| Scroll Wheel | Zoom camera |
| HUD Buttons | Switch tools and modes |

## Building

Requires Godot 4.6 (non-Mono) with Web export templates installed.

```bash
godot --headless --export-release "Web" "index.html"
```
