# TODO: Separate bypassUsed from completionType

## Objective
Refine analytics to separate final session outcome (completionType) from bypass behavior (bypassUsed).

## Changes Required

### 1. TimerEvent.kt - Update Models
- [x] Remove BYPASS from CompletionType enum
- [x] Add bypassUsed: Boolean to TimerCompleted data class

### 2. EventRepository.kt - Update Serialization
- [x] Update recordTimerCompleted() signature to include bypassUsed
- [x] Update serializeEvent() to persist bypassUsed
- [x] Update parseEvent() to parse bypassUsed (with backward compatibility)

### 3. BlockRepository.kt - Update Classification
- [x] Update determineCompletionType() to remove BYPASS logic
- [x] Update calculateActualDuration() to remove BYPASS case
- [x] Update all recordTimerCompleted() calls to pass bypassUsed = timer.wasBypassed

## Files Modified
1. `android/app/src/main/kotlin/core/blocker/events/TimerEvent.kt`
2. `android/app/src/main/kotlin/core/blocker/events/EventRepository.kt`
3. `android/app/src/main/kotlin/core/blocker/persistence/BlockRepository.kt`

## Summary of Changes

### Updated CompletionType Enum
```kotlin
enum class CompletionType {
    NATURAL,      // Timer ran to its natural end
    UNDO,         // User cancelled via undo within grace window
    SYSTEM_KILL   // App was killed or system interrupted
    // BYPASS removed - now tracked via bypassUsed flag
}
```

### Updated TimerCompleted Model
```kotlin
data class TimerCompleted(
    val completionType: CompletionType,  // Final outcome only
    val bypassUsed: Boolean,              // Independent behavioral flag
    // ... other fields
)
```

### Event JSON Format
```json
{
  "timerId": "...",
  "completionType": "NATURAL",
  "bypassUsed": true,  // Independent flag
  ...
}

