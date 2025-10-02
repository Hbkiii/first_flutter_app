import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:timeline_tile/timeline_tile.dart';

// 1. データ構造を「単一イベント」として定義
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

// 2. 画像のタイムラインに合わせたダミーデータを作成
final List<UsageEvent> mockEvents = [
  UsageEvent(
    title: 'Pantalla apagada (bloqueada)', // 画面オフ（ロック）
    icon: Icons.phonelink_lock,
    iconColor: Colors.grey,
    duration: const Duration(minutes: 8, seconds: 25),
    timestamp: DateTime.now().subtract(const Duration(minutes: 10)),
  ),
  UsageEvent(
    title: 'Pantalla apagada (no bloqueada)', // 画面オフ（非ロック）
    icon: Icons.phone_android,
    iconColor: Colors.grey,
    duration: const Duration(seconds: 5),
    timestamp: DateTime.now().subtract(const Duration(minutes: 10)),
  ),
  UsageEvent(
    title: 'Instagram',
    icon: Icons.camera_alt, // 仮のアイコン
    iconColor: Colors.pink,
    duration: const Duration(seconds: 2),
    timestamp: DateTime.now().subtract(const Duration(minutes: 10)),
  ),
  UsageEvent(
    title: 'Pantalla encendida (no bloqueada)', // 画面オン（非ロック）
    icon: Icons.lightbulb_outline,
    iconColor: Colors.yellow,
    duration: const Duration(seconds: 0),
    timestamp: DateTime.now().subtract(const Duration(minutes: 10)),
  ),
  UsageEvent(
    title: 'Instagram',
    icon: Icons.camera_alt,
    iconColor: Colors.pink,
    duration: const Duration(seconds: 1),
    timestamp: DateTime.now().subtract(const Duration(minutes: 10, seconds: 3)),
  ),
  UsageEvent(
    title: 'Pantalla apagada (bloqueada)',
    icon: Icons.phonelink_lock,
    iconColor: Colors.grey,
    duration: const Duration(seconds: 1),
    timestamp: DateTime.now().subtract(const Duration(minutes: 10, seconds: 4)),
  ),
  UsageEvent(
    title: 'Pantalla apagada (bloqueada)',
    icon: Icons.phonelink_lock,
    iconColor: Colors.grey,
    duration: const Duration(minutes: 5, seconds: 9),
    timestamp: DateTime.now().subtract(const Duration(minutes: 15)),
  ),
  UsageEvent(
    title: 'Pantalla apagada (no bloqueada)',
    icon: Icons.phone_android,
    iconColor: Colors.grey,
    duration: const Duration(seconds: 5),
    timestamp: DateTime.now().subtract(const Duration(minutes: 15)),
  ),
  UsageEvent(
    title: 'Instagram',
    icon: Icons.camera_alt,
    iconColor: Colors.pink,
    duration: const Duration(minutes: 1, seconds: 2),
    timestamp: DateTime.now().subtract(const Duration(minutes: 16)),
  ),
];


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
  late final List<UsageEvent> _events;

  @override
  void initState() {
    super.initState();
    // データを時間順（新しいものが上）にソート
    _events = mockEvents..sort((a, b) => b.timestamp.compareTo(a.timestamp));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('利用ログ (プロトタイプ)'),
        backgroundColor: const Color(0xFF2D2F41),
        elevation: 1,
      ),
      body: ListView.builder(
        itemCount: _events.length,
        itemBuilder: (context, index) {
          final event = _events[index];
          return TimelineTile(
            alignment: TimelineAlign.manual,
            lineXY: 0.2, // タイムラインを画面の20%の位置に表示
            isFirst: index == 0,
            isLast: index == _events.length - 1,
            // タイムラインの線のスタイル
            beforeLineStyle: const LineStyle(color: Colors.white54, thickness: 2),
            afterLineStyle: const LineStyle(color: Colors.white54, thickness: 2),
            // タイムライン上の丸（インジケーター）のスタイル
            indicatorStyle: IndicatorStyle(
              width: 15,
              color: Colors.white54,
              padding: const EdgeInsets.all(4),
            ),
            // 左側（時刻）のウィジェット
            startChild: Text(
              DateFormat('HH:mm').format(event.timestamp),
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
            ),
            // 右側（イベント詳細）のウィジェット
            endChild: _buildEventDetails(event),
          );
        },
      ),
    );
  }

  // イベント詳細部分のUIを生成するメソッド
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

  // Duration型を「X分Y秒」の文字列に変換するヘルパー関数
  String _formatDuration(Duration d) {
    if (d.inSeconds < 0) return '';
    final minutes = d.inMinutes;
    final seconds = d.inSeconds % 60;
    String result = '';
    if (minutes > 0) {
      result += '$minutes分 ';
    }
    result += '$seconds秒';
    return result;
  }
}