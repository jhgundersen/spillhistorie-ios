# Spillhistorie for iPad

`Spillhistorie` is an iPad app for reading articles from `spillhistorie.no` and listening to related Norwegian gaming podcasts in one place.

## What the app does

- Fetches article lists and article content from the WordPress API at `spillhistorie.no`
- Organizes articles into categories like `Nye spill`, `Retro`, `Indie`, `Inntrykk`, `Features`, and `Quiz`
- Renders article bodies from HTML into native SwiftUI views
- Aggregates podcast episodes from multiple feeds, with search and series filtering
- Includes a built-in audio player with lock screen controls, resume playback, and chapter support when available
- Uses an iPad-first `NavigationSplitView` layout with article browsing on one side and detail content on the other

## Included podcast feeds

- `Diskettkameratene`
- `cd SPILL`
- `Spaell`
- `Pappskaller`

## Tech stack

- SwiftUI for the UI
- AVFoundation and MediaPlayer for audio playback and now playing integration
- `FeedKit` for podcast RSS parsing
- `SwiftSoup` plus a custom HTML parser for article rendering
- WordPress REST API for article and notice data

## Project setup

This repository includes both `SpillhistorieApp.xcodeproj` and `project.yml`.

To open the app in Xcode:

1. Open `SpillhistorieApp.xcodeproj`
2. Select an iPad simulator or device
3. Build and run

If you want to regenerate the Xcode project from `project.yml`, use `XcodeGen`:

```bash
xcodegen generate
```

## Requirements

- Xcode 16+
- iOS 17+
- An iPad simulator or iPad device

## Notes

- The app is currently configured as iPad-only
- Audio playback is enabled in the background
- Article and podcast data are loaded from live remote sources
