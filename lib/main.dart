import 'package:cryptocalc/app.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

void main() async {
 WidgetsFlutterBinding.ensureInitialized();

 await HiveInitializer.init();
 await configureDependencies();

 SystemChrome.setSystemUIOverlayStyle(
   const SystemUiOverlayStyle(
     statusBarColor: Colors.transparent,
     statusBarIconBrightness: Brightness.dark,
     systemNavigationBarColor: UIConstants.primaryColor,
     systemNavigationBarIconBrightness: Brightness.dark,
   ),
 );

 runApp(const CryptoCalcApp());
}