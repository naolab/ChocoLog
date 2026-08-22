import 'package:chocolog/core/supabase/supabase_service.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

final supabaseFriendsRepositoryProvider = Provider<SupabaseFriendsRepository>(
  (ref) => SupabaseFriendsRepository(),
);

class FriendProfile {
  const FriendProfile({
    required this.userId,
    required this.publicId,
    required this.displayName,
  });

  final String userId;
  final String publicId;
  final String displayName;

  factory FriendProfile.fromMap(Map<String, dynamic> map) => FriendProfile(
    userId: (map['user_id'] ?? map['id']) as String,
    publicId: map['public_id'] as String,
    displayName: map['display_name'] as String,
  );
}

class FriendRequest {
  const FriendRequest({
    required this.id,
    required this.counterpart,
    required this.isIncoming,
  });

  final String id;
  final FriendProfile counterpart;
  final bool isIncoming;
}

class Friendship {
  const Friendship({required this.id, required this.profile});

  final String id;
  final FriendProfile profile;
}

class FriendsSnapshot {
  const FriendsSnapshot({required this.requests, required this.friends});

  final List<FriendRequest> requests;
  final List<Friendship> friends;
}

class SupabaseFriendsRepository {
  SupabaseClient get _client =>
      SupabaseService.client ??
      (throw StateError('Supabase has not been initialized'));

  User get _user => _client.auth.currentUser ?? (throw StateError('ログインが必要です'));

  Future<FriendProfile?> findByPublicId(String publicId) async {
    final rows = await _client.rpc(
      'find_profile_by_public_id',
      params: {'p_public_id': publicId.trim()},
    );
    if (rows is! List || rows.isEmpty) return null;
    return FriendProfile.fromMap(Map<String, dynamic>.from(rows.first as Map));
  }

  Future<void> sendRequestByPublicId(String publicId) async {
    final target = await findByPublicId(publicId);
    if (target == null) throw StateError('公開IDが見つかりません');
    if (target.userId == _user.id) throw StateError('自分自身には申請できません');
    await _client.from('friend_requests').insert({
      'requester_id': _user.id,
      'target_id': target.userId,
      'status': 'pending',
    });
  }

  Future<FriendsSnapshot> load() async {
    final userId = _user.id;
    final requestRows = await _client
        .from('friend_requests')
        .select('id, requester_id, target_id, status, created_at')
        .or('requester_id.eq.$userId,target_id.eq.$userId')
        .eq('status', 'pending')
        .order('created_at', ascending: false);
    final friendshipRows = await _client
        .from('friendships')
        .select('id, requester_id, addressee_id, status, created_at')
        .or('requester_id.eq.$userId,addressee_id.eq.$userId')
        .eq('status', 'accepted')
        .order('created_at', ascending: false);

    final counterpartIds = <String>{
      for (final row in requestRows)
        (row['requester_id'] == userId ? row['target_id'] : row['requester_id'])
            as String,
      for (final row in friendshipRows)
        (row['requester_id'] == userId
                ? row['addressee_id']
                : row['requester_id'])
            as String,
    };
    final profiles = await _profilesByIds(counterpartIds);

    return FriendsSnapshot(
      requests: [
        for (final row in requestRows)
          if (profiles[row['requester_id'] == userId
                  ? row['target_id'] as String
                  : row['requester_id'] as String]
              case final profile?)
            FriendRequest(
              id: row['id'] as String,
              counterpart: profile,
              isIncoming: row['target_id'] == userId,
            ),
      ],
      friends: [
        for (final row in friendshipRows)
          if (profiles[row['requester_id'] == userId
                  ? row['addressee_id'] as String
                  : row['requester_id'] as String]
              case final profile?)
            Friendship(id: row['id'] as String, profile: profile),
      ],
    );
  }

  Future<void> acceptRequest(String requestId) =>
      _client.rpc('accept_friend_request', params: {'p_request_id': requestId});

  Future<void> rejectRequest(String requestId) async {
    await (_client.from('friend_requests').update({'status': 'rejected'})
      ..eq('id', requestId)
      ..eq('target_id', _user.id)
      ..eq('status', 'pending'));
  }

  Future<void> cancelRequest(String requestId) async {
    await (_client.from('friend_requests').update({'status': 'cancelled'})
      ..eq('id', requestId)
      ..eq('requester_id', _user.id)
      ..eq('status', 'pending'));
  }

  Future<void> removeFriend(String friendshipId) async {
    await (_client.from('friendships').delete()
      ..eq('id', friendshipId)
      ..eq('status', 'accepted'));
  }

  Future<Map<String, FriendProfile>> _profilesByIds(Set<String> ids) async {
    if (ids.isEmpty) return const {};
    final rows = await _client
        .from('profiles')
        .select('id, public_id, display_name')
        .inFilter('id', ids.toList());
    return {
      for (final row in rows) (row['id'] as String): FriendProfile.fromMap(row),
    };
  }
}
