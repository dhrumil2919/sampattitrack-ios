# SampattiTrack iOS - Agent Guidelines

This directory contains strict workflow contracts and guardrails for AI coding agents working on this iOS application.

## Files

| File | Purpose |
|------|---------|
| [architecture.md](./architecture.md) | Project architecture, patterns, and structure |
| [conventions.md](./conventions.md) | Naming conventions and coding standards |
| [workflow.md](./workflow.md) | Mandatory coding workflow and checklists |
| [rules.md](./rules.md) | Strict rules and prohibitions |
| [build.md](./build.md) | Build, test, and verification commands |

## Quick Reference

- **Architecture**: MVVM with SwiftUI + SwiftData
- **iOS Minimum**: 17.0+
- **Persistence**: Offline-first with SwiftData
- **Sync**: Queue-based bidirectional sync

## Before ANY Code Change

1. Read `architecture.md` to understand project structure
2. Read `conventions.md` for naming patterns
3. Follow `workflow.md` for implementation steps
4. Respect `rules.md` prohibitions
5. Use `build.md` to verify changes
