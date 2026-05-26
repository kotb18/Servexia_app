import 'package:tflite_flutter/tflite_flutter.dart';

class AIService {
  static Future<dynamic> loadModel() async {
    return await Interpreter.fromAsset('assets/face_model.tflite');
  }
}
