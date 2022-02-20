import 'package:flutter/material.dart';
import 'package:termare_view/termare_view.dart';

void main() => runApp(const MyApp());

class MyApp extends StatelessWidget {
  const MyApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Flutter Demo',
      theme: ThemeData(
        primarySwatch: Colors.blue,
      ),
      home: const HomePageMod(),
    );
  }
}

class HomePageMod extends StatefulWidget {
  const HomePageMod({Key? key}) : super(key: key);

  @override
  _HomePageModState createState() => _HomePageModState();
}

class _HomePageModState extends State<HomePageMod> {
TermareController termareController = TermareController(
  showBackgroundLine: true,
);

@override
Widget build(BuildContext context) {
  return RawKeyboardListener(
    focusNode: FocusNode(),
    autofocus: true,
    onKey: (key) {
      print('->$key');
    },
    child: Visibility(
      visible: true,
      child: SafeArea(
        child: Stack(
          children: [
            TermareView(
              keyboardInput: (value) {
                print('code value of keyboardInput is: ${value.codeUnits}');
                termareController.enableAutoScroll();
                termareController.write(value);
              },
              controller: termareController,
            ),
          ],
        ),
      ),
    ),
  );
}
}
