import 'package:web/web.dart' as web;

void navigateBrowserToImplementation(Uri uri) {
  web.window.location.assign(uri.toString());
}
