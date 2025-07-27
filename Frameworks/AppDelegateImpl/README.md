# AppDelegateImpl Module

This module provides Firebase-based implementations of the AppDelegate protocols.

## Overview

The AppDelegateImpl module provides:

- `FirebaseAppDelegate` - A Firebase-based implementation of `AppDelegateImplementation`
- `StoreAwareAppDelegate` - A wrapper that connects implementations to Redux store dispatch
- `AppDelegateActionDispatcher` - Protocol for dispatching actions to the store
- Firebase-dependent middleware and reducers

## Key Features

- **Firebase Integration**: Handles Firebase initialization, messaging, and Firestore
- **Store Integration**: Automatically dispatches relevant actions to the Redux store
- **Modular Design**: Can be swapped out for different implementations
- **Deep Link Handling**: Processes notification deep links and routes them appropriately

## Dependencies

- Firebase Core, Messaging, and Firestore
- SatelliteForecast business logic
- AppDelegate interface module

## Usage

The main app creates a `StoreAwareAppDelegate` that wraps a `FirebaseAppDelegate`:

```swift
let firebaseImpl = FirebaseAppDelegate()
let implementation = StoreAwareAppDelegate(implementation: firebaseImpl, actionDispatcher: store)
```

This separation allows the Firebase dependencies to be isolated while maintaining clean integration with the app's Redux architecture.
