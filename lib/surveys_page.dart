import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';

class SurveysPage extends StatefulWidget {
  final String title;
  final String url;

  const SurveysPage({
    super.key,
    required this.title,
    required this.url,
  });

  @override
  State<SurveysPage> createState() => _SurveysPageState();
}

class _SurveysPageState extends State<SurveysPage> {
  late final WebViewController controller;

  bool isLoading = true;

  @override
  void initState() {
    super.initState();

    controller = WebViewController()

    // تفعيل JavaScript
      ..setJavaScriptMode(JavaScriptMode.unrestricted)

    // خلفية شفافة
      ..setBackgroundColor(const Color(0x00000000))

    // السماح بالتنقل داخل الصفحة
      ..setNavigationDelegate(
        NavigationDelegate(

          onPageStarted: (url) {
            setState(() {
              isLoading = true;
            });
          },

          onPageFinished: (url) {
            setState(() {
              isLoading = false;
            });
          },

          onWebResourceError: (error) {
            debugPrint(error.description);
          },
        ),
      )

    // تحميل الرابط
      ..loadRequest(
        Uri.parse(widget.url),
      );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF020817),

      appBar: AppBar(
        backgroundColor: const Color(0xFF020817),
        elevation: 0,
        centerTitle: true,

        title: Text(
          widget.title,
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),

      body: Stack(
        children: [
          WebViewWidget(
            controller: controller,
          ),

          if (isLoading)
            const Center(
              child: CircularProgressIndicator(),
            ),
        ],
      ),
    );
  }
}