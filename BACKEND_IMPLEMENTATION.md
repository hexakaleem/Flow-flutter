# FLOW Backend Implementation Guide

## Overview
This document describes the complete backend logic implementation for the FLOW Flutter app, including authentication, load management, and shipment tracking.

## Architecture

### Models (lib/models/)
Models represent the data structures used throughout the app:

#### 1. **User.dart**
- `username`: Driver's display name
- `mcNumber`: MC (Motor Carrier) number - unique identifier
- `password`: Authentication password
- `email`: Driver's email
- `phoneNumber`: Driver's phone number
- `truckNumber`: Truck/Vehicle identification
- `companyName`: Company/carrier name

#### 2. **Load.dart**
- `id`: Unique load identifier
- `loadNumber`: Display load number (e.g., #FL-8812)
- `rate`: Total rate (e.g., $2,800)
- `rateUnit`: Rate per unit (e.g., $3,550/mi)
- `commodity`: Type of cargo (e.g., Fresh Food)
- `origin`, `destination`: Location information
- `originDate/Time`, `destinationDate/Time`: Scheduling
- `weight`: Cargo weight
- `distance`: Distance between origin and destination
- `status`: Load status (Reefer, Dry Van, etc.)
- `requirements`: Special requirements (list)

#### 3. **Shipment.dart**
Represents a booked load that's now being transported:
- `id`: Unique shipment ID
- `loadId`: Reference to the original load
- `commodity`, `origin`, `destination`: Route details
- `weight`, `rate`: Cargo information
- `status`: Current shipment status (Active, Completed, etc.)
- `carrier`: Carrier/company name

### Services (lib/services/)

#### 1. **AuthService.dart** - Authentication & Registration
Manages user authentication with dummy data support.

**Key Methods:**
- `register()`: Register new truck driver
  - Validates input
  - Stores user data locally
  - Returns success/failure
  
- `login()`: Authenticate driver
  - Supports registered users
  - Demo credentials: `MC123456` / `password123`
  - Returns true on success
  
- `logout()`: Clear current user session
- `currentUser`: Access currently logged-in user
- `isLoggedIn()`: Check if user is authenticated

**Dummy Data:**
- All registrations are stored in memory
- Demo login: MC123456 / password123
- Registration data persists during app session

#### 2. **LoadService.dart** - Load Management
Provides load board functionality with dummy loads.

**Key Methods:**
- `getAvailableLoads()`: Retrieve all available loads
  - Returns List<Load>
  - Includes dummy data with realistic values
  
- `getLoadById()`: Get specific load details
- `bookLoad()`: Book a load (removes from available)
- `searchLoads()`: Search by origin/destination
- `filterLoadsByRate()`: Filter by price range

**Dummy Loads Included:**
- Fresh Food routes (Dallas → Atlanta)
- Automotive Parts routes
- Electronics shipments
- General freight loads
- Includes all details: rates, weights, requirements

#### 3. **ShipmentService.dart** - Shipment Tracking
Manages booked shipments for each driver.

**Key Methods:**
- `getCurrentUserShipments()`: Get active shipments for logged-in driver
- `addShipment()`: Create new shipment when load is booked
- `getShipmentById()`: Get specific shipment details
- `updateShipmentStatus()`: Update shipment progress
- `deleteShipment()`: Remove completed shipments

**Features:**
- Shipments stored per user (by MC number)
- Automatic creation when load is booked
- Status tracking support

## Screen Flow & Navigation

### 1. **Intro Screen** (IntroScreen)
- Entry point of the app
- Shows FLOW branding
- Navigation to Login/Register

### 2. **Register Screen** (RegisterScreen)
**Inputs:**
- Username
- MC Number
- Password
- Email
- Phone Number
- Truck Number
- Company Name

**Features:**
- Form validation
- Error messages
- Success confirmation
- Redirects to login after registration

**Backend Integration:**
```dart
AuthService.register(
  username: username,
  mcNumber: mcNumber,
  password: password,
  email: email,
  phoneNumber: phoneNumber,
  truckNumber: truckNumber,
  companyName: companyName,
);
```

### 3. **Login Screen** (LoginScreen)
**Inputs:**
- MC Number
- Password

**Demo Credentials:**
- MC: `MC123456`
- Password: `password123`

**Features:**
- Form validation
- Error handling
- Demo credential hint displayed
- Navigation to home on success

**Backend Integration:**
```dart
AuthService.login(
  mcNumber: mcNumber,
  password: password,
);
```

### 4. **Home Screen** (HomeScreen)
**Features:**
- Displays logged-in user's name ("WELCOME [USERNAME]!")
- Shows active shipments or "No shipment available to track"
- Quick action buttons (Fuel up, Maintenance, Earnings)
- Map placeholder with current route
- Bottom navigation bar

**Navigation:**
- Load Board: Access load board to browse available loads
- Orders: Coming soon
- Statistics: Coming soon
- Logout: Long press logout icon

**Shipment Display:**
```dart
FutureBuilder<List<Shipment>>(
  future: _shipmentsFuture,
  builder: (context, snapshot) {
    // Shows either:
    // 1. Booked shipments if available
    // 2. "No shipment available to track" message with browse loads button
  }
)
```

### 5. **Load Board Screen** (LoadBoardScreen)
**Features:**
- Displays all available loads
- Scrollable list of load cards
- Each card shows:
  - Load number & commodity
  - Rate information
  - Origin & destination with dates/times
  - Weight, distance, status info
  - Tap to view details

**Backend Integration:**
```dart
LoadService().getAvailableLoads()
  .then((loads) => displayLoadCards(loads));
```

### 6. **Load Details Screen** (LoadDetailsScreen)
**Features:**
- Full load information display
- Route visualization (origin → destination)
- Load requirements (Reefer, Full TL, Hazmat, etc.)
- "Book Load" button

**When Load is Booked:**
1. Load removed from availability
2. Shipment created in user's account
3. Success message displayed
4. Auto-redirect to home screen
5. Shipment appears in "Current Shipment" section

**Backend Integration:**
```dart
// 1. Book the load
LoadService().bookLoad(loadId);

// 2. Create shipment for user
ShipmentService().addShipment(
  loadId: loadNumber,
  commodity: commodity,
  origin: origin,
  destination: destination,
  // ... other details
);
```

### 7. **Shipment Detail Screen** (ShipmentDetailScreen)
- Shows booked shipment details
- Route progress tracking
- Cargo information (weight, distance, temp)
- Action buttons (Phone, Navigate, Documents)

## Data Flow Examples

### Example 1: New Driver Registration
```
1. User fills registration form
2. RegisterScreen.register() called
3. AuthService.register() validates & stores data
4. User redirected to LoginScreen
5. User logs in with registered credentials
6. HomeScreen displayed with "No shipment available to track"
```

### Example 2: Booking a Load
```
1. Home Screen → Tap Load Board button
2. LoadBoardScreen displayed with all loads
3. User taps a load card
4. LoadDetailsScreen shows full details
5. User taps "Book Load" button
6. LoadService.bookLoad() removes from available
7. ShipmentService.addShipment() creates shipment
8. Success message displayed
9. Auto-redirect to HomeScreen
10. Shipment now visible in "Current Shipment" section
```

### Example 3: Multiple Shipments
```
1. User books first load → 1 shipment in list
2. User returns to Load Board, books another load
3. HomeScreen now shows 2 active shipments
4. Each shipment is clickable for details
```

## API Placeholder

All services are currently using dummy data. When connecting to real API:

### AuthService Changes:
```dart
// Replace dummy data logic with:
final response = await http.post(
  Uri.parse('https://api.flow.com/auth/login'),
  body: {'mcNumber': mcNumber, 'password': password},
);
```

### LoadService Changes:
```dart
// Replace dummy loads with:
final response = await http.get(
  Uri.parse('https://api.flow.com/loads'),
);
```

### ShipmentService Changes:
```dart
// Replace local storage with:
final response = await http.post(
  Uri.parse('https://api.flow.com/shipments'),
  body: shipmentData,
);
```

## Testing the App

### To Test Registration:
1. Tap Register on intro screen
2. Fill all fields with dummy data
3. MC Number: "MC123457" (or any unique number)
4. Tap Register
5. Should redirect to login screen

### To Test Login:
1. Login with: MC123456 / password123 (demo)
2. Or use a registered MC number with your password

### To Test Load Booking:
1. Log in successfully
2. Tap "Load Board" in bottom navigation
3. Browse and tap any load card
4. Tap "Book Load" button
5. Observe:
   - Success message
   - Auto-redirect to home
   - New shipment appears in list

### To Test Multiple Shipments:
1. Book multiple loads
2. HomeScreen shows all booked shipments
3. Tap any shipment for details

### To Test Logout:
1. On HomeScreen, tap logout icon (or long press)
2. Confirm logout
3. Redirect to login screen

## State Management

Currently using:
- **AuthService**: Singleton pattern for global auth state
- **ShipmentService**: Singleton pattern for shipment data
- **LoadService**: Singleton pattern for load data
- **StatefulWidget**: Local state in screens

Future improvements:
- Consider Provider package
- Or GetX for advanced state management
- Implement persistent local storage with Hive/SQLite

## Error Handling

Each service includes:
- Try-catch blocks
- Meaningful error messages
- User-friendly snackbars
- Fallback UI states

## Next Steps for Full Integration

1. **Database**: Connect to backend API
2. **Authentication**: Implement JWT tokens
3. **Real-time Updates**: WebSocket for shipment tracking
4. **Notifications**: FCM for load updates
5. **Payment**: Integration for earnings
6. **Maps**: Real Google Maps integration
7. **Persistence**: Local storage for offline support

---

For questions or updates, refer to the service files for implementation details.
