# AppDelegateImpl Module

This module provides Firebase-based implementations of the AppDelegate protocols.

## Overview

The AppDelegateImpl module provides:

- `AppDelegateImpl` - A unified Firebase-based implementation of the AppDelegate protocols
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
