# TODO: Phase 2 - Aggregation Backend (StatsRepository)

## Objective
Implement backend aggregation for weekly stats, monthly stats, and per-app blocked duration.

## Tasks Completed ✅

### 1. Create StatsRepository Structure ✅
- [x] Created `core/blocker/stats/StatsRepository.kt`
- [x] Depends only on EventRepository

### 2. Implement Data Classes ✅
- [x] Created `WeeklyStats` data class
- [x] Created `MonthlyStats` data class
- [x] Created `AppBlockStat` data class

### 3. Implement Weekly Stats ✅
- [x] Implemented `getWeeklyStats(weekStartMillis: Long): WeeklyStats`
- [x] Filter events by week range [weekStartMillis, weekStartMillis + 7 days)
- [x] Count by completionType (NATURAL, UNDO, SYSTEM_KILL)
- [x] Calculate totalFocusMinutes (NATURAL only, mode = FOCUS or POMODORO_FOCUS)
- [x] Count bypassUsed sessions

### 4. Implement Monthly Stats ✅
- [x] Implemented `getMonthlyStats(monthStartMillis: Long): MonthlyStats`
- [x] Calculate month boundaries from epoch millis
- [x] Generate weekly breakdown

### 5. Implement Per-App Block Stats with Interval Merging ✅
- [x] Implemented `getPerAppBlockStats(startMillis, endMillis): List<AppBlockStat>`
- [x] Filter TIMER_COMPLETED events with completionType = NATURAL
- [x] Create intervals per package [startTimeMillis, endTimeMillis]
- [x] Group intervals by package
- [x] Implement interval merging algorithm
- [x] Sum merged durations correctly

### 6. Edge Case Handling ✅
- [x] Timer spanning midnight (epoch millis handles this naturally)
- [x] UNDO sessions excluded from focus time
- [x] SYSTEM_KILL: use actualDurationMinutes (partial time counts)
- [x] bypassUsed does not affect blocked time calculation

## Files Created
- `android/app/src/main/kotlin/core/blocker/stats/StatsRepository.kt`
- `android/app/src/main/kotlin/core/blocker/stats/WeeklyStats.kt`
- `android/app/src/main/kotlin/core/blocker/stats/MonthlyStats.kt`
- `android/app/src/main/kotlin/core/blocker/stats/AppBlockStat.kt`

## How Interval Merging Works

**Algorithm:**
1. Sort intervals by start time
2. Iterate and merge overlapping intervals
3. Sum merged durations

**Example:**
```
Intervals: [10:00-10:30], [10:15-10:45], [11:00-11:30]
Merged:    [10:00-10:45], [11:00-11:30]
Total:     45 + 30 = 75 minutes (not 30+30+30 = 90)
```

**Why double counting is impossible:**
- Overlapping intervals are merged into a single continuous interval
- Each time point belongs to at most one merged interval
- The merged set represents the union of all original intervals

## bypassUsed Counting

`bypassUsed` is counted separately from session completion:
- `totalBypassUsedSessions` counts all sessions where bypass was used
- Independent of completionType (counts NATURAL, UNDO, SYSTEM_KILL)
- Used for analytics on how often users resort to bypass

## Usage Examples

```kotlin
// Get current week stats
val weeklyStats = statsRepository.getCurrentWeekStats()

// Get current month stats with weekly breakdown
val monthlyStats = statsRepository.getCurrentMonthStats()

// Get per-app blocked time for current month
val appStats = statsRepository.getCurrentMonthPerAppStats()

// Custom date range
val customAppStats = statsRepository.getPerAppBlockStats(startMillis, endMillis)
```

