# Save System Architecture

## Overview
Hybrid save system using both KV storage (cloud) and local file storage for optimal performance and user experience.

## Data Storage Strategy

### KV Storage (Cloud - Playcademy)
**What:** Game progress and performance data  
**Where:** `.playcademy/kv/` (local dev) → Cloudflare KV (production)  
**Sync:** Cross-device, cross-platform  
**When saved:** Only on level completion or drill mode completion

**Data stored:**
- Level progress (stars, accuracy, best times, CQPM)
- Question history (last 5 attempts per question)
- Drill mode high scores
- Pack completion data

**Save frequency:** 
- ✅ Level complete
- ✅ Drill mode complete
- ❌ NOT on every question
- ❌ NOT on volume changes

### Local File Storage (Per-Machine)
**What:** User preferences and settings  
**Where:** `user://local_settings.json` (OS-specific user directory)  
**Sync:** Per-machine only (not synced across devices)  
**When saved:** Immediately on change

**Data stored:**
- SFX volume
- Music volume
- (Future: graphics quality, keybindings, etc.)

## Benefits

### KV Storage Benefits
✅ Cross-device progress sync  
✅ Cloud backup  
✅ No local storage quotas  
✅ Platform integration

### Local Storage Benefits
✅ Instant saves (no network latency)  
✅ Per-machine preferences  
✅ Reduced KV write costs  
✅ Works offline

## Implementation Details

### Dirty Flag System
- `has_unsaved_changes` flag tracks if KV data needs saving
- Set to `true` when game progress changes
- Set to `false` after successful KV save
- Prevents unnecessary KV writes

### Save Points
KV storage is only written at these points:
1. **Level Complete** - When `update_level_data()` is called
2. **Drill Mode Complete** - When `update_drill_mode_high_score()` returns true
3. **Migration** - When save structure needs updating

Question data is accumulated in memory and saved with level completion.

### Data Flow

```
Game Start:
  1. Show "Loading" screen
  2. Load local_settings.json (volumes) - instant
  3. Load save_data from KV storage (progress) - async
  4. Wait for KV data to load...
  5. Apply volumes and create UI
  6. Hide "Loading", show "MainMenu"

During Play:
  - Questions answered → Mark dirty, accumulate in memory
  - Volume changed → Save immediately to local file
  
Level Complete:
  - Update level stats → Mark dirty
  - Save all accumulated data to KV storage
  - Clear dirty flag
```

### Loading Screen

A loading screen is displayed while save data loads from KV storage:
- **Local Dev:** Very brief (milliseconds), may not be noticeable
- **Production:** May be visible for 100-500ms depending on network latency
- **Purpose:** Prevents showing empty menu while level buttons are being created

The loading screen ensures users see a polished experience rather than a blank menu during the async data load.

## Migration Notes

Old save data with volumes in KV is automatically migrated:
- Volumes are removed from KV data
- Local settings file is created with default volumes
- User will need to re-set their volume preferences once

## Files Modified

- `scripts/save_manager.gd` - Core save system logic
- `scripts/main.gd` - Initialization and volume application
- `scripts/ui_manager.gd` - Volume slider handling
- `server/api/save.ts` - KV storage backend API

## Testing

To verify the system works:

1. **Local volumes persist per-machine:**
   - Change volume settings
   - Close game
   - Reopen → volumes should be restored

2. **Progress syncs across devices:**
   - Complete a level on one machine
   - Open on another machine → progress should sync

3. **Minimal KV writes:**
   - Check console logs
   - Should only see "Saving game progress to KV storage..." on level/drill complete
   - Should NOT see it on every question or volume change

