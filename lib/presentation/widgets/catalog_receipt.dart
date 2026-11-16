import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/product_provider.dart';
import 'product_formatters.dart';

class CatalogReceipt extends StatelessWidget {
  const CatalogReceipt({super.key});

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<ProductProvider?>();
    final received = DateTime.tryParse(provider?.cachedAt ?? '')?.toLocal();
    if (received == null) return const SizedBox.shrink();
    final time =
        '${received.hour.toString().padLeft(2, '0')}:${received.minute.toString().padLeft(2, '0')}';
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '데이터 수신 ${formatCompactDate(received)} $time · 가격 확인일과 별개',
          style: const TextStyle(fontSize: 11, color: Color(0xFF657181)),
        ),
        if (provider!.usingCache)
          TextButton(
            onPressed: provider.isLoading ? null : provider.loadProducts,
            child: const Text('저장된 정보예요 · 연결 재시도'),
          ),
      ],
    );
  }
}
