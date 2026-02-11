# TODO: Fix Duplicate TIMER_COMPLETED Risk

## Objective
Eliminate the possibility of duplicate TIMER_COMPLETED events by restricting cleanup to a single authority and adding idempotency guards.

## Changes Required

### 1. EventRepository.kt - Add Idempotency Guard
- [x] Add `hasTimerCompletedEvent(timerId: String): Boolean` method
- [x] Add idempotency check in `recordTimerCompleted()` to prevent duplicates

### 2. MethodChannelHandler.kt - Remove Duplicate Cleanup Calls
- [x] Remove `clearExpiredTimersWithEvents()` from `getPermissionStatus()`
- [x] Remove `clearExpiredTimersWithEvents()` from `getBlockStatus()`
- [x] Remove `clearExpiredTimersWithEvents()` from `getActiveTimers()`

### 3. BlockAccessibilityService.kt - Remove Cleanup Call
- [x] Remove `clearExpiredTimersWithEvents()` from `onAccessibilityEvent()`

## Verification
- [ ] Only TimerMonitorService performs cleanup
- [ ] All other components are read-only
- [ ] Duplicate completion events are now impossible

## Files Modified
1. `android/app/src/main/kotlin/core/blocker/events/EventRepository.kt`
2. `android/app/src/main/kotlin/com/example/my_first_app/MethodChannelHandler.kt`
3. `android/app/src/main/kotlin/core/blocker/enforcement/BlockAccessibilityService.kt`

## Summary of Changes

### EventRepository.kt
- Added idempotency guard in `recordTimerCompleted()` to check if a TIMER_COMPLETED event already exists for the timerId
- Added `hasTimerCompletedEvent(timerId: String): Boolean` method to check for existing completion events

### MethodChannelHandler.kt
- Removed `clearExpiredTimersWithEvents()` from `getPermissionStatus()`
- Removed `clearExpiredTimersWithEvents()` and `clearExpiredBypasses()` from `getBlockStatus()`
- Removed `clearExpiredTimersWithEvents()` from `getActiveTimers()`
- Added explanatory comments about intentional exclusion of cleanup calls

### BlockAccessibilityService.kt
- Removed `clearExpiredTimersWithEvents()` from `onAccessibilityEvent()`
- Added explanatory comment about exclusive handling by TimerMonitorService

