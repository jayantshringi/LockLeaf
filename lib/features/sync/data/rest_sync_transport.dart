import 'dart:convert';
import 'dart:io';

import 'package:lockleaf/core/errors/app_exception.dart';
import 'package:lockleaf/features/sync/data/cloud_sync_transport.dart';
import 'package:lockleaf/features/sync/domain/encrypted_sync_record.dart';

/// Zero-knowledge HTTPS REST transport for synchronizing encrypted records
/// with a self-hosted or dedicated LockLeaf sync server.
class RestSyncTransport implements CloudSyncTransport {
  @override
  final String name = 'LockLeaf REST Server';

  final Uri _baseUri;
  final String? _apiToken;
  final HttpClient Function() _clientFactory;

  RestSyncTransport({
    required String serverUrl,
    String? apiToken,
    HttpClient Function()? clientFactory,
  })  : _baseUri = Uri.parse(serverUrl.trim().replaceAll(RegExp(r'/+$'), '')),
        _apiToken = apiToken?.trim().isEmpty ?? true ? null : apiToken!.trim(),
        _clientFactory = clientFactory ?? (() => HttpClient());

  @override
  Future<bool> checkHealth() async {
    final client = _clientFactory();
    try {
      final uri = _baseUri.replace(path: '${_baseUri.path}/api/v1/health');
      final request = await client.getUrl(uri).timeout(const Duration(seconds: 5));
      _addHeaders(request);
      final response = await request.close().timeout(const Duration(seconds: 5));
      return response.statusCode == HttpStatus.ok;
    } catch (_) {
      return false;
    } finally {
      client.close();
    }
  }

  @override
  Future<SyncPullResponse> pullChanges({
    required String vaultId,
    required String? sinceCursor,
  }) async {
    final client = _clientFactory();
    try {
      final queryParams = <String, String>{};
      if (sinceCursor != null && sinceCursor.isNotEmpty) {
        queryParams['since'] = sinceCursor;
      }

      final uri = _baseUri.replace(
        path: '${_baseUri.path}/api/v1/vaults/$vaultId/changes',
        queryParameters: queryParams.isEmpty ? null : queryParams,
      );

      final request = await client.getUrl(uri).timeout(const Duration(seconds: 15));
      _addHeaders(request);

      final response = await request.close().timeout(const Duration(seconds: 15));
      final responseBody = await response.transform(utf8.decoder).join();

      if (response.statusCode == HttpStatus.unauthorized ||
          response.statusCode == HttpStatus.forbidden) {
        throw const AuthenticationException('Sync server authentication failed.');
      }

      if (response.statusCode != HttpStatus.ok) {
        throw NetworkException(
          'Failed to pull changes from sync server (${response.statusCode}).',
        );
      }

      final decoded = jsonDecode(responseBody);
      if (decoded is! Map<String, dynamic>) {
        throw const NetworkException('Invalid JSON response from sync server.');
      }

      final rawRecords = decoded['records'] as List<dynamic>? ?? <dynamic>[];
      final records = <EncryptedSyncRecord>[];
      for (final raw in rawRecords) {
        if (raw is Map<String, dynamic>) {
          records.add(EncryptedSyncRecord.fromJson(raw));
        }
      }

      final nextCursor = decoded['next_cursor'] as String?;
      final serverVersion = decoded['server_version'] as int? ?? 0;

      return SyncPullResponse(
        records: records,
        nextCursor: nextCursor,
        serverVersion: serverVersion,
      );
    } on SocketException catch (e) {
      throw NetworkException('Unable to reach sync server: ${e.message}');
    } on AppException {
      rethrow;
    } catch (e) {
      throw NetworkException('Sync pull failed: $e');
    } finally {
      client.close();
    }
  }

  @override
  Future<SyncPushResponse> pushChanges({
    required String vaultId,
    required List<EncryptedSyncRecord> records,
  }) async {
    if (records.isEmpty) {
      return const SyncPushResponse(success: true, acceptedCount: 0);
    }

    final client = _clientFactory();
    try {
      final uri = _baseUri.replace(
        path: '${_baseUri.path}/api/v1/vaults/$vaultId/changes',
      );

      final request = await client.postUrl(uri).timeout(const Duration(seconds: 15));
      _addHeaders(request);
      request.headers.contentType = ContentType.json;

      final payload = jsonEncode(<String, dynamic>{
        'records': records.map((r) => r.toJson()).toList(growable: false),
      });

      request.write(payload);
      final response = await request.close().timeout(const Duration(seconds: 15));
      final responseBody = await response.transform(utf8.decoder).join();

      if (response.statusCode == HttpStatus.unauthorized ||
          response.statusCode == HttpStatus.forbidden) {
        throw const AuthenticationException('Sync server authentication failed.');
      }

      if (response.statusCode != HttpStatus.ok &&
          response.statusCode != HttpStatus.created) {
        throw NetworkException(
          'Failed to push changes to sync server (${response.statusCode}).',
        );
      }

      final decoded = jsonDecode(responseBody) as Map<String, dynamic>? ?? {};
      final accepted = decoded['accepted_count'] as int? ?? records.length;
      final serverVersion = decoded['server_version'] as int? ?? 0;
      final newCursor = decoded['new_cursor'] as String?;

      return SyncPushResponse(
        success: true,
        acceptedCount: accepted,
        serverVersion: serverVersion,
        newCursor: newCursor,
      );
    } on SocketException catch (e) {
      return SyncPushResponse(
        success: false,
        acceptedCount: 0,
        errorMessage: 'Unable to reach sync server: ${e.message}',
      );
    } on AppException catch (e) {
      return SyncPushResponse(
        success: false,
        acceptedCount: 0,
        errorMessage: e.message,
      );
    } catch (e) {
      return SyncPushResponse(
        success: false,
        acceptedCount: 0,
        errorMessage: 'Sync push failed: $e',
      );
    } finally {
      client.close();
    }
  }

  void _addHeaders(HttpClientRequest request) {
    if (_apiToken != null) {
      request.headers.set(HttpHeaders.authorizationHeader, 'Bearer $_apiToken');
    }
    request.headers.set(HttpHeaders.acceptHeader, 'application/json');
    request.headers.set(HttpHeaders.userAgentHeader, 'LockLeaf-Client/1.0');
  }
}

