import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'data/services/product_repository.dart';
import 'presentation/providers/product_provider.dart';
import 'presentation/screens/product_comparison_screen.dart';

void main() {
  runApp(
    ChangeNotifierProvider(
      create: (_) =>
          ProductProvider(repository: ProductRepository())..loadProducts(),
      child: const PickWiseApp(),
    ),
  );
}

class PickWiseApp extends StatelessWidget {
  const PickWiseApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'PickWise',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF165A4B),
          surface: Colors.white,
        ),
        scaffoldBackgroundColor: Colors.white,
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
      home: const ProductComparisonScreen(),
    );
  }
}
