# AppDelegate Module

This module provides the protocol-based interface for app delegate functionality without any external dependencies.

## Overview

The AppDelegate module defines:

- `AppDelegateAction` - The actions that can be dispatched related to app delegate events
- `AppDelegateProtocol` - Interface for core UIApplication delegate methods
- `MessagingHandlerProtocol` - Interface for handling Firebase Cloud Messaging
- `NotificationHandlerProtocol` - Interface for handling user notifications
- `AppDelegateImplementation` - Combined protocol for a complete app delegate implementation

## Key Features

- **Dependency-free**: No external dependencies except for basic UIKit/UserNotifications
- **Protocol-based**: Enables dependency injection and testing
- **Modular**: Can be implemented differently for different environments (production, testing, etc.)

## Usage

Implement the `AppDelegateImplementation` protocol to provide your app delegate functionality:

```swift
class MyAppDelegate: AppDelegateImplementation {
    // Implement required methods
}
```

This design allows the main app to remain Firebase-free while implementations can include whatever dependencies they need.
