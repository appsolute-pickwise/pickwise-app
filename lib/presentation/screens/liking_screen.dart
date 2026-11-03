import 'package:flutter/material.dart';

import '../../data/models/product_preferences.dart';
import 'result_screen.dart';

class LikingScreen extends StatefulWidget {
  const LikingScreen({super.key});

  @override
  State<LikingScreen> createState() => _LikingScreenState();
}

class _LikingScreenState extends State<LikingScreen> {
  final List<String> tag = ['배터리', '무게', 'ANC', '방수'];
  final List<String> wearTags = ['커널형', '세미오픈형', '오픈이어형', '귀걸이형'];
  final List<String> budget = ['5만원 미만', '5만~15만원', '15만원 초과'];
  final List<String> selectTag = [];
  final List<String> selectBudget = [];
  final List<String> selectWear = [];

  static const Color green = Color(0xff477966);
  static const Color selectedBackground = Color(0xffE5F0E9);

  Widget _choice(String label, List<String> selection, {bool roomy = false}) {
    final selected = selection.contains(label);
    return InkWell(
      borderRadius: BorderRadius.circular(15),
      onTap: () => setState(() {
        if (selected) {
          selection.remove(label);
        } else {
          if (!identical(selection, selectTag)) selection.clear();
          selection.add(label);
        }
      }),
      child: Container(
        alignment: roomy ? Alignment.center : null,
        padding: EdgeInsets.symmetric(
          horizontal: roomy ? 17 : 10,
          vertical: roomy ? 10 : 7,
        ),
        decoration: BoxDecoration(
          color: selected ? selectedBackground : Colors.white,
          border: Border.all(
            color: selected ? const Color(0xff9fc2b2) : const Color(0xffe1e7e2),
          ),
          borderRadius: BorderRadius.circular(15),
        ),
        child: Text(
          '${selected ? '✓ ' : ''}$label',
          maxLines: 1,
          style: TextStyle(
            color: selected ? green : const Color(0xff202623),
            fontSize: roomy ? 16 : 13,
            fontWeight: selected ? FontWeight.w600 : FontWeight.normal,
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: const BackButton(color: Color(0xff818985)),
        titleSpacing: 0,
        title: const Text(
          '내 기준 고르기',
          style: TextStyle(
            color: Color(0xff202623),
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
      body: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        '어떤 조건이 가장\n중요한가요?',
                        style: TextStyle(
                          color: Color(0xff202623),
                          fontWeight: FontWeight.bold,
                          fontSize: 27,
                        ),
                      ),
                      const SizedBox(height: 30),
                      const Text(
                        '무엇을 우선해서 볼까요?',
                        style: TextStyle(
                          color: Color(0xff202623),
                          fontWeight: FontWeight.bold,
                          fontSize: 20,
                        ),
                      ),
                      const SizedBox(height: 20),
                      SizedBox(
                        height: 180,
                        child: GridView.builder(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          itemCount: tag.length,
                          gridDelegate:
                              const SliverGridDelegateWithFixedCrossAxisCount(
                                crossAxisCount: 2,
                                crossAxisSpacing: 20,
                                mainAxisSpacing: 15,
                                mainAxisExtent: 58,
                              ),
                          itemBuilder: (context, index) =>
                              _choice(tag[index], selectTag, roomy: true),
                        ),
                      ),
                      const Text(
                        '예산 범위',
                        style: TextStyle(
                          color: Color(0xff202623),
                          fontWeight: FontWeight.bold,
                          fontSize: 20,
                        ),
                      ),
                      const SizedBox(height: 10),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: budget
                            .map((label) => _choice(label, selectBudget))
                            .toList(),
                      ),
                      const SizedBox(height: 14),
                      const Text(
                        '착용 형태',
                        style: TextStyle(
                          color: Color(0xff202623),
                          fontWeight: FontWeight.bold,
                          fontSize: 20,
                        ),
                      ),
                      const SizedBox(height: 9),
                      Wrap(
                        spacing: 6,
                        runSpacing: 8,
                        children: wearTags
                            .map((label) => _choice(label, selectWear))
                            .toList(),
                      ),
                      const SizedBox(height: 14),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 13,
                          vertical: 12,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(0xfff2f5f2),
                          borderRadius: BorderRadius.circular(13),
                        ),
                        child: const Row(
                          children: [
                            Icon(
                              Icons.verified_user_outlined,
                              color: Color(0xff70a28c),
                              size: 19,
                            ),
                            SizedBox(width: 9),
                            Expanded(
                              child: Text(
                                '기준은 여러 개, 예산과 착용 형태는 하나씩 선택해요.\n비우면 제한 없이 추천해요.',
                                style: TextStyle(
                                  color: Color(0xff66716b),
                                  fontSize: 11,
                                  height: 1.4,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              SizedBox(
                width: double.infinity,
                height: 46,
                child: ElevatedButton(
                  onPressed: () => Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) => ResultScreen(
                        preferences: ProductPreferences(
                          priorities: List.unmodifiable(selectTag),
                          budget: selectBudget.firstOrNull,
                          wearType: selectWear.firstOrNull,
                        ),
                      ),
                    ),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xffdcebe3),
                    foregroundColor: const Color(0xff202623),
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(13),
                      side: const BorderSide(color: Color(0xffb7d0c3)),
                    ),
                  ),
                  child: const Text(
                    '추천 보기',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
      // 하단 메뉴를 숨긴 뒤에도 추천 버튼이 이전 위치에 머물도록 공간을 유지합니다.
      bottomNavigationBar: const SafeArea(
        top: false,
        child: SizedBox(height: 58),
      ),
    );
  }
}
