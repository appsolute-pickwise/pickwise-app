import 'package:flutter/material.dart';

class ResultScreen extends StatefulWidget {
  const ResultScreen({super.key});

  @override
  State<ResultScreen> createState() => _ResultScreenState();
}

class _ResultScreenState extends State<ResultScreen> {
  bool isAddedToCompare = false;

  static const Color green = Color(0xff477966);
  static const Color paleGreen = Color(0xffe5f0e9);
  static const Color borderColor = Color(0xffe1e8e3);
  static const Color textColor = Color(0xff252c28);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: const BackButton(color: Color(0xff858c88)),
        titleSpacing: 0,
        title: const Text(
          '맞춤 추천',
          style: TextStyle(
            color: textColor,
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
      body: SafeArea(
        top: false,
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(22, 18, 22, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                '선택한 조건에 가까운 제품',
                style: TextStyle(
                  color: textColor,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 12),
              const Text(
                '선택한 기준에 따라 순위가 달라져요.',
                style: TextStyle(
                  color: Color(0xff858d88),
                  fontSize: 12,
                ),
              ),
              const SizedBox(height: 30),

              // 추천 제품 카드
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.white,
                  border: Border.all(color: borderColor),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 26,
                        vertical: 5,
                      ),
                      decoration: BoxDecoration(
                        color: paleGreen,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: const Text(
                        '먼저 살펴볼 제품',
                        style: TextStyle(
                          color: green,
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    const SizedBox(height: 9),
                    Row(
                      children: [
                        const _EmptyProductImage(width: 118, height: 104),
                        const SizedBox(width: 12),
                        const Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Anker',
                                style: TextStyle(
                                  color: Color(0xff68736d),
                                  fontSize: 12,
                                ),
                              ),
                              SizedBox(height: 4),
                              Text(
                                'Soundcore P40i',
                                style: TextStyle(
                                  color: textColor,
                                  fontSize: 15,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              SizedBox(height: 8),
                              Text(
                                '51,900원',
                                style: TextStyle(
                                  color: green,
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    const Divider(height: 1, color: borderColor),
                    const SizedBox(height: 9),
                    const _Reason(
                      text: '긴 배터리 시간으로 외출할 때 편하게 쓸 수 있어요.',
                    ),
                    const SizedBox(height: 5),
                    const _Reason(
                      text: '무게와 방수 등급을 함께 비교했어요.',
                    ),
                    const SizedBox(height: 10),
                    SizedBox(
                      width: double.infinity,
                      height: 38,
                      child: OutlinedButton(
                        onPressed: () {
                          setState(() {
                            isAddedToCompare = !isAddedToCompare;
                          });
                        },
                        style: OutlinedButton.styleFrom(
                          backgroundColor: paleGreen,
                          foregroundColor: green,
                          side: const BorderSide(
                            color: Color(0xffb8d2c4),
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                        child: Text(
                          isAddedToCompare ? '✓ 비교에 담았어요' : '+ 비교에 담기',
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 16),
              const Text(
                '함께 비교해 볼 제품',
                style: TextStyle(
                  color: textColor,
                  fontSize: 15,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 9),

              // 비교할 제품 카드
              Row(
                children: const [
                  Expanded(
                    child: _CompareProductCard(
                      name: 'Galaxy Buds3',
                      price: '166,780원',
                    ),
                  ),
                  SizedBox(width: 10),
                  Expanded(
                    child: _CompareProductCard(
                      name: 'Redmi Buds 6',
                      price: '49,990원',
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
      bottomNavigationBar: SafeArea(
        top: false,
        child: SizedBox(
          height: 58,
          child: Row(
            children: const [
              Expanded(
                child: _BottomItem(
                  icon: Icons.home_outlined,
                  label: '홈',
                  selected: true,
                ),
              ),
              Expanded(
                child: _BottomItem(
                  icon: Icons.search,
                  label: '탐색',
                ),
              ),
              Expanded(
                child: _BottomItem(
                  icon: Icons.view_column_outlined,
                  label: '비교',
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Reason extends StatelessWidget {
  const _Reason({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        const Icon(
          Icons.check,
          color: Color(0xff65a58b),
          size: 16,
        ),
        const SizedBox(width: 6),
        Expanded(
          child: Text(
            text,
            style: const TextStyle(
              color: Color(0xff5e6963),
              fontSize: 11,
            ),
          ),
        ),
      ],
    );
  }
}

class _CompareProductCard extends StatelessWidget {
  const _CompareProductCard({
    required this.name,
    required this.price,
  });

  final String name;
  final String price;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        border: Border.all(color: const Color(0xffe1e8e3)),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _EmptyProductImage(width: double.infinity, height: 70),
          const SizedBox(height: 6),
          Text(
            name,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: Color(0xff252c28),
              fontSize: 11,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 5),
          Text(
            price,
            style: const TextStyle(
              color: Color(0xff477966),
              fontSize: 12,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }
}

// 실제 제품 이미지를 넣기 전까지 비워두는 영역
class _EmptyProductImage extends StatelessWidget {
  const _EmptyProductImage({
    required this.width,
    required this.height,
  });

  final double width;
  final double height;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: const Color(0xfff4f3f1),
        borderRadius: BorderRadius.circular(14),
      ),
    );
  }
}

class _BottomItem extends StatelessWidget {
  const _BottomItem({
    required this.icon,
    required this.label,
    this.selected = false,
  });

  final IconData icon;
  final String label;
  final bool selected;

  @override
  Widget build(BuildContext context) {
    final color = selected
        ? const Color(0xff477966)
        : const Color(0xff7b8580);

    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(icon, color: color, size: 20),
        const SizedBox(height: 2),
        Text(
          label,
          style: TextStyle(color: color, fontSize: 10),
        ),
      ],
    );
  }
}