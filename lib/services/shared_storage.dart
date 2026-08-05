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
/// This goes through a small native channel (AppGroupPlugin.swift) backed
/// by a plain JSON file in that container (SharedState.swift) -- plugin
/// registration issues and UserDefaults' cross-process caching behavior
/// were both tried and ruled out as reliable options first.
class SharedStorage {
  SharedStorage(this._prefs);

  final SharedPreferences _prefs;

  static const MethodChannel _iosChannel = MethodChannel(
    'com.apppostit.apppostit/shared_storage',
  );

  Future<bool?> getBool(String key) async {
    if (Platform.isIOS) {
      try {
        return await _iosChannel.invokeMethod<bool>('getBool', {'key': key});
      } catch (_) {
        return null;
      }
    }
    await _prefs.reload();
    return _prefs.getBool(key);
  }

  Future<void> setBool(String key, bool value) async {
    if (Platform.isIOS) {
      try {
        await _iosChannel.invokeMethod<void>('setBool', {
          'key': key,
          'value': value,
        });
      } catch (_) {
        // Nothing more to do -- the paywall/purchase-restore flow is the
        // only caller and it has no separate UI feedback path to wire up.
      }
      return;
    }
    await _prefs.setBool(key, value);
  }

  Future<int?> getInt(String key) async {
    if (Platform.isIOS) {
      try {
        return await _iosChannel.invokeMethod<int>('getInt', {'key': key});
      } catch (_) {
        return null;
      }
    }
    await _prefs.reload();
    return _prefs.getInt(key);
  }
}
