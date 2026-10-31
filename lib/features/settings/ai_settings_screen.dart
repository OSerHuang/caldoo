/// The 模型设置 page: the BYOK form, one level below the 设置 hub.
///
/// API key (secure storage), base URL and model (non-secret prefs), plus a
/// "测试连接" probe that surfaces the typed `AiError` honestly — no fake
/// success. It keeps its explicit 保存 action; the display-unit preferences
/// live on their own page ([DisplaySettingsScreen]).
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:caldoo/features/settings/ai_error_text.dart';
import 'package:caldoo/features/settings/settings_providers.dart';
import 'package:caldoo/l10n/app_strings.dart';

/// The 模型设置 screen.
class AiSettingsScreen extends ConsumerStatefulWidget {
  /// Creates the model-settings form.
  const AiSettingsScreen({super.key});

  @override
  ConsumerState<AiSettingsScreen> createState() => _AiSettingsScreenState();
}

class _AiSettingsScreenState extends ConsumerState<AiSettingsScreen> {
  final TextEditingController _keyController = TextEditingController();
  final TextEditingController _baseUrlController = TextEditingController();
  final TextEditingController _modelController = TextEditingController();

  /// The saved config is seeded into the fields exactly once; the key field
  /// stays empty forever (write-only: the secret is never read back into
  /// the UI).
  bool _seeded = false;

  @override
  void dispose() {
    _keyController.dispose();
    _baseUrlController.dispose();
    _modelController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    await ref
        .read(settingsControllerProvider.notifier)
        .save(
          baseUrl: _baseUrlController.text,
          model: _modelController.text,
          apiKey: _keyController.text,
        );
    if (mounted) {
      _keyController.clear();
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(S.of(context).savedSnack)));
    }
  }

  Future<void> _testConnection() async {
    await ref
        .read(settingsControllerProvider.notifier)
        .saveAndTestConnection(
          baseUrl: _baseUrlController.text,
          model: _modelController.text,
          apiKey: _keyController.text,
        );
    if (mounted &&
        ref.read(settingsControllerProvider).value?.testOutcome
            is ConnectionTestSuccess) {
      _keyController.clear();
    }
  }

  @override
  Widget build(BuildContext context) {
    final AsyncValue<SettingsViewState> asyncState = ref.watch(
      settingsControllerProvider,
    );
    return Scaffold(
      appBar: AppBar(title: Text(S.of(context).settingsSectionModel)),
      body: switch (asyncState) {
        AsyncLoading() => const Center(child: CircularProgressIndicator()),
        AsyncError() => Center(child: Text(S.of(context).settingsLoadFailed)),
        AsyncData(:final value) => _buildForm(context, value),
      },
    );
  }

  Widget _buildForm(BuildContext context, SettingsViewState state) {
    if (!_seeded) {
      _baseUrlController.text = state.settings.baseUrl;
      _modelController.text = state.settings.model;
      _seeded = true;
    }
    return ListView(
      padding: const EdgeInsets.all(16),
      children: <Widget>[
        TextField(
          key: const Key('settings_api_key_field'),
          controller: _keyController,
          obscureText: true,
          autocorrect: false,
          enableSuggestions: false,
          decoration: InputDecoration(
            labelText: S.of(context).apiKeyLabel,
            hintText: state.hasSavedKey
                ? S.of(context).apiKeyHintSaved
                : S.of(context).apiKeyHintEmpty,
            helperText: S.of(context).apiKeyHelper,
          ),
        ),
        const SizedBox(height: 16),
        TextField(
          key: const Key('settings_base_url_field'),
          controller: _baseUrlController,
          autocorrect: false,
          enableSuggestions: false,
          keyboardType: TextInputType.url,
          decoration: InputDecoration(
            labelText: S.of(context).baseUrlLabel,
            helperText: S.of(context).baseUrlHelper,
          ),
        ),
        const SizedBox(height: 16),
        TextField(
          key: const Key('settings_model_field'),
          controller: _modelController,
          autocorrect: false,
          enableSuggestions: false,
          decoration: InputDecoration(labelText: S.of(context).modelLabel),
        ),
        const SizedBox(height: 24),
        FilledButton(
          key: const Key('settings_save_button'),
          onPressed: _save,
          child: Text(S.of(context).save),
        ),
        const SizedBox(height: 12),
        ValueListenableBuilder<TextEditingValue>(
          valueListenable: _keyController,
          builder: (context, keyValue, _) {
            final bool canTest =
                keyValue.text.trim().isNotEmpty || state.hasSavedKey;
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                OutlinedButton(
                  key: const Key('settings_test_button'),
                  onPressed: canTest ? _testConnection : null,
                  child: Text(S.of(context).testConnection),
                ),
                if (!canTest)
                  Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Text(
                      S.of(context).testNeedKey,
                      key: const Key('settings_test_disabled_hint'),
                    ),
                  ),
              ],
            );
          },
        ),
        const SizedBox(height: 16),
        _OutcomeView(outcome: state.testOutcome),
      ],
    );
  }
}

class _OutcomeView extends StatelessWidget {
  const _OutcomeView({required this.outcome});

  final ConnectionTestOutcome outcome;

  @override
  Widget build(BuildContext context) {
    return switch (outcome) {
      ConnectionTestIdle() => const SizedBox.shrink(),
      ConnectionTestRunning() => const Center(
        child: Padding(
          padding: EdgeInsets.all(8),
          child: CircularProgressIndicator(),
        ),
      ),
      ConnectionTestSuccess() => Text(
        S.of(context).connectionSuccess,
        key: const Key('settings_test_result'),
        textAlign: TextAlign.center,
      ),
      ConnectionTestFailure(:final error) => Text(
        describeAiError(error),
        key: const Key('settings_test_result'),
        textAlign: TextAlign.center,
        style: TextStyle(color: Theme.of(context).colorScheme.error),
      ),
    };
  }
}
