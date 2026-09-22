import 'browser_navigation_stub.dart'
    if (dart.library.js_interop) 'browser_navigation_web.dart';

/// Navega a aba atual para uma URL externa quando o app está rodando na Web.
void navigateBrowserTo(Uri uri) => navigateBrowserToImplementation(uri);
