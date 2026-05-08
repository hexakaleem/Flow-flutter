import 'package:flutter/material.dart';
import 'screens/intro_screen.dart';
import 'screens/login_screen.dart';
import 'screens/register_screen.dart';
import 'screens/home_screen.dart';
import 'screens/shipment_detail_screen.dart';
import 'screens/load_board_screen.dart';
import 'screens/load_details_screen.dart';
import 'screens/profile_screen.dart';
import 'screens/navigation_screen.dart';
import 'models/load.dart';
import 'models/shipment.dart';
import 'theme/app_theme.dart';
import 'package:latlong2/latlong.dart';

void main() {
  runApp(const FlowApp());
}

class FlowApp extends StatelessWidget {
  const FlowApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'FLOW',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.darkTheme,
      initialRoute: '/',
      routes: {
        '/': (context) => const IntroScreen(),
        '/login': (context) => const LoginScreen(),
        '/register': (context) => const RegisterScreen(),
        '/home': (context) => const HomeScreen(),
        '/profile': (context) => const ProfileScreen(),
        '/load_board': (context) => const LoadBoardScreen(),
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
        '/navigation': (context) {
          final args = ModalRoute.of(context)?.settings.arguments as Map?;
          final shipment = args?['shipment'] as Shipment?;
          final origin = args?['origin'] as LatLng? ?? const LatLng(32.78, -96.8);
          final destination = args?['destination'] as LatLng? ?? const LatLng(33.74, -84.38);
          return NavigationScreen(
            shipment: shipment,
            origin: origin,
            destination: destination,
          );
        },
      },
    );
  }
}
