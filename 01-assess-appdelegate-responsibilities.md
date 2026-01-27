# AppDelegate Responsibilities Assessment

## Overview
This document assesses the responsibilities currently handled by the AppDelegate in the Gaze application, identifying the core functions and potential areas for improvement.

## Current Responsibilities

### 1. Application Lifecycle Management
- Handles `applicationDidFinishLaunching` to initialize app state
- Manages `applicationWillTerminate` for cleanup
- Sets up system lifecycle observers (sleep/wake notifications)

### 2. Service Initialization
- Initializes the TimerEngine
- Sets up smart mode services (FullscreenDetectionService, IdleMonitoringService, UsageTrackingService)
- Configures update manager after onboarding completion

### 3. Settings Management
- Observes settings changes to start/stop timers appropriately
- Handles onboarding state management
- Manages Smart Mode settings observation

### 4. User Interface Management
- Displays onboarding at launch if needed
- Shows reminder windows (overlay and subtle)
- Manages settings and onboarding windows through WindowManager
- Handles menu dismissal logic for proper UI flow

### 5. Timer State Management
- Starts timers when onboarding is complete
- Handles system sleep/wake events
- Observes timer state changes to update UI

## Key Findings

### Positive Aspects:
- Clear separation of concerns with service container pattern
- Dependency injection allows for testing
- Lifecycle management is centralized
- Window management is abstracted through protocol

### Potential Issues:
- AppDelegate is handling too many responsibilities (service coordination, UI management, lifecycle)
- Direct dependency on NSWorkspace notifications instead of using more structured event handling
- Tight coupling between multiple services and the AppDelegate

## Recommendations

1. **Reduce AppDelegate Responsibilities**:
   - Move timer state change handling to TimerEngine or a dedicated timer manager
   - Extract window management logic into separate components
   - Consider delegating system lifecycle handling to dedicated observers

2. **Improve Modularity**:
   - Create a dedicated service coordinator that handles inter-service communication
   - Implement a more structured event system for state changes instead of direct observing

3. **Enhance Testability**:
   - The current dependency injection approach is good, but could be made even more flexible
   - Add more granular mocking capabilities for individual services

## Conclusion
While the AppDelegate currently fulfills its role in managing application lifecycle and coordinating services, it's handling too many responsibilities that should ideally be distributed among specialized components. This makes the code harder to test and maintain.