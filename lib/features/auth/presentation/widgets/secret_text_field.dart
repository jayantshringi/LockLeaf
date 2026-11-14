import 'package:flutter/material.dart';

/// Masked input field for master passwords and sensitive entry credentials.
///
/// Disables keyboard suggestions, autocorrect, and IME personalized learning
/// so software keyboards do not record secrets in user dictionaries.
class SecretTextField extends StatefulWidget {
  /// Controller managing the underlying text.
  final TextEditingController controller;

  /// Label displayed above or inside the field border.
  final String labelText;

  /// Optional helper hint when empty.
  final String? hintText;

  /// Optional validation callback.
  final String? Function(String? value)? validator;

  /// Callback invoked on every text change.
  final ValueChanged<String>? onChanged;

  /// Callback invoked when the user submits via keyboard action.
  final ValueChanged<String>? onFieldSubmitted;

  /// Keyboard action button (defaults to [TextInputAction.done]).
  final TextInputAction textInputAction;

  /// Whether input editing is currently enabled.
  final bool enabled;

  /// Optional semantic key for the visibility toggle icon button.
  final Key? toggleKey;

  /// Creates a security-hardened [SecretTextField].
  const SecretTextField({
    super.key,
    required this.controller,
    required this.labelText,
    this.hintText,
    this.validator,
    this.onChanged,
    this.onFieldSubmitted,
    this.textInputAction = TextInputAction.done,
    this.enabled = true,
    this.toggleKey,
  });

  @override
  State<SecretTextField> createState() => _SecretTextFieldState();
}

class _SecretTextFieldState extends State<SecretTextField> {
  bool _obscured = true;

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: widget.controller,
      enabled: widget.enabled,
      obscureText: _obscured,
      autocorrect: false,
      enableSuggestions: false,
      enableIMEPersonalizedLearning: false,
      keyboardType: TextInputType.visiblePassword,
      textInputAction: widget.textInputAction,
      validator: widget.validator,
      onChanged: widget.onChanged,
      onFieldSubmitted: widget.onFieldSubmitted,
      decoration: InputDecoration(
        labelText: widget.labelText,
        hintText: widget.hintText,
        prefixIcon: const Icon(Icons.lock_outline),
        suffixIcon: IconButton(
          key: widget.toggleKey,
          tooltip: _obscured ? 'Show password' : 'Hide password',
          icon: Icon(
            _obscured
                ? Icons.visibility_outlined
                : Icons.visibility_off_outlined,
          ),
          onPressed: () {
            setState(() {
              _obscured = !_obscured;
            });
          },
        ),
      ),
    );
  }
}
