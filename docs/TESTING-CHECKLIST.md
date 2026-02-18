# Testing Checklist - Kinex Fit iOS

Comprehensive testing checklist before App Store submission.

## Authentication & Onboarding

### Sign In
- [ ] Sign in with Apple works and creates new user
- [ ] Sign in with existing Apple ID loads user data
- [ ] JWT token is stored securely in keychain
- [ ] Token refresh works automatically
- [ ] Sign out clears all local data and tokens

### Onboarding Flow
- [ ] All 8 onboarding steps display correctly
- [ ] Back navigation works (except on first step)
- [ ] Skip button shows confirmation dialog
- [ ] Experience level selection required
- [ ] Schedule selection validates both fields
- [ ] Equipment allows multiple selections
- [ ] Goals allow multiple selections
- [ ] Personal records can be added/deleted
- [ ] Complete step shows accurate summary
- [ ] Backend receives onboarding data
- [ ] Onboarding only shows once per user
- [ ] Onboarding can be skipped entirely

## Core Features

### Workout Management
- [ ] Create new workout manually
- [ ] View workout list (sorted by date)
- [ ] Edit existing workout
- [ ] Delete workout with confirmation
- [ ] Workout details show all information
- [ ] Empty state shows helpful message

### OCR Scanning
- [ ] Camera permission requested properly
- [ ] Photo library permission requested properly
- [ ] Camera captures workout photo
- [ ] Photo library allows image selection
- [ ] OCR extracts text from image
- [ ] Extracted text parses into exercises
- [ ] AI enhancement works (if quota available)
- [ ] Quota limits enforced properly

### Sync Engine
- [ ] Workouts sync when online
- [ ] Offline changes enqueue properly
- [ ] Sync queue processes when connection restored
- [ ] Sync status indicator shows correct state
- [ ] Pull-to-refresh triggers sync
- [ ] Conflict resolution works (last-write-wins)
- [ ] Exponential backoff on failures
- [ ] Failed syncs show error banner
- [ ] Retry button works

### Body Metrics
- [ ] Log weight entry
- [ ] View weight history chart
- [ ] Log body measurements
- [ ] View measurements history
- [ ] Edit/delete metrics
- [ ] Unit conversion (kg/lbs) works

## In-App Purchases

### StoreKit Integration
- [ ] Products load from App Store Connect
- [ ] Subscription tiers display correctly
- [ ] Purchase flow works for each tier
- [ ] Payment is processed successfully
- [ ] Receipt validation with backend works
- [ ] User subscription tier updates locally
- [ ] Restore purchases works
- [ ] Subscription status shows in profile
- [ ] Quota limits update based on tier
- [ ] Downgrade/upgrade handled properly

### Paywall
- [ ] Paywall displays beautifully
- [ ] Feature comparison is clear
- [ ] Recommended tier is highlighted
- [ ] Purchase button shows loading state
- [ ] Error handling works (payment declined)
- [ ] Success dismisses paywall
- [ ] Legal links work (Terms, Privacy)

## Push Notifications

### Permission & Registration
- [ ] Notification permission request displays
- [ ] Permission denial handled gracefully
- [ ] Device token registers with APNs
- [ ] Token sends to backend successfully
- [ ] Permission status tracked correctly

### Notifications
- [ ] Local workout reminders can be scheduled
- [ ] Notifications appear at correct time
- [ ] Foreground presentation works
- [ ] Notification actions work (complete, snooze)
- [ ] Tapping notification opens app
- [ ] Badge count updates
- [ ] Notification settings in Settings app work

## Account Management

### Settings
- [ ] Unit preferences save and apply
- [ ] Theme selection works (light/dark/system)
- [ ] Notification toggle works
- [ ] Privacy policy link opens
- [ ] Terms of service link opens
- [ ] Support links work
- [ ] App version displays correctly

### Delete Account
- [ ] Delete account screen shows warnings
- [ ] Typing "DELETE" enables button
- [ ] Delete confirmation works
- [ ] Backend deletes all user data
- [ ] Local database cleared
- [ ] User signed out automatically
- [ ] Cannot recover deleted account

## UI/UX

### General
- [ ] App launches without crashes
- [ ] Navigation flows make sense
- [ ] Back buttons work everywhere
- [ ] Loading states display properly
- [ ] Error messages are clear
- [ ] Empty states are helpful
- [ ] Animations are smooth
- [ ] Dark mode looks good
- [ ] Light mode looks good

### Accessibility
- [ ] VoiceOver reads all elements
- [ ] Dynamic Type scales properly
- [ ] Contrast ratios meet WCAG AA
- [ ] Touch targets are 44x44+ points
- [ ] Labels are descriptive
- [ ] Buttons have accessibility labels

### Performance
- [ ] App launches in <3 seconds
- [ ] Workout list scrolls smoothly
- [ ] Image loading is fast
- [ ] No memory leaks
- [ ] No crashes in console
- [ ] Battery usage is reasonable
- [ ] Network calls are efficient

## Edge Cases

### Network
- [ ] Offline mode works (local-first)
- [ ] Airplane mode handled gracefully
- [ ] Poor connection shows appropriate state
- [ ] Network errors display helpful messages
- [ ] Retry mechanisms work

### Data
- [ ] Large workout lists perform well
- [ ] Empty data states handled
- [ ] Corrupted data doesn't crash app
- [ ] Database migrations work
- [ ] Quota limits enforced properly

### Security
- [ ] JWT tokens expire and refresh
- [ ] Sensitive data not logged
- [ ] API calls require authentication
- [ ] Receipt validation prevents fraud
- [ ] User can only access own data

## App Store Compliance

### Required
- [ ] Privacy manifest included (PrivacyInfo.xcprivacy)
- [ ] Permission strings in Info.plist
- [ ] Sign in with Apple works
- [ ] Account deletion available
- [ ] App icons (all sizes) included
- [ ] Launch screen works
- [ ] No placeholder content
- [ ] No debug/test features

### Best Practices
- [ ] App Store description accurate
- [ ] Screenshots representative
- [ ] Keywords relevant
- [ ] Support URL works
- [ ] Privacy policy URL works
- [ ] Age rating appropriate

## Device Testing

### Simulators
- [ ] iPhone 15 Pro (6.1")
- [ ] iPhone 15 Pro Max (6.7")
- [ ] iPhone SE (4.7")
- [ ] iPad Pro 12.9"

### Physical Devices (Recommended)
- [ ] iPhone with Face ID
- [ ] iPhone with Touch ID
- [ ] iPad
- [ ] Different iOS versions (16.0+)

## Pre-Submission

- [ ] All features tested end-to-end
- [ ] No critical bugs
- [ ] Performance acceptable
- [ ] Accessibility reviewed
- [ ] Privacy compliance verified
- [ ] Terms & privacy updated
- [ ] TestFlight beta tested
- [ ] Crash reports reviewed
- [ ] Analytics configured
- [ ] App Store metadata ready
- [ ] Screenshots prepared
- [ ] App review notes written

## Known Issues

Document any known issues here before submission:

- [ ] App icons still using placeholder (BLOCKER)
- [ ] Push notifications require APNs certificate (BLOCKER for production)
- [ ] Social features not implemented (FUTURE)

---

**Testing Status**: ⬜ Not Started | 🟡 In Progress | ✅ Complete

**Last Updated**: [Date]
**Tester**: [Name]
**Build Version**: [Version]
