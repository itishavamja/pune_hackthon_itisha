import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/api_client.dart';
import '../../core/config.dart';
import '../../core/theme.dart';
import '../../providers/providers.dart';
import '../../widgets/toast.dart';

/// Lets the user point the app at the backend (needed on a real phone: use the PC's LAN IP).
class ApiSettingsSheet extends ConsumerStatefulWidget {
  const ApiSettingsSheet({super.key});

  @override
  ConsumerState<ApiSettingsSheet> createState() => _ApiSettingsSheetState();
}

class _ApiSettingsSheetState extends ConsumerState<ApiSettingsSheet> {
  late final TextEditingController _url = TextEditingController(text: ref.read(apiUrlProvider));
  bool _testing = false;
  bool? _ok;
  String? _msg;

  @override
  void dispose() {
    _url.dispose();
    super.dispose();
  }

  String get _clean => _url.text.trim().replaceAll(RegExp(r'/+$'), '');

  bool get _valid {
    final u = Uri.tryParse(_clean);
    return u != null && (u.scheme == 'http' || u.scheme == 'https') && u.host.isNotEmpty;
  }

  Future<void> _test() async {
    if (!_valid) {
      setState(() {
        _ok = false;
        _msg = 'Enter a full address like http://192.168.1.5:8000';
      });
      return;
    }
    setState(() {
      _testing = true;
      _ok = null;
    });
    final client = ApiClient(_clean);
    try {
      final ok = await client.health();
      setState(() {
        _ok = ok;
        _msg = ok ? 'Connected. The backend is running.' : 'Reached a server, but it is not Dukaan360.';
      });
    } on ApiException catch (e) {
      setState(() {
        _ok = false;
        _msg = e.message;
      });
    } finally {
      client.close();
      if (mounted) setState(() => _testing = false);
    }
  }

  Future<void> _save() async {
    if (!_valid) {
      setState(() {
        _ok = false;
        _msg = 'Enter a full address like http://192.168.1.5:8000';
      });
      return;
    }
    await ref.read(sharedPrefsProvider).setString(kPrefApiUrl, _clean);
    ref.read(apiUrlProvider.notifier).state = _clean;
    invalidateAll(ref.invalidate);
    if (!mounted) return;
    Navigator.of(context).pop();
    showToast(context, 'Server address saved', kind: ToastKind.success);
  }

  @override
  Widget build(BuildContext context) {
    final presets = <(String, String)>[
      ('Android emulator', 'http://10.0.2.2:8000'),
      ('This computer', 'http://127.0.0.1:8000'),
    ];
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text('Server settings', style: context.tt.titleLarge),
          const SizedBox(height: 6),
          Text(
            'The app talks to the Dukaan360 backend. On a real phone, use your computer\'s Wi-Fi address and start the backend with --host 0.0.0.0.',
            style: TextStyle(color: context.muted, height: 1.45),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _url,
            keyboardType: TextInputType.url,
            autocorrect: false,
            onChanged: (_) => setState(() => _ok = null),
            decoration: const InputDecoration(labelText: 'Backend address', hintText: 'http://192.168.1.5:8000'),
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            children: [
              for (final (label, url) in presets)
                ActionChip(
                  label: Text(label),
                  onPressed: () => setState(() {
                    _url.text = url;
                    _ok = null;
                  }),
                ),
            ],
          ),
          if (_msg != null && _ok != null) ...[
            const SizedBox(height: 12),
            Row(
              children: [
                Icon(_ok! ? Icons.check_circle_rounded : Icons.error_rounded,
                    color: _ok! ? Brand.success : Brand.danger, size: 20),
                const SizedBox(width: 8),
                Expanded(child: Text(_msg!, style: TextStyle(color: _ok! ? Brand.success : Brand.danger))),
              ],
            ),
          ],
          const SizedBox(height: 18),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: _testing ? null : _test,
                  child: _testing
                      ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                      : const Text('Test connection'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(child: FilledButton(onPressed: _save, child: const Text('Save'))),
            ],
          ),
        ],
      ),
    );
  }
}
