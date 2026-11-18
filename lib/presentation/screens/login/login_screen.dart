import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:uuid/uuid.dart';

import '../../../core/errors/app_exception.dart';
import '../../../core/utils/api_token_notice.dart';
import '../../../core/utils/connection_diagnostics.dart';
import '../../../core/utils/l10n_extension.dart';
import '../../../data/datasources/remote/wavelog_remote_datasource.dart';
import '../../../data/models/station_model.dart';
import '../../../data/models/user_profile_model.dart';
import '../../../providers/connection_report.dart';
import '../../../providers/dio_provider.dart';
import '../../../providers/profile_provider.dart';
import '../../../providers/qso_provider.dart';
import '../../../providers/settings_provider.dart';
import '../../../providers/station_provider.dart';
import '../../../providers/statistics_provider.dart';
import '../../widgets/diagnostics/connection_diagnostics_dialog.dart';
import '../celebration/api_v2_celebration_screen.dart';

class LoginScreen extends ConsumerWidget {
  const LoginScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final profiles = ref.watch(profileProvider);
    final serverUrl = ref.watch(settingsProvider).serverUrl;

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.loginTitle),
        automaticallyImplyLeading: false,
        actions: [
          TextButton.icon(
            onPressed: () => context.push('/server-setup'),
            icon: const Icon(Icons.dns_outlined, size: 18),
            label: Text(l10n.serverBtn),
          ),
        ],
      ),
      body: profiles.when(
        data: (list) => list.isEmpty
            ? _EmptyState(serverUrl: serverUrl)
            : _ProfileList(profiles: list, serverUrl: serverUrl),
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('${context.l10n.error}: $e')),
      ),
      floatingActionButton: profiles.maybeWhen(
        data: (list) => list.isNotEmpty
            ? FloatingActionButton.extended(
                onPressed: () =>
                    _showAddProfileSheet(context, ref, serverUrl),
                icon: const Icon(Icons.person_add),
                label: Text(l10n.addAccountBtn),
              )
            : null,
        orElse: () => null,
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  final String serverUrl;
  const _EmptyState({required this.serverUrl});

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.account_circle_outlined,
              size: 80,
              color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.5),
            ),
            const SizedBox(height: 24),
            Text(
              l10n.loginTitle,
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: 32),
            FilledButton.icon(
              onPressed: () =>
                  _showAddProfileSheet(context, null, serverUrl),
              icon: const Icon(Icons.person_add),
              label: Text(l10n.addAccountBtn),
            ),
          ],
        ),
      ),
    );
  }
}

class _ProfileList extends ConsumerWidget {
  final List<UserProfileModel> profiles;
  final String serverUrl;

  const _ProfileList({required this.profiles, required this.serverUrl});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        ...profiles.map(
          (p) => _ProfileCard(
            profile: p,
            serverUrl: serverUrl,
            onDelete: () =>
                ref.read(profileProvider.notifier).deleteProfile(p.id),
          ),
        ),
      ],
    );
  }
}

class _ProfileCard extends ConsumerWidget {
  final UserProfileModel profile;
  final String serverUrl;
  final VoidCallback onDelete;

  const _ProfileCard({
    required this.profile,
    required this.serverUrl,
    required this.onDelete,
  });

  Future<void> _login(BuildContext context, WidgetRef ref) async {
    final notifier = ref.read(settingsProvider.notifier);

    if (!context.mounted) return;
    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => const PopScope(
        canPop: false,
        child: Center(child: CircularProgressIndicator()),
      ),
    );

    StationModel? autoStation;
    try {
      final remote = WavelogRemoteDatasource(
          dio: buildWavelogDio(serverUrl,
              bearerToken: profile.apiKey,
              allowInsecureSsl:
                  ref.read(settingsProvider).allowInsecureSsl));
      final stations = await remote.getStations();

      autoStation = stations.where((s) =>
          s.callsign.toUpperCase() == profile.callsign.toUpperCase()).firstOrNull;
      autoStation ??= stations.where((s) => s.isActive).firstOrNull;
      autoStation ??= stations.firstOrNull;

      if (autoStation != null) {
        final updated = profile.copyWith(
          defaultStationId: autoStation.id,
          defaultStationCallsign: autoStation.callsign,
          defaultStationName: autoStation.profileName,
        );
        await ref.read(profileProvider.notifier).updateProfile(updated);
      }
    } catch (e) {
      debugPrint('Auto-station fetch failed (non-fatal): $e');
    }

    await notifier.loginWithProfile(profile, autoStation);

    if (context.mounted) {
      ref.invalidate(stationProvider);
      ref.invalidate(qsoProvider);
      ref.invalidate(statisticsProvider);
      Navigator.of(context, rootNavigator: true).pop();
      context.go('/home');
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final initials = profile.callsign.isNotEmpty
        ? profile.callsign.substring(0, profile.callsign.length.clamp(0, 2))
        : '?';

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            CircleAvatar(
              radius: 28,
              backgroundColor: Theme.of(context).colorScheme.primaryContainer,
              child: Text(
                initials.toUpperCase(),
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: Theme.of(context).colorScheme.onPrimaryContainer,
                ),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    profile.callsign,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                  ),
                  Text(
                    profile.displayName,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Theme.of(context).colorScheme.secondary,
                        ),
                  ),
                  if (profile.defaultStationName != null)
                    Text(
                      profile.defaultStationName!,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: Theme.of(context).colorScheme.tertiary,
                          ),
                    ),
                ],
              ),
            ),
            FilledButton(
              onPressed: () => _login(context, ref),
              child: Text(l10n.signInBtn),
            ),
            PopupMenuButton<_ProfileAction>(
              icon: const Icon(Icons.more_vert),
              onSelected: (action) async {
                if (action == _ProfileAction.delete) {
                  final confirmed = await showDialog<bool>(
                    context: context,
                    builder: (dialogCtx) => AlertDialog(
                      title: Text(l10n.deleteProfileTitle),
                      content: Text(
                          l10n.deleteProfileConfirm(profile.callsign)),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.pop(dialogCtx, false),
                          child: Text(l10n.cancel),
                        ),
                        TextButton(
                          onPressed: () => Navigator.pop(dialogCtx, true),
                          child: Text(l10n.delete,
                              style: const TextStyle(color: Colors.red)),
                        ),
                      ],
                    ),
                  );
                  if (confirmed == true) onDelete();
                }
              },
              itemBuilder: (_) => [
                PopupMenuItem(
                  value: _ProfileAction.delete,
                  child: ListTile(
                    leading:
                        const Icon(Icons.delete_outline, color: Colors.red),
                    title: Text(l10n.delete,
                        style: const TextStyle(color: Colors.red)),
                    contentPadding: EdgeInsets.zero,
                    visualDensity: VisualDensity.compact,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

enum _ProfileAction { delete }

void _showAddProfileSheet(
    BuildContext context, WidgetRef? ref, String serverUrl) {
  Navigator.of(context).push(
    MaterialPageRoute(
      fullscreenDialog: true,
      builder: (ctx) => _AddProfileSheet(serverUrl: serverUrl),
    ),
  );
}

class _AddProfileSheet extends ConsumerStatefulWidget {
  final String serverUrl;
  const _AddProfileSheet({required this.serverUrl});

  @override
  ConsumerState<_AddProfileSheet> createState() => _AddProfileSheetState();
}

class _AddProfileSheetState extends ConsumerState<_AddProfileSheet> {
  final _formKey = GlobalKey<FormState>();
  final _nameCtrl = TextEditingController();
  final _callsignCtrl = TextEditingController();
  final _apiKeyCtrl = TextEditingController();
  bool _keyObscure = true;
  bool _loading = false;
  String? _error;

  bool _testingScopes = false;
  List<ScopeTestResult>? _scopeResults;

  @override
  void dispose() {
    _nameCtrl.dispose();
    _callsignCtrl.dispose();
    _apiKeyCtrl.dispose();
    super.dispose();
  }

  /// Lightweight probes per scope, see [scopeProbes]: read-only calls, plus
  /// the one write scope that can be checked without changing anything
  /// (radio:write, see [ScopeProbe.okStatuses]). Other write and delete scopes
  /// can't be tested without risking real data changes on the user's server,
  /// so they're left to the full scope guide.
  Future<List<ScopeTestResult>> _runScopeTests(
      Dio dio, String callsign) async {
    return [
      for (final probe in scopeProbes(callsign))
        ScopeTestResult(probe.scope, await runScopeProbe(dio, probe)),
    ];
  }

  Future<void> _runDiagnostics() {
    final callsign = _callsignCtrl.text.trim().toUpperCase();
    final token = _apiKeyCtrl.text.trim();
    final insecure = ref.read(settingsProvider).allowInsecureSsl;
    return showConnectionDiagnostics(
      context,
      run: () => buildConnectionReport(
        serverUrl: widget.serverUrl,
        token: token,
        callsign: callsign,
        allowInsecureSsl: insecure,
      ),
    );
  }

  /// A failure that says nothing about the token's scopes: the connection to
  /// the server did not work.
  bool _isConnectionFailure(Object e) =>
      e is NetworkException ||
      e is TimeoutException ||
      e is SslException ||
      e is LocalNetworkPermissionException;

  Future<void> _addAndLogin() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _loading = true;
      _error = null;
      _testingScopes = false;
      _scopeResults = null;
    });

    final callsign = _callsignCtrl.text.trim().toUpperCase();
    final apiKey = _apiKeyCtrl.text.trim();
    final dio = buildWavelogDio(widget.serverUrl,
        bearerToken: apiKey,
        allowInsecureSsl: ref.read(settingsProvider).allowInsecureSsl);

    // The station list is all sign-in needs, so it goes first and alone: a
    // server that limits requests, or bans a client that sends many in a
    // row, no longer fails a sign-in that would have worked.
    List<StationModel> stations = [];
    try {
      final remote = WavelogRemoteDatasource(dio: dio);
      stations = await remote.getStations();
    } catch (e) {
      if (!mounted) return;
      // Only a failure that can be about the token is worth the scope checks
      // (which show what is missing); when the connection itself failed they
      // would only repeat the failure for every scope, and wait for each.
      final checkScopes = !_isConnectionFailure(e);
      setState(() {
        _loading = false;
        _testingScopes = checkScopes;
        _error = '${context.l10n.loginFailed}: $e';
      });
      if (checkScopes) {
        final results = await _runScopeTests(dio, callsign);
        if (!mounted) return;
        setState(() {
          _scopeResults = results;
          _testingScopes = false;
        });
      }
      return;
    }

    StationModel? match = stations
        .where((s) => s.callsign.toUpperCase() == callsign)
        .firstOrNull;
    match ??= stations.where((s) => s.isActive).firstOrNull;
    match ??= stations.firstOrNull;

    final profile = UserProfileModel(
      id: const Uuid().v4(),
      displayName: _nameCtrl.text.trim(),
      callsign: callsign,
      apiKey: apiKey,
      defaultStationId: match?.id,
      defaultStationCallsign: match?.callsign,
      defaultStationName: match?.profileName,
    );

    await ref.read(profileProvider.notifier).addProfile(profile);
    await ref.read(settingsProvider.notifier).loginWithProfile(profile, match);
    // Fresh setup — this account was just created with a v2 (wl2_-style) key,
    // so the "you need to migrate to API v2" reminder on Home is irrelevant
    // to them. Only pre-existing installs going through the migration screen
    // should ever see that notice.
    await ApiTokenNotice.markDismissed();
    // Same for the one-time "server patch no longer needed" screen: a brand
    // new install never had a patch to begin with, so it must not appear on
    // the second launch. Existing users still see it via the splash screen.
    await ApiV2CelebrationScreen.markShown();

    if (mounted) {
      ref.invalidate(stationProvider);
      ref.invalidate(qsoProvider);
      ref.invalidate(statisticsProvider);
      Navigator.of(context).pop();
      context.go('/home');
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.addAccountBtn),
        leading: IconButton(
          icon: const Icon(Icons.close),
          onPressed: _loading ? null : () => Navigator.of(context).pop(),
        ),
      ),
      body: SingleChildScrollView(
        padding: EdgeInsets.only(
          left: 24,
          right: 24,
          top: 24,
          bottom: MediaQuery.of(context).viewInsets.bottom + 24,
        ),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              TextFormField(
                controller: _nameCtrl,
                decoration: InputDecoration(
                  labelText: '${l10n.displayName} *',
                  prefixIcon: const Icon(Icons.person_outline),
                ),
                textCapitalization: TextCapitalization.words,
                validator: (v) =>
                    (v == null || v.trim().isEmpty) ? l10n.displayName : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _callsignCtrl,
                decoration: InputDecoration(
                  labelText: '${l10n.callsign} *',
                  hintText: 'TA4RX',
                  prefixIcon: const Icon(Icons.cell_tower_outlined),
                ),
                textCapitalization: TextCapitalization.characters,
                validator: (v) =>
                    (v == null || v.trim().isEmpty) ? l10n.callsign : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _apiKeyCtrl,
                decoration: InputDecoration(
                  labelText: '${l10n.apiKeyLabel} *',
                  prefixIcon: const Icon(Icons.key),
                  suffixIcon: IconButton(
                    icon: Icon(
                        _keyObscure ? Icons.visibility_off : Icons.visibility),
                    onPressed: () =>
                        setState(() => _keyObscure = !_keyObscure),
                  ),
                ),
                obscureText: _keyObscure,
                autocorrect: false,
                validator: (v) =>
                    (v == null || v.trim().isEmpty) ? l10n.apiKeyLabel : null,
              ),
              Align(
                alignment: Alignment.centerRight,
                child: TextButton.icon(
                  onPressed: () => context.push('/api-scope-guide'),
                  icon: const Icon(Icons.help_outline, size: 16),
                  label: Text(l10n.apiScopeGuideBtn,
                      style: const TextStyle(fontSize: 13)),
                  style: TextButton.styleFrom(
                    visualDensity: VisualDensity.compact,
                    padding: const EdgeInsets.symmetric(horizontal: 0),
                  ),
                ),
              ),
              if (_testingScopes || _scopeResults != null) ...[
                const SizedBox(height: 8),
                ScopeTestPanel(
                  testing: _testingScopes,
                  results: _scopeResults,
                ),
              ],
              if (_error != null) ...[
                const SizedBox(height: 12),
                Row(
                  children: [
                    const Icon(Icons.error_outline, color: Colors.red, size: 16),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        _error!,
                        style: const TextStyle(color: Colors.red, fontSize: 13),
                      ),
                    ),
                  ],
                ),
                Align(
                  alignment: Alignment.centerLeft,
                  child: TextButton.icon(
                    onPressed: _runDiagnostics,
                    icon: const Icon(Icons.bug_report_outlined, size: 16),
                    label: Text(l10n.connectionDiagnosticsBtn,
                        style: const TextStyle(fontSize: 13)),
                    style: TextButton.styleFrom(
                      visualDensity: VisualDensity.compact,
                      padding: const EdgeInsets.symmetric(horizontal: 0),
                    ),
                  ),
                ),
              ],
              const SizedBox(height: 24),
              FilledButton.icon(
                onPressed: _loading ? null : _addAndLogin,
                icon: _loading
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: Colors.white),
                      )
                    : const Icon(Icons.login),
                label: Text(_loading ? l10n.validating : l10n.signInBtn),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Scope test result & panel ────────────────────────────────────────────────

/// radio:write is the one write scope that can be tested without touching
/// data: Wavelog checks the scope first (403 without it) and only then the
/// body, and an empty body is rejected as a validation error (400) before
/// anything is written. Reaching that 400 means the scope is there.
/// Null when it can't be told (network, or a server without the endpoint).
Future<bool?> probeRadioWriteScope(Dio dio) =>
    runScopeProbe(dio, scopeProbes('').last);

/// [passed]: true = scope confirmed working, false = server rejected it
/// (401/403 — likely missing from the token), null = could not be
/// determined (network hiccup etc.) and isn't held against the user.
class ScopeTestResult {
  final String scopeKey;
  final bool? passed;
  const ScopeTestResult(this.scopeKey, this.passed);
}

/// Maps a scope key to its human description, reusing the same l10n strings
/// as the full API Scope Guide screen so the two stay in sync.
String _scopeDescription(BuildContext context, String scopeKey) {
  final l10n = context.l10n;
  switch (scopeKey) {
    case 'station:read':
      return l10n.scopeStationRead;
    case 'logbook:read':
      return l10n.scopeLogbookRead;
    case 'contest:read':
      return l10n.scopeContestRead;
    case 'statistic:read':
      return l10n.scopeStatisticsRead;
    case 'lookup:read':
      return l10n.scopeLookupRead;
    case 'confirmation:read':
      return l10n.scopeConfirmationRead;
    case 'qso:read':
      return l10n.scopeQsoRead;
    case 'radio:write':
      return l10n.scopeRadioWrite;
    default:
      return scopeKey;
  }
}

class ScopeTestPanel extends StatelessWidget {
  final bool testing;
  final List<ScopeTestResult>? results;
  const ScopeTestPanel({super.key, required this.testing, required this.results});

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final cs = Theme.of(context).colorScheme;

    if (testing) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: cs.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Row(
          children: [
            const SizedBox(
              width: 14,
              height: 14,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
            const SizedBox(width: 10),
            Text(l10n.scopeTestRunning,
                style: TextStyle(fontSize: 12, color: cs.onSurfaceVariant)),
          ],
        ),
      );
    }

    final list = results;
    if (list == null || list.isEmpty) return const SizedBox.shrink();

    final failed = list.where((r) => r.passed == false).toList();
    // A check that got no answer is not a pass: with no connection to the
    // server every check ends that way, and "all present" would be wrong.
    final unverified = list.where((r) => r.passed == null).toList();
    final allGood = failed.isEmpty && unverified.isEmpty;

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: cs.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: (allGood ? Colors.green : Colors.orange).withValues(alpha: 0.4),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                allGood ? Icons.check_circle_rounded : Icons.warning_amber_rounded,
                size: 16,
                color: allGood ? Colors.green : Colors.orange,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  allGood
                      ? l10n.scopeTestAllPassed
                      : failed.isEmpty
                          ? l10n.scopeTestSomeUnverified
                          : l10n.scopeTestSomeFailed,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color:
                        allGood ? Colors.green.shade700 : Colors.orange.shade800,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          ...list.map((r) => Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(
                      r.passed == true
                          ? Icons.check_circle_outline
                          : r.passed == false
                              ? Icons.cancel_outlined
                              : Icons.help_outline,
                      size: 14,
                      color: r.passed == true
                          ? Colors.green
                          : r.passed == false
                              ? Colors.red
                              : cs.onSurfaceVariant,
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '${r.scopeKey} — ${_scopeDescription(context, r.scopeKey)}',
                            style: TextStyle(
                              fontSize: 11.5,
                              fontFamily: 'monospace',
                              color: r.passed == false
                                  ? Colors.red.shade700
                                  : cs.onSurfaceVariant,
                            ),
                          ),
                          if (r.passed == false)
                            Padding(
                              padding: const EdgeInsets.only(top: 1),
                              child: Text(
                                l10n.scopeTestAddHint,
                                style: TextStyle(
                                  fontSize: 11,
                                  fontStyle: FontStyle.italic,
                                  color: Colors.red.shade400,
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ],
                ),
              )),
        ],
      ),
    );
  }
}

