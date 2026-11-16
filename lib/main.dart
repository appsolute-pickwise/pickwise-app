import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'data/services/product_repository.dart';
import 'data/services/pickwise_api.dart';
import 'presentation/providers/session_provider.dart';
import 'presentation/providers/product_provider.dart';
import 'presentation/providers/app_navigation_controller.dart';
import 'presentation/screens/auth_gate.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  final api = PickwiseApi();
  final products = ProductProvider(repository: ProductRepository(api: api));
  runApp(
    ChangeNotifierProvider.value(value: products, child: const PickWiseApp()),
  );
  products.loadProducts();
}

class PickWiseApp extends StatelessWidget {
  const PickWiseApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AppNavigationController()),
        ChangeNotifierProvider(
          create: (context) => SessionProvider(
            api: context.read<ProductProvider>().api,
            products: context.read<ProductProvider>(),
          )..initialize(),
          lazy: false,
        ),
      ],
      child: MaterialApp(
        debugShowCheckedModeBanner: false,
        title: 'PickWise',
        theme: ThemeData(
          colorScheme: ColorScheme.fromSeed(
            seedColor: const Color(0xFF165A4B),
            surface: Colors.white,
          ),
          scaffoldBackgroundColor: Colors.white,
          visualDensity: VisualDensity.standard,
          inputDecorationTheme: InputDecorationTheme(
            helperMaxLines: 3,
            errorMaxLines: 3,
            filled: true,
            fillColor: const Color(0xFFF5F6F8),
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 16,
            ),
            hintStyle: const TextStyle(color: Color(0xFF657181), fontSize: 14),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: BorderSide.none,
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: BorderSide.none,
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: const BorderSide(color: Color(0xFF165A4B)),
            ),
          ),
          filledButtonTheme: FilledButtonThemeData(
            style: FilledButton.styleFrom(
              minimumSize: const Size(48, 52),
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
              textStyle: const TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w600,
              ),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
            ),
          ),
          chipTheme: ChipThemeData(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            side: const BorderSide(color: Color(0xFFE1E8E3)),
            labelStyle: const TextStyle(
              color: Color(0xFF191F28),
              fontSize: 13,
              fontWeight: FontWeight.w500,
            ),
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
          ),
          appBarTheme: const AppBarTheme(
            backgroundColor: Colors.white,
            foregroundColor: Color(0xFF191F28),
            elevation: 0,
            scrolledUnderElevation: 0,
            titleTextStyle: TextStyle(
              color: Color(0xFF191F28),
              fontSize: 18,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
        home: const AuthGate(),
      ),
    );
  }
}
