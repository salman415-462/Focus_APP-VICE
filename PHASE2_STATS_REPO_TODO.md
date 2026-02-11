# TODO: Phase 2 - Aggregation Backend (StatsRepository)

## Objective
Implement backend aggregation for weekly stats, monthly stats, and per-app blocked duration.

## Tasks

### 1. Create StatsRepository Structure
- [ ] Create `core/blocker/stats/StatsRepository.kt`
- [ ] Depend only on EventRepository

### 2. Implement Data Classes
- [ ] Create `WeeklyStats` data class
- [ ] Create `MonthlyStats` data class
- [ ] Create `AppBlockStat` data class

### 3. Implement Weekly Stats
- [ ] Implement `getWeeklyStats(weekStartMillis: Long): WeeklyStats`
- [ ] Filter events by week range [weekStartMillis, weekStartMillis + 7 days)
- [ ] Count by completionType
- [ ] Calculate totalFocusMinutes (NATURAL only, mode = FOCUS or POMODORO_FOCUS)
- [ ] Count bypassUsed sessions

### 4. Implement Monthly Stats
- [ ] Implement `getMonthlyStats(monthStartMillis: Long): MonthlyStats`
- [ ] Calculate month boundaries from epoch millis
- [ ] Generate weekly breakdown

### 5. Implement Per-App Block Stats with Interval Merging
- [ ] Implement `getPerAppBlockStats(startMillis, endMillis): List<AppBlockStat>`
- [ ] Filter TIMER_COMPLETED events with completionType = NATURAL
- [ ] Create intervals per package [startTimeMillis, endTimeMillis]
- [ ] Group intervals by package
- [ ] Implement interval merging algorithm
- [ ] Sum merged durations correctly

### 6. Edge Case Handling
- [ ] Timer spanning midnight (epoch millis handles this naturally)
- [ ] UNDO sessions excluded from focus time
- [ ] SYSTEM_KILL: use actualDurationMinutes (partial time counts)
- [ ] bypassUsed does not affect blocked time calculation

## Files to Create
- `android/app/src/main/kotlin/core/blocker/stats/StatsRepository.kt`
- `android/app/src/main/kotlin/core/blocker/stats/WeeklyStats.kt`
- `android/app/src/main/kotlin/core/blocker/stats/MonthlyStats.kt`
- `android/app/src/main/kotlin/core/blocker/stats/AppBlockStat.kt`

## Notes
- Do NOT modify event structure
- Do NOT modify storage
- Do NOT modify enforcement
- Pure analytics layer only

