import os, re
P = r"c:\Godot_projects\branchy"

def read(fn):
    with open(os.path.join(P, fn), "r", encoding="utf-8") as f:
        return f.read()

def write(fn, code):
    with open(os.path.join(P, fn), "w", encoding="utf-8") as f:
        f.write(code)

# ======================
# FIX 1: CHIPPER - upside down, too small, buried
# ======================
print("FIX 1: Wood chipper orientation and size")
main = read("Main.gd")
# AABB: size=(3701, 1947, 1674), center=(1952, 234, 82)
# Model is in mm. Wheels are at the TOP of the AABB (high Y values)
# At rotation -90 on X: Y becomes -Z, Z becomes Y -> wheels go UP
# Fix: rotation (90, 0, 0) to flip it right-side up
# Or try (0,0,0) with just scaling
# At scale 0.002: 3701*0.002=7.4m wide, 1947*0.002=3.9m tall, 1674*0.002=3.3m deep
# Center offset at 0.002: (3.9, 0.47, 0.16)
# So position needs to subtract center X to center it, and lift Y so bottom is at ground

main = main.replace(
    "chipper_mi.scale = Vector3(0.0015, 0.0015, 0.0015)",
    "chipper_mi.scale = Vector3(0.003, 0.003, 0.003)")
# OBJ files: typically Y-up or Z-up. The wheels-up issue means Z-up model with -90 rotation
# Try rotation 90 instead of -90 to flip it right
main = main.replace(
    "chipper_mi.rotation_degrees = Vector3(-90, 0, 0)",
    "chipper_mi.rotation_degrees = Vector3(90, 0, 180)")
# Reposition: at scale 0.003, AABB extends from roughly:
# X: (1952-3701/2)*0.003 to (1952+3701/2)*0.003 = 0.3 to 11.4 -> center at 5.9
# Need to shift X by about -5.9 to center the model at X=4
# Y: bottom should be at 0. AABB min_y = 234-1947/2 = -740 -> at 0.003 = -2.2
# So position.y should be about 2.2 to put bottom on ground
main = main.replace(
    'chipper_mi.position = Vector3(4.0, 0.0, 2.0)',
    'chipper_mi.position = Vector3(-2.0, 2.5, 3.0)')
write("Main.gd", main)
print("  Chipper: scale 0.003, rotation (90,0,180), repositioned")

# ======================
# FIX 2: Add 1m reference cube
# ======================
print("\nFIX 2: Add 1m reference cube")
main = read("Main.gd")
# Add reference cube at end of _ready
old_ready_end = "\tsetup_gui()\n\tpass #vfx"
if old_ready_end in main:
    new_ready_end = old_ready_end + "\n\tsetup_reference_cube()"
    main = main.replace(old_ready_end, new_ready_end)
    # Add function
    main += """
func setup_reference_cube():
\tvar cube_mi = MeshInstance3D.new()
\tcube_mi.name = "ReferenceCube"
\tvar box = BoxMesh.new()
\tbox.size = Vector3(1.0, 1.0, 1.0)
\tcube_mi.mesh = box
\tvar mat = StandardMaterial3D.new()
\tmat.albedo_color = Color(1.0, 0.2, 0.2, 0.5)
\tmat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
\tcube_mi.material_override = mat
\tcube_mi.position = Vector3(2.0, 0.5, 0.0)
\tadd_child(cube_mi)
"""
    write("Main.gd", main)
    print("  Red 1m cube at (2, 0.5, 0)")
else:
    # Try alternate pattern
    if "setup_vfx_assets()" in main:
        main = main.replace("setup_vfx_assets()", "setup_vfx_assets()\n\tsetup_reference_cube()")
    elif "setup_gui()" in main:
        main = main.replace("setup_gui()", "setup_gui()\n\tsetup_reference_cube()")
    main += """
func setup_reference_cube():
\tvar cube_mi = MeshInstance3D.new()
\tcube_mi.name = "ReferenceCube"
\tvar box = BoxMesh.new()
\tbox.size = Vector3(1.0, 1.0, 1.0)
\tcube_mi.mesh = box
\tvar mat = StandardMaterial3D.new()
\tmat.albedo_color = Color(1.0, 0.2, 0.2, 0.5)
\tmat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
\tcube_mi.material_override = mat
\tcube_mi.position = Vector3(2.0, 0.5, 0.0)
\tadd_child(cube_mi)
"""
    write("Main.gd", main)
    print("  Red 1m cube added")

# ======================
# FIX 3: Chainsaw too close to camera
# ======================
print("\nFIX 3: Chainsaw position - move further from camera")
tc = read("ToolController.gd")
# Pivot was at (0.35, -0.40, 0.0) which is basically AT the camera
# Move it to (0.4, -0.3, -0.7) so tool is visible in front
tc = tc.replace(
    "var pivot = Vector3(0.35, -0.40, 0.0)",
    "var pivot = Vector3(0.4, -0.3, -0.25)")
tc = tc.replace(
    "var aim_point = Vector3(ndc_x * 0.4, ndc_y * 0.3, -0.9)",
    "var aim_point = Vector3(ndc_x * 0.35, ndc_y * 0.25, -1.2)")
# Also the rest_pos is where tool_holder starts
tc = tc.replace(
    "var rest_pos: Vector3 = Vector3(0.3, -0.28, -0.5)",
    "var rest_pos: Vector3 = Vector3(0.35, -0.25, -0.6)")
write("ToolController.gd", tc)
print("  Tool pivot moved to (0.4,-0.3,-0.25), aim to z=-1.2")

# ======================
# FIX 4: Only 6 branches - spawn rate too low
# ======================
print("\nFIX 4: Branch spawn rate")
tg = read("TreeGenerator3D.gd")
# Current: falloff * 0.6, clamp(0.1, 0.5) -> with cap at 80
# At height_ratio=0.5, falloff = (0.5)^1.2 = 0.43, * 0.6 = 0.26
# Only 26% chance per F segment. With many F segments, 6 is suspiciously low.
# The issue is that the L-system rule "F[+X]F[-X]+X" at 5 iterations
# generates many F tokens but should_spawn_branch caps at 80.
# With seed=30, the RNG might just be unlucky.
# Let's increase probability and lower base_branch_offset
tg = tg.replace(
    "return rng.randf() < clamp(falloff * 0.6, 0.1, 0.5)",
    "return rng.randf() < clamp(falloff * 0.85, 0.25, 0.7)")
# Also lower base_branch_offset so branches can grow from lower on trunk
tg = tg.replace(
    "@export var base_branch_offset: float = 0.35",
    "@export var base_branch_offset: float = 0.15")
write("TreeGenerator3D.gd", tg)
print("  Spawn rate: falloff*0.85, clamp(0.25,0.7), base_offset=0.15")

print("\n=== ALL FIXES APPLIED ===")
