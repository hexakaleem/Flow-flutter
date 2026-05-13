import 'package:flutter/material.dart';
import 'screens/intro_screen.dart';
import 'screens/login_screen.dart';
import 'screens/register_screen.dart';
import 'screens/home_screen.dart';
import 'screens/shipment_detail_screen.dart';
import 'screens/load_board_screen.dart';
import 'screens/load_details_screen.dart';
import 'screens/profile_screen.dart';
import 'screens/customer_support_screen.dart';
import 'screens/order_history_screen.dart';
import 'screens/vehicle_registration_screen.dart';
import 'screens/fuel_log_screen.dart';
import 'screens/stats_screen.dart';
import 'screens/search_screen.dart';
import 'screens/notification_screen.dart';
import 'screens/tasks_screen.dart';
import 'services/notification_service.dart';
import 'models/load.dart';
import 'models/shipment.dart';
import 'theme/app_theme.dart';
import 'services/auth_service.dart';
import 'services/token_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // Load persisted tokens first so the API client can attach them.
  await TokenService().load();
  // Restore persisted session (if any) before the widget tree is built.
  final bool loggedIn = await AuthService.tryAutoLogin();
  // Load persisted notifications.
  await NotificationService().load();
  runApp(FlowApp(startLoggedIn: loggedIn));
}

class FlowApp extends StatelessWidget {
  final bool startLoggedIn;
  const FlowApp({super.key, required this.startLoggedIn});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'FLOW',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.darkTheme,
      // Skip the intro/login flow if the driver is already authenticated.
      initialRoute: startLoggedIn ? '/home' : '/',
      routes: {
        '/': (context) => const IntroScreen(),
        '/login': (context) => const LoginScreen(),
        '/register': (context) => const RegisterScreen(),
        '/home': (context) => const HomeScreen(),
        '/profile': (context) => const ProfileScreen(),
        '/load_board': (context) => const LoadBoardScreen(),
        '/customer_support': (context) => const CustomerSupportScreen(),
        '/load_details': (context) {
          final load = ModalRoute.of(context)?.settings.arguments as Load?;
          if (load == null) return const LoadBoardScreen();
          return LoadDetailsScreen(load: load);
        },
        '/shipment_detail': (context) {
          final shipment =
              ModalRoute.of(context)?.settings.arguments as Shipment?;
          return ShipmentDetailScreen(shipment: shipment);
        },
        '/vehicle_registration': (context) {
          final isEditing =
              ModalRoute.of(context)?.settings.arguments as bool? ?? false;
          return VehicleRegistrationScreen(isEditing: isEditing);
        },
        '/fuel_log': (context) => const FuelLogScreen(),
        '/stats': (context) => const StatsScreen(),
        '/search': (context) => const SearchScreen(),
        '/notifications': (context) => const NotificationScreen(),
        '/order_history': (context) => const OrderHistoryScreen(),
        '/tasks': (context) => const TasksScreen(),
      },
    );
  }
}
