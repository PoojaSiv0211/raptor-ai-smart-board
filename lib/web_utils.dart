import 'package:flutter/foundation.dart';

// Web-specific utilities
void openUrlInNewTab(String url) {
  if (kIsWeb) {
    // This will only work on web
    // ignore: avoid_web_libraries_in_flutter
    // dart:html is only available on web
    try {
      // Use JS interop to open URL
      // This is a safer approach than importing dart:html
      // ignore: undefined_prefixed_name
      // html.window.open(url, '_blank');
      
      // Alternative: Use url_launcher which handles web properly
      // For now, we'll show a message
      print('Would open URL in new tab: $url');
    } catch (e) {
      print('Error opening URL: $e');
    }
  }
}