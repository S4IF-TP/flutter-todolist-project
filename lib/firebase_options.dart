// File generated by FlutterFire CLI.
// ignore_for_file: type=lint
import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;
import 'package:flutter/foundation.dart'
    show defaultTargetPlatform, kIsWeb, TargetPlatform;

/// Default [FirebaseOptions] for use with your Firebase apps.
///
/// Example:
/// ```dart
/// import 'firebase_options.dart';
/// // ...
/// await Firebase.initializeApp(
///   options: DefaultFirebaseOptions.currentPlatform,
/// );
/// ```
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
        return macos;
      case TargetPlatform.windows:
        return windows;
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
    apiKey: 'AIzaSyBY6SeSl4GPjq-pr5gGL4sejRFn0y4xtoE',
    appId: '1:175299177871:web:31ff3933310f0248ab6ffa',
    messagingSenderId: '175299177871',
    projectId: 'todolistapp-dc0f5',
    authDomain: 'todolistapp-dc0f5.firebaseapp.com',
    storageBucket: 'todolistapp-dc0f5.firebasestorage.app',
    measurementId: 'G-VR0M08FCRQ',
  );

  static const FirebaseOptions android = FirebaseOptions(
    apiKey: 'AIzaSyAuXX6FJ76cQY0r30OfQobL5xp5CJOc6y4',
    appId: '1:175299177871:android:354d27494f530f57ab6ffa',
    messagingSenderId: '175299177871',
    projectId: 'todolistapp-dc0f5',
    storageBucket: 'todolistapp-dc0f5.firebasestorage.app',
  );

  static const FirebaseOptions ios = FirebaseOptions(
    apiKey: 'AIzaSyAuMCzDMrenEYxfl2C0jaHOgcQ_KEzMjUQ',
    appId: '1:175299177871:ios:11dcb28240b988c6ab6ffa',
    messagingSenderId: '175299177871',
    projectId: 'todolistapp-dc0f5',
    storageBucket: 'todolistapp-dc0f5.firebasestorage.app',
    iosBundleId: 'com.example.todolistApp',
  );

  static const FirebaseOptions macos = FirebaseOptions(
    apiKey: 'AIzaSyAuMCzDMrenEYxfl2C0jaHOgcQ_KEzMjUQ',
    appId: '1:175299177871:ios:11dcb28240b988c6ab6ffa',
    messagingSenderId: '175299177871',
    projectId: 'todolistapp-dc0f5',
    storageBucket: 'todolistapp-dc0f5.firebasestorage.app',
    iosBundleId: 'com.example.todolistApp',
  );

  static const FirebaseOptions windows = FirebaseOptions(
    apiKey: 'AIzaSyBY6SeSl4GPjq-pr5gGL4sejRFn0y4xtoE',
    appId: '1:175299177871:web:42476075b8b9a72dab6ffa',
    messagingSenderId: '175299177871',
    projectId: 'todolistapp-dc0f5',
    authDomain: 'todolistapp-dc0f5.firebaseapp.com',
    storageBucket: 'todolistapp-dc0f5.firebasestorage.app',
    measurementId: 'G-7MVSF118Q3',
  );
}
