import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

class StudioItem {
  const StudioItem({
    required this.id,
    required this.name,
    required this.address,
    required this.access,
    required this.equipmentUnits,
  });

  final String id;
  final String name;
  final String address;
  final String access;
  final Map<String, int> equipmentUnits;

  Map<String, Object> toJson() => {
    'id': id,
    'name': name,
    'address': address,
    'access': access,
    'equipmentUnits': equipmentUnits,
  };

  factory StudioItem.fromJson(Map<String, dynamic> json) => StudioItem(
    id: json['id'] as String,
    name: json['name'] as String,
    address: json['address'] as String? ?? '',
    access: json['access'] as String? ?? '',
    equipmentUnits: (json['equipmentUnits'] as Map<String, dynamic>? ?? {}).map(
      (key, value) => MapEntry(key, value as int),
    ),
  );
}

class StudioRepository {
  StudioRepository._();

  static final instance = StudioRepository._();
  static const _studiosUrl =
      'https://chocozap.g.kuroco.app/rcms-api/34/studios?cnt=2500';
  static const _machinesUrl =
      'https://chocozap.g.kuroco.app/rcms-api/57/training_machines';
  static const _favoriteIdsKey = 'studios.favoriteIds';
  static const _preferredStudioIdKey = 'studios.preferredId';
  static const _preferredStudioConfiguredKey = 'studios.preferredConfigured';
  static const _cacheLifetime = Duration(hours: 24);

  List<StudioItem>? _memoryCache;

  Future<List<StudioItem>> load({bool forceRefresh = false}) async {
    if (!forceRefresh && _memoryCache != null) return _memoryCache!;
    final cached = await _readCache();
    if (!forceRefresh && cached != null && !cached.isExpired) {
      return _memoryCache = cached.items;
    }
    try {
      final fresh = await _fetch();
      _memoryCache = fresh;
      await _writeCache(fresh);
      return fresh;
    } catch (_) {
      if (cached != null) return _memoryCache = cached.items;
      rethrow;
    }
  }

  Future<List<StudioItem>> search(
    String query, {
    bool forceRefresh = false,
  }) async {
    final studios = await load(forceRefresh: forceRefresh);
    final normalized = query.trim().toLowerCase();
    if (normalized.isEmpty) return studios.take(100).toList();
    return studios
        .where(
          (studio) =>
              studio.name.toLowerCase().contains(normalized) ||
              studio.address.toLowerCase().contains(normalized) ||
              studio.access.toLowerCase().contains(normalized),
        )
        .take(100)
        .toList();
  }

  Future<StudioItem?> findById(String id) async {
    final studios = await load();
    for (final studio in studios) {
      if (studio.id == id) return studio;
    }
    return null;
  }

  Future<Set<String>> favoriteIds() async {
    final preferences = await SharedPreferences.getInstance();
    return (preferences.getStringList(_favoriteIdsKey) ?? const []).toSet();
  }

  Future<void> setFavorite(String id, bool favorite) async {
    final preferences = await SharedPreferences.getInstance();
    final ids = await favoriteIds();
    favorite ? ids.add(id) : ids.remove(id);
    await preferences.setStringList(_favoriteIdsKey, ids.toList()..sort());
    if (!favorite && preferences.getString(_preferredStudioIdKey) == id) {
      await preferences.remove(_preferredStudioIdKey);
    }
  }

  Future<List<StudioItem>> favorites() async {
    final ids = await favoriteIds();
    if (ids.isEmpty) return const [];
    return (await load()).where((studio) => ids.contains(studio.id)).toList();
  }

  Future<StudioItem?> preferredStudio() async {
    final preferences = await SharedPreferences.getInstance();
    final preferredId = preferences.getString(_preferredStudioIdKey);
    if (preferences.getBool(_preferredStudioConfiguredKey) == true &&
        preferredId == null) {
      return null;
    }
    final favoriteIds = await this.favoriteIds();
    final targetId = preferredId ?? favoriteIds.firstOrNull;
    if (targetId == null) return null;
    return findById(targetId);
  }

  Future<void> setPreferredStudio(StudioItem? studio) async {
    final preferences = await SharedPreferences.getInstance();
    if (studio == null) {
      await preferences.remove(_preferredStudioIdKey);
      await preferences.setBool(_preferredStudioConfiguredKey, true);
      return;
    }
    await setFavorite(studio.id, true);
    await preferences.setString(_preferredStudioIdKey, studio.id);
    await preferences.setBool(_preferredStudioConfiguredKey, true);
  }

  Future<List<StudioItem>> _fetch() async {
    final responses = await Future.wait([
      http.get(Uri.parse(_studiosUrl)).timeout(const Duration(seconds: 20)),
      http.get(Uri.parse(_machinesUrl)).timeout(const Duration(seconds: 20)),
    ]);
    if (responses.any((response) => response.statusCode != 200)) {
      throw const HttpException('店舗情報を取得できませんでした');
    }
    return parseStudioCatalog(responses[0].body, responses[1].body);
  }

  Future<_StudioCache?> _readCache() async {
    try {
      final file = await _cacheFile();
      if (!await file.exists()) return null;
      final json =
          jsonDecode(await file.readAsString()) as Map<String, dynamic>;
      return _StudioCache(
        updatedAt: DateTime.parse(json['updatedAt'] as String),
        items: [
          for (final item in json['items'] as List<dynamic>)
            StudioItem.fromJson(item as Map<String, dynamic>),
        ],
      );
    } catch (_) {
      return null;
    }
  }

  Future<void> _writeCache(List<StudioItem> items) async {
    final file = await _cacheFile();
    await file.writeAsString(
      jsonEncode({
        'updatedAt': DateTime.now().toUtc().toIso8601String(),
        'items': items.map((item) => item.toJson()).toList(),
      }),
      flush: true,
    );
  }

  Future<File> _cacheFile() async {
    final directory = await getApplicationSupportDirectory();
    return File('${directory.path}/studios-cache.json');
  }
}

List<StudioItem> parseStudioCatalog(
  String studiosResponse,
  String machinesResponse,
) {
  final studiosJson = jsonDecode(studiosResponse) as Map<String, dynamic>;
  final machinesJson = jsonDecode(machinesResponse) as Map<String, dynamic>;
  final machineNames = {
    for (final value in machinesJson['list'] as List<dynamic>)
      (value as Map<String, dynamic>)['topics_id'] as int:
          value['name'] as String,
  };
  return [
    for (final value in studiosJson['list'] as List<dynamic>)
      _mapStudio(value as Map<String, dynamic>, machineNames),
  ];
}

StudioItem _mapStudio(
  Map<String, dynamic> json,
  Map<int, String> machineNames,
) {
  final units = <String, int>{};
  for (final value in json['machines'] as List<dynamic>? ?? const []) {
    final machine = value as Map<String, dynamic>;
    final details = machine['machine_details'] as Map<String, dynamic>?;
    final name = machineNames[details?['module_id'] as int?];
    final equipmentId = name == null ? null : _equipmentIdsByName[name];
    if (equipmentId != null) {
      units[equipmentId] = machine['total_units'] as int? ?? 1;
    }
  }
  return StudioItem(
    id: '${json['hacomono_studio_id']}',
    name: json['name'] as String,
    address: json['address'] as String? ?? '',
    access: json['access'] as String? ?? '',
    equipmentUnits: units,
  );
}

class _StudioCache {
  const _StudioCache({required this.updatedAt, required this.items});

  final DateTime updatedAt;
  final List<StudioItem> items;

  bool get isExpired =>
      DateTime.now().toUtc().difference(updatedAt) >
      StudioRepository._cacheLifetime;
}

const _equipmentIdsByName = {
  'ショルダープレス': 'shoulder-press',
  'チェストプレス': 'chest-press',
  'ラットプルダウン': 'lat-pulldown',
  'バイセップスカール': 'biceps-curl',
  'ディップス': 'dips',
  'アブドミナルトレーナー': 'abdominal-trainer',
  'アブベンチ': 'ab-bench',
  'レッグプレス': 'leg-press',
  'アダクション': 'adduction',
  'アブダクション': 'abduction',
  'トレッドミル': 'treadmill',
  'バイク': 'bike',
};
