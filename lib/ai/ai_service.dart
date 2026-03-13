import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:http/http.dart' as http;

/// Central AI service:
/// - streaming POST
/// - retry logic
/// - timeout handling
/// - cancel support
class AIService {
  AIService({
    required this.baseUrl,
    http.Client? client,
    Connectivity? connectivity,
  }) : _client = client ?? http.Client(),
       _connectivity = connectivity ?? Connectivity();

  final String baseUrl;
  http.Client _client; // ✅ not final anymore (we can recreate safely)
  final Connectivity _connectivity;

  StreamSubscription<String>? _streamSub;

  bool _cancelled = false;

  Future<bool> get isOffline async {
    final r = await _connectivity.checkConnectivity();
    return r == ConnectivityResult.none;
  }

  /// Cancel current streaming request (without permanently breaking future calls).
  Future<void> cancel() async {
    _cancelled = true;
    await _streamSub?.cancel();
    _streamSub = null;

    // ✅ recreate client so next request works reliably
    try {
      _client.close();
    } catch (_) {}
    _client = http.Client();
  }

  Future<void> postStream({
    required String path,
    required Map<String, dynamic> body,
    required void Function(String chunk) onChunk,
    void Function(double p)? onProgress,
    required void Function(String message) onError,
    required void Function() onDone,
    Duration timeout = const Duration(seconds: 30),
    int maxRetries = 2,
  }) async {
    if (await isOffline) {
      onError("No internet connection. Please check your network.");
      return;
    }

    _cancelled = false;

    final url = Uri.parse("$baseUrl$path");
    final headers = {
      HttpHeaders.contentTypeHeader: "application/json",
      HttpHeaders.acceptHeader: "text/plain, application/json",
    };

    int attempt = 0;

    while (attempt <= maxRetries) {
      attempt++;

      // ✅ this completer guarantees we always exit postStream
      final doneCompleter = Completer<void>();

      try {
        final req = http.Request("POST", url);
        req.headers.addAll(headers);
        req.body = jsonEncode(body);

        final streamed = await _client.send(req).timeout(timeout);

        if (streamed.statusCode < 200 || streamed.statusCode >= 300) {
          final errText = await streamed.stream.bytesToString();
          throw HttpException("HTTP ${streamed.statusCode}: $errText");
        }

        final chunkStream = streamed.stream.transform(utf8.decoder);

        _streamSub = chunkStream.listen(
          (chunk) {
            if (_cancelled) return;
            onChunk(chunk);
          },
          onError: (e) {
            if (!doneCompleter.isCompleted) {
              doneCompleter.complete();
            }
            if (_cancelled) return;
            onError("Streaming failed: $e");
          },
          onDone: () {
            if (!doneCompleter.isCompleted) {
              doneCompleter.complete();
            }
            if (_cancelled) return;
            onDone();
          },
          cancelOnError: true,
        );

        // ✅ wait until onDone/onError triggers completer
        await doneCompleter.future;
        _streamSub = null;

        return; // success (or finished)
      } on TimeoutException {
        _streamSub = null;

        if (_cancelled) {
          // cancel should not show a timeout error
          return;
        }

        if (attempt > maxRetries) {
          onError("Request timed out. Please try again.");
          return;
        }
        await Future.delayed(Duration(milliseconds: 400 * attempt));
      } on SocketException {
        _streamSub = null;

        if (_cancelled) return;

        onError("Network error. Please check your internet connection.");
        return;
      } catch (e) {
        _streamSub = null;

        if (_cancelled) return;

        if (attempt > maxRetries) {
          onError("AI request failed: $e");
          return;
        }
        await Future.delayed(Duration(milliseconds: 450 * attempt * attempt));
      } finally {
        if (!doneCompleter.isCompleted) {
          doneCompleter.complete();
        }
      }
    }
  }
}
