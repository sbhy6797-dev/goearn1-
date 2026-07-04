import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:firebase_auth/firebase_auth.dart';

class AoyCoPage extends StatefulWidget {
  const AoyCoPage({super.key});

  @override
  State<AoyCoPage> createState() => _AoyCoPageState();
}

class _AoyCoPageState extends State<AoyCoPage> {
  late final WebViewController controller;

  @override
  void initState() {
    super.initState();

    final userId = FirebaseAuth.instance.currentUser!.uid;

    final url =
        "https://aoyco.in/offerwall/QO85oCW4UBP5fcdiRuVjVElVK7Uulh6p/$userId";

    controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..loadRequest(Uri.parse(url));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("AoyCo Offers")),
      body: WebViewWidget(controller: controller),
    );
  }
}