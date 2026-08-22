import 'package:chocolog/app/theme.dart';
import 'package:chocolog/features/account/data/supabase_auth_repository.dart';
import 'package:chocolog/features/account/data/supabase_profile_repository.dart';
import 'package:chocolog/features/friends/data/supabase_friends_repository.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:qr_flutter/qr_flutter.dart';

class FriendsScreen extends ConsumerStatefulWidget {
  const FriendsScreen({super.key});

  @override
  ConsumerState<FriendsScreen> createState() => _FriendsScreenState();
}

class _FriendsScreenState extends ConsumerState<FriendsScreen> {
  final _publicIdController = TextEditingController();
  Future<FriendsSnapshot>? _friendsFuture;
  Future<SupabaseProfile?>? _profileFuture;
  String? _loadedUserId;
  var _sending = false;

  @override
  void initState() {
    super.initState();
  }

  @override
  void dispose() {
    _publicIdController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final session = ref.watch(supabaseSessionProvider).valueOrNull;
    if (session == null) {
      _loadedUserId = null;
      _friendsFuture = null;
      _profileFuture = null;
      return const _SignInPrompt();
    }
    if (_loadedUserId != session.user.id) {
      _loadedUserId = session.user.id;
      _friendsFuture = _loadFriends();
      _profileFuture = ref
          .read(supabaseProfileRepositoryProvider)
          .currentProfile();
    }
    return Scaffold(
      appBar: AppBar(
        title: const Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.group_rounded, size: 25),
            SizedBox(width: 8),
            Text('友人と共有'),
          ],
        ),
      ),
      body: RefreshIndicator(
        onRefresh: _refresh,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
          children: [
            FutureBuilder<SupabaseProfile?>(
              future: _profileFuture!,
              builder: (context, snapshot) {
                final profile = snapshot.data;
                if (profile == null) return const SizedBox.shrink();
                return Card(
                  child: ListTile(
                    leading: const Icon(Icons.badge_outlined),
                    title: Text(profile.displayName),
                    subtitle: Text('あなたの公開ID  ${profile.publicId}'),
                    trailing: IconButton(
                      tooltip: '公開IDをコピー',
                      onPressed: () => _copy(profile.publicId),
                      icon: const Icon(Icons.copy_rounded),
                    ),
                    onTap: () => _showQr(profile.publicId),
                  ),
                );
              },
            ),
            const SizedBox(height: 16),
            const _SectionTitle('友人を追加'),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    TextField(
                      controller: _publicIdController,
                      textCapitalization: TextCapitalization.characters,
                      textInputAction: TextInputAction.done,
                      onSubmitted: (_) => _sendRequest(),
                      decoration: const InputDecoration(
                        labelText: '友人の公開ID',
                        hintText: 'CL-7K4P9Q',
                        prefixIcon: Icon(Icons.search_rounded),
                      ),
                    ),
                    const SizedBox(height: 10),
                    FilledButton.icon(
                      onPressed: _sending ? null : _sendRequest,
                      icon: const Icon(Icons.person_add_rounded),
                      label: Text(_sending ? '送信中…' : '友人申請を送る'),
                    ),
                  ],
                ),
              ),
            ),
            FutureBuilder<FriendsSnapshot>(
              future: _friendsFuture!,
              builder: (context, snapshot) {
                if (snapshot.hasError) {
                  return Padding(
                    padding: const EdgeInsets.only(top: 20),
                    child: _ErrorCard(onRetry: _refresh),
                  );
                }
                if (!snapshot.hasData) {
                  return const Padding(
                    padding: EdgeInsets.all(32),
                    child: Center(child: CircularProgressIndicator()),
                  );
                }
                final data = snapshot.requireData;
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    if (data.requests.isNotEmpty) ...[
                      const _SectionTitle('申請'),
                      Card(
                        child: Column(
                          children: [
                            for (final (index, request)
                                in data.requests.indexed) ...[
                              if (index > 0) const Divider(height: 1),
                              _RequestTile(
                                request: request,
                                onAccept: request.isIncoming
                                    ? () => _accept(request.id)
                                    : null,
                                onReject: request.isIncoming
                                    ? () => _reject(request.id)
                                    : () => _cancel(request.id),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ],
                    const _SectionTitle('友人一覧'),
                    Card(
                      child: data.friends.isEmpty
                          ? const Padding(
                              padding: EdgeInsets.all(20),
                              child: Text('まだ友人がいません。公開IDを交換して追加しましょう。'),
                            )
                          : Column(
                              children: [
                                for (final (index, friend)
                                    in data.friends.indexed) ...[
                                  if (index > 0) const Divider(height: 1),
                                  ListTile(
                                    leading: const Icon(Icons.person_rounded),
                                    title: Text(friend.profile.displayName),
                                    subtitle: Text(friend.profile.publicId),
                                    onTap: () => context.push(
                                      '/friends/${friend.profile.userId}?name=${Uri.encodeComponent(friend.profile.displayName)}',
                                    ),
                                    trailing: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        const Icon(Icons.chevron_right),
                                        IconButton(
                                          tooltip: '友人を解除',
                                          onPressed: () => _remove(friend),
                                          icon: const Icon(
                                            Icons.person_remove_outlined,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ],
                            ),
                    ),
                  ],
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Future<FriendsSnapshot> _loadFriends() {
    return ref.read(supabaseFriendsRepositoryProvider).load();
  }

  Future<void> _refresh() async {
    setState(() {
      _friendsFuture = _loadFriends();
      _profileFuture = ref
          .read(supabaseProfileRepositoryProvider)
          .currentProfile();
    });
    await _friendsFuture!;
  }

  Future<void> _sendRequest() async {
    final publicId = _publicIdController.text.trim().toUpperCase();
    if (publicId.isEmpty) return;
    setState(() => _sending = true);
    try {
      await ref
          .read(supabaseFriendsRepositoryProvider)
          .sendRequestByPublicId(publicId);
      _publicIdController.clear();
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('友人申請を送りました')));
      await _refresh();
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('申請できませんでした: $error')));
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  Future<void> _accept(String requestId) async {
    await _runAction(
      () =>
          ref.read(supabaseFriendsRepositoryProvider).acceptRequest(requestId),
    );
  }

  Future<void> _reject(String requestId) async {
    await _runAction(
      () =>
          ref.read(supabaseFriendsRepositoryProvider).rejectRequest(requestId),
    );
  }

  Future<void> _cancel(String requestId) async {
    await _runAction(
      () =>
          ref.read(supabaseFriendsRepositoryProvider).cancelRequest(requestId),
    );
  }

  Future<void> _remove(Friendship friendship) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('友人を解除しますか？'),
        content: Text('${friendship.profile.displayName}さんの履歴が見えなくなります。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('キャンセル'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('解除'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    await _runAction(
      () => ref
          .read(supabaseFriendsRepositoryProvider)
          .removeFriend(friendship.id),
    );
  }

  Future<void> _runAction(Future<void> Function() action) async {
    try {
      await action();
      await _refresh();
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('更新できませんでした: $error')));
    }
  }

  Future<void> _copy(String value) async {
    await Clipboard.setData(ClipboardData(text: value));
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('公開IDをコピーしました')));
  }

  Future<void> _showQr(String publicId) {
    return showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('友人追加用QRコード'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            QrImageView(data: publicId, size: 220),
            const SizedBox(height: 12),
            Text(publicId, style: Theme.of(context).textTheme.titleMedium),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => _copy(publicId),
            child: const Text('IDをコピー'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('閉じる'),
          ),
        ],
      ),
    );
  }
}

class _SignInPrompt extends ConsumerWidget {
  const _SignInPrompt();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      appBar: AppBar(
        title: const Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.group_rounded, size: 25),
            SizedBox(width: 8),
            Text('フレンド'),
          ],
        ),
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(28),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.group_outlined, size: 56),
              const SizedBox(height: 16),
              Text(
                '友人のトレーニング履歴を見たり、\n自分の履歴を共有できます',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 20),
              FilledButton.icon(
                onPressed: () async {
                  try {
                    await ref
                        .read(supabaseAuthRepositoryProvider)
                        .signInWithGoogle();
                  } catch (error) {
                    if (!context.mounted) return;
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('ログインを開始できませんでした: $error')),
                    );
                  }
                },
                icon: const Icon(Icons.login_rounded),
                label: const Text('Googleでログイン'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _RequestTile extends StatelessWidget {
  const _RequestTile({
    required this.request,
    this.onAccept,
    required this.onReject,
  });

  final FriendRequest request;
  final VoidCallback? onAccept;
  final VoidCallback onReject;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: const Icon(Icons.person_add_alt_1_rounded),
      title: Text(request.counterpart.displayName),
      subtitle: Text(request.counterpart.publicId),
      trailing: Wrap(
        spacing: 4,
        children: [
          if (onAccept != null)
            IconButton(
              tooltip: '承認',
              onPressed: onAccept,
              icon: const Icon(Icons.check_rounded),
            ),
          IconButton(
            tooltip: request.isIncoming ? '拒否' : 'キャンセル',
            onPressed: onReject,
            icon: const Icon(Icons.close_rounded),
          ),
        ],
      ),
    );
  }
}

class _ErrorCard extends StatelessWidget {
  const _ErrorCard({required this.onRetry});

  final Future<void> Function() onRetry;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            const Text('友人情報を取得できませんでした'),
            const SizedBox(height: 8),
            OutlinedButton(onPressed: onRetry, child: const Text('再読み込み')),
          ],
        ),
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle(this.label);

  final String label;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(4, 22, 4, 8),
    child: Text(
      label,
      style: Theme.of(
        context,
      ).textTheme.titleSmall?.copyWith(color: ChocoLogColors.muted),
    ),
  );
}
