import 'package:chocolog/features/friends/data/supabase_friends_repository.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('公開ID検索結果を友人プロフィールに変換できる', () {
    final profile = FriendProfile.fromMap({
      'user_id': 'user-2',
      'public_id': 'CL-7K4P9Q',
      'display_name': '友人',
    });

    expect(profile.userId, 'user-2');
    expect(profile.publicId, 'CL-7K4P9Q');
    expect(profile.displayName, '友人');
  });

  test('友人申請と友人一覧のスナップショットを保持できる', () {
    const profile = FriendProfile(
      userId: 'user-2',
      publicId: 'CL-7K4P9Q',
      displayName: '友人',
    );
    const snapshot = FriendsSnapshot(
      requests: [
        FriendRequest(id: 'request-1', counterpart: profile, isIncoming: true),
      ],
      friends: [Friendship(id: 'friendship-1', profile: profile)],
    );

    expect(snapshot.requests.single.isIncoming, isTrue);
    expect(snapshot.friends.single.profile.publicId, 'CL-7K4P9Q');
  });
}
