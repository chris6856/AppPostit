import 'dart:io';

import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Reads/writes the handful of keys the native keyboard extension also
/// reads or writes (is_premium, insert_count) -- the ones that must live
/// in whatever storage the extension can see.
///
/// Android: the keyboard (a same-UID, same-process-family native service)
/// reads/writes the app's own "FlutterSharedPreferences" file directly via
/// the standard Android SharedPreferences API, so this just wraps the
/// classic [SharedPreferences] plugin instance, using reload() to bypass
/// its in-memory cache when a native write may have happened since it was
/// last read (see main.dart's resume handler).
///
/// iOS: the keyboard extension runs as a genuinely separate process with
/// its own sandbox, so sharing requires an explicit App Group container.
/// There's no well-documented way to point the shared_preferences plugin
/// at an App-Group-scoped UserDefaults suite, so this goes through a
/// small native channel (AppGroupPlugin.swift) that reads/writes
/// `UserDefaults(suiteName: "group.com.apppostit.apppostit")` directly --
/// the same suite the keyboard extension's Swift code reads/writes.
class SharedStorage {
  SharedStorage(this._prefs);

  final SharedPreferences _prefs;

  static const MethodChannel _iosChannel = MethodChannel(
    'com.apppostit.apppostit/shared_storage',
  );

  Future<bool?> getBool(String key) async {
    if (Platform.isIOS) {
      return _iosChannel.invokeMethod<bool>('getBool', {'key': key});
    }
    await _prefs.reload();
    return _prefs.getBool(key);
  }

  Future<void> setBool(String key, bool value) async {
    if (Platform.isIOS) {
      await _iosChannel.invokeMethod<void>('setBool', {
        'key': key,
        'value': value,
      });
      return;
    }
    await _prefs.setBool(key, value);
  }

  Future<int?> getInt(String key) async {
    if (Platform.isIOS) {
      return _iosChannel.invokeMethod<int>('getInt', {'key': key});
    }
    await _prefs.reload();
    return _prefs.getInt(key);
  }
}
