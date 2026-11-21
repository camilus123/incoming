# Design

This is the working design reference. The original build spec is the source; `DECISIONS.md` records every change and clarification. Balance numbers live in `data/`, not here.

## Summary

INCOMING is a single-player, first-person ground turret defence game. The player is a stationary turret with a limited forward aim arc (yaw ±80°, pitch −5° to +85°), shooting down enemies that attack from the sky and from orbit. Between stages the player spends credits in a tech tree (shields, primary weapons, alternate weapons, core systems).

## Pillars

1. Weighty gunplay: each weapon feels different (recoil, sound, flash, impact, shake, tracers).
2. Moment-to-moment choices: power split, target choice, primary vs alternate fire.
3. Long-term choices: upgrade paths that change how you play.
4. Data-driven everything: content changes without code changes.
5. Looks great, runs great: realistic sci-fi PBR at a high frame rate.

## Core rules

- **Damage flow on the turret:** shields absorb first, then hull. Hull at 0 ends the run. Hull does not regenerate in a stage; it is repaired in the shop.
- **Power split:** one `shield_share` value in steps of 0.1. Shield recharge scales from 0× to 2×, weapon output from 0.5× to 1.5×. Energy weapons scale damage; kinetic weapons scale fire rate and cooling. Missiles are not powered: they have a per-stage ammo stock.
- **Damage types:** energy, kinetic, explosive. Enemy shields absorb all damage before HP and regenerate (energy 2×, kinetic 0.5×, explosive 1× against shields). Armour is a flat per-hit reduction, countered by each weapon's `armour_pierce`.
- **Weapons:** one primary and one alternate slot, both can fire together. Archetypes: hitscan_pulse, beam, projectile, airburst, charge_pierce, spinup, homing, area_pulse. Every weapon has heat and overheats.
- **Stages:** a wave director spends a threat budget (`100 × 1.18^(stage−1)`) on unlocked enemy types. Stages 1 to 10 are authored, every 5th is a boss stage, later stages are procedural.
- **Economy:** 1,500 starting credits; per-stage reward from base, bounties, accuracy, hull, no-shield-break, speed and intercepts.
- **Tech tree:** pure data. Bastion and Flicker shield branches exclude each other. Respec is allowed.

## Architecture

- `EventBus` (autoload): signals between unrelated systems.
- `GameData` (autoload): loaded data (`DataLoader`) and assets by ID (`AssetResolver`).
- Gameplay logic (stats, damage, rewards, tech tree) is plain script classes without scene dependencies so it can be unit tested; scenes only present it.
- `CameraRig` abstraction so a third-person rig can be added later.

Sections for each system are added here as it is built.
