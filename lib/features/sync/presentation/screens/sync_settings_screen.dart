import 'package:flutter/material.dart';
import 'package:lockleaf/core/theme/app_theme.dart';
import 'package:lockleaf/features/auth/presentation/widgets/secret_text_field.dart';
import 'package:lockleaf/features/sync/data/rest_sync_transport.dart';
import 'package:lockleaf/features/sync/domain/sync_status.dart';
import 'package:lockleaf/features/sync/presentation/sync_controller.dart';

/// Screen allowing configuration and triggering of End-to-End Encrypted Cloud Sync.
class SyncSettingsScreen extends StatefulWidget {
  final SyncController syncController;

  const SyncSettingsScreen({
    super.key,
    required this.syncController,
  });

  @override
  State<SyncSettingsScreen> createState() => _SyncSettingsScreenState();
}

class _SyncSettingsScreenState extends State<SyncSettingsScreen> {
  final _formKey = GlobalKey<FormState>();
  final _serverUrlController = TextEditingController();
  final _apiTokenController = TextEditingController();

  bool _obscureToken = true;
  bool _testingConnection = false;
  String? _connectionTestResult;

  @override
  void initState() {
    super.initState();
    final transport = widget.syncController.transport;
    if (transport is RestSyncTransport) {
      // Pre-fill if configured
    }
  }

  @override
  void dispose() {
    _serverUrlController.dispose();
    _apiTokenController.dispose();
    super.dispose();
  }

  Future<void> _testConnection() async {
    final url = _serverUrlController.text.trim();
    if (url.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a server URL first.')),
      );
      return;
    }

    setState(() {
      _testingConnection = true;
      _connectionTestResult = null;
    });

    final testTransport = RestSyncTransport(
      serverUrl: url,
      apiToken: _apiTokenController.text.trim().isEmpty
          ? null
          : _apiTokenController.text.trim(),
    );

    final ok = await testTransport.checkHealth();
    if (mounted) {
      setState(() {
        _testingConnection = false;
        _connectionTestResult = ok
            ? 'Connected successfully to sync server.'
            : 'Unable to reach sync server. Check URL and connection.';
      });
    }
  }

  Future<void> _handleManualSync() async {
    final result = await widget.syncController.triggerSync();
    if (!mounted) return;

    if (result.isSuccess) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Sync completed: ${result.pushedCount} pushed, ${result.appliedRemoteCount} pulled.',
          ),
        ),
      );
    } else if (result.state == SyncState.offline) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Sync server is offline or unreachable.')),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(result.errorMessage ?? 'Sync failed.'),
          backgroundColor: AppTheme.errorRed,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final controller = widget.syncController;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Cloud Synchronization'),
      ),
      body: SafeArea(
        child: AnimatedBuilder(
          animation: controller,
          builder: (context, _) {
            final state = controller.state;
            final isSyncing = controller.isSyncing;

            return SingleChildScrollView(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Container(
                    padding: const EdgeInsets.all(16.0),
                    decoration: BoxDecoration(
                      color: AppTheme.primaryGreen.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(12.0),
                      border: Border.all(
                        color: AppTheme.primaryGreen.withValues(alpha: 0.3),
                      ),
                    ),
                    child: Row(
                      children: [
                        const Icon(
                          Icons.cloud_sync_outlined,
                          color: AppTheme.primaryGreen,
                          size: 32,
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'End-to-End Encrypted',
                                style: theme.textTheme.titleMedium?.copyWith(
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                'Data is encrypted and decrypted strictly on your device. '
                                'The cloud server stores only opaque ciphertexts.',
                                style: theme.textTheme.bodySmall,
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              _buildStatusIndicator(state),
                              const SizedBox(width: 10),
                              Text(
                                _statusText(state),
                                style: const TextStyle(fontWeight: FontWeight.bold),
                              ),
                            ],
                          ),
                          const Divider(height: 24),
                          Text(
                            'Last Synced: ${controller.lastSyncedAt != null ? controller.lastSyncedAt!.toLocal().toString().split('.').first : 'Never'}',
                            style: theme.textTheme.bodyMedium,
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Pending Uploads: ${controller.pendingCount}',
                            style: theme.textTheme.bodyMedium,
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Active Backend: ${controller.transport.name}',
                            style: theme.textTheme.bodySmall?.copyWith(color: Colors.grey),
                          ),
                          const SizedBox(height: 16),
                          SizedBox(
                            width: double.infinity,
                            child: ElevatedButton.icon(
                              key: const Key('sync_now_button'),
                              onPressed: isSyncing ? null : _handleManualSync,
                              icon: isSyncing
                                  ? const SizedBox(
                                      width: 18,
                                      height: 18,
                                      child: CircularProgressIndicator(strokeWidth: 2),
                                    )
                                  : const Icon(Icons.sync_rounded),
                              label: Text(isSyncing ? 'Syncing...' : 'Sync Now'),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 28),
                  Text(
                    'Custom Server Configuration',
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Form(
                    key: _formKey,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        TextFormField(
                          key: const Key('sync_server_url_field'),
                          controller: _serverUrlController,
                          decoration: const InputDecoration(
                            labelText: 'Server URL',
                            hintText: 'https://sync.example.com',
                            prefixIcon: Icon(Icons.dns_outlined),
                          ),
                        ),
                        const SizedBox(height: 16),
                        SecretTextField(
                          key: const Key('sync_api_token_field'),
                          controller: _apiTokenController,
                          obscureText: _obscureToken,
                          labelText: 'API Token (Optional)',
                          hintText: 'Bearer token for private server',
                          prefixIcon: const Icon(Icons.vpn_key_outlined),
                          suffixIcon: IconButton(
                            icon: Icon(
                              _obscureToken
                                  ? Icons.visibility_off_outlined
                                  : Icons.visibility_outlined,
                            ),
                            onPressed: () =>
                                setState(() => _obscureToken = !_obscureToken),
                          ),
                        ),
                        if (_connectionTestResult != null) ...[
                          const SizedBox(height: 12),
                          Text(
                            _connectionTestResult!,
                            style: TextStyle(
                              fontSize: 13,
                              color: _connectionTestResult!.contains('success')
                                  ? AppTheme.primaryGreen
                                  : AppTheme.errorRed,
                            ),
                          ),
                        ],
                        const SizedBox(height: 16),
                        OutlinedButton.icon(
                          key: const Key('test_connection_button'),
                          onPressed: _testingConnection ? null : _testConnection,
                          icon: _testingConnection
                              ? const SizedBox(
                                  width: 16,
                                  height: 16,
                                  child: CircularProgressIndicator(strokeWidth: 2),
                                )
                              : const Icon(Icons.network_check_rounded),
                          label: const Text('Test Connection'),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildStatusIndicator(SyncState state) {
    switch (state) {
      case SyncState.syncing:
        return const SizedBox(
          width: 16,
          height: 16,
          child: CircularProgressIndicator(strokeWidth: 2),
        );
      case SyncState.success:
        return const Icon(Icons.check_circle_rounded, color: AppTheme.primaryGreen, size: 20);
      case SyncState.offline:
        return const Icon(Icons.cloud_off_rounded, color: Colors.grey, size: 20);
      case SyncState.error:
        return const Icon(Icons.error_outline_rounded, color: AppTheme.errorRed, size: 20);
      case SyncState.idle:
        return const Icon(Icons.cloud_done_outlined, color: AppTheme.primaryGreen, size: 20);
    }
  }

  String _statusText(SyncState state) {
    switch (state) {
      case SyncState.syncing:
        return 'Synchronizing...';
      case SyncState.success:
        return 'Synchronized';
      case SyncState.offline:
        return 'Offline';
      case SyncState.error:
        return 'Sync Error';
      case SyncState.idle:
        return 'Ready';
    }
  }
}

