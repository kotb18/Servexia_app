import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class SettingsGroups extends StatefulWidget {
  const SettingsGroups({super.key});
  static const String screenroute = 'SettingsGroups';

  @override
  State<SettingsGroups> createState() => _SettingsGroupsState();
}

class _SettingsGroupsState extends State<SettingsGroups> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('اعدادات التطبيق')),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(18),
            child: Row(
              children: [
                // الأيقونة
                Container(
                  width: 52,
                  height: 52,
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.primaryContainer,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Icon(
                    Icons.event_available_rounded,
                    color: Theme.of(context).colorScheme.primary,
                    size: 28,
                  ),
                ),

                const SizedBox(width: 14),

                // النص
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'فترة السماح',
                        style: Theme.of(context).textTheme.titleMedium
                            ?.copyWith(fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 5),
                      Text(
                        'تعديل موعد انتهاء اشتراك مالك المجموعة',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(width: 10),

                // زر التعديل
                IconButton.filled(
                  tooltip: 'تعديل فترة السماح',
                  onPressed: () {
                    _adjustingGracePeriod();
                  },
                  icon: const Icon(Icons.edit_calendar_rounded),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _adjustingGracePeriod() async {
    final usersSnap = await FirebaseFirestore.instance
        .collection('users')
        .get();

    final List<String> docs = usersSnap.docs.map((doc) => doc.id).toList();

    final now = DateTime.now();
    DateTime selectedDate = now.add(Duration(days: 31));
    final firestore = FirebaseFirestore.instance;
    final batch = firestore.batch();
    bool isSelected = false;

    if (docs.isEmpty) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('لم يتم العثور على بيانات المستخدم')),
      );

      return;
    }

    await showDialog(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              title: const Text(
                'تعديل موعد انتهاء الاشتراك',
                // textDirection: TextDirection.rtl,
              ),

              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const SizedBox(height: 24),

                  ElevatedButton.icon(
                    onPressed: () async {
                      final date = await showDatePicker(
                        context: context,
                        initialDate: selectedDate,
                        firstDate: DateTime(2020),
                        lastDate: DateTime(2100),
                      );

                      if (date == null) return;

                      setState(() {
                        selectedDate = DateTime(
                          date.year,
                          date.month,
                          date.day,
                          selectedDate.hour,
                          selectedDate.minute,
                        );
                        isSelected = true;
                      });
                    },
                    icon: const Icon(Icons.calendar_month),
                    label: Text(DateFormat('yyyy/MM/dd').format(now)),
                  ),
                ],
              ),

              actions: [
                TextButton(
                  onPressed: () {
                    Navigator.pop(dialogContext);
                  },
                  child: const Text('إلغاء'),
                ),

                FilledButton(
                  onPressed: !isSelected
                      ? null
                      : () async {
                          try {
                            for (var doc in docs) {
                              var userRef = firestore
                                  .collection('users')
                                  .doc(doc);
                              batch.update(userRef, {
                                'expiredAt': Timestamp.fromDate(selectedDate),
                                'status': '1',
                              });
                            }

                            await batch.commit();
                            if (!dialogContext.mounted) return;

                            Navigator.pop(dialogContext);

                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text(
                                  'تم تعديل موعد انتهاء الاشتراك بنجاح',
                                ),
                              ),
                            );
                          } catch (e) {
                            if (!dialogContext.mounted) return;

                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text('حدث خطأ: $e')),
                            );
                          }
                        },
                  child: const Text('حفظ'),
                ),
              ],
            );
          },
        );
      },
    );
  }
}
