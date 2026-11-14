import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'gateway/gateway_page.dart';
import 'theme/palette.dart';

void main() {
  runApp(const MediSyncApp());
}

class MediSyncApp extends StatelessWidget {
  const MediSyncApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<Locale>(
      valueListenable: GatewayPage.localeNotifier,
      builder: (context, locale, _) {
        return MaterialApp(
          title: 'MediSync',
          debugShowCheckedModeBanner: false,
          locale: locale,
          supportedLocales: const [
            Locale('en'),
            Locale('tl'),
          ],
          localizationsDelegates: GlobalMaterialLocalizations.delegates,
          theme: ThemeData(
            useMaterial3: true,
            scaffoldBackgroundColor: Palette.brightSnow,
            colorScheme: ColorScheme.fromSeed(
              seedColor: Palette.darkCyan,
              primary: Palette.darkCyan,
              secondary: Palette.prussianBlue,
              surface: Palette.brightSnow,
              error: Palette.scarletFire,
            ),
          ),
          home: const GatewayPage(),
        );
      },
    );
  }
}
