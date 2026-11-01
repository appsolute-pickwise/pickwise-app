import 'package:flutter/material.dart';
import 'package:pickwise/presentation/providers/temp_product_provider.dart';
import 'package:pickwise/presentation/screens/search_screen.dart';
import 'package:provider/provider.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
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

            final products = provider.products;
            if (products.isEmpty) {
              return const Center(child: Text('비교할 제품이 없습니다.'));
            }

            return Padding(
              padding: .symmetric(horizontal: 5),
              child: SafeArea(
                child: Column(
                  crossAxisAlignment: .start,
                  children: [
                    Image.asset('assets/images/logo/pickwiselogo.png',width: 300,),
                    SizedBox(height: 20,),
                    Padding(
                      padding: .symmetric(horizontal: 20),
                      child: Column(
                        crossAxisAlignment: .start,
                        children: [
                          Text('내게 맞는\n선택을쉽게.',style: TextStyle(color: Colors.black,fontSize: 30,fontWeight: .bold,height: 1),),
                          Text('필요한 사양만 골라 제품을 비교해요.',style: TextStyle(color: Colors.black.withOpacity(0.6),fontSize: 13,height: 3.5),),
                          Container(
                            width: .infinity,
                            padding: .symmetric(vertical: 2),
                            decoration: BoxDecoration(
                              color: Colors.transparent,
                              borderRadius: .circular(15),
                              border: .all(color: Colors.black.withOpacity(0.2))
                            ),
                            child: TextField(
                              onTap: (){
                                Navigator.push(context, MaterialPageRoute(builder: (context) => SearchScreen()));
                              },
                              readOnly: true,
                              decoration: InputDecoration(
                                border: .none,
                                hintText: '모델명이나 브랜드를 검색해요',
                                hintStyle: TextStyle(color: Colors.black.withOpacity(0.6),fontSize: 15),
                                prefixIcon: Icon(Icons.search,color: Colors.black.withOpacity(0.6),)
                              ),
                              textAlignVertical: .center,
                              textAlign: .start,
                            ),
                          ),
                          Container(
                            width: .infinity,
                            padding: .symmetric(horizontal: 25,vertical: 15),
                            margin: .symmetric(vertical: 30),
                            decoration: BoxDecoration(
                              color: Color(0xffE5F0E9),
                              borderRadius: .circular(15)
                            ),
                            child: Column(
                              crossAxisAlignment: .start,
                              children: [
                                Text('내 기준으로 비교 시작',style: TextStyle(color: Colors.black,fontSize: 17,fontWeight: .bold),),
                                SizedBox(height: 20,),
                                Text('배터리, 무게, ANC, 방수 중 중요한 것부터.',style: TextStyle(color: Colors.black.withOpacity(0.6),fontSize: 13,),),
                                SizedBox(height: 20,),
                                TextButton(
                                    onPressed: (){
                                      // 쇼핑 취향 설정 화면 완성시 연결
                                    },
                                    child: Row(
                                      mainAxisAlignment: .start,
                                      children: [
                                        Text('기준 선택하기',style: TextStyle(color: Color(0xff477966),fontWeight: .bold),),
                                        Icon(Icons.arrow_right_alt,color: Color(0xff477966),)
                                    ],
                                  ),
                                  style: TextButton.styleFrom(
                                    padding: .zero,
                                    minimumSize: Size.zero,
                                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                  ),
                                )
                              ],
                            ),
                          ),
                          Text('제품부터 둘러보기',style: TextStyle(color: Colors.black,fontWeight: .bold,fontSize: 20),),
                          SizedBox(height: 20,),
                          SizedBox(
                            width: .infinity,
                            height: 200,
                            child: ListView.separated(
                              itemCount: products.length,
                                scrollDirection: .horizontal,
                                separatorBuilder: (context,index) => SizedBox(width: 15,),
                                itemBuilder: (context,index) {
                                  final product = products[index];

                                  return GestureDetector(
                                    onTap: (){
                                      // main 병합 후 제품 상세화면과 연결
                                    },
                                    child: Container(
                                      width: 210,
                                      height: .infinity,
                                      padding: .symmetric(horizontal: 10,vertical: 13),
                                      decoration: BoxDecoration(
                                        color: Colors.transparent,
                                        borderRadius: .circular(15),
                                        border: .all(color: Colors.black.withOpacity(0.2))
                                      ),
                                      child: Column(
                                        crossAxisAlignment: .start,
                                        children: [
                                          Container(
                                            width: .infinity,
                                            height: 100,
                                            decoration: BoxDecoration(
                                              borderRadius: .circular(15),
                                              image: DecorationImage(image: AssetImage(product.imageAsset!),fit: .fill)
                                            ),
                                          ),
                                          SizedBox(height: 10,),
                                          Text(product.name,style: TextStyle(color: Colors.black,fontSize: 15,fontWeight: .bold),),
                                          SizedBox(height: 10,),
                                          Text('${product.price.toString().replaceAllMapped(RegExp(r'\B(?=(\d{3})+(?!\d))'), (match) => ',',)}원',style: TextStyle(color: Color(0xff477966),fontWeight: .bold,fontSize: 17),)
                                        ],
                                      ),
                                    ),
                                  );
                                }
                            )
                          )
                        ],
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
