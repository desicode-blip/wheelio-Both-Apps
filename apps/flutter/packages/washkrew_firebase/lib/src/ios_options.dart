// Public Firebase application identifiers, downloaded from wheelio-apps.
// Native initialization is explicit; no service account or payment secrets belong here.
import 'package:firebase_core/firebase_core.dart';

FirebaseOptions iosOptions({required bool captain}) =>
    captain ? captainIos : customerIos;

const customerIos = FirebaseOptions(
  apiKey: 'AIzaSyBkXLGPh_VXV2Ug8oALmm1KnfOe8gfwPdI',
  appId: '1:763324255731:ios:e608aa639acba895ef9686',
  messagingSenderId: '763324255731',
  projectId: 'wheelio-apps',
  storageBucket: 'wheelio-apps.firebasestorage.app',
  iosBundleId: 'com.amanmaheshwari.wheelio.customer',
);

const captainIos = FirebaseOptions(
  apiKey: 'AIzaSyBkXLGPh_VXV2Ug8oALmm1KnfOe8gfwPdI',
  appId: '1:763324255731:ios:a3ecaa80486a8314ef9686',
  messagingSenderId: '763324255731',
  projectId: 'wheelio-apps',
  storageBucket: 'wheelio-apps.firebasestorage.app',
  iosBundleId: 'com.amanmaheshwari.wheelio.captain',
);
