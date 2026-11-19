import 'package:flutter_test/flutter_test.dart';
import 'package:lockleaf/core/errors/app_exception.dart';
import 'package:lockleaf/features/sync/data/rest_sync_transport.dart';

void main() {
  group('RestSyncTransport URL validation', () {
    group('HTTPS acceptance', () {
      test('accepts valid https URLs without trailing slash', () {
        final uri = RestSyncTransport.validateAndParseServerUrl(
          'https://sync.lockleaf.org',
        );
        expect(uri.scheme, 'https');
        expect(uri.host, 'sync.lockleaf.org');
      });

      test('accepts valid https URLs with path, port, and trailing slashes', () {
        final uri = RestSyncTransport.validateAndParseServerUrl(
          'https://api.example.com:8443/vault/sync///',
        );
        expect(uri.scheme, 'https');
        expect(uri.host, 'api.example.com');
        expect(uri.port, 8443);
        expect(uri.path, '/vault/sync');
      });

      test('constructs RestSyncTransport with valid https URL', () {
        final transport = RestSyncTransport(
          serverUrl: 'https://sync.lockleaf.org',
        );
        expect(transport.name, 'LockLeaf REST Server');
      });
    });

    group('HTTP rejection', () {
      test('rejects cleartext http URL to remote host in debug mode', () {
        expect(
          () => RestSyncTransport.validateAndParseServerUrl(
            'http://sync.lockleaf.org',
            isDebugMode: true,
          ),
          throwsA(
            isA<ValidationException>().having(
              (e) => e.message,
              'message',
              contains('Insecure HTTP is forbidden'),
            ),
          ),
        );
      });

      test('rejects cleartext http URL to remote host in release mode', () {
        expect(
          () => RestSyncTransport.validateAndParseServerUrl(
            'http://sync.lockleaf.org',
            isDebugMode: false,
          ),
          throwsA(
            isA<ValidationException>().having(
              (e) => e.message,
              'message',
              contains('Insecure HTTP is forbidden'),
            ),
          ),
        );
      });

      test('rejects http localhost in release mode', () {
        expect(
          () => RestSyncTransport.validateAndParseServerUrl(
            'http://localhost:8080',
            isDebugMode: false,
          ),
          throwsA(
            isA<ValidationException>().having(
              (e) => e.message,
              'message',
              contains('Cleartext HTTP is only permitted on local addresses in debug mode'),
            ),
          ),
        );

        expect(
          () => RestSyncTransport.validateAndParseServerUrl(
            'http://127.0.0.1:8080',
            isDebugMode: false,
          ),
          throwsA(
            isA<ValidationException>().having(
              (e) => e.message,
              'message',
              contains('Cleartext HTTP is only permitted on local addresses in debug mode'),
            ),
          ),
        );

        expect(
          () => RestSyncTransport.validateAndParseServerUrl(
            'http://10.0.2.2:8000',
            isDebugMode: false,
          ),
          throwsA(
            isA<ValidationException>().having(
              (e) => e.message,
              'message',
              contains('Cleartext HTTP is only permitted on local addresses in debug mode'),
            ),
          ),
        );
      });
    });

    group('HTTP localhost in debug mode', () {
      test('accepts http localhost in debug mode', () {
        final uri = RestSyncTransport.validateAndParseServerUrl(
          'http://localhost:8080/sync',
          isDebugMode: true,
        );
        expect(uri.scheme, 'http');
        expect(uri.host, 'localhost');
        expect(uri.port, 8080);
      });

      test('accepts http 127.0.0.1 in debug mode', () {
        final uri = RestSyncTransport.validateAndParseServerUrl(
          'http://127.0.0.1:9090',
          isDebugMode: true,
        );
        expect(uri.scheme, 'http');
        expect(uri.host, '127.0.0.1');
        expect(uri.port, 9090);
      });

      test('accepts http 10.0.2.2 Android emulator loopback in debug mode', () {
        final uri = RestSyncTransport.validateAndParseServerUrl(
          'http://10.0.2.2:8080',
          isDebugMode: true,
        );
        expect(uri.scheme, 'http');
        expect(uri.host, '10.0.2.2');
        expect(uri.port, 8080);
      });
    });

    group('Malformed URL rejection', () {
      test('rejects empty and whitespace-only URLs', () {
        expect(
          () => RestSyncTransport.validateAndParseServerUrl(''),
          throwsA(isA<ValidationException>()),
        );
        expect(
          () => RestSyncTransport.validateAndParseServerUrl('   '),
          throwsA(isA<ValidationException>()),
        );
      });

      test('rejects URLs missing scheme or host', () {
        expect(
          () => RestSyncTransport.validateAndParseServerUrl('sync.example.com'),
          throwsA(isA<ValidationException>()),
        );
        expect(
          () => RestSyncTransport.validateAndParseServerUrl('https://'),
          throwsA(isA<ValidationException>()),
        );
      });

      test('rejects non-HTTP schemes like ftp or ws', () {
        expect(
          () => RestSyncTransport.validateAndParseServerUrl('ftp://example.com/file'),
          throwsA(
            isA<ValidationException>().having(
              (e) => e.message,
              'message',
              contains('Sync server URL scheme must be HTTPS'),
            ),
          ),
        );
        expect(
          () => RestSyncTransport.validateAndParseServerUrl('ws://example.com/socket'),
          throwsA(isA<ValidationException>()),
        );
      });
    });

    group('URL with embedded credentials rejection', () {
      test('rejects URLs containing username and password userInfo', () {
        expect(
          () => RestSyncTransport.validateAndParseServerUrl(
            'https://admin:supersecret@sync.example.com',
          ),
          throwsA(
            isA<ValidationException>().having(
              (e) => e.message,
              'message',
              contains('must not contain embedded user credentials'),
            ),
          ),
        );
      });

      test('rejects URLs containing username-only userInfo', () {
        expect(
          () => RestSyncTransport.validateAndParseServerUrl(
            'https://admin@sync.example.com',
          ),
          throwsA(
            isA<ValidationException>().having(
              (e) => e.message,
              'message',
              contains('must not contain embedded user credentials'),
            ),
          ),
        );
      });
    });
  });
}
