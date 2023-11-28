import 'package:cart_stepper/cart_stepper.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:custom_radio_grouped_button/custom_radio_grouped_button.dart';
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter_application_kiosk/order_result.dart';
import 'package:sliding_up_panel/sliding_up_panel.dart';
import 'firebase_options.dart';
import 'package:intl/intl.dart';

var f = NumberFormat.currency(locale: "ko_KR", symbol: "￦");

var db = FirebaseFirestore.instance;

String categoryColletionName = "cafe-categroy";
String itemCollectionName = "cafe-item";

void main() async {
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  runApp(const MyApp());
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  @override
  Widget build(BuildContext context) {
    return const MaterialApp(
      debugShowCheckedModeBanner: false,
      home: Main(),
    );
  }
}

class Main extends StatefulWidget {
  const Main({
    super.key,
  });

  @override
  State<Main> createState() => _MainState();
}

// 진입점
class _MainState extends State<Main> {
  dynamic categoryList = const Text("category");
  dynamic itemList = const Text("items");

  // 패널 (장바구니) 컨트롤러
  PanelController panelController = PanelController();
  // 카테고리 기능 보기
  var orderList = [];
  dynamic orderListView = const Center(child: Text("아무것도 없음."));

  //장바구니 목록 보기
  void showOrderList() {
    setState(() {
      orderListView = ListView.separated(
        itemBuilder: (cotext, index) {
          var order = orderList[index];

          return ListTile(
            leading: IconButton(
              onPressed: () {
                orderList.removeAt(index);
                showOrderList();
              },
              icon: const Icon(Icons.close),
            ),
            title: Text("${order['orderItem']} X ${order['orderQty']}"),
            subtitle: Text(order['optionData']
                .toString()
                .replaceAll("{", "(")
                .replaceAll('}', ')')),
            trailing: Text(f.format(order['orderPrice'] * order['orderQty'])),
          );
        },
        separatorBuilder: (context, index) => const Divider(),
        itemCount: orderList.length,
      );
    });
  }

  Future<void> showCategoryList() async {
    categoryList = FutureBuilder(
      future: db.collection("cafe-category").get(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const CircularProgressIndicator();
        }

        var datas = snapshot.data!.docs;

        return CustomRadioButton(
          enableButtonWrap: true,
          wrapAlignment: WrapAlignment.start,
          defaultSelected: "allData",
          buttonLables: ["전체보기", for (var data in datas) data['categoryName']],
          buttonValues: ["allData", for (var data in datas) data.id],
          radioButtonValue: (p0) {
            // print(p0);
            getItems(p0);
          },
          selectedColor: Colors.amber,
          unSelectedColor: Colors.white,
        );
      },
    );
  }

  // 아이템 보기 기능

  Future<void> getItems(var p0) async {
    setState(() {
      itemList = FutureBuilder(
        future: p0 != "allData"
            ? db
                .collection(itemCollectionName)
                .where("categoryId", isEqualTo: p0)
                .get()
            : db.collection(itemCollectionName).get(),
        builder: (context, snapshot) {
          if (snapshot.hasData) {
            var items = snapshot.data!.docs;

            if (items.isEmpty) {
              return const Center(child: Text("Empty"));
            }

            List<Widget> lt = [];
            for (var item in items) {
              lt.add(
                GestureDetector(
                  onTap: () {
                    int price = item['itemPrice'];
                    int cnt = 1;
                    var optionData = {};
                    var orderData = {};

                    var options = item['options'];
                    List<Widget> data = [];

                    for (var option in options) {
                      var optionValue =
                          option['optionValue'].toString().split("\n");

                      optionData[option['optionName']] = optionValue[0];

                      data.add(
                        ListTile(
                          title: Text(option['optionName']),
                          subtitle: CustomRadioButton(
                            enableButtonWrap: true,
                            wrapAlignment: WrapAlignment.start,
                            buttonLables: optionValue,
                            buttonValues: optionValue,
                            defaultSelected: optionValue[0],
                            radioButtonValue: (p0) {
                              optionData[option['optionName']] = p0;
                              print(optionData);
                            },
                            selectedColor: Colors.amber,
                            unSelectedColor: Colors.white,
                          ),
                        ),
                      );
                    }

                    showDialog(
                      context: context,
                      builder: (context) => StatefulBuilder(
                        builder: (context, st) {
                          return AlertDialog(
                            title: ListTile(
                              title: Text(item['itemName']),
                              subtitle: Text(f.format(price)),
                              trailing: CartStepper(
                                stepper: 1,
                                value: cnt,
                                didChangeCount: (value) {
                                  if (value > 0) {
                                    st(() {
                                      cnt = value;
                                      price = item['itemPrice'] * cnt;
                                    });
                                  }
                                },
                              ),
                            ),
                            content: Column(
                              children: data,
                            ),
                            actions: [
                              TextButton(
                                onPressed: () {
                                  Navigator.pop(context);
                                },
                                child: const Text("취소"),
                              ),
                              TextButton(
                                onPressed: () {
                                  orderData['orderItem'] = item['itemName'];
                                  orderData['orderQty'] = cnt;
                                  orderData['optionData'] = optionData;
                                  orderData['orderPrice'] = item['itemPrice'];
                                  orderList.add(orderData);
                                  showOrderList();
                                  Navigator.pop(context);
                                },
                                child: const Text("담기"),
                              ),
                            ],
                          );
                        },
                      ),
                    );
                  },
                  child: Container(
                    width: 150,
                    height: 150,
                    margin: const EdgeInsets.all(5),
                    decoration: BoxDecoration(
                      border: Border.all(width: 1, color: Colors.blue),
                      color: const Color.fromARGB(255, 255, 255, 255),
                      borderRadius: BorderRadius.circular(5),
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.spaceAround,
                      children: [
                        Text(item['itemName']),
                        Text(f.format(item['itemPrice'])),
                      ],
                    ),
                  ),
                ),
              );
            }
            return Wrap(
              children: lt,
            );
          }

          return const Center(child: CircularProgressIndicator());
        },
      );
    });
  }

  @override
  void initState() {
    // TODO: implement initState
    super.initState();
    showCategoryList();
    getItems("allData");
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          "Cafe",
        ),
        centerTitle: true,
        actions: [
          Transform.translate(
            offset: const Offset(-10, 8),
            child: Badge(
              label: Text(orderList.length.toString()),
              child: IconButton(
                onPressed: () {
                  if (panelController.isPanelOpen) {
                    panelController.close();
                  } else {
                    panelController.open();
                  }
                },
                icon: const Icon(Icons.shopping_cart),
              ),
            ),
          )
        ],
      ),
      body: SlidingUpPanel(
        controller: panelController,
        minHeight: 100,
        maxHeight: 600,
        panel: Container(
          color: Colors.white30,
          child: Column(
            children: [
              Container(
                width: double.infinity,
                decoration: const BoxDecoration(
                    color: Colors.blue,
                    borderRadius:
                        BorderRadius.vertical(top: Radius.circular(10))),
                height: 50,
                child: const Center(
                    child: Text(
                  "장바구니",
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                  ),
                )),
              ),
              Expanded(
                child: orderListView,
              ),
              ElevatedButton(
                onPressed: orderList.length == 0
                    ? null
                    : () async {
                        var controller = TextEditingController();
                        var result = await showDialog(
                          context: context,
                          builder: (context) => AlertDialog(
                            title: Text('결재하기'),
                            content: TextFormField(),
                            actions: [
                              TextButton(
                                  onPressed: () {
                                    Navigator.pop(context, null);
                                  },
                                  child: Text('취소')),
                              TextButton(
                                  onPressed: () {
                                    var orderResult = {
                                      'orders': orderList,
                                      'orderName': controller.text,
                                    };
                                    Navigator.pop(context, orderResult);
                                  },
                                  child: Text('결재')),
                            ],
                          ),
                        );
                        if (result != null) {
                          //결재가 완료되어서 다음페이지 주문번호 받기
                          Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => OrderResult(
                                  orderResult: result,
                                ),
                              ));
                        }
                      },
                child: Text('결재하기'),
              ),
            ],
          ),
        ),
        body: Column(
          children: [
            // 카테고리 목록
            categoryList,
            Expanded(child: itemList)
            // 아이템 목록
          ],
        ),
      ),
    );
  }
}
