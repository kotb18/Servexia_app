import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:maintenance/addTask.dart';
import 'package:maintenance/homePage.dart';

TextEditingController commentController = TextEditingController();

class TasksScreen extends StatefulWidget {
  final String groupId;
  final bool isAdmin;

  TasksScreen({super.key, required this.groupId, required this.isAdmin});

  static const String screenroute = 'tasks';

  @override
  State<TasksScreen> createState() => _TasksScreenState();
}

class _TasksScreenState extends State<TasksScreen> {
  @override
  void dispose() {
    // TODO: implement dispose
    super.dispose();
    commentController.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final tasksRef = FirebaseFirestore.instance
        .collection('tasks')
        .doc(widget.groupId)
        .collection('items')
        .orderBy('createdAt', descending: true);

    return Scaffold(
      appBar: AppBar(title: const Text('المهام والأعطال'), centerTitle: true),
      body: StreamBuilder<QuerySnapshot>(
        stream: tasksRef.snapshots(),
        builder: (context, snap) {
          if (snap.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (!snap.hasData || snap.data!.docs.isEmpty) {
            return const Center(child: Text('لا توجد مهام'));
          }

          final docs = snap.data!.docs;

          return ListView.builder(
            padding: const EdgeInsets.all(12),
            itemCount: docs.length,
            itemBuilder: (context, index) {
              final task = docs[index];
              final List assets = task['assets'] ?? [];

              final List<String> assignedTo = (task['assignedTo'] as List)
                  .map<String>((m) => m['name'].toString())
                  .toList();
              final bool isReport = task['isReport'];
              final createdAt = task['createdAt'] != null
                  ? DateFormat(
                      'dd/MM/yyyy – HH:mm',
                    ).format((task['createdAt'] as Timestamp).toDate())
                  : '';
              final timeReq = task['taskDateTime'] != null
                  ? DateFormat(
                      'dd/MM/yyyy – HH:mm',
                    ).format((task['taskDateTime'] as Timestamp).toDate())
                  : '';

              return Card(
                elevation: 4,
                margin: const EdgeInsets.only(bottom: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      /// ================== ASSETS ==================
                      if (assets.isNotEmpty)
                        Column(
                          children: assets.map<Widget>((asset) {
                            return Column(
                              children: [
                                SizedBox(
                                  width: 150,
                                  child: Card(
                                    color: isReport ? Colors.red : Colors.grey,
                                    margin: const EdgeInsets.symmetric(
                                      vertical: 6,
                                    ),
                                    elevation: 2,
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: Center(
                                      child: Text(isReport ? 'عطل' : 'مهمة'),
                                    ),
                                  ),
                                ),
                                Card(
                                  margin: const EdgeInsets.symmetric(
                                    vertical: 6,
                                  ),
                                  elevation: 2,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: ListTile(
                                    leading: CircleAvatar(
                                      backgroundColor: Colors.blue.shade100,
                                      child: Text(
                                        asset['number'] ?? '',
                                        style: const TextStyle(
                                          fontWeight: FontWeight.bold,
                                          color: Colors.black,
                                        ),
                                      ),
                                    ),
                                    title: Text(
                                      asset['name'] ?? '',
                                      style: const TextStyle(
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                    subtitle: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text('الموقع: ${asset['site']}'),
                                        Text('المكان: ${asset['location']}'),
                                      ],
                                    ),
                                    trailing: const Icon(
                                      Icons.arrow_forward_ios,
                                      size: 16,
                                    ),
                                    onTap: () {
                                      debugPrint(
                                        'Asset ID: ${asset['assetId']}',
                                      );
                                    },
                                  ),
                                ),
                              ],
                            );
                          }).toList(),
                        ),

                      /// ================== DATE ==================
                      if (createdAt.isNotEmpty)
                        Row(
                          children: [
                            const Icon(Icons.schedule, size: 16),
                            Text(
                              isReport
                                  ? 'توقيت انشاء البلاغ'
                                  : 'توقيت انشاء المهمة:',
                              style: const TextStyle(fontSize: 10),
                            ),
                            const SizedBox(width: 6),
                            Text(
                              createdAt,
                              style: const TextStyle(fontSize: 10),
                            ),
                          ],
                        ),

                      const SizedBox(height: 8),

                      /// ================== TITLE + STATUS ==================
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              task['title'],
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                          !isReport
                              ? _StatusChip(status: task['status'])
                              : SizedBox.shrink(),
                        ],
                      ),

                      /// ================== DESCRIPTION ==================
                      if (task['description'] != null &&
                          task['description'].toString().isNotEmpty) ...[
                        const SizedBox(height: 6),
                        Text(
                          task['description'],
                          style: TextStyle(color: Colors.grey[700]),
                        ),
                      ],

                      const SizedBox(height: 10),
                      Divider(),

                      /// ================== ASSIGNED TO ==================
                      !isReport
                          ? Column(
                              children: [
                                Text(
                                  'المكلفون بأنهاء المهمة:',
                                  style: TextStyle(color: Colors.blueGrey),
                                ),
                                Wrap(
                                  spacing: 6,
                                  runSpacing: -8,
                                  children: assignedTo
                                      .map(
                                        (name) => Chip(
                                          avatar: const Icon(
                                            Icons.person,
                                            size: 16,
                                          ),
                                          label: Text(name),
                                        ),
                                      )
                                      .toList(),
                                ),
                              ],
                            )
                          : Chip(
                              avatar: const Icon(Icons.person, size: 16),
                              label: Text('المبلغ: ${assignedTo[0]}'),
                            ),

                      Divider(),
                      if (timeReq.isNotEmpty && !isReport)
                        Row(
                          children: [
                            // const Icon(Icons.schedule, size: 16),
                            Text('التاريخ المطلوب للبدء في المهمة:'),
                            const SizedBox(width: 6),
                            Text(timeReq, style: const TextStyle(fontSize: 12)),
                          ],
                        ),
                      if (isReport)
                        Row(
                          children: [
                            // const Icon(Icons.schedule, size: 16),
                            Text('حالة العطل: '),
                            const SizedBox(width: 6),
                            Text(
                              task['priority'],
                              style: TextStyle(
                                color: task['priority'] == 'عادي'
                                    ? Colors.green
                                    : task['priority'] == 'عاجل'
                                    ? Colors.orange
                                    : task['priority'] == "طارئ"
                                    ? Colors.red
                                    : Colors.black,
                              ),
                            ),
                          ],
                        ),
                      const SizedBox(height: 5),
                      Card(
                        color: Colors.blueGrey.shade50,
                        margin: const EdgeInsets.symmetric(vertical: 6),
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            ElevatedButton.icon(
                              onPressed: () async {
                                await addComment(task.id);
                              },
                              label: Text('أضف تعليق'),
                              icon: Icon(Icons.comment),
                            ),
                            SizedBox(width: 10),
                            ElevatedButton.icon(
                              onPressed: () async {
                                await showComments(task.id);
                              },
                              label: Text('عرض التعليقات'),
                              icon: Icon(Icons.comment_bank),
                            ),
                          ],
                        ),
                      ),

                      /// ================== ADMIN ACTIONS ==================
                      if (widget.isAdmin)
                        Align(
                          alignment: Alignment.centerRight,
                          child: PopupMenuButton<String>(
                            icon: const Icon(Icons.more_vert),
                            onSelected: (value) async {
                              if (value == 'confirm') {
                                await _confirmTask(
                                  task,
                                  task['assetIds'],
                                  isReport
                                      ? 'تأكيد الانتهاء من العطل'
                                      : 'تـأكيد اتمام المهمة',
                                );
                              } else if (value == 'delete') {
                                showDialog(
                                  context: context,
                                  builder: (context) => AlertDialog(
                                    title: Text(
                                      isReport ? "حذف البلاغ" : "حذف المهمة",
                                      style: TextStyle(color: Colors.red),
                                    ),
                                    content: Text(
                                      isReport
                                          ? "هل أنت متأكد أنك تريد حذف هذا البلاغ؟"
                                          : "هل أنت متأكد أنك تريد حذف هذه المهمة؟",
                                    ),
                                    actions: [
                                      TextButton(
                                        onPressed: () => Navigator.pop(context),
                                        child: const Text("إلغاء"),
                                      ),
                                      ElevatedButton(
                                        onPressed: () async {
                                          await task.reference.delete();

                                          Navigator.pop(context);
                                          ScaffoldMessenger.of(
                                            context,
                                          ).showSnackBar(
                                            SnackBar(
                                              content: Text(
                                                isReport
                                                    ? "تم حذف البلاغ"
                                                    : "تم حذف المهمة",
                                              ),
                                            ),
                                          );
                                        },
                                        child: const Text(
                                          "حذف",
                                          style: TextStyle(color: Colors.red),
                                        ),
                                      ),
                                    ],
                                  ),
                                );
                              }
                            },
                            itemBuilder: (context) => [
                              PopupMenuItem(
                                value: 'confirm',
                                child: Text(
                                  isReport
                                      ? 'تأكيد اتمام البلاغ'
                                      : 'تأكيد اتمام المهمة',
                                ),
                              ),
                              PopupMenuItem(
                                value: 'delete',
                                child: Text(
                                  isReport ? 'حذف البلاغ' : 'حذف المهمة',
                                  style: TextStyle(color: Colors.red),
                                ),
                              ),
                            ],
                          ),
                        ),
                      const SizedBox(height: 15),
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }

  /// ================== STATUS CHIP ==================
  Widget _StatusChip({required String status}) {
    late Color color;
    late String text;

    switch (status) {
      case 'confirmed':
        color = Colors.green;
        text = 'مؤكدة';
        break;
      case 'pending':
        color = Colors.orange;
        text = 'قيد التنفيذ';
        break;
      default:
        color = Colors.grey;
        text = status;
    }

    return Chip(
      label: Text(text, style: const TextStyle(color: Colors.white)),
      backgroundColor: color,
    );
  }

  addComment(String taskId) async {
    commentController = TextEditingController();
    String? name;

    final memberDoc = await FirebaseFirestore.instance
        .collection('teams')
        .doc(widget.groupId)
        .collection('members')
        .doc(FirebaseAuth.instance.currentUser!.uid)
        .get();

    name = memberDoc.data()?['name'];

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(context).viewInsets.bottom,
            left: 16,
            right: 16,
            top: 20,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                "إضافة تعليق",
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 20),
              TextField(
                controller: commentController,
                maxLines: 3,
                decoration: InputDecoration(
                  hintText: "اكتب تعليقك هنا...",
                  filled: true,
                  fillColor: Colors.grey.shade100,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
              const SizedBox(height: 20),
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  minimumSize: const Size(double.infinity, 45),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                icon: const Icon(Icons.send),
                label: const Text("إرسال"),
                onPressed: () async {
                  await FirebaseFirestore.instance
                      .collection('tasks')
                      .doc(widget.groupId)
                      .collection('items')
                      .doc(taskId)
                      .update({
                        'comments': FieldValue.arrayUnion([
                          {
                            'comment': commentController.text,
                            'commenter': name ?? '',
                            'commentCreatedAt': Timestamp.now(),
                            'id': uid,
                          },
                        ]),
                      });
                  sendTopicNotification(
                    topic: widget.groupId,
                    title: 'تعليق جديد',
                    body: commentController.text,
                  );

                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text("تم إضافة التعليق")),
                  );
                },
              ),
              const SizedBox(height: 60),
            ],
          ),
        );
      },
    );
  }

  showComments(String taskId) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return Padding(
          padding: const EdgeInsets.all(16),
          child: SizedBox(
            height: MediaQuery.of(context).size.height * 0.75,
            child: Column(
              children: [
                const Text(
                  "التعليقات",
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 20),

                Expanded(
                  child: StreamBuilder<DocumentSnapshot>(
                    stream: FirebaseFirestore.instance
                        .collection('tasks')
                        .doc(widget.groupId)
                        .collection('items')
                        .doc(taskId)
                        .snapshots(),
                    builder: (context, snapshot) {
                      if (!snapshot.hasData) {
                        return const Center(child: CircularProgressIndicator());
                      }

                      final comments =
                          (snapshot.data?.get('comments') as List?) ?? [];

                      if (comments.isEmpty) {
                        return const Center(child: Text("لا توجد تعليقات بعد"));
                      }

                      return ListView.builder(
                        itemCount: comments.length,
                        itemBuilder: (context, index) {
                          final comment = comments[index];

                          return InkWell(
                            onLongPress: () {
                              if (comment['id'] == uid) {
                                showDialog(
                                  context: context,
                                  builder: (context) => AlertDialog(
                                    title: const Text(
                                      "حذف التعليق",
                                      style: TextStyle(color: Colors.red),
                                    ),
                                    content: const Text(
                                      "هل أنت متأكد أنك تريد حذف هذا التعليق؟",
                                    ),
                                    actions: [
                                      TextButton(
                                        onPressed: () => Navigator.pop(context),
                                        child: const Text("إلغاء"),
                                      ),
                                      ElevatedButton(
                                        onPressed: () async {
                                          await FirebaseFirestore.instance
                                              .collection('tasks')
                                              .doc(widget.groupId)
                                              .collection('items')
                                              .doc(taskId)
                                              .update({
                                                'comments':
                                                    FieldValue.arrayRemove([
                                                      comment,
                                                    ]),
                                              });

                                          Navigator.pop(context);
                                          ScaffoldMessenger.of(
                                            context,
                                          ).showSnackBar(
                                            const SnackBar(
                                              content: Text("تم حذف التعليق"),
                                            ),
                                          );
                                        },
                                        child: const Text(
                                          "حذف",
                                          style: TextStyle(color: Colors.red),
                                        ),
                                      ),
                                    ],
                                  ),
                                );
                              }
                            },
                            child: Container(
                              margin: const EdgeInsets.only(bottom: 12),
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: Colors.grey.shade100,
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    comment['commenter'] ?? 'مستخدم مجهول',
                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  const SizedBox(height: 5),
                                  Text(
                                    comment['comment'] ?? '',
                                    style: TextStyle(color: Colors.blue),
                                  ),
                                  const SizedBox(height: 8),
                                  Align(
                                    alignment: Alignment.bottomRight,
                                    child: Text(
                                      DateFormat('dd/MM/yyyy – HH:mm').format(
                                        (comment['commentCreatedAt']
                                                as Timestamp)
                                            .toDate(),
                                      ),
                                      style: TextStyle(
                                        fontSize: 11,
                                        color: Colors.grey.shade600,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  /// ================== CONFIRM TASK ==================
  Future<void> _confirmTask(
    QueryDocumentSnapshot task,
    List assetIds,
    String text,
  ) async {
    final notesController = TextEditingController();
    final costController = TextEditingController();

    final confirmed = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: Text(text),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: notesController,
              decoration: const InputDecoration(labelText: 'ملاحظات'),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: costController,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: 'التكلفة'),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('إلغاء'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('حفظ'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    final cost = double.tryParse(costController.text) ?? 0;

    for (var assetId in assetIds) {
      await FirebaseFirestore.instance
          .collection('assets')
          .doc(widget.groupId)
          .collection('items')
          .doc(assetId)
          .collection('works')
          .add({
            'title': task['title'],
            'note': notesController.text.trim(),
            'cost': cost,
            'assignedTo': task['assignedTo'],
            'taskDateTime': task['taskDateTime'],
            'description': task['description'],
            'createdAt': task['createdAt'],
          });
      await FirebaseFirestore.instance
          .collection('tasks')
          .doc(widget.groupId)
          .collection('items')
          .doc(task.id)
          .delete();
    }
    setState(() {});
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('تم تأكيد المهمة بنجاح')));
  }
}
