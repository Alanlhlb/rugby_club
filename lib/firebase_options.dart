import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;
import 'package:flutter/foundation.dart'
    show defaultTargetPlatform, kIsWeb, TargetPlatform;

class DefaultFirebaseOptions {
  static FirebaseOptions get currentPlatform {
    if (kIsWeb) {
      return web;
    }
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return android;
      case TargetPlatform.iOS:
        return ios;
      case TargetPlatform.macOS:
        throw UnsupportedError(
          'DefaultFirebaseOptions have not been configured for macos - '
          'you can reconfigure this by running the FlutterFire CLI again.',
        );
      case TargetPlatform.windows:
        throw UnsupportedError(
          'DefaultFirebaseOptions have not been configured for windows - '
          'you can reconfigure this by running the FlutterFire CLI again.',
        );
      case TargetPlatform.linux:
        throw UnsupportedError(
          'DefaultFirebaseOptions have not been configured for linux - '
          'you can reconfigure this by running the FlutterFire CLI again.',
        );
      default:
        throw UnsupportedError(
          'DefaultFirebaseOptions are not supported for this platform.',
        );
    }
  }

  static const FirebaseOptions web = FirebaseOptions(
    apiKey: 'AIzaSyC_iM4i7Kjmsr_aPQ_9DSrbIte26GMAzjA',
    appId: '1:719427061450:web:a378cd6ac7e662c8291633',
    messagingSenderId: '719427061450',
    projectId: 'rugby-club-app-bcef7',
    authDomain: 'rugby-club-app-bcef7.firebaseapp.com',
    storageBucket: 'rugby-club-app-bcef7.firebasestorage.app',
    measurementId: 'G-8LDKFYDGX3',
  );

  static const FirebaseOptions android = FirebaseOptions(
    apiKey: 'AIzaSyATwA2LnJ0Ej6KF6sGDpOpuHPUP1hjKh4M',
    appId: '1:719427061450:android:3b5373e93a713a07291633',
    messagingSenderId: '719427061450',
    projectId: 'rugby-club-app-bcef7',
    authDomain: 'rugby-club-app-bcef7.firebaseapp.com',
    storageBucket: 'rugby-club-app-bcef7.firebasestorage.app',
  );

  static const FirebaseOptions ios = FirebaseOptions(
    apiKey: 'AIzaSyCJ_uwQGUi5mNFVp0S0tGZeLRjnqNDKc6c',
    appId: '1:719427061450:ios:a00251d053cfedac291633',
    messagingSenderId: '719427061450',
    projectId: 'rugby-club-app-bcef7',
    authDomain: 'rugby-club-app-bcef7.firebaseapp.com',
    storageBucket: 'rugby-club-app-bcef7.firebasestorage.app',
    iosBundleId: 'com.rugbyclub.rugbyClub',
  );
}
