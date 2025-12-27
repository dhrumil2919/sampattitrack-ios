# Build & Verification

## Build Commands

### Build for Simulator
```bash
xcodebuild -project SampattiTrack/SampattiTrack.xcodeproj \
  -scheme SampattiTrack \
  -sdk iphonesimulator \
  -destination 'platform=iOS Simulator,name=iPhone 17' \
  build
```

### Build for Device
```bash
xcodebuild -project SampattiTrack/SampattiTrack.xcodeproj \
  -scheme SampattiTrack \
  -sdk iphoneos \
  build
```

### Clean Build
```bash
xcodebuild -project SampattiTrack/SampattiTrack.xcodeproj \
  -scheme SampattiTrack \
  clean build
```

---

## Test Commands

### Run All Tests
```bash
xcodebuild -project SampattiTrack/SampattiTrack.xcodeproj \
  -scheme SampattiTrack \
  -sdk iphonesimulator \
  -destination 'platform=iOS Simulator,name=iPhone 17' \
  test
```

### Run Specific Test Class
```bash
xcodebuild -project SampattiTrack/SampattiTrack.xcodeproj \
  -scheme SampattiTrack \
  -sdk iphonesimulator \
  -destination 'platform=iOS Simulator,name=iPhone 17' \
  -only-testing:SampattiTrackTests/TestClassName \
  test
```

---

## Verification Checklist

After every change, verify:

### Build
- [ ] Project builds without errors
- [ ] No new warnings introduced
- [ ] No deprecation warnings for targeted iOS

### Tests
- [ ] Existing tests pass
- [ ] New tests added for new functionality (if applicable)

### Runtime (if running in simulator)
- [ ] App launches successfully
- [ ] No crash on affected screens
- [ ] Sync completes without errors

---

## Common Build Issues

### Missing Module
If you see "No such module 'X'":
- Check if the module is in the project
- Try cleaning the build folder

### Type Mismatch
If you see type errors:
- Verify domain model matches SwiftData model
- Check conversion properties

### Swift Concurrency
If you see actor isolation errors:
- Use `@MainActor` for UI updates
- Use `nonisolated` for sync callbacks
- Check `@ModelActor` usage in `SyncActor`

---

## Project Locations

| Item | Path |
|------|------|
| Project file | `SampattiTrack/SampattiTrack.xcodeproj` |
| Main scheme | `SampattiTrack` |
| Tests | `SampattiTrack/SampattiTrackTests/` |
| Source code | `SampattiTrack/SampattiTrack/` |
