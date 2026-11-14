import 'package:flutter/material.dart';
import 'package:lockleaf/core/theme/app_theme.dart';
import 'package:lockleaf/features/auth/presentation/vault_controller.dart';

class _OnboardingSlide {
  final IconData icon;
  final String title;
  final String description;

  const _OnboardingSlide({
    required this.icon,
    required this.title,
    required this.description,
  });
}

/// First-run onboarding carousel explaining LockLeaf's zero-knowledge guarantees.
class OnboardingScreen extends StatefulWidget {
  /// Controller used for theme toggling.
  final VaultController controller;

  /// Invoked when the user chooses to create their master password.
  final VoidCallback onGetStarted;

  /// Creates an [OnboardingScreen].
  const OnboardingScreen({
    super.key,
    required this.controller,
    required this.onGetStarted,
  });

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  static const List<_OnboardingSlide> _slides = <_OnboardingSlide>[
    _OnboardingSlide(
      icon: Icons.shield_outlined,
      title: 'Zero-Knowledge Vault',
      description: 'Your master password never leaves your device. Only you hold the keys to decrypt your secrets.',
    ),
    _OnboardingSlide(
      icon: Icons.enhanced_encryption_outlined,
      title: 'Audited Cryptography',
      description: 'Protected with Argon2id key derivation and XChaCha20-Poly1305 encryption using unique random nonces.',
    ),
    _OnboardingSlide(
      icon: Icons.storage_outlined,
      title: 'Encrypted Local Storage',
      description: 'Every entry title, username, and password is stored exclusively as authenticated ciphertext.',
    ),
  ];

  final PageController _pageController = PageController();
  int _currentPage = 0;

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  Future<void> _advanceOrStart() async {
    if (_currentPage < _slides.length - 1) {
      await _pageController.nextPage(
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeOut,
      );
    } else {
      widget.onGetStarted();
    }
  }

  @override
  Widget build(BuildContext context) {
    final isLastPage = _currentPage == _slides.length - 1;

    return Scaffold(
      appBar: AppBar(
        title: const Text('LockLeaf'),
        actions: [
          IconButton(
            tooltip: 'Toggle theme',
            icon: Icon(
              widget.controller.isDarkMode
                  ? Icons.light_mode_outlined
                  : Icons.dark_mode_outlined,
            ),
            onPressed: widget.controller.toggleDarkMode,
          ),
          if (!isLastPage)
            TextButton(
              onPressed: widget.onGetStarted,
              child: const Text('Skip'),
            ),
        ],
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            children: [
              Expanded(
                child: PageView.builder(
                  controller: _pageController,
                  itemCount: _slides.length,
                  onPageChanged: (int index) {
                    setState(() {
                      _currentPage = index;
                    });
                  },
                  itemBuilder: (BuildContext context, int index) {
                    final slide = _slides[index];
                    return Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Container(
                          padding: const EdgeInsets.all(24),
                          decoration: BoxDecoration(
                            color: AppTheme.primaryGreen.withOpacity(0.12),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            slide.icon,
                            size: 72,
                            color: AppTheme.primaryGreen,
                          ),
                        ),
                        const SizedBox(height: 32),
                        Text(
                          slide.title,
                          textAlign: TextAlign.center,
                          style: Theme.of(context).textTheme.headlineSmall
                              ?.copyWith(fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 16),
                        Text(
                          slide.description,
                          textAlign: TextAlign.center,
                          style: Theme.of(context).textTheme.bodyLarge
                              ?.copyWith(color: Colors.grey),
                        ),
                      ],
                    );
                  },
                ),
              ),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List<Widget>.generate(_slides.length, (int index) {
                  final active = index == _currentPage;
                  return AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    margin: const EdgeInsets.symmetric(horizontal: 4),
                    width: active ? 24 : 8,
                    height: 8,
                    decoration: BoxDecoration(
                      color: active
                          ? AppTheme.primaryGreen
                          : Colors.grey.withOpacity(0.4),
                      borderRadius: BorderRadius.circular(4),
                    ),
                  );
                }),
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                height: 52,
                child: FilledButton(
                  onPressed: _advanceOrStart,
                  child: Text(isLastPage ? 'Create Master Password' : 'Next'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
