import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:table_calendar/table_calendar.dart';
import 'package:intl/intl.dart';

class SchedulePage extends StatefulWidget {
  const SchedulePage({super.key});

  @override
  State<SchedulePage> createState() => _SchedulePageState();
}

class _SchedulePageState extends State<SchedulePage> {
  DateTime _selectedDate = DateTime.now();

  String? _groupId;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchUserGroup();
  }

  /// FirestoreからログインユーザーのgroupIdを取得する
  Future<void> _fetchUserGroup() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      final doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get();
      if (doc.exists) {
        setState(() {
          _groupId = doc.data()?['groupId'];
          _isLoading = false;
        });
        return;
      }
    }
    setState(() {
      _groupId = 'my_band_01';
      _isLoading = false;
    });
  }

  /// 新しい予定をFirestoreに保存。日付は検索しやすいように時間(00:00:00)を揃えて保存
  void _showAddEventDialog() {
    if (_groupId == null) return;

    final TextEditingController timeController = TextEditingController();
    final TextEditingController titleController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('新しい予定を追加'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: timeController,
                decoration: const InputDecoration(hintText: '時間 (例: 19:00)'),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: titleController,
                decoration: const InputDecoration(hintText: '予定名 (例: Studio)'),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('キャンセル', style: TextStyle(color: Colors.grey)),
            ),
            ElevatedButton(
              style:
                  ElevatedButton.styleFrom(backgroundColor: Colors.green[700]),
              onPressed: () async {
                final time = timeController.text.trim();
                final title = titleController.text.trim();

                if (title.isNotEmpty) {
                  final dateKey = DateTime(_selectedDate.year,
                      _selectedDate.month, _selectedDate.day);

                  await FirebaseFirestore.instance
                      .collection('groups')
                      .doc(_groupId)
                      .collection('schedules')
                      .add({
                    'title': title,
                    'time': time,
                    'date': Timestamp.fromDate(dateKey),
                  });
                }
                if (mounted) Navigator.pop(context);
              },
              child: const Text('追加', style: TextStyle(color: Colors.white)),
            ),
          ],
        );
      },
    );
  }

  /// 指定した予定の削除機能。ドキュメントIDを指定してFirestoreから削除
  Future<void> _deleteEvent(String docId) async {
    if (_groupId == null || docId.isEmpty) return;
    try {
      await FirebaseFirestore.instance
          .collection('groups')
          .doc(_groupId)
          .collection('schedules')
          .doc(docId)
          .delete();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('予定の削除に失敗しました: $e')),
        );
      }
    }
  }

  /// タップした日の予定をポップアップで表示する機能
  void _showEventsPopup(DateTime date, List<Map<String, String>> dayEvents) {
    if (dayEvents.isEmpty) return;

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('${DateFormat('M/d').format(date)}の予定'),
              IconButton(
                icon: const Icon(Icons.close),
                onPressed: () => Navigator.pop(context),
              ),
            ],
          ),
          content: SizedBox(
            width: double.maxFinite,
            child: ListView.builder(
              shrinkWrap: true,
              itemCount: dayEvents.length,
              itemBuilder: (context, index) {
                final event = dayEvents[index];
                final String docId = event['id'] ?? '';

                return Card(
                  elevation: 2,
                  child: ListTile(
                    leading: const Icon(Icons.access_time, color: Colors.green),
                    title: Text(event['title'] ?? ''),
                    subtitle: Text(event['time'] ?? ''),
                    // ポップアップ内にも削除ボタンを配置（誤動作防止のためタップ後にダイアログを閉じます）
                    trailing: IconButton(
                      icon: const Icon(Icons.delete_outline,
                          color: Colors.redAccent),
                      onPressed: () async {
                        if (docId.isNotEmpty) {
                          await _deleteEvent(docId);
                          if (mounted) Navigator.pop(context);
                        }
                      },
                    ),
                  ),
                );
              },
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('groups')
          .doc(_groupId)
          .collection('schedules')
          .snapshots(),
      builder: (context, snapshot) {
        final Map<DateTime, List<Map<String, String>>> compiledEvents = {};

        if (snapshot.hasData) {
          for (var doc in snapshot.data!.docs) {
            final data = doc.data() as Map<String, dynamic>;
            if (data['date'] != null) {
              final DateTime dateTime = (data['date'] as Timestamp).toDate();
              final dateKey =
                  DateTime(dateTime.year, dateTime.month, dateTime.day);

              if (compiledEvents[dateKey] == null) {
                compiledEvents[dateKey] = [];
              }
              // 予定を削除できるように、データだけでなくFirestoreのdoc.idもMapに含めておく（ここで結構詰まった）
              compiledEvents[dateKey]!.add({
                'id': doc.id,
                'title': data['title'] ?? '',
                'time': data['time'] ?? '',
              });
            }
          }
        }

        final currentSelectedKey = DateTime(
            _selectedDate.year, _selectedDate.month, _selectedDate.day);
        final selectedDayEvents = compiledEvents[currentSelectedKey] ?? [];

        return Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                '【SCHEDULE】カレンダー・予定',
                style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.black87),
              ),
              const SizedBox(height: 16),

              // --- カレンダー部分 ---
              Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.grey.withOpacity(0.2)),
                ),
                child: TableCalendar(
                  firstDay: DateTime.utc(2000, 1, 1),
                  lastDay: DateTime.utc(2100, 12, 31),
                  focusedDay: _selectedDate,
                  availableCalendarFormats: const {
                    CalendarFormat.month: 'Month'
                  },
                  selectedDayPredicate: (day) => isSameDay(_selectedDate, day),
                  onDaySelected: (selectedDay, focusedDay) {
                    setState(() {
                      _selectedDate = selectedDay;
                    });
                    final clickedKey = DateTime(
                        selectedDay.year, selectedDay.month, selectedDay.day);
                    final clickedEvents = compiledEvents[clickedKey] ?? [];
                    _showEventsPopup(selectedDay, clickedEvents);
                  },
                  eventLoader: (day) {
                    final dateKey = DateTime(day.year, day.month, day.day);
                    return compiledEvents[dateKey] ?? [];
                  },
                  calendarStyle: CalendarStyle(
                    selectedDecoration: BoxDecoration(
                        color: Colors.green[700], shape: BoxShape.circle),
                    todayDecoration: BoxDecoration(
                        color: Colors.green.withOpacity(0.3),
                        shape: BoxShape.circle),
                  ),
                  calendarBuilders: CalendarBuilders(
                    markerBuilder: (context, date, events) {
                      if (events.isNotEmpty) {
                        return Positioned(
                          bottom: 6,
                          child: Container(
                            width: 24,
                            height: 4,
                            decoration: BoxDecoration(
                              color: Colors.blue,
                              borderRadius: BorderRadius.circular(2),
                            ),
                          ),
                        );
                      }
                      return const SizedBox();
                    },
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // --- 予定の追加ボタン ---
              ElevatedButton.icon(
                onPressed: _showAddEventDialog,
                icon: const Icon(Icons.add),
                label: const Text('新しい予定を追加'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.white,
                  foregroundColor: Colors.black87,
                  side: BorderSide(color: Colors.grey.withOpacity(0.5)),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8)),
                ),
              ),
              const SizedBox(height: 16),

              // --- 画面下部のリスト表示 ---
              Text(
                '${DateFormat('yyyy/MM/dd').format(_selectedDate)} の予定',
                style: const TextStyle(
                    fontWeight: FontWeight.bold, color: Colors.green),
              ),
              const SizedBox(height: 8),
              Expanded(
                child: selectedDayEvents.isEmpty
                    ? const Text('予定はありません',
                        style: TextStyle(color: Colors.grey))
                    : ListView.builder(
                        itemCount: selectedDayEvents.length,
                        itemBuilder: (context, index) {
                          final event = selectedDayEvents[index];
                          final String docId = event['id'] ?? '';

                          return Card(
                            color: Colors.white,
                            child: ListTile(
                              leading:
                                  Icon(Icons.event, color: Colors.green[700]),
                              title: Text(event['title'] ?? ''),
                              // 🌟 下部リストの右側に時間とゴミ箱ボタンを綺麗に横並びで配置
                              trailing: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(
                                    event['time'] ?? '',
                                    style: const TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.bold,
                                        color: Colors.black87),
                                  ),
                                  const SizedBox(width: 12),
                                  IconButton(
                                    icon: const Icon(Icons.delete_outline,
                                        color: Colors.redAccent),
                                    onPressed: () => _deleteEvent(docId),
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
              ),
            ],
          ),
        );
      },
    );
  }
}
