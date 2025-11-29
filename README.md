# rrscan

**Turtle WoW Addon for Karazhan 40 - Second Boss Ley-Watcher Incantagos Encounter**

Automatically detects, targets, and attacks Affinity mobs using GUID-based instant targeting powered by SuperWoW.

---

## Requirements

**SuperWoW is REQUIRED** - This addon will not function without it.

Download and install SuperWoW: https://github.com/balakethelock/SuperWoW

---

## Installation

1. Install SuperWoW first (see link above)
2. Download this addon
3. Extract the `rrscan` folder to `World of Warcraft/Interface/AddOns/`
4. Restart WoW or type `/reload` in-game
5. Enable the addon at character select if needed

---

## Supported Affinities

| Affinity Name | Damage Type | Classes That Can Attack |
|--------------|-------------|------------------------|
| Red Affinity | Fire | Mage, Warlock |
| Blue Affinity | Frost | Mage |
| Mana Affinity | Arcane | Mage, Druid, Hunter |
| Green Affinity | Nature | Druid, Hunter |
| Black Affinity | Shadow | Warlock, Priest |
| Crystal Affinity | Physical | All melee classes + Hunters |

---

## Usage

### Basic Command

```
/rrscan
```

Scans for Affinities your class can attack, targets the first found, and casts the appropriate spell.

### With Fallback Spell

```
/rrscan <SpellName>
```

If no attackable Affinity is found, casts the specified spell instead.

**Example:**
```
/rrscan Frostbolt
```

### Recommended Macro Setup

Create a macro and spam it during the fight:

```
/rrscan Frostbolt
```

Replace `Frostbolt` with your primary DPS spell. The addon will:
1. **Priority**: Attack Affinities if found and attackable
2. **Fallback**: Cast your default spell if no Affinity is available

---

## Commands

| Command | Description |
|---------|-------------|
| `/rrscan` | Main scan and attack command |
| `/rrscan status` | View GUID cache statistics and known Affinities |
| `/rrscan debug` | Toggle debug messages on/off |
| `/rrscan clear` | Clear all cached GUID data (use if having issues) |

---

## Class-Specific Behavior

### Mages
- **Fire Affinity**: Fireball
- **Frost Affinity**: Frostbolt
- **Arcane Affinity**: Arcane Rupture
- **Nature Affinity**: Wand (shoot)

### Warlocks
- **Fire Affinity**: Immolate
- **Shadow Affinity**: Shadow Bolt
- **Nature Affinity**: Wand (shoot)

### Priests
- **Shadow Affinity**: Shadow Word: Pain
- **Nature Affinity**: Wand (shoot)

### Druids
- **Arcane Affinity**: Starfire (cancels Cat/Bear form if needed)
- **Nature Affinity**: Wrath (cancels Cat/Bear form if needed)
- **Physical Affinity**: Cat Form → Claw (requires 2 executions: first shifts, second attacks)

### Hunters
- **Arcane Affinity**: Arcane Shot
- **Nature Affinity**: Serpent Sting
- **Physical Affinity**: Melee attacks

### Warriors, Paladins, Rogues
- **Physical Affinity Only**: Melee attacks

---

## Features

### Instant Targeting
- GUID targeting is instant and foolproof.

### Smart Caching
- Maintains separate caches for general units and Affinities
- Automatically detects respawns (new GUID = new spawn)
- Removes dead units immediately

### Death Detection
- Health checks
- Dead state checks
- Existence checks
- Dead Affinities are instantly removed from cache

### Audio/Visual Alerts
When an Affinity is detected:
- Plays a sound alert
- Displays colored message: `"Red Affinity detected, CAST FIRE SPELLS!"`

---

## Troubleshooting

### "SuperWoW required!" Error
**Problem**: SuperWoW is not installed or not loaded correctly.

**Solution**:
1. Download SuperWoW: https://github.com/balakethelock/SuperWoW
2. Follow SuperWoW installation instructions
3. Restart WoW completely
4. Verify SuperWoW is working (check other SuperWoW addons or features)

### Addon Not Finding Affinities
**Problem**: GUID cache might be empty or outdated.

**Solution**:
1. Run `/rrscan clear` to reset the cache
2. Mouseover some mobs to start collecting GUIDs
3. Run `/rrscan status` to verify GUIDs are being collected

### Targeting Dead Affinities
**Problem**: Cache contains stale GUIDs.

**Solution**: This should be automatic, but if it happens:
1. Run `/rrscan clear`
2. The cleanup system runs every 0.1 seconds and should prevent this

---

## Credits

- **SuperWoW**: https://github.com/balakethelock/SuperWoW
- **Author**: me0wg4ming
- **Version**: 0.1
