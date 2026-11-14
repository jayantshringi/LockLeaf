import 'package:flutter/material.dart';
import 'package:lockleaf/core/theme/app_theme.dart';
import 'package:lockleaf/features/auth/domain/password_strength.dart';
import 'package:lockleaf/features/auth/presentation/vault_controller.dart';
import 'package:lockleaf/features/auth/presentation/widgets/password_strength_meter.dart';
import 'package:lockleaf/features/auth/presentation/widgets/secret_text_field.dart';
import 'package:lockleaf/features/tools/presentation/screens/password_generator_screen.dart';
import 'package:lockleaf/features/vault/domain/vault_entry.dart';
import 'package:lockleaf/features/vault/domain/vault_entry_category.dart';

/// Form screen for creating a new vault entry or updating an existing one.
class AddEditEntryScreen extends StatefulWidget {
  /// Controller managing vault encryption and persistence.
  final VaultController controller;

  /// Existing entry when editing, or null when creating a new entry.
  final VaultEntry? existingEntry;

  /// Creates an [AddEditEntryScreen].
  const AddEditEntryScreen({
    super.key,
    required this.controller,
    this.existingEntry,
  });

  @override
  State<AddEditEntryScreen> createState() => _AddEditEntryScreenState();
}

class _AddEditEntryScreenState extends State<AddEditEntryScreen> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  late final TextEditingController _titleController;
  late final TextEditingController _usernameController;
  late final TextEditingController _passwordController;
  late final TextEditingController _urlController;
  late final TextEditingController _notesController;

  late VaultEntryCategory _category;
  late bool _isFavorite;
  late PasswordStrengthResult _strength;

  bool get _isEditing => widget.existingEntry != null;

  @override
  void initState() {
    super.initState();
    final existing = widget.existingEntry;
    _titleController = TextEditingController(text: existing?.title ?? '');
    _usernameController = TextEditingController(text: existing?.username ?? '');
    _passwordController = TextEditingController(text: existing?.password ?? '');
    _urlController = TextEditingController(text: existing?.url ?? '');
    _notesController = TextEditingController(text: existing?.notes ?? '');

    _category = existing?.category ?? VaultEntryCategory.login;
    _isFavorite = existing?.isFavorite ?? false;
    _strength = PasswordStrengthEvaluator.evaluate(_passwordController.text);
  }

  @override
  void dispose() {
    _passwordController.clear();
    _titleController.dispose();
    _usernameController.dispose();
    _passwordController.dispose();
    _urlController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final formState = _formKey.currentState;
    if (formState == null || !formState.validate()) {
      return;
    }

    final urlText = _urlController.text.trim();
    final notesText = _notesController.text;

    final VaultEntry? saved;
    final existing = widget.existingEntry;
    if (existing != null) {
      saved = await widget.controller.editEntry(
        existing.copyWith(
          title: _titleController.text.trim(),
          username: _usernameController.text.trim(),
          password: _passwordController.text,
          url: urlText.isEmpty ? null : urlText,
          clearUrl: urlText.isEmpty,
          notes: notesText.isEmpty ? null : notesText,
          clearNotes: notesText.isEmpty,
          category: _category,
          isFavorite: _isFavorite,
        ),
      );
    } else {
      saved = await widget.controller.addEntry(
        title: _titleController.text.trim(),
        username: _usernameController.text.trim(),
        password: _passwordController.text,
        url: urlText.isEmpty ? null : urlText,
        notes: notesText.isEmpty ? null : notesText,
        category: _category,
        isFavorite: _isFavorite,
      );
    }

    if (!mounted) {
      return;
    }
    if (saved != null) {
      Navigator.of(context).pop(saved);
    }
  }

  Future<void> _pickGeneratedPassword() async {
    final generated = await Navigator.of(context).push<String>(
      MaterialPageRoute<String>(
        builder: (BuildContext context) =>
            const PasswordGeneratorScreen(returnSelection: true),
      ),
    );
    if (!mounted || generated == null || generated.isEmpty) {
      return;
    }
    setState(() {
      _passwordController.text = generated;
      _strength = PasswordStrengthEvaluator.evaluate(generated);
    });
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: widget.controller,
      builder: (BuildContext context, Widget? child) {
        final isBusy = widget.controller.isBusy;
        final errorMessage = widget.controller.errorMessage;

        return Scaffold(
          appBar: AppBar(
            title: Text(_isEditing ? 'Edit Entry' : 'New Entry'),
            actions: [
              IconButton(
                key: const Key('entry_favorite_toggle'),
                tooltip: _isFavorite ? 'Remove favorite' : 'Mark favorite',
                icon: Icon(
                  _isFavorite ? Icons.star_rounded : Icons.star_border_rounded,
                  color: _isFavorite ? AppTheme.warning : null,
                ),
                onPressed: isBusy
                    ? null
                    : () {
                        setState(() {
                          _isFavorite = !_isFavorite;
                        });
                      },
              ),
            ],
          ),
          body: SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(20.0),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    DropdownButtonFormField<VaultEntryCategory>(
                      key: const Key('entry_category_dropdown'),
                      value: _category,
                      decoration: const InputDecoration(
                        labelText: 'Category',
                        prefixIcon: Icon(Icons.category_outlined),
                      ),
                      items: VaultEntryCategory.values
                          .map(
                            (VaultEntryCategory category) =>
                                DropdownMenuItem<VaultEntryCategory>(
                              value: category,
                              child: Text(category.label),
                            ),
                          )
                          .toList(),
                      onChanged: isBusy
                          ? null
                          : (VaultEntryCategory? selected) {
                              if (selected != null) {
                                setState(() {
                                  _category = selected;
                                });
                              }
                            },
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      key: const Key('entry_title_field'),
                      controller: _titleController,
                      enabled: !isBusy,
                      textInputAction: TextInputAction.next,
                      decoration: const InputDecoration(
                        labelText: 'Title',
                        hintText: 'e.g. Email, Cloud Console',
                        prefixIcon: Icon(Icons.label_outline),
                      ),
                      validator: (String? value) {
                        if (value == null || value.trim().isEmpty) {
                          return 'Title is required';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      key: const Key('entry_username_field'),
                      controller: _usernameController,
                      enabled: !isBusy,
                      autocorrect: false,
                      enableSuggestions: false,
                      textInputAction: TextInputAction.next,
                      decoration: const InputDecoration(
                        labelText: 'Username or Email',
                        prefixIcon: Icon(Icons.person_outline),
                      ),
                    ),
                    const SizedBox(height: 16),
                    SecretTextField(
                      key: const Key('entry_password_field'),
                      controller: _passwordController,
                      labelText: 'Password / Secret',
                      enabled: !isBusy,
                      textInputAction: TextInputAction.next,
                      onChanged: (String value) {
                        setState(() {
                          _strength = PasswordStrengthEvaluator.evaluate(value);
                        });
                      },
                      validator: (String? value) {
                        if (value == null || value.isEmpty) {
                          return 'Password is required';
                        }
                        return null;
                      },
                    ),
                    Align(
                      alignment: Alignment.centerRight,
                      child: TextButton.icon(
                        key: const Key('entry_generate_password_button'),
                        onPressed: isBusy ? null : _pickGeneratedPassword,
                        icon: const Icon(Icons.auto_fix_high, size: 18),
                        label: const Text('Generate Password'),
                      ),
                    ),
                    const SizedBox(height: 6),
                    PasswordStrengthMeter(result: _strength),
                    const SizedBox(height: 16),
                    TextFormField(
                      key: const Key('entry_url_field'),
                      controller: _urlController,
                      enabled: !isBusy,
                      autocorrect: false,
                      keyboardType: TextInputType.url,
                      textInputAction: TextInputAction.next,
                      decoration: const InputDecoration(
                        labelText: 'Website URL (optional)',
                        hintText: 'https://example.com',
                        prefixIcon: Icon(Icons.link_outlined),
                      ),
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      key: const Key('entry_notes_field'),
                      controller: _notesController,
                      enabled: !isBusy,
                      maxLines: 4,
                      decoration: const InputDecoration(
                        labelText: 'Notes (optional)',
                        alignLabelWithHint: true,
                        prefixIcon: Icon(Icons.notes_outlined),
                      ),
                    ),
                    if (errorMessage != null) ...[
                      const SizedBox(height: 16),
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: AppTheme.danger.withOpacity(0.12),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          errorMessage,
                          style: const TextStyle(color: AppTheme.danger),
                        ),
                      ),
                    ],
                    const SizedBox(height: 24),
                    SizedBox(
                      height: 52,
                      child: FilledButton(
                        key: const Key('entry_save_button'),
                        onPressed: isBusy ? null : _save,
                        child: isBusy
                            ? const SizedBox(
                                width: 22,
                                height: 22,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              )
                            : Text(_isEditing ? 'Save Changes' : 'Save Entry'),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
