import 'package:web/web.dart' as web;

String? readRecovery(String key) => web.window.localStorage.getItem(key);
void writeRecovery(String value, {required String key}) =>
    web.window.localStorage.setItem(key, value);
bool demoVideoReady() =>
    web.window.localStorage.getItem('washkrew-studio-video-ready') == 'yes';
void clearDemoVideo() {
  web.window.localStorage.removeItem('washkrew-studio-video-ready');
  web.window.localStorage.removeItem('washkrew-studio-video-version');
}
