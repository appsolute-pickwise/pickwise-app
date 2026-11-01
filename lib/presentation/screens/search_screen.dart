import 'package:flutter/material.dart';
import 'package:pickwise/presentation/providers/temp_product_provider.dart';
import 'package:provider/provider.dart';


class SearchScreen extends StatefulWidget {
  const SearchScreen({super.key});

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  List<String> filter = ['전체','통학','운동','업무','노캔'];
  // 상품 전체데이터 json파일에 필터태그 추가시 필터기능 적용 (현재 태그가 없어 필터기능 적용x)
  String selectedFilter = '전체';
  String searchQuery = '';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        title: Text('이어폰 둘러보기',style: TextStyle(color: Colors.black,fontSize: 20,fontWeight: .bold),),
      ),
      body: Consumer<ProductProvider>(
          builder: (context,provider,_) {
            if (provider.isLoading) {
              return const Center(child: CircularProgressIndicator());
            }
            if (provider.hasLoadError) {
              return Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(provider.loadErrorMessage),
                    const SizedBox(height: 12),
                    ElevatedButton(
                      onPressed: provider.loadProducts,
                      child: const Text('다시 불러오기'),
                    ),
                  ],
                ),
              );
            }

            final products = provider.products.where((product) {
              return product.name.toLowerCase().contains(searchQuery.toLowerCase()) ||
                  product.brand.toLowerCase().contains(searchQuery.toLowerCase());
            }).toList();

            return Padding(
              padding: .symmetric(horizontal: 20,vertical: 20),
              child: SafeArea(
                child: Column(
                  crossAxisAlignment: .start,
                  children: [
                    Container(
                      width: .infinity,
                      padding: .symmetric(vertical: 2),
                      decoration: BoxDecoration(
                          color: Colors.transparent,
                          borderRadius: .circular(15),
                          border: .all(color: Colors.black.withOpacity(0.2))
                      ),
                      child: TextField(
                        onChanged: (value){
                          setState(() {
                            searchQuery = value;
                          });
                        },
                        decoration: InputDecoration(
                            border: .none,
                            hintText: '무선 이어폰, 브랜드 검색',
                            hintStyle: TextStyle(color: Colors.black.withOpacity(0.6),fontSize: 15),
                            prefixIcon: Icon(Icons.search,color: Colors.black.withOpacity(0.6),)
                        ),
                        textAlignVertical: .center,
                        textAlign: .start,
                      ),
                    ),
                    SizedBox(height: 15,),
                    SizedBox(
                      width: .infinity,
                      height: 35,
                      child: ListView.separated(
                        scrollDirection: .horizontal,
                          itemBuilder: (context,index) {
                            return GestureDetector(
                              onTap: (){
                                setState(() {
                                  selectedFilter = filter[index];
                                  // 아직 json파일에 필터태그 존재 x -> 추가시 변경
                                });
                              },
                              child: Container(
                                width: 70,
                                decoration: BoxDecoration(
                                  color: selectedFilter == filter[index] ? Color(0xffE5F0E9) :Colors.transparent,
                                  borderRadius: .circular(13),
                                  border: .all(color: selectedFilter == filter[index] ? Color(0xff477966) : Colors.black.withOpacity(0.2))
                                ),
                                child: Center(child: Text(filter[index],style: TextStyle(color: selectedFilter == filter[index] ? Color(0xff477966) :Colors.black,fontSize: 14),)),
                              ),
                            );
                          },
                          separatorBuilder: (context,index) => SizedBox(width: 5,),
                          itemCount: filter.length,
                      ),
                    ),
                    SizedBox(height: 20,),
                    Text('20~30개 이어폰 후보',style: TextStyle(color: Colors.black,fontWeight: .bold,fontSize: 20),),
                    Expanded(
                      child: products.isEmpty ? Center(child: Text('찾는 상품이 없습니다.'),) :ListView.builder(
                        itemCount: products.length, // 상품 전체데이터로 이후에 변경
                          itemBuilder: (context,index) {
                            final product = products[index];

                            return Container(
                              width: .infinity,
                              height: 150,
                              padding: .symmetric(horizontal: 15,vertical: 15),
                              margin: .symmetric(vertical: 10),
                              decoration: BoxDecoration(
                                color: Colors.transparent,
                                borderRadius: .circular(13),
                                border: .all(color: Colors.black.withOpacity(0.2)),
                              ),
                              child: Row(
                                mainAxisAlignment: .start,
                                children: [
                                  Container(
                                    width: 100,
                                      height: .infinity,
                                    decoration: BoxDecoration(
                                      borderRadius: .circular(10),
                                      image: DecorationImage(image: AssetImage(product.imageAsset!),fit: .contain)
                                    ),
                                  ),
                                  SizedBox(width: 15,),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: .start,
                                      children: [
                                        Text(product.brand,style: TextStyle(color: Colors.black.withOpacity(0.6),fontSize: 15,fontWeight: .bold),),
                                        Text(product.name,style: TextStyle(color: Colors.black,fontSize: 18,fontWeight: .bold,height: 2),),
                                        Text('${product.price.toString().replaceAllMapped(RegExp(r'\B(?=(\d{3})+(?!\d))'), (match) => ',',)}원',style: TextStyle(color: Color(0xff477966),fontWeight: .bold,fontSize: 17),),
                                        Align(
                                          alignment: .bottomRight,
                                          child: Container(
                                            width: 130,
                                            padding: .symmetric(horizontal: 20,vertical: 7),
                                            decoration: BoxDecoration(
                                              color: Color(0xffE5F0E9),
                                              borderRadius: .circular(10),
                                            ),
                                            child: TextButton(
                                              style: TextButton.styleFrom(padding: .zero,minimumSize: Size.zero,tapTargetSize: MaterialTapTargetSize.shrinkWrap,),
                                                onPressed: (){},
                                                child: Row(
                                                  mainAxisAlignment: .center,
                                                  children: [
                                                    Icon(Icons.add,color: Color(0xff477966),size: 20,),
                                                    Text('비교에 담기',style: TextStyle(color: Color(0xff477966),fontWeight: .bold,fontSize: 14),),
                                                    // 제품비교 페이지와 연동시 비교할 제품에 추가
                                                  ],
                                                )
                                            ),
                                          ),
                                        )
                                      ],
                                    ),
                                  )
                                ],
                              ),
                            );
                          }
                      ),
                    )
                  ],
                ),
              ),
            );
          }
      ),
    );
  }
}
