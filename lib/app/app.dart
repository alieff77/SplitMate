import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:splitmate/app/routes/app_pages.dart';
import 'package:splitmate/app/routes/app_routes.dart';
import 'package:splitmate/controllers/auth_controller.dart';
import 'package:splitmate/core/constants/app_theme.dart';

class SplitMateApp extends StatelessWidget {
  const SplitMateApp({super.key});

  @override
  Widget build(BuildContext context) {
    return GetMaterialApp(
      title: 'SplitMate',
      theme: AppTheme.theme,
      debugShowCheckedModeBanner: false,
      initialRoute: AppRoutes.login,
      getPages: AppPages.pages,
      initialBinding: BindingsBuilder(() {
        Get.put(AuthController(), permanent: true);
      }),
    );
  }
}
