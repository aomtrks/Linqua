
import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:receive_sharing_intent/receive_sharing_intent.dart';
import 'word_capture_strategy.dart';

class ShareIntentCaptureStrategy implements WordCaptureStrategy {
  StreamSubscription<List<SharedMediaFile>>? _intentDataStreamSubscription;

  @override
  void initialize(Function(String) onWordCaptured) {
    // Uygulama arka plandayken veya açıksa gelen paylaşımları dinler
    _intentDataStreamSubscription =
        ReceiveSharingIntent.instance.getMediaStream().listen(
      (List<SharedMediaFile> value) {
        if (value.isNotEmpty) {
          final String sharedText = value.first.path;
          if (sharedText.isNotEmpty) {
            onWordCaptured(sharedText);
          }
          ReceiveSharingIntent.instance.reset();
        }
      },
      onError: (Object err) {
        debugPrint("Paylaşım yakalama hatası: $err");
      },
    );

    // Uygulama tamamen kapalıyken dışarıdan paylaşım yapılarak açılmasını yakalar
    ReceiveSharingIntent.instance
        .getInitialMedia()
        .then((List<SharedMediaFile> value) {
      if (value.isNotEmpty) {
        final String sharedText = value.first.path;
        if (sharedText.isNotEmpty) {
          onWordCaptured(sharedText);
        }
        ReceiveSharingIntent.instance.reset();
      }
    });
  }

  @override
  void dispose() {
    _intentDataStreamSubscription?.cancel();
  }
}