import 'package:lockleaf/core/crypto/secure_random_service.dart';
import 'package:lockleaf/features/tools/domain/password_generator_options.dart';

/// Generates cryptographically random passwords backed by [SecureRandomService].
class PasswordGenerator {
  static const String _lowercaseChars = 'abcdefghijklmnopqrstuvwxyz';
  static const String _uppercaseChars = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ';
  static const String _digitChars = '0123456789';
  static const String _symbolChars = r'!@#$%^&*()-_=+[]{};:,.?~';
  static const Set<String> _ambiguousChars = <String>{
    '0',
    'O',
    'o',
    '1',
    'l',
    'I',
    '|',
  };

  final SecureRandomService _randomService;

  /// Creates a [PasswordGenerator].
  PasswordGenerator({SecureRandomService? randomService})
    : _randomService = randomService ?? SecureRandomService();

  /// Generates a random password matching [options].
  String generate([
    PasswordGeneratorOptions options =
        const PasswordGeneratorOptions.standard(),
  ]) {
    final activePools = _buildActivePools(options);
    final combinedPool = activePools.expand((List<String> p) => p).toList();

    final resultChars = <String>[];
    for (final pool in activePools) {
      if (resultChars.length < options.length) {
        resultChars.add(pool[_randomService.nextInt(pool.length)]);
      }
    }

    while (resultChars.length < options.length) {
      resultChars.add(
        combinedPool[_randomService.nextInt(combinedPool.length)],
      );
    }

    // Fisher-Yates shuffle using CSPRNG to remove positional bias.
    for (var i = resultChars.length - 1; i > 0; i--) {
      final j = _randomService.nextInt(i + 1);
      final temp = resultChars[i];
      resultChars[i] = resultChars[j];
      resultChars[j] = temp;
    }

    return resultChars.join();
  }

  List<List<String>> _buildActivePools(PasswordGeneratorOptions options) {
    final pools = <List<String>>[];

    void addFiltered(String raw) {
      final chars = raw
          .split('')
          .where(
            (String ch) =>
                !options.excludeAmbiguous || !_ambiguousChars.contains(ch),
          )
          .toList();
      if (chars.isNotEmpty) {
        pools.add(chars);
      }
    }

    if (options.includeLowercase) addFiltered(_lowercaseChars);
    if (options.includeUppercase) addFiltered(_uppercaseChars);
    if (options.includeDigits) addFiltered(_digitChars);
    if (options.includeSymbols) addFiltered(_symbolChars);

    return pools;
  }
}
