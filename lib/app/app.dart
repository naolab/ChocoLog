import 'package:chocolog/app/router.dart';
import 'package:chocolog/app/theme.dart';
import 'package:flutter/material.dart';

class ChocoLogApp extends StatelessWidget {
  const ChocoLogApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      title: 'ChocoLog',
      debugShowCheckedModeBanner: false,
      theme: ChocoLogTheme.light,
      routerConfig: appRouter,
    );
  }
}
