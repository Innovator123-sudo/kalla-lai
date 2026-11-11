import 'dart:js_interop';

import 'package:web/web.dart' as web;

const List<String> _gestureEvents = <String>[
  'pointerup',
  'touchend',
  'click',
  'keydown',
];

/// Runs [callback] inside every browser event that counts as a user gesture,
/// which is the only moment a browser lets a page switch sound on. Returns a
/// function that stops listening.
void Function() onUserGesture(void Function() callback) {
  final listener = ((web.Event _) => callback()).toJS;
  for (final type in _gestureEvents) {
    web.document.addEventListener(type, listener, true.toJS);
  }
  return () {
    for (final type in _gestureEvents) {
      web.document.removeEventListener(type, listener, true.toJS);
    }
  };
}
