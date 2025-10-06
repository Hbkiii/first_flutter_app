import 'dart:async'; // タイマー機能を使うためにインポート
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:timeline_tile/timeline_tile.dart';
import 'package:usage_stats/usage_stats.dart';

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
  Timer? _timer; // --- 自動更新用のタイマー ---

  @override
  void initState() {
    super.initState();
    // 最初に一度、手動更新と同じ処理を呼び出す
    _loadUsageData(isManualRefresh: true);
    // --- ★★★ 自動更新タイマーを開始 ★★★ ---
    _startAutoUpdateTimer();
  }

  @override
  void dispose() {
    _timer?.cancel(); // 画面が閉じられるときにタイマーを停止
    super.dispose();
  }
  
  // --- ★★★ 15秒ごとに全データを再取得するタイマー ★★★ ---
  void _startAutoUpdateTimer() {
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 5), (timer) {
      // 15秒ごとに、裏側でデータを読み込む（読み込み中は表示しない）
      _loadUsageData(isManualRefresh: false);
    });
  }

  // --- isManualRefresh という引数を追加 ---
  Future<void> _loadUsageData({required bool isManualRefresh}) async {
    // 手動更新の時だけ、くるくるマークを表示する
    if (isManualRefresh) {
      setState(() { _isLoading = true; });
    }

    bool isPermission = await UsageStats.checkUsagePermission() ?? false;
    if (!isPermission) {
      UsageStats.grantUsagePermission();
      if (isManualRefresh) { setState(() { _isLoading = false; }); }
      return;
    }

    try {
      DateTime endDate = DateTime.now();
      DateTime startDate = endDate.subtract(const Duration(days: 7));
      List<EventUsageInfo> rawEvents = await UsageStats.queryEvents(startDate, endDate);

      List<EventUsageInfo> foregroundEvents = rawEvents.where((event) {
        return event.eventType == '1';
      }).toList();

      const List<String> blockList = [
        'android', 'com.android.systemui', 
        'com.google.android.inputmethod.latin', 'com.android.vending',
        'com.google.android.deskclock', 'com.google.android.apps.messaging',
      ];
      List<EventUsageInfo> filteredEvents = foregroundEvents.where((event) {
        if (event.packageName == null) return false;
        if (event.packageName == 'com.example.flutter_application_1') return true;
        return !blockList.any((item) => event.packageName!.startsWith(item));
      }).toList();

      filteredEvents.sort((a, b) => a.timeStamp!.compareTo(b.timeStamp!));

      List<EventUsageInfo> sessionStartEvents = [];
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
          duration = Duration(
            milliseconds: int.parse(nextSession.timeStamp!) - int.parse(currentSession.timeStamp!)
          );
        } else {
          duration = DateTime.now().difference(
            DateTime.fromMillisecondsSinceEpoch(int.parse(currentSession.timeStamp!))
          );
        }

        final timestamp = DateTime.fromMillisecondsSinceEpoch(int.parse(currentSession.timeStamp!));
        final dateKey = DateFormat('yyyy年MM月dd日').format(timestamp);
        final appInfo = _getAppIconInfo(currentSession.packageName!);

        final event = UsageEvent(
          title: appInfo['name'],
          icon: appInfo['icon'],
          iconColor: appInfo['color'],
          duration: duration,
          timestamp: timestamp,
        );
        
        if (tempGroupedEvents[dateKey] == null) { tempGroupedEvents[dateKey] = []; }
        tempGroupedEvents[dateKey]!.add(event);
      }

      tempGroupedEvents.forEach((key, value) {
        tempGroupedEvents[key] = value.reversed.toList();
      });

      setState(() {
        _groupedEvents = tempGroupedEvents;
        _isLoading = false;
      });

    } catch (err) {
      debugPrint(err.toString());
      if (isManualRefresh) { setState(() { _isLoading = false; }); }
    }
  }

  Map<String, dynamic> _getAppIconInfo(String packageName) {
    if (packageName.contains('instagram')) { return {'name': 'Instagram', 'icon': Icons.camera_alt, 'color': Colors.pink}; }
    if (packageName.contains('youtube')) { return {'name': 'YouTube', 'icon': Icons.play_arrow, 'color': Colors.red}; }
    if (packageName.contains('chrome')) { return {'name': 'Chrome', 'icon': Icons.web, 'color': Colors.green}; }
    if (packageName.contains('twitter') || packageName.contains('x.android')) { return {'name': 'X (Twitter)', 'icon': Icons.close, 'color': Colors.white}; }
    if (packageName.contains('camera')) { return {'name': 'カメラ', 'icon': Icons.camera, 'color': Colors.lightBlue}; }
    if (packageName.contains('com.example.flutter_application_1')) { return {'name': '開発中のアプリ', 'icon': Icons.adb, 'color': Colors.cyan}; }
    if (packageName.contains('launcher')) { return {'name': 'ホーム', 'icon': Icons.home, 'color': const Color.fromARGB(255, 38, 255, 110)}; }
    return {'name': packageName, 'icon': Icons.app_blocking, 'color': Colors.grey};
  }
  
  @override
  Widget build(BuildContext context) {
    final dateKeys = _groupedEvents.keys.toList()
      ..sort((a, b) => DateFormat('yyyy年MM月dd日').parse(b).compareTo(DateFormat('yyyy年MM月dd日').parse(a)));
      
    return Scaffold(
      appBar: AppBar(
        title: const Text('利用ログ'),
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
                    
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Padding(
                          padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                          child: Text(
                            dateKey,
                            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white),
                          ),
                        ),
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
        // 右下のボタンは、手動更新として明示的に呼び出す
        onPressed: () => _loadUsageData(isManualRefresh: true),
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
    if (minutes > 0) {
      result += '$minutes分 ';
    }
    if (minutes < 1 && seconds > 0) {
      result += '$seconds秒';
    }
    return result.isEmpty ? '一瞬' : result.trim();
  }
}