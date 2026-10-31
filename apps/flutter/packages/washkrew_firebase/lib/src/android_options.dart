// Public Firebase Android app identifiers from wheelio-apps, never merchant secrets.
import 'package:firebase_core/firebase_core.dart';

FirebaseOptions androidOptions({required bool captain}) =>
    captain ? captainAndroid : customerAndroid;

const customerAndroid = FirebaseOptions(
  apiKey: 'AIzaSyDD0u37N_kYE-mD4rbE64zBY89iMImu0-U',
  appId: '1:763324255731:android:d0687e4e12291913ef9686',
  messagingSenderId: '763324255731',
  projectId: 'wheelio-apps',
  storageBucket: 'wheelio-apps.firebasestorage.app',
);

const captainAndroid = FirebaseOptions(
  apiKey: 'AIzaSyDD0u37N_kYE-mD4rbE64zBY89iMImu0-U',
  appId: '1:763324255731:android:3370a35ef9bb652bef9686',
  messagingSenderId: '763324255731',
  projectId: 'wheelio-apps',
  storageBucket: 'wheelio-apps.firebasestorage.app',
);
