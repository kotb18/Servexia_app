import 'dart:convert';
import 'package:awesome_dialog/awesome_dialog.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:intl_phone_field/intl_phone_field.dart';
import 'dart:io';
import 'dart:typed_data';
import 'package:camera/camera.dart';
import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart';
import 'package:image/image.dart' as img;
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:tflite_flutter/tflite_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';

class JoinGroupScreen extends StatefulWidget {
  const JoinGroupScreen({super.key});
  static const String screenroute = 'joinGroup';

  @override
  State<JoinGroupScreen> createState() => _JoinGroupScreenState();
}

class _JoinGroupScreenState extends State<JoinGroupScreen> {
  final _formKey = GlobalKey<FormState>();
  static String _localKey(String uid) => 'face_data_$uid';

  final nameController = TextEditingController();
  final jobController = TextEditingController();

  bool isLoading = false;
  String? scannedGroupId;
  String? _completePhoneNumber;

  List<double> faceEmbedding = [];

  final String uid = FirebaseAuth.instance.currentUser!.uid;

  @override
  void dispose() {
    nameController.dispose();
    jobController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey.shade100,
      appBar: AppBar(
        centerTitle: true,
        title: const Text(
          'الانضمام لمجموعة',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            const SizedBox(height: 20),

            Icon(
              Icons.group_add,
              size: 70,
              color: Theme.of(context).primaryColor,
            ),

            const SizedBox(height: 10),

            const Text(
              "انضم إلى فريق العمل",
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),

            const SizedBox(height: 25),

            Card(
              elevation: 6,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
              ),
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Form(
                  key: _formKey,
                  child: Column(
                    children: [
                      TextFormField(
                        controller: nameController,
                        decoration: _inputDecoration('الاسم', Icons.person),
                        validator: (v) =>
                            v == null || v.trim().isEmpty ? 'أدخل الاسم' : null,
                      ),
                      const SizedBox(height: 15),

                      TextFormField(
                        controller: jobController,
                        decoration: _inputDecoration('الوظيفة', Icons.work),
                        validator: (v) => v == null || v.trim().isEmpty
                            ? 'أدخل الوظيفة'
                            : null,
                      ),
                      const SizedBox(height: 15),

                      Directionality(
                        textDirection: TextDirection.ltr,
                        child: IntlPhoneField(
                          decoration: _inputDecoration(
                            'رقم الهاتف',
                            Icons.phone,
                          ),
                          initialCountryCode: 'EG',
                          onChanged: (phone) {
                            _completePhoneNumber = phone.completeNumber;
                          },
                          validator: (phone) {
                            if (phone == null || phone.number.isEmpty) {
                              return 'رقم الهاتف مطلوب';
                            }
                            if (!phone.isValidNumber()) {
                              return 'رقم غير صحيح';
                            }
                            return null;
                          },
                        ),
                      ),

                      const SizedBox(height: 20),

                      /// زر تسجيل الوجه
                      SizedBox(
                        width: double.infinity,
                        height: 55,
                        child: ElevatedButton.icon(
                          icon: const Icon(Icons.face),
                          label: Text(
                            faceEmbedding.isEmpty
                                ? 'التقاط بصمة الوجه'
                                : 'تم تسجيل الوجه ✔',
                          ),
                          onPressed: () async {
                            final result = await Navigator.push<List<double>>(
                              context,
                              MaterialPageRoute(
                                builder: (_) => const FaceRegisterScreen(),
                              ),
                            );

                            if (result != null) {
                              setState(() {
                                faceEmbedding = result;
                              });
                            }
                          },
                        ),
                      ),

                      const SizedBox(height: 25),

                      /// زر المسح والانضمام
                      SizedBox(
                        width: double.infinity,
                        height: 55,
                        child: ElevatedButton.icon(
                          icon: isLoading
                              ? const SizedBox(
                                  width: 18,
                                  height: 18,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: Colors.white,
                                  ),
                                )
                              : const Icon(Icons.qr_code_scanner),
                          label: Text(
                            isLoading ? 'جارٍ الإرسال...' : 'مسح QR والانضمام',
                          ),
                          onPressed: isLoading ? null : scanQrAndJoin,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  InputDecoration _inputDecoration(String label, IconData icon) {
    return InputDecoration(
      labelText: label,
      prefixIcon: Icon(icon),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(15)),
    );
  }

  Future<void> scanQrAndJoin() async {
    if (!_formKey.currentState!.validate()) return;

    if (_completePhoneNumber == null) {
      _showError("رقم الهاتف مطلوب");
      return;
    }

    if (faceEmbedding.isEmpty) {
      _showError("بصمة الوجه مطلوبة");
      return;
    }

    final scanResult = await Navigator.push<String>(
      context,
      MaterialPageRoute(builder: (_) => const QrScanScreen()),
    );

    if (scanResult == null) return;

    Map<String, dynamic> data;
    try {
      data = jsonDecode(scanResult);
    } catch (_) {
      _showError("QR غير صالح");
      return;
    }

    if (data['type'] != 'group_invite') {
      _showError("QR غير صالح");
      return;
    }

    final expiresAt = DateTime.fromMillisecondsSinceEpoch(data['expiresAt']);

    if (DateTime.now().isAfter(expiresAt)) {
      _showError("QR منتهي الصلاحية");
      return;
    }

    final String groupId = data['groupId'];

    setState(() => isLoading = true);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      _localKey('$groupId $uid'),
      jsonEncode(faceEmbedding),
    );

    final memberRef = FirebaseFirestore.instance
        .collection('teams')
        .doc(groupId)
        .collection('members')
        .doc(uid);

    await memberRef.set({
      'id': uid,
      'name': nameController.text.trim(),
      'job': jobController.text.trim(),
      'phone': _completePhoneNumber!,
      'joinedAt': Timestamp.now(),
      'confirm': false,
      'photoURL': FirebaseAuth.instance.currentUser!.photoURL ?? '',
    });
    FirebaseFirestore.instance
        .collection('faceEmbedding')
        .doc(groupId)
        .collection('users')
        .doc(uid)
        .set({
          'faceEmbedding': faceEmbedding,
          'updatedAt': FieldValue.serverTimestamp(),
        });
    await FirebaseMessaging.instance.subscribeToTopic(groupId);

    setState(() => isLoading = false);

    _showSuccess("تم إرسال طلب الانضمام بنجاح\nفي انتظار موافقة الأدمن");
  }

  void _showError(String msg) {
    AwesomeDialog(
      context: context,
      dialogType: DialogType.error,
      title: "خطأ",
      desc: msg,
    ).show();
  }

  void _showSuccess(String msg) {
    AwesomeDialog(
      context: context,
      dialogType: DialogType.success,
      title: "نجاح",
      desc: msg,
      btnOkText: 'حسنا',
      btnOkOnPress: () {
        Navigator.of(context).pop();
      },
    ).show();
  }
}

class FaceRegisterScreen extends StatefulWidget {
  const FaceRegisterScreen({super.key});

  @override
  State<FaceRegisterScreen> createState() => _FaceRegisterScreenState();
}

class _FaceRegisterScreenState extends State<FaceRegisterScreen> {
  late CameraController _cameraController;
  late List<CameraDescription> _cameras;

  String statusText = "وجّه الكاميرا لوجهك";
  bool captured = false;
  bool processing = false;

  @override
  void initState() {
    super.initState();
    _initCamera();
  }

  Future<void> _initCamera() async {
    _cameras = await availableCameras();

    final frontCamera = _cameras.firstWhere(
      (c) => c.lensDirection == CameraLensDirection.front,
    );

    _cameraController = CameraController(
      frontCamera,
      ResolutionPreset.medium,
      enableAudio: false,
    );

    await _cameraController.initialize();
    setState(() {});
    _captureFace();
  }

  void _showError(String msg) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(msg), backgroundColor: Colors.red));
  }

  Future<void> _captureFace() async {
    await Future.delayed(const Duration(seconds: 2));

    final picture = await _cameraController.takePicture();
    final file = File(picture.path);

    final inputImage = InputImage.fromFile(file);

    final faceDetector = FaceDetector(
      options: FaceDetectorOptions(
        enableLandmarks: true,
        enableClassification: true,
      ),
    );

    final faces = await faceDetector.processImage(inputImage);

    if (faces.isEmpty) {
      faceDetector.close();
      _showError("لم يتم اكتشاف أي وجه");
      return;
    }

    if (faces.length > 1) {
      faceDetector.close();
      _showError("يجب أن يكون هناك شخص واحد فقط أمام الكاميرا");
      return;
    }

    final embedding = await _extractEmbedding(
      imagePath: picture.path,
      face: faces.first,
    );

    faceDetector.close();
    await _cameraController.dispose();

    if (mounted) {
      Navigator.pop(context, embedding);
    }
  }

  Future<List<double>> _extractEmbedding({
    required String imagePath,
    required Face face,
  }) async {
    final interpreter = await Interpreter.fromAsset('assets/face_model.tflite');

    final bytes = await File(imagePath).readAsBytes();
    final img.Image original = img.decodeImage(bytes)!;

    final rect = face.boundingBox;

    final img.Image cropped = img.copyCrop(
      original,
      x: rect.left.toInt().clamp(0, original.width),
      y: rect.top.toInt().clamp(0, original.height),
      width: rect.width.toInt().clamp(0, original.width),
      height: rect.height.toInt().clamp(0, original.height),
    );

    final img.Image resized = img.copyResize(cropped, width: 112, height: 112);

    final input = _imageToFloat32(resized);

    final output = List.generate(1, (_) => List.filled(192, 0.0));

    interpreter.run(input.reshape([1, 112, 112, 3]), output);

    interpreter.close();

    return output.first.map((e) => e.toDouble()).toList();
  }

  Float32List _imageToFloat32(img.Image image) {
    final Float32List convertedBytes = Float32List(1 * 112 * 112 * 3);

    int pixelIndex = 0;

    for (int y = 0; y < 112; y++) {
      for (int x = 0; x < 112; x++) {
        final pixel = image.getPixel(x, y);

        final r = pixel.r;
        final g = pixel.g;
        final b = pixel.b;

        convertedBytes[pixelIndex++] = (r - 127.5) / 127.5;
        convertedBytes[pixelIndex++] = (g - 127.5) / 127.5;
        convertedBytes[pixelIndex++] = (b - 127.5) / 127.5;
      }
    }

    return convertedBytes;
  }

  @override
  Widget build(BuildContext context) {
    if (!_cameraController.value.isInitialized) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    return Scaffold(
      body: Stack(
        children: [
          CameraPreview(_cameraController),
          Positioned(
            bottom: 40,
            left: 0,
            right: 0,
            child: Center(
              child: Container(
                padding: const EdgeInsets.all(12),
                color: Colors.black54,
                child: Text(
                  statusText,
                  style: const TextStyle(color: Colors.white),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class QrScanScreen extends StatefulWidget {
  const QrScanScreen({super.key});

  @override
  State<QrScanScreen> createState() => _QrScanScreenState();
}

class _QrScanScreenState extends State<QrScanScreen> {
  final MobileScannerController controller = MobileScannerController(
    detectionSpeed: DetectionSpeed.noDuplicates,
    facing: CameraFacing.back,
    torchEnabled: false,
  );

  bool isProcessing = false;

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  void _onDetect(BarcodeCapture capture) async {
    if (isProcessing) return;

    final barcode = capture.barcodes.first.rawValue;

    if (barcode == null || barcode.isEmpty) return;

    isProcessing = true;

    try {
      final data = jsonDecode(barcode);

      if (data is Map &&
          data.containsKey('groupId') &&
          data.containsKey('type')) {
        await controller.stop();
        if (mounted) {
          Navigator.pop(context, barcode);
        }
      } else {
        _showInvalidQr();
      }
    } catch (_) {
      _showInvalidQr();
    }

    isProcessing = false;
  }

  void _showInvalidQr() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('QR غير صالح'), backgroundColor: Colors.red),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: const Text("مسح QR"),
        actions: [
          IconButton(
            icon: const Icon(Icons.flash_on),
            onPressed: () => controller.toggleTorch(),
          ),
        ],
      ),
      body: Stack(
        children: [
          MobileScanner(controller: controller, onDetect: _onDetect),

          /// إطار توضيحي في النص
          Center(
            child: Container(
              width: 250,
              height: 250,
              decoration: BoxDecoration(
                border: Border.all(color: Colors.white, width: 3),
                borderRadius: BorderRadius.circular(20),
              ),
            ),
          ),

          Positioned(
            bottom: 40,
            left: 0,
            right: 0,
            child: Center(
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 10,
                ),
                decoration: BoxDecoration(
                  color: Colors.black54,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: const Text(
                  "وجّه الكاميرا نحو QR الخاص بالمجموعة",
                  style: TextStyle(color: Colors.white, fontSize: 14),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
