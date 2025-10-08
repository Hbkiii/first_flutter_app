import 'dart:async';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:timeline_tile/timeline_tile.dart';
import 'package:usage_stats/usage_stats.dart';

import 'database_helper.dart'; // 作成したヘルパーファイルをインポート

class UsageEvent {
  final String title;
  final IconData icon;
  final Color iconColor;
  final Duration duration;
  final DateTime timestamp;

  UsageEvent({
    required this.title,
    required this.icon,
    required this.iconColor,
    required this.duration,
    required this.timestamp,
  });
}

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Timeline Prototype',
      theme: ThemeData.dark().copyWith(
        scaffoldBackgroundColor: const Color(0xFF2D2F41),
      ),
      home: const UsageLogScreen(),
    );
  }
}

class UsageLogScreen extends StatefulWidget {
  const UsageLogScreen({super.key});

  @override
  State<UsageLogScreen> createState() => _UsageLogScreenState();
}

class _UsageLogScreenState extends State<UsageLogScreen> {
  Map<String, List<UsageEvent>> _groupedEvents = {};
  bool _isLoading = true;
  Timer? _timer;
  Set<String> _expandedDateKeys = {};

  @override
  void initState() {
    super.initState();
    _loadDataFromDb(showLoading: true);
    _startAutoUpdateTimer();
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _startAutoUpdateTimer() {
    // --- ★★★ 修正点①: 自動更新を5秒に変更 ★★★ ---
    _timer = Timer.periodic(const Duration(seconds: 5), (timer) {
       _syncAndReloadData();
    });
  }

  Future<void> _syncAndReloadData() async {
    bool isPermission = await UsageStats.checkUsagePermission() ?? false;
    if (!isPermission) {
      UsageStats.grantUsagePermission();
      return;
    }
    try {
      DateTime endDate = DateTime.now();
      DateTime startDate = endDate.subtract(const Duration(days: 7));
      List<EventUsageInfo> rawEvents = await UsageStats.queryEvents(startDate, endDate);
      final dbHelper = DatabaseHelper.instance;
      for (var event in rawEvents) {
        if (event.timeStamp != null && event.packageName != null && event.eventType != null) {
          final model = UsageEventModel(
            packageName: event.packageName!,
            eventType: event.eventType!,
            timestamp: int.parse(event.timeStamp!),
          );
          await dbHelper.insert(model);
        }
      }
      await _loadDataFromDb();
    } catch (err) {
      debugPrint("Error syncing data: $err");
    }
  }

  Future<void> _loadDataFromDb({bool showLoading = false}) async {
    if (showLoading) { setState(() { _isLoading = true; }); }
    
    final dbHelper = DatabaseHelper.instance;
    DateTime endDate = DateTime.now();
    DateTime startDate = endDate.subtract(const Duration(days: 7));
    
    List<UsageEventModel> eventsFromDb = await dbHelper.queryAllEvents(startDate, endDate);

        // --- ★★★ ここからが新しいフィルタリングロジック ★★★ ---

    // 1. 表示したいイベントタイプだけを許可するリスト
    const allowedEventTypes = {
      '1', // アプリ利用 (ACTIVITY_RESUMED)
      '15', // 画面オン (SCREEN_INTERACTIVE)
      '16', // 画面オフ (SCREEN_NON_INTERACTIVE)
    };

    // 2. 表示したくないシステムアプリのリスト
    const List<String> blockList = [
      'com.android.systemui',
      'com.sec.android.app.launcher', 'com.mi.android.globallauncher',
      'com.google.android.inputmethod.latin', 'com.android.vending',
      'com.google.android.deskclock', 'com.google.android.apps.messaging',
    ];

    // 3. 上記のルールに基づいてイベントをフィルタリング
    List<UsageEventModel> filteredEvents = eventsFromDb.where((event) {
      // 許可リストにないイベントは、まず除外
      if (!allowedEventTypes.contains(event.eventType)) {
        return false;
      }
      
      // アプリ利用イベント(type 1)の場合のみ、blockListを適用
      if (event.eventType == '1') {
        // blockListに含まれるアプリも表示しない
        if (blockList.any((item) => event.packageName.startsWith(item))) return false;
      }
      
      // 上記の条件をすべてクリアしたものだけが残る
      return true;
    }).toList();
    
    // --- ★★★ フィルタリングロジックここまで ★★★ ---

    List<UsageEventModel> sessionStartEvents = [];
    if (filteredEvents.isNotEmpty) {
      sessionStartEvents.add(filteredEvents.first);
      for (int i = 1; i < filteredEvents.length; i++) {
        if (filteredEvents[i].packageName != filteredEvents[i - 1].packageName) {
          sessionStartEvents.add(filteredEvents[i]);
        }
      }
    }
    
    Map<String, List<UsageEvent>> tempGroupedEvents = {};
    for (int i = 0; i < sessionStartEvents.length; i++) {
      final currentSession = sessionStartEvents[i];
      Duration duration;

      if (i < sessionStartEvents.length - 1) {
        final nextSession = sessionStartEvents[i + 1];
        duration = Duration(milliseconds: nextSession.timestamp - currentSession.timestamp);
      } else {
        duration = DateTime.now().difference(DateTime.fromMillisecondsSinceEpoch(currentSession.timestamp));
      }

      final timestamp = DateTime.fromMillisecondsSinceEpoch(currentSession.timestamp);
      final dateKey = DateFormat('yyyy年MM月dd日').format(timestamp);
      final appInfo = _getAppIconInfo(currentSession.packageName, currentSession.eventType);

      final event = UsageEvent(
        title: appInfo['name'], icon: appInfo['icon'], iconColor: appInfo['color'],
        duration: duration, timestamp: timestamp,
      );
      
      if (tempGroupedEvents[dateKey] == null) { tempGroupedEvents[dateKey] = []; }
      tempGroupedEvents[dateKey]!.add(event);
    }

    tempGroupedEvents.forEach((key, value) {
      tempGroupedEvents[key] = value.reversed.toList();
    });
    
    if (_expandedDateKeys.isEmpty || showLoading) {
      final todayKey = DateFormat('yyyy年MM月dd日').format(DateTime.now());
      _expandedDateKeys = {
        if (tempGroupedEvents.containsKey(todayKey)) todayKey,
      };
    }

    setState(() {
      _groupedEvents = tempGroupedEvents;
      _isLoading = false;
    });
  }


  // Map<String, dynamic> _getAppIconInfo(String packageName) {
  //   if (packageName.contains('instagram')) { return {'name': 'Instagram', 'icon': Icons.camera_alt, 'color': Colors.pink}; }
  //   if (packageName.contains('youtube')) { return {'name': 'YouTube', 'icon': Icons.play_arrow, 'color': Colors.red}; }
  //   if (packageName.contains('chrome')) { return {'name': 'Chrome', 'icon': Icons.web, 'color': Colors.green}; }
  //   if (packageName.contains('twitter') || packageName.contains('x.android')) { return {'name': 'X (Twitter)', 'icon': Icons.close, 'color': Colors.white}; }
  //   if (packageName.contains('camera')) { return {'name': 'カメラ', 'icon': Icons.camera, 'color': Colors.lightBlue}; }
  //   if (packageName.contains('com.example.flutter_application_1')) { return {'name': '開発中のアプリ', 'icon': Icons.adb, 'color': Colors.cyan}; }
  //   // --- ★★★ 修正点②: nexuslauncherを「ホーム」として表示する処理を追加 ★★★ ---
  //   if (packageName.contains('nexuslauncher')) { return {'name': 'ホーム', 'icon': Icons.home, 'color': Colors.greenAccent}; }
  //   return {'name': packageName, 'icon': Icons.app_blocking, 'color': Colors.grey};
  // }

  Map<String, dynamic> _getAppIconInfo(String packageName, String eventType) {
    switch (eventType) {
      // --- ★★★ ここを修正しました ★★★ ---
      case '15': // 画面オン
        return {'name': '画面オン', 'icon': Icons.lightbulb_outline, 'color': Colors.yellowAccent};
      case '16': // 画面オフ
        return {'name': '画面オフ', 'icon': Icons.phone_android, 'color': Colors.grey};
      // --- ★★★ 修正ここまで ★★★ ---
        
      case '1': // ACTIVITY_RESUMED (アプリ利用)
        if (packageName.contains('instagram')) { return {'name': 'Instagram', 'icon': Icons.camera_alt, 'color': Colors.pink}; }
        if (packageName.contains('youtube')) { return {'name': 'YouTube', 'icon': Icons.play_arrow, 'color': Colors.red}; }
        if (packageName.contains('chrome')) { return {'name': 'Chrome', 'icon': Icons.web, 'color': Colors.green}; }
        if (packageName.contains('twitter') || packageName.contains('x.android')) { return {'name': 'X (Twitter)', 'icon': Icons.close, 'color': Colors.white}; }
        if (packageName.contains('camera')) { return {'name': 'カメラ', 'icon': Icons.camera, 'color': Colors.lightBlue}; }
        if (packageName.contains('com.example.flutter_application_1')) { return {'name': '開発中のアプリ', 'icon': Icons.adb, 'color': Colors.cyan}; }
        if (packageName.contains('nexuslauncher')) { return {'name': 'ホーム', 'icon': Icons.home, 'color': Colors.greenAccent}; }
        return {'name': packageName, 'icon': Icons.app_blocking, 'color': Colors.grey};
      default:
        return {'name': '不明なイベント ($eventType)', 'icon': Icons.help_outline, 'color': Colors.grey};
    }
  }
  
  @override
  Widget build(BuildContext context) {
    final dateKeys = _groupedEvents.keys.toList()
      ..sort((a, b) => DateFormat('yyyy年MM月dd日').parse(b).compareTo(DateFormat('yyyy年MM月dd日').parse(a)));
      
    return Scaffold(
      appBar: AppBar(
        title: const Text('利用ログ (SQLite)'),
        backgroundColor: const Color(0xFF2D2F41),
        elevation: 1,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _groupedEvents.isEmpty
              ? Center( child: Text('データがありません。\n権限を許可し、更新ボタンを押してください。', textAlign: TextAlign.center),)
              : ListView.builder(
                  itemCount: dateKeys.length,
                  itemBuilder: (context, index) {
                    final dateKey = dateKeys[index];
                    final eventsForDay = _groupedEvents[dateKey]!;
                    final isExpanded = _expandedDateKeys.contains(dateKey);
                    
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        InkWell(
                          onTap: () {
                            setState(() {
                              if (isExpanded) {
                                _expandedDateKeys.remove(dateKey);
                              } else {
                                _expandedDateKeys.add(dateKey);
                              }
                            });
                          },
                          child: Padding(
                            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  dateKey,
                                  style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white),
                                ),
                                Icon(
                                  isExpanded ? Icons.expand_less : Icons.expand_more,
                                  color: Colors.white,
                                ),
                              ],
                            ),
                          ),
                        ),
                        if (isExpanded)
                          ListView.builder(
                            shrinkWrap: true,
                            physics: const NeverScrollableScrollPhysics(),
                            itemCount: eventsForDay.length,
                            itemBuilder: (context, eventIndex) {
                              final event = eventsForDay[eventIndex];
                              return TimelineTile(
                                alignment: TimelineAlign.manual,
                                lineXY: 0.2,
                                isFirst: eventIndex == 0,
                                isLast: eventIndex == eventsForDay.length - 1,
                                beforeLineStyle: const LineStyle(color: Colors.white54, thickness: 2),
                                afterLineStyle: const LineStyle(color: Colors.white54, thickness: 2),
                                indicatorStyle: IndicatorStyle(
                                  width: 15, color: Colors.white54, padding: const EdgeInsets.all(4),),
                                startChild: Text( DateFormat('HH:mm').format(event.timestamp), textAlign: TextAlign.center,
                                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12),),
                                endChild: _buildEventDetails(event),
                              );
                            },
                          ),
                      ],
                    );
                  },
                ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _loadDataFromDb(showLoading: true),
        child: const Icon(Icons.refresh),
      ),
    );
  }
  
  Widget _buildEventDetails(UsageEvent event) {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Row(
        children: [
          Icon(event.icon, color: event.iconColor, size: 30),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  event.title,
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 4),
                Text(
                  _formatDuration(event.duration),
                  style: TextStyle(color: Colors.lightGreenAccent[400]),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
  
  String _formatDuration(Duration d) {
    if (d.inSeconds <= 0) return '一瞬';
    final minutes = d.inMinutes;
    final seconds = d.inSeconds % 60;
    String result = '';
    if (minutes > 0) { result += '$minutes分 '; }
    if (minutes < 1 && seconds > 0) { result += '$seconds秒'; }
    return result.isEmpty ? '一瞬' : result.trim();
  }
}