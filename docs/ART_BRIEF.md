# Art brief: what the final models and textures should be

The game ships with placeholder models built from primitives. This file describes what each real asset should look like, so an artist (or an asset pack search) has a target. Technical rules (format, scale, socket names) are in `ASSETS.md`. Sizes are in metres.

## Overall look

Realistic hard sci-fi, not cartoon. A hardened military emplacement on a desolate frontier world under a dramatic sky. Think worn gunmetal, ceramic armour plates, exposed hydraulics and cabling, hazard markings, dust and scorch marks. Player hardware is angular and utilitarian in dark grey-green with amber/orange markings. Enemy hardware is sleeker and colder: dark blue-black hulls with pale panel lines and red or violet emissive accents, so friend and foe read differently at a glance. Energy effects must be bright and readable against the sky.

## Textures (all models)

- PBR metallic-roughness: albedo, normal, ORM, emission where lights or heat glow exist.
- 2K for the turret and first-person weapons (seen up close), 1K to 2K for large enemies, 512 to 1K for small enemies and projectiles.
- Wear tells a story: edge chipping on plates, soot behind muzzles and exhausts, heat tint (blue to straw) on barrels.
- Emission masks for: status lights, barrel heat glow (driven by the heat meter), engine nozzles, shield emitters.

## Player turret

| Asset ID | Description | Size |
|---|---|---|
| `model.turret.base` | Armoured ring mount bolted to a concrete and steel pad. A rotating yaw ring carries a cradle with heavy side trunnions, recoil cylinders and an ammunition feed. Needs `Pivot_Yaw`, `Pivot_Pitch`, `ViewAnchor`. | Pad about 6 wide, cradle about 2.5 tall |
| `model.turret.shield_emitters` | Four low pylons around the pad with glowing emitter caps (the dome originates here). | 1 tall each |

## Weapons (first-person visible)

Each needs `Muzzle_*` sockets, kinetic ones also `Eject_*`. Barrels sit left/right or below the view. Each family should have a distinct silhouette.

| Asset ID | Description |
|---|---|
| `model.weapon.pulse_laser` | Twin slim barrels with ribbed cooling fins and glowing focus lenses. Mk II/III add fins and a larger capacitor housing. |
| `model.weapon.beam_laser` | Single long barrel with a large crystal emitter and coolant lines. |
| `model.weapon.particle_lance` | Heavy accelerator tube with ring magnets along its length and a split muzzle. |
| `model.weapon.plasma_repeater` | Short wide barrels with containment coils that glow green-white when charged. |
| `model.weapon.plasma_cannon` | One very large-bore barrel with thick coil rings and vents. |
| `model.weapon.chain_gun` | Six rotating barrels, belt feed on the side, ejection port. The barrel cluster must be a separate node so it can spin. |
| `model.weapon.rotary_cannon` | Larger three-barrel rotary with a heavy shroud. Spinning cluster as a separate node. |
| `model.weapon.autocannon` | Long single barrel with a muzzle brake and a drum magazine. |
| `model.weapon.twin_autocannon` | Two autocannon barrels side by side that recoil alternately (each barrel a separate node). |
| `model.weapon.coilgun` | Square-section barrel made of stacked coil blocks. |
| `model.weapon.railgun` | Two long parallel rails with capacitor banks at the breech; rails glow as it charges. |
| `model.weapon.hyper_rail` | Longer, heavier railgun with radiator panels. |
| `model.weapon.missile_pod` | Box launcher with 4 tubes (Micro-Missile), mounted beside the main gun. Variants with more tubes for Mk II/III and Swarm. |
| `model.weapon.seeker_torpedo` | Single large launch rail with one visible torpedo. |
| `model.weapon.flak_barrage` | Cluster of short mortar-like tubes. |
| `model.weapon.emp_burst` | Dish or coil emitter with a glowing core. |
| `model.weapon.arc_projector` | Forked electrode prongs with insulator rings. |
| `model.weapon.singularity_charge` | Launcher holding a dark sphere caged in rings. |

## Projectiles

Small, emissive, readable at distance: micro-missile (0.6 long), swarm mini-missile (0.3), seeker torpedo (2.0), plasma bolt (effect only), flak shell (effect only), enemy bomb (1.0, finned), enemy missile (1.5), drop pod (see enemies).

## Enemies

Each needs `Hitbox_*`, `Engine_*`, `Hardpoint_*` and, where listed, `WeakPoint_*`. Provide a low-detail LOD for the large ones.

| Asset ID | Description | Size |
|---|---|---|
| `model.enemy.drone_swarmer` | Small dart-shaped drone with a single red sensor eye and one engine. Very low poly (drawn in hundreds). | 1.5 long |
| `model.enemy.interceptor` | Fast forward-swept-wing fighter, twin engines, chin laser. | 9 long |
| `model.enemy.bomber` | Broad flying wing with a thick belly bomb bay and four engines. | 22 wingspan |
| `model.enemy.missile_boat` | Hovering slab-sided craft with missile racks on both flanks and a visible shield emitter. | 16 long |
| `model.enemy.drop_pod` | Blunt cone with an ablative heat shield and retro thrusters; glows on re-entry. | 4 tall |
| `model.enemy.shield_frigate` | Tall vessel built around a large ring-shaped shield projector. `WeakPoint_ShieldProjector`. | 45 long |
| `model.enemy.gunship` | Heavily armoured hover gunship with a chin heavy cannon and flare dispensers. | 20 long |
| `model.enemy.carrier` | Long flat carrier with open hangar bays along the sides. `WeakPoint_Hangar_0..3`. | 120 long |
| `model.enemy.boss_dreadnought` | Massive wedge-shaped capital ship. `WeakPoint_ShieldGen_0..1`, `WeakPoint_Turret_0..3`, `WeakPoint_Engine_0..2`, a ventral beam emitter. | 400 long |

## Environment

| Asset ID | Description |
|---|---|
| `model.env.terrain` | Rocky desert basin with distant mesas and mountain silhouettes on the horizon across the whole forward arc. Low detail far away. |
| `model.env.props` | A few scattered props near the pad: sandbag walls, a generator, antenna mast, wrecked vehicle. |
| `texture.env.ground_*` | Cracked dry earth and rock, tileable, 2K, with normal and ORM. |
| `texture.env.sky_*` | Day, dusk and night variants: dramatic clouds, a large ringed planet or moon low in the sky, stars at night, faint orbital debris streaks. HDR. |
| `texture.env.planet` | The visible planet/moon as a separate layer so it can be placed per stage. |

## VFX textures

Soft and hard-edged flipbooks or noise textures for: muzzle flashes per weapon family, smoke, fire, sparks, shockwave rings, lightning arcs, shield hex ripple, lens dirt.

## UI

Clean sci-fi HUD font (monospaced digits), icon set for each weapon, shield node, and enemy type (used in the tech tree, loadout and stage preview), all as white-on-transparent so they can be tinted.
