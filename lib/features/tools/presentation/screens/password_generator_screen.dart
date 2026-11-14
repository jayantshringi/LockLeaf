import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:lockleaf/core/constants/security_constants.dart';
import 'package:lockleaf/features/auth/domain/password_strength.dart';
import 'package:lockleaf/features/auth/presentation/widgets/password_strength_meter.dart';
import 'package:lockleaf/features/security/presentation/security_controller.dart';
import 'package:lockleaf/features/tools/domain/passphrase_generator.dart';
import 'package:lockleaf/features/tools/domain/password_generator.dart';
import 'package:lockleaf/features/tools/domain/password_generator_options.dart';

enum _GeneratorMode { password, passphrase }

/// Interactive CSPRNG password and Diceware passphrase generator screen.
class PasswordGeneratorScreen extends StatefulWidget {
  /// Optional security controller enabling 30s clipboard auto-clear.
  final SecurityController? securityController;

  /// When true, displays an action button returning the generated string.
  final bool returnSelection;

  /// Optional password generator override.
  final PasswordGenerator? passwordGenerator;

  /// Optional passphrase generator override.
  final PassphraseGenerator? passphraseGenerator;

  /// Creates a [PasswordGeneratorScreen].
  const PasswordGeneratorScreen({
    super.key,
    this.securityController,
    this.returnSelection = false,
    this.passwordGenerator,
    this.passphraseGenerator,
  });

  @override
  State<PasswordGeneratorScreen> createState() =>
      _PasswordGeneratorScreenState();
}

class _PasswordGeneratorScreenState extends State<PasswordGeneratorScreen> {
  late final PasswordGenerator _passwordGenerator;
  late final PassphraseGenerator _passphraseGenerator;

  _GeneratorMode _mode = _GeneratorMode.password;
  PasswordGeneratorOptions _passwordOptions =
      const PasswordGeneratorOptions.standard();
  PassphraseGeneratorOptions _passphraseOptions =
      const PassphraseGeneratorOptions.standard();
  late String _generated;

  @override
  void initState() {
    super.initState();
    _passwordGenerator = widget.passwordGenerator ?? PasswordGenerator();
    _passphraseGenerator = widget.passphraseGenerator ?? PassphraseGenerator();
    _generated = _generateCurrent();
  }

  String _generateCurrent() {
    switch (_mode) {
      case _GeneratorMode.password:
        return _passwordGenerator.generate(_passwordOptions);
      case _GeneratorMode.passphrase:
        return _passphraseGenerator.generate(_passphraseOptions);
    }
  }

  void _regenerate() {
    setState(() {
      _generated = _generateCurrent();
    });
  }

  void _updatePasswordOptions(PasswordGeneratorOptions next) {
    setState(() {
      _passwordOptions = next;
      _generated = _generateCurrent();
    });
  }

  void _updatePassphraseOptions(PassphraseGeneratorOptions next) {
    setState(() {
      _passphraseOptions = next;
      _generated = _generateCurrent();
    });
  }

  bool _canDisableClass({
    required bool lower,
    required bool upper,
    required bool digits,
    required bool symbols,
  }) {
    final activeCount =
        (lower ? 1 : 0) +
        (upper ? 1 : 0) +
        (digits ? 1 : 0) +
        (symbols ? 1 : 0);
    return activeCount > 0;
  }

  Future<void> _copyGenerated() async {
    final security = widget.securityController;
    final String message;
    if (security != null) {
      await security.copySecret(_generated);
      message =
          'Generated secret copied — clears in '
          '${SecurityConstants.clipboardClearDelaySeconds}s';
    } else {
      await Clipboard.setData(ClipboardData(text: _generated));
      message = 'Generated secret copied to clipboard';
    }
    if (!mounted) {
      return;
    }
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    final strength = PasswordStrengthEvaluator.evaluate(_generated);

    return Scaffold(
      appBar: AppBar(title: const Text('Generator')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            SegmentedButton<_GeneratorMode>(
              key: const Key('generator_mode_segment'),
              segments: const <ButtonSegment<_GeneratorMode>>[
                ButtonSegment<_GeneratorMode>(
                  value: _GeneratorMode.password,
                  icon: Icon(Icons.password),
                  label: Text('Password'),
                ),
                ButtonSegment<_GeneratorMode>(
                  value: _GeneratorMode.passphrase,
                  icon: Icon(Icons.short_text),
                  label: Text('Passphrase'),
                ),
              ],
              selected: <_GeneratorMode>{_mode},
              onSelectionChanged: (Set<_GeneratorMode> selected) {
                setState(() {
                  _mode = selected.first;
                  _generated = _generateCurrent();
                });
              },
            ),
            const SizedBox(height: 16),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    SelectableText(
                      _generated,
                      key: const Key('generator_output_text'),
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontFamily: 'monospace',
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 12),
                    PasswordStrengthMeter(result: strength),
                    const SizedBox(height: 12),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        TextButton.icon(
                          key: const Key('generator_regenerate_button'),
                          onPressed: _regenerate,
                          icon: const Icon(Icons.refresh),
                          label: const Text('Regenerate'),
                        ),
                        const SizedBox(width: 8),
                        FilledButton.tonalIcon(
                          key: const Key('generator_copy_button'),
                          onPressed: _copyGenerated,
                          icon: const Icon(Icons.copy_outlined),
                          label: const Text('Copy'),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            if (widget.returnSelection) ...[
              const SizedBox(height: 12),
              SizedBox(
                height: 48,
                child: FilledButton.icon(
                  key: const Key('generator_use_button'),
                  onPressed: () => Navigator.of(context).pop(_generated),
                  icon: const Icon(Icons.check),
                  label: const Text('Use This Password'),
                ),
              ),
            ],
            const SizedBox(height: 16),
            if (_mode == _GeneratorMode.password)
              _buildPasswordControls()
            else
              _buildPassphraseControls(),
          ],
        ),
      ),
    );
  }

  Widget _buildPasswordControls() {
    return Card(
      child: Column(
        children: [
          ListTile(
            title: const Text('Length'),
            trailing: Text(
              '${_passwordOptions.length}',
              key: const Key('generator_length_value'),
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
          Slider(
            key: const Key('generator_length_slider'),
            min: PasswordGeneratorOptions.minLength.toDouble(),
            max: 64,
            divisions: 56,
            value: _passwordOptions.length.clamp(8, 64).toDouble(),
            onChanged: (double value) {
              _updatePasswordOptions(
                _passwordOptions.copyWith(length: value.round()),
              );
            },
          ),
          SwitchListTile(
            key: const Key('generator_uppercase_switch'),
            title: const Text('Uppercase (A-Z)'),
            value: _passwordOptions.includeUppercase,
            onChanged: (bool value) {
              if (!_canDisableClass(
                lower: _passwordOptions.includeLowercase,
                upper: value,
                digits: _passwordOptions.includeDigits,
                symbols: _passwordOptions.includeSymbols,
              )) {
                return;
              }
              _updatePasswordOptions(
                _passwordOptions.copyWith(includeUppercase: value),
              );
            },
          ),
          SwitchListTile(
            key: const Key('generator_lowercase_switch'),
            title: const Text('Lowercase (a-z)'),
            value: _passwordOptions.includeLowercase,
            onChanged: (bool value) {
              if (!_canDisableClass(
                lower: value,
                upper: _passwordOptions.includeUppercase,
                digits: _passwordOptions.includeDigits,
                symbols: _passwordOptions.includeSymbols,
              )) {
                return;
              }
              _updatePasswordOptions(
                _passwordOptions.copyWith(includeLowercase: value),
              );
            },
          ),
          SwitchListTile(
            key: const Key('generator_digits_switch'),
            title: const Text('Digits (0-9)'),
            value: _passwordOptions.includeDigits,
            onChanged: (bool value) {
              if (!_canDisableClass(
                lower: _passwordOptions.includeLowercase,
                upper: _passwordOptions.includeUppercase,
                digits: value,
                symbols: _passwordOptions.includeSymbols,
              )) {
                return;
              }
              _updatePasswordOptions(
                _passwordOptions.copyWith(includeDigits: value),
              );
            },
          ),
          SwitchListTile(
            key: const Key('generator_symbols_switch'),
            title: const Text('Symbols (!@#\$%...)'),
            value: _passwordOptions.includeSymbols,
            onChanged: (bool value) {
              if (!_canDisableClass(
                lower: _passwordOptions.includeLowercase,
                upper: _passwordOptions.includeUppercase,
                digits: _passwordOptions.includeDigits,
                symbols: value,
              )) {
                return;
              }
              _updatePasswordOptions(
                _passwordOptions.copyWith(includeSymbols: value),
              );
            },
          ),
          SwitchListTile(
            key: const Key('generator_ambiguous_switch'),
            title: const Text('Exclude Ambiguous (0, O, 1, l, I)'),
            value: _passwordOptions.excludeAmbiguous,
            onChanged: (bool value) {
              _updatePasswordOptions(
                _passwordOptions.copyWith(excludeAmbiguous: value),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildPassphraseControls() {
    const separators = <String, String>{
      '-': 'Hyphen (-)',
      '_': 'Underscore (_)',
      ' ': 'Space ( )',
      '.': 'Period (.)',
    };

    return Card(
      child: Column(
        children: [
          ListTile(
            title: const Text('Word Count'),
            trailing: Text(
              '${_passphraseOptions.wordCount}',
              key: const Key('passphrase_word_count_value'),
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
          Slider(
            key: const Key('passphrase_words_slider'),
            min: PassphraseGeneratorOptions.minWords.toDouble(),
            max: 12,
            divisions: 8,
            value: _passphraseOptions.wordCount.clamp(4, 12).toDouble(),
            onChanged: (double value) {
              _updatePassphraseOptions(
                _passphraseOptions.copyWith(wordCount: value.round()),
              );
            },
          ),
          ListTile(
            title: const Text('Word Separator'),
            trailing: DropdownButton<String>(
              key: const Key('passphrase_separator_dropdown'),
              value: _passphraseOptions.separator,
              underline: const SizedBox.shrink(),
              items: separators.entries
                  .map(
                    (MapEntry<String, String> entry) =>
                        DropdownMenuItem<String>(
                          value: entry.key,
                          child: Text(entry.value),
                        ),
                  )
                  .toList(),
              onChanged: (String? selected) {
                if (selected != null) {
                  _updatePassphraseOptions(
                    _passphraseOptions.copyWith(separator: selected),
                  );
                }
              },
            ),
          ),
          SwitchListTile(
            key: const Key('passphrase_capitalize_switch'),
            title: const Text('Capitalize Words'),
            value: _passphraseOptions.capitalizeWords,
            onChanged: (bool value) {
              _updatePassphraseOptions(
                _passphraseOptions.copyWith(capitalizeWords: value),
              );
            },
          ),
          SwitchListTile(
            key: const Key('passphrase_number_switch'),
            title: const Text('Include Number'),
            value: _passphraseOptions.appendNumber,
            onChanged: (bool value) {
              _updatePassphraseOptions(
                _passphraseOptions.copyWith(appendNumber: value),
              );
            },
          ),
        ],
      ),
    );
  }
}
