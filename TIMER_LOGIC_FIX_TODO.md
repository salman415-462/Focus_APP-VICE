# Timer Logic Fix - Implementation Plan

## Objective
Implement correct runtime behavior for Timer-based blocking with Emergency Bypass

## Status: ✅ IMPLEMENTED

## Changes Made

### 1. Fixed Timer Blocking Logic (BlockAccessibilityService.kt)
**Previous Issue**: Timer active passed `activeBlockRules = emptyList()` → returns ALLOW

**Fix Applied**: Implemented correct decision order:
```kotlin
if (emergencyBypassActive) → ALLOW
else if (timerActive) → BLOCK (immediate, no bypass check)
else → normal rule evaluation
```

### 2. Implemented Timer Consumption
When timer blocks and user reaches Home:
- ✅ Timer is consumed/deactivated via `repository.clearActiveTimer(blockingTimer.id)`
- Prevents timer from re-triggering on app re-open

### 3. Fixed Emergency Bypass Priority
- ✅ Bypass is checked FIRST (highest priority)
- When bypass active: allow through immediately
- When no bypass but timer active: hard block

### 4. Fixed Overlay Lifecycle
- ✅ Overlay stays visible for ~2 seconds (OVERLAY_TIMEOUT_MS = 2000L)
- ✅ Disappears after Home is shown (via handler callback)
- ✅ No persistence after app is gone

## Files Modified
1. `android/app/src/main/kotlin/core/blocker/enforcement/BlockAccessibilityService.kt`
   - Updated `evaluateAndEnforce()` method with correct decision order
   - Updated `enforceBlock()` to accept timer parameter and consume it
   - Updated `isPackageBlocked()` to match new decision logic
   - Added import for `ActiveTimer`
   - Removed unused `MIN_BYPASS_REMAINING_SECONDS` constant

## Expected Behavior After Fix
- Timer active → BLOCK immediately ✅
- Emergency bypass → ALLOW for 2 minutes ✅  
- After bypass expires → BLOCK again (if timer still active) ✅
- Timer consumed after block → no re-triggering ✅

