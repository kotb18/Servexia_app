import 'package:flutter/material.dart';

class TermsAndConditionsScreen extends StatelessWidget {
  const TermsAndConditionsScreen({super.key});

  static const String screenroute = 'terms';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xffF5F7FA),
      appBar: AppBar(
        elevation: 0,
        centerTitle: true,
        title: const Text(
          'الشروط والأحكام',
          style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white),
        ),
        flexibleSpace: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [Color(0xff0F2027), Color(0xff2C5364)],
            ),
          ),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          /// مقدمة
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xff11998e), Color(0xff38ef7d)],
              ),
              borderRadius: BorderRadius.circular(16),
            ),
            child: const Text(
              'مرحبًا بك في تطبيق Servexia!\n\n'
              'قبل استخدام التطبيق، يرجى قراءة الشروط والأحكام التالية بعناية. '
              'باستخدامك للتطبيق فإنك توافق على الالتزام بها.',
              style: TextStyle(fontSize: 16, color: Colors.white, height: 1.6),
            ),
          ),

          const SizedBox(height: 24),

          _buildSection(
            number: "1",
            title: "استخدام التطبيق",
            body:
                "يُستخدم التطبيق لإدارة فرق الصيانة، الأصول، المهام، الحضور والانصراف وتوثيق الأعمال. "
                "يجب استخدامه فقط للأغراض المشروعة.",
          ),

          _buildSection(
            number: "2",
            title: "الحسابات والعضوية",
            body:
                "أنت مسؤول عن الحفاظ على سرية بيانات حسابك. أي نشاط يتم من خلال حسابك يقع تحت مسؤوليتك الكاملة.",
          ),

          _buildSection(
            number: "3",
            title: "البيانات والمحتوى",
            body:
                "أنت مسؤول عن صحة البيانات المدخلة مثل المهام، الأصول، التكاليف ومعلومات الأعضاء. التطبيق غير مسؤول عن أي بيانات خاطئة.",
          ),

          _buildSection(
            number: "4",
            title: "الموقع الجغرافي",
            body:
                "قد يستخدم التطبيق خدمات الموقع لتسجيل الحضور والانصراف. لن يتم استخدام الموقع إلا في إطار وظائف التطبيق.",
          ),

          _buildSection(
            number: "5",
            title: "الخصوصية",
            body:
                "نحترم خصوصيتك ولا يتم مشاركة بياناتك مع أي طرف ثالث إلا في حدود تشغيل التطبيق.",
          ),

          _buildSection(
            number: "6",
            title: "التعديلات",
            body:
                "يحتفظ مطور التطبيق بالحق في تعديل هذه الشروط في أي وقت دون إشعار مسبق.",
          ),

          _buildSection(
            number: "7",
            title: "إخلاء المسؤولية",
            body:
                "يتم توفير التطبيق \"كما هو\" دون ضمانات. المطور غير مسؤول عن أي خسائر ناتجة عن سوء الاستخدام.\n\n"
                "في حالة عدم نشاط الحساب لمدة 3 أشهر قد يتم حذف البيانات.\n\n"
                "للتواصل: maintenancemasry1991@gmail.com",
          ),

          const SizedBox(height: 30),

          const Divider(),

          const SizedBox(height: 12),

          const Center(
            child: Text(
              "Servexia App\nCreated by Al_Ostaz",
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey),
            ),
          ),

          const SizedBox(height: 40),
        ],
      ),
    );
  }

  /// 🔥 تصميم القسم
  Widget _buildSection({
    required String number,
    required String title,
    required String body,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(.08),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 14,
                backgroundColor: const Color(0xff2C5364),
                child: Text(
                  number,
                  style: const TextStyle(color: Colors.white, fontSize: 13),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 12),

          Text(
            body,
            style: const TextStyle(
              fontSize: 15,
              height: 1.6,
              color: Colors.black87,
            ),
          ),
        ],
      ),
    );
  }
}
