import 'package:flutter/material.dart';
import 'package:pickwise/data/services/temp_product_repository.dart';
import 'package:pickwise/presentation/providers/temp_product_provider.dart';
import 'package:pickwise/presentation/screens/home_screen.dart';
import 'package:provider/provider.dart';

void main() {
  runApp(
    ChangeNotifierProvider(
      create: (_) =>
      ProductProvider(repository: ProductRepository())..loadProducts(),
      child: MaterialApp(home: HomeScreen(),),
    ),
  );
}
