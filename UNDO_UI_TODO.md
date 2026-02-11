# Undo UI Implementation Plan

## Step 1: Update MethodChannelService.dart ✅
- [x] Add `graceExpiresAt` field to timer data structure in `getActiveTimers()`
- [x] Add `getRemainingGraceTime(timerId)` method

## Step 2: Update Android MethodChannelHandler.kt ✅
- [x] Add `graceExpiresAt` field to getActiveTimers() return map
- [x] Add `getRemainingGraceTime` method handler

## Step 3: Update home_screen.dart ✅
- [x] Add state variables for tracking undoable timers
- [x] Add `_loadUndoStatus()` method to check which timers can be undone
- [x] Add `_handleUndo(timerId)` method to trigger undo
- [x] Add `_buildUndoTimerCard()` widget
- [x] Integrate undo cards into the UI

## Step 4: Build and Test ✅
- [x] Run flutter pub get
- [x] flutter analyze - No errors found

