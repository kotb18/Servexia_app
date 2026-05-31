import 'package:tflite_flutter/tflite_flutter.dart';

class AIService {
  static Future<Interpreter> loadModel() async {
    return await Interpreter.fromAsset('assets/face_model.tflite');
  }
}
