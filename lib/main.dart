// lib/main.dart
// ignore_for_file: depend_on_referenced_packages
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart'; // Paquete principal de Firebase
import 'firebase_options.dart'; // Archivo generado por FlutterFire CLI
import 'dart:ui';
import 'package:flutter/widgets.dart';
import 'package:provider/provider.dart';

// Imports de tus páginas
import 'pages/login_page.dart';
import 'pages/dashboard_page.dart';
import 'pages/combustible_page.dart';
import 'pages/registro_asistencia_page.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'pages/falla_electrica_page.dart';
import 'pages/registrar_mantenimiento_page.dart';
import 'pages/mantenimiento_home_page.dart';
import 'pages/reporte_cfe_page.dart';
import 'pages/admin_usuarios_page.dart';
import 'providers/user_profile_provider.dart';

void main() async {
  // Asegura que los bindings de Flutter estén inicializados
  WidgetsFlutterBinding.ensureInitialized();
  // Inicializa Firebase para la plataforma actual
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  // Corre la aplicación

  await initializeDateFormatting('es_MX', null);
  runApp(
    ChangeNotifierProvider(
      create: (context) => UserProfileProvider(),
      child: const GestionTransmisionApp(),
    ),
  );
//  runApp(const GestionTransmisionApp());
  runWidget(
    View(
      view: WidgetsBinding.instance.platformDispatcher.views.first,
      child:
          const GestionTransmisionApp(), // Make sure MyApp is the name of your root widget
    ),
  );
}

class GestionTransmisionApp extends StatelessWidget {
  const GestionTransmisionApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Gestión CORAT',
      debugShowCheckedModeBanner: false,

      // ▼▼▼ INICIO DE LA DEFINICIÓN DEL TEMA ▼▼▼
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.red[900]!,
          primary: Colors.red[900]!,
          secondary: Colors.amber[700]!,
          surface: Colors.grey[100]!,
          surfaceContainerHighest: Colors.white,
          error: Colors.redAccent,
          onPrimary: Colors.white,
          onSecondary: Colors.black,
          onSurface: Colors.black,
          onError: Colors.white,
        ),

        appBarTheme: AppBarTheme(
          backgroundColor: Colors.red[900]!,
          foregroundColor: Colors.white,
          elevation: 4.0,
          titleTextStyle: const TextStyle(
            color: Colors.white,
            fontSize: 20.0,
            fontWeight: FontWeight.bold,
          ),
          iconTheme: const IconThemeData(
            color: Colors.white,
          ),
        ),

        // =================================================================
        // ▼▼▼ AQUÍ ESTÁ LA CORRECCIÓN ▼▼▼
        // Se cambió CardTheme por CardThemeData
        cardTheme: CardThemeData(
          color: Colors.white,
          elevation: 2.0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12.0),
          ),
          margin: const EdgeInsets.all(8.0),
        ),
        // ▲▲▲ FIN DE LA CORRECCIÓN ▲▲▲
        // =================================================================

        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.red[900]!,
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8.0),
            ),
            textStyle: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),

        inputDecorationTheme: InputDecorationTheme(
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8.0),
            borderSide: BorderSide(color: Colors.grey[400]!),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8.0),
            borderSide: BorderSide(color: Colors.grey[400]!),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8.0),
            borderSide: BorderSide(color: Colors.red[900]!, width: 2.0),
          ),
          labelStyle: TextStyle(color: Colors.grey[700]),
        ),

        useMaterial3: true,
      ),
      // ▲▲▲ FIN DE LA DEFINICIÓN DEL TEMA ▲▲▲

      // Rutas de la aplicación
      initialRoute: '/login',
      routes: {
        '/login': (_) => const LoginPage(),
        '/dashboard': (_) => const DashboardPage(),
        '/combustible': (_) => const CombustiblePage(),
        '/asistencia': (_) => const RegistroAsistenciaPage(),
        '/falla_electrica': (_) => const FallaElectricaPage(),
        '/registrar_mantenimiento': (_) => const RegistrarMantenimientoPage(),
        '/mantenimiento_home': (_) => const MantenimientoHomePage(),
        '/reporte_cfe': (context) {
          // Extrae el ID del argumento pasado por Navigator.pushNamed
          final faultId = ModalRoute.of(context)?.settings.arguments as String?;
          // Asegúrate de que el ID no sea nulo antes de construir la página
          if (faultId != null) {
            return ReporteCFEPage(faultId: faultId);
          } else {
            // Manejo de error: Si no se pasó ID, regresa al dashboard o muestra error
            // (Aquí regresamos al dashboard por seguridad)
            WidgetsBinding.instance.addPostFrameCallback((_) {
              Navigator.pushReplacementNamed(context, '/dashboard');
            });
            return const Scaffold(
                body: Center(child: Text("Error: Falta ID de falla")));
          }
        },
        '/admin_usuarios': (_) => const AdminUsuariosPage(),
      },
    );
  }
}
