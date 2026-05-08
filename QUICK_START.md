# FLOW App - Quick Start Guide

## What Was Implemented

### ✅ Authentication System
- **Registration**: New truck drivers can register with full details (username, MC number, password, email, phone, truck number, company)
- **Login**: Authenticate using MC number + password
- **Demo Credentials**: MC123456 / password123
- **Logout**: Option to logout from home screen

### ✅ Home Screen
- Shows welcome message with logged-in driver's username
- Displays current shipments in a list
- Shows "No shipment available to track" when empty with Browse Loads button
- Navigation to all other screens via bottom nav bar
- Logout functionality

### ✅ Load Board System
- Displays all available loads as scrollable cards
- Shows load details on each card:
  - Load number & commodity type
  - Rate and rate per mile
  - Origin & destination with dates/times
  - Weight, distance, and status
- Tap any load to see full details

### ✅ Load Booking System
- Load details screen with complete information
- "Book Load" button that:
  - Removes load from available list
  - Creates shipment for the driver
  - Shows success message
  - Auto-redirects to home
  - New shipment appears immediately
- View load requirements (Reefer, Full TL, Hazmat, etc.)

### ✅ Shipment Tracking
- Lists all active shipments for logged-in driver
- Each shipment shows:
  - Load ID and commodity
  - Active status badge
  - Origin and destination routes
  - Go to Map button
- Tap to see full shipment details

### ✅ Navigation System
- Bottom navigation bar with Load Board access
- Proper routing between all screens
- Back navigation properly handled

## Running the App

```bash
# Get dependencies
flutter pub get

# Run the app
flutter run
```

## Testing Scenarios

### Scenario 1: Complete New User Journey
1. **App Opens** → Intro screen shown
2. **Register** → Fill form and submit
   - Username: John Driver
   - MC Number: MC123456
   - Password: password123
   - Email: john@driver.com
   - Phone: +1234567890
   - Truck: TR-001
   - Company: Driver Inc
3. **Login** → Use registered credentials
4. **Home Screen** → Shows "No shipment available to track"
5. **Browse Loads** → Tap Load Board
6. **View Loads** → Scroll through available loads
7. **Book Load** → Select a load and tap "Book Load"
8. **Success** → Auto-redirect to home
9. **Shipment Appears** → See booked shipment in list

### Scenario 2: Demo Login
1. **App Opens** → Intro screen
2. **Login** → Use demo credentials
   - MC: MC123456
   - Password: password123
3. **Home Screen** → No shipments (first login)
4. **Book a Load** → Follow booking flow
5. **Multiple Bookings** → Book more loads, see them all in list

### Scenario 3: Logout & Re-login
1. **Home Screen** → Tap logout icon (top right)
2. **Confirm** → Logout dialog appears
3. **Login Screen** → Redirected
4. **Login Again** → Previous shipments still available for the user

## Dummy Load Data

The app includes 6 pre-loaded dummy loads:
1. **#FL-8812** - Fresh Food (Dallas → Atlanta) - $2,800
2. **#FL-7209** - Automotive Parts (Houston → Miami) - $1,950
3. **#FL-83417** - Consumer Electronics (Chicago → Charlotte) - $3,400
4. **#FL-51830** - General Freight (Nashville → Louisville) - $890
5. **#FL-9204** - Perishable Goods (Phoenix → Denver) - $2,150
6. **#FL-7651** - Industrial Equipment (Cleveland → Pittsburgh) - $1,750

Each includes:
- Complete route information
- Dates and times
- Weight and distance
- Special requirements
- Rate information

## File Structure

```
lib/
├── main.dart                          # App entry point with routes
├── models/
│   ├── user.dart                      # User data model
│   ├── load.dart                      # Load data model
│   └── shipment.dart                  # Shipment data model
├── services/
│   ├── auth_service.dart              # Authentication service
│   ├── load_service.dart              # Load management service
│   └── shipment_service.dart          # Shipment tracking service
├── screens/
│   ├── intro_screen.dart              # App entry screen
│   ├── login_screen.dart              # Login screen (UPDATED)
│   ├── register_screen.dart           # Registration screen (UPDATED)
│   ├── home_screen.dart               # Home screen (UPDATED)
│   ├── load_board_screen.dart         # Load board screen (NEW)
│   ├── load_details_screen.dart       # Load details screen (NEW)
│   └── shipment_detail_screen.dart    # Shipment details screen (UPDATED)
└── theme/
    └── app_theme.dart                 # App theme configuration
```

## Key Features

### Authentication
- ✅ Register with full driver details
- ✅ Login with MC number
- ✅ Demo credentials support
- ✅ Session management
- ✅ Logout functionality

### Load Board
- ✅ Display all loads with rich information
- ✅ Scrollable list
- ✅ Tap for details
- ✅ Book loads
- ✅ Update availability

### Shipments
- ✅ Track active shipments
- ✅ Per-driver shipment tracking
- ✅ Multiple simultaneous shipments
- ✅ Shipment details view
- ✅ Empty state handling

### UX/UI
- ✅ Purple gradient theme (brand colors)
- ✅ Bottom navigation bar
- ✅ Loading indicators
- ✅ Error messages
- ✅ Success feedback
- ✅ Smooth transitions

## API Integration Ready

All services have placeholder API structure. To connect to actual API:

1. Update `AuthService.register()` to call API endpoint
2. Update `AuthService.login()` to call API endpoint
3. Update `LoadService.getAvailableLoads()` to call API endpoint
4. Update `ShipmentService` methods to call API endpoint

Example structure already in place - just replace the dummy data calls with HTTP requests.

## Known Limitations (By Design)

1. **Data Persistence**: Data resets when app closes (use Hive/SQLite for persistence)
2. **Offline Mode**: Requires internet connectivity simulation (implement caching)
3. **Real Maps**: Currently shows placeholder gradient (integrate Google Maps)
4. **Payment**: Not implemented (add payment gateway)
5. **Notifications**: Not implemented (add FCM)

## Next Development Steps

1. **Connect to Web API** - Replace dummy data with real API calls
2. **Add Persistence** - Save user data locally
3. **Implement Real Maps** - Use Google Maps API
4. **Add Notifications** - Firebase Cloud Messaging
5. **Payment System** - For earnings settlement
6. **Chat/Support** - In-app messaging
7. **Analytics** - Track usage patterns

## Testing Tips

- **Register multiple times** with different MC numbers
- **Each user gets their own shipments** - shipments are stored per MC number
- **Booking removes loads** - Once booked, a load is unavailable to others
- **All data is in-memory** - Restarting app resets everything

---

For detailed documentation, see BACKEND_IMPLEMENTATION.md
