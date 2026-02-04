# UI Redesign Tasks - Matching Flagged Components to Design System

## Completed ✓

### 1. Update main.dart ThemeData ✓
- [x] Add missing theme components (TimePickerTheme, ProgressIndicatorTheme, etc.)

### 2. Redesign Onboarding Screen (HIGH PRIORITY) ✓
- [x] Change background from dark to cream gradient
- [x] Update text colors from white to dark
- [x] Style page indicators with app colors
- [x] Update ElevatedButton to use app's button style
- [x] Add decorative leaves/rivers painter
- [x] Update icon colors to match theme

### 3. Redesign Schedule Config TimePicker (HIGH PRIORITY) ✓
- [x] Add TimePickerTheme with cream background

### 4. Redesign Permission Screen Error Banner (MEDIUM PRIORITY) ✓
- [x] Change from default red to warm error palette (0xFFB57A7A)
- [x] Update warning icon styling
- [x] Standardize dialog backgrounds to cream

### 5. Standardize Loading Indicators (MEDIUM PRIORITY) ✓
- [x] Update stats_screen.dart loading state
- [x] Update permission_status_screen.dart loading state with CircularProgressIndicator

### 6. Dialog Backgrounds Standardization ✓
- [x] Update permission_status_screen.dart dialogs
- [x] Update pomodoro_config_screen.dart dialogs

---

## Summary of Changes

| Component | Before | After |
|-----------|--------|-------|
| Onboarding background | Dark (0xFF0F0F1A) | Cream gradient |
| Onboarding text | White | Dark brown (0xFF2C2C25) |
| Page indicators | Default blue | Sage green (0xFF6E8F5E) |
| Error banner | Harsh red (0xFFFAEBEB) | Warm error (0xFFFFF2F0) |
| TimePicker | Default white | Cream (0xFFFFFDF2) |
| Loading indicators | Inconsistent | Consistent with stroke |
| Dialog backgrounds | Various (0xFFFAF8F0) | Cream (0xFFFFFDF2) |

## Theme Extensions Added to main.dart

```dart
timePickerTheme: TimePickerThemeData(
  backgroundColor: Color(0xFFFFFDF2),
  dialBackgroundColor: Color(0xFFF3F2E8),
  hourMinuteColor: Color(0xFF16213E),
  dayPeriodColor: Color(0xFF6E8F5E),
  entryModeIconColor: Color(0xFF4E6E3A),
),
progressIndicatorTheme: ProgressIndicatorThemeData(
  color: Color(0xFF6E8F5E),
  linearTrackColor: Color(0xFFE6EFE3),
),
dialogTheme: DialogTheme(
  backgroundColor: Color(0xFFFFFDF2),
  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
),
```

