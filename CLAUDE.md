# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

Kinex Fit is an AI-powered fitness iOS application built with Swift and SwiftUI. It connects to a Next.js backend API hosted at `https://kinexfit.com` for workout tracking, AI-assisted workout generation, progress analytics, and subscription management via StoreKit 2.

## Building & Running

Open `ios/Kinex Fit.xcodeproj` in Xcode 15+ and build for iOS 17+. Swift Package Manager handles dependencies (Google Sign-In, Facebook SDK) — resolved automatically on first open.

## Architecture

### Tech Stack
- **Language**: Swift (async/await concurrency)
- **UI Framework**: SwiftUI
- **Auth**: Google Sign-In, Facebook Login, Email/Password (token-based via backend)
- **Networking**: URLSession with async/await (`APIClient`)
- **Local Storage**: SQLite via `AppDatabase` / `DatabaseMigrator`
- **In-App Purchases**: StoreKit 2 (`StoreManager`, `PurchaseValidator`)
- **Background Sync**: BackgroundTasks framework (`SyncEngine`)
- **Image/OCR**: Vision framework (`OCRService`, `TextExtractionService`)

### Directory Structure
```
ios/
├── Kinex Fit.xcodeproj/        # Xcode project
├── Kinex Fit.entitlements       # App capabilities
├── KinexFit/
│   ├── App/                     # App lifecycle & configuration
│   │   ├── KinexFitApp.swift    # @main SwiftUI app entry
│   │   ├── AppDelegate.swift    # UIKit delegate bridge
│   │   ├── AppState.swift       # Global observable state
│   │   ├── AppConfig.swift      # API base URL config
│   │   ├── AppEnvironment.swift # Dependency container
│   │   ├── RootView.swift       # Root navigation view
│   │   └── Theme.swift          # Design tokens
│   ├── Auth/                    # Authentication
│   │   ├── AuthViewModel.swift  # Auth state management
│   │   └── TokenStore.swift     # Secure token storage
│   ├── Models/                  # Data models
│   │   ├── User.swift, Workout.swift, BodyMetric.swift, etc.
│   │   └── AI/AIModels.swift    # AI request/response models
│   ├── Networking/              # API communication
│   │   ├── APIClient.swift      # Centralized HTTP client
│   │   └── APIRequest.swift     # Request builders
│   ├── Services/                # Business logic
│   │   ├── AuthService.swift, AIService.swift
│   │   ├── GoogleSignInManager.swift, FacebookSignInManager.swift
│   │   ├── InstagramFetchService.swift, InstagramImportService.swift
│   │   ├── WorkoutRepository.swift, UserRepository.swift
│   │   ├── OCRService.swift, TextExtractionService.swift
│   │   └── NotificationManager.swift
│   ├── Persistence/             # Local database
│   │   ├── AppDatabase.swift
│   │   └── DatabaseMigrator.swift
│   ├── Store/                   # In-app purchases
│   │   ├── StoreManager.swift
│   │   ├── PurchaseValidator.swift
│   │   └── ProductIDs.swift
│   ├── Sync/                    # Background sync
│   │   ├── SyncEngine.swift
│   │   ├── BackgroundSyncTask.swift
│   │   └── NetworkMonitor.swift
│   ├── Views/                   # SwiftUI views (tab-based)
│   │   ├── Main/MainTabView.swift
│   │   ├── Home/                # Dashboard
│   │   ├── Create/              # Workout creation (with import tabs)
│   │   ├── Add/                 # Add workout manually
│   │   ├── Metrics/             # Progress analytics
│   │   ├── Profile/             # User settings
│   │   ├── Auth/                # Sign in/up flows
│   │   ├── AI/                  # AI enhancement UI
│   │   ├── Store/               # Subscription UI
│   │   ├── Scan/                # OCR scanning
│   │   ├── Onboarding/          # First-run onboarding
│   │   ├── Import/              # Workout import
│   │   ├── Workouts/            # Workout list/detail
│   │   ├── Notifications/       # Notification views
│   │   └── Components/          # Reusable UI components
│   └── Resources/
│       ├── Assets.xcassets/     # App icons, colors
│       ├── Info.plist           # App metadata
│       └── PrivacyInfo.xcprivacy
└── KinexFitShareExtension/      # iOS Share Extension
```

### Key Patterns

**API Communication**: All network calls go through `APIClient` which handles auth tokens, base URL, and error mapping.

**Dependency Injection**: `AppEnvironment` acts as a service container, injected via SwiftUI environment.

**Auth Flow**: `AuthViewModel` manages sign-in state. Tokens stored securely via `TokenStore`. OAuth handled through Google/Facebook SDKs with URL callback in `KinexFitApp.onOpenURL`.

**Backend API**: The iOS app connects to the Kinex Fit web API at `https://kinexfit.com` (configured in `AppConfig.swift`).

## Key Files

- `ios/KinexFit/App/KinexFitApp.swift` - App entry point
- `ios/KinexFit/App/AppEnvironment.swift` - Dependency container
- `ios/KinexFit/App/AppConfig.swift` - API base URL
- `ios/KinexFit/Networking/APIClient.swift` - HTTP client
- `ios/KinexFit/Auth/AuthViewModel.swift` - Auth state
- `ios/KinexFit/Services/WorkoutRepository.swift` - Workout data access
- `ios/KinexFit/Store/StoreManager.swift` - StoreKit 2 purchases

## Documentation

iOS-specific documentation in `docs/`:
- `docs/APP-ICON-AI-GENERATION.md` - App icon generation prompts
- `docs/LAUNCH-SCREEN-SETUP.md` - Launch screen configuration
- `docs/TESTING-CHECKLIST.md` - QA testing checklist
- `docs/LAUNCH-READINESS.md` - Launch readiness tracker
