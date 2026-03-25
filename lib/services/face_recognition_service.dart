import 'dart:io';
import 'dart:math';
import 'dart:typed_data';
import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart';
import 'package:image/image.dart' as img;

enum FaceCaptureStep {
  center,
  left,
  right,
  up,
  down,
  smile,
}

class FaceRecognitionService {
  static const int embeddingDimension = 512;

  final FaceDetector _faceDetector = FaceDetector(
    options: FaceDetectorOptions(
      enableContours: true,
      enableLandmarks: true,
      enableClassification: true,
      enableTracking: true,
    ),
  );

  InputImage? _inputImageFromCameraImage(CameraImage image, CameraDescription camera) {
    final sensorOrientation = camera.sensorOrientation;
    InputImageRotation? rotation;

    if (Platform.isIOS || Platform.isAndroid) {
      rotation = InputImageRotationValue.fromRawValue(sensorOrientation);
    }

    if (rotation == null) return null;

    final format = InputImageFormatValue.fromRawValue(image.format.raw);
    if (format == null || image.planes.isEmpty) return null;

    final plane = image.planes.first;

    return InputImage.fromBytes(
      bytes: plane.bytes,
      metadata: InputImageMetadata(
        size: Size(image.width.toDouble(), image.height.toDouble()),
        rotation: rotation,
        format: format,
        bytesPerRow: plane.bytesPerRow,
      ),
    );
  }

  Future<List<Face>> detectFacesInCameraImage(
      CameraImage image,
      CameraDescription camera,
      ) async {
    try {
      final inputImage = _inputImageFromCameraImage(image, camera);
      if (inputImage == null) return [];
      return await _faceDetector.processImage(inputImage);
    } catch (e) {
      print('Face detection error: $e');
      return [];
    }
  }

  Future<List<Face>> detectFacesInFile(String imagePath) async {
    try {
      final inputImage = InputImage.fromFilePath(imagePath);
      return await _faceDetector.processImage(inputImage);
    } catch (e) {
      print('Face detection error: $e');
      return [];
    }
  }

  bool validateFaceForStep(Face face, FaceCaptureStep step) {
    switch (step) {
      case FaceCaptureStep.center:
        return face.headEulerAngleY!.abs() < 15 && face.headEulerAngleZ!.abs() < 15;
      case FaceCaptureStep.left:
        return face.headEulerAngleY! > 20 && face.headEulerAngleY! < 45;
      case FaceCaptureStep.right:
        return face.headEulerAngleY! < -20 && face.headEulerAngleY! > -45;
      case FaceCaptureStep.up:
        return face.headEulerAngleX! < -10 && face.headEulerAngleX! > -30;
      case FaceCaptureStep.down:
        return face.headEulerAngleX! > 10 && face.headEulerAngleX! < 30;
      case FaceCaptureStep.smile:
        return face.smilingProbability != null && face.smilingProbability! > 0.7;
    }
  }

  Future<List<double>> generateEmbeddings(List<String> imagePaths) async {
    try {
      List<double> combinedEmbeddings = [];

      for (String imagePath in imagePaths) {
        final faces = await detectFacesInFile(imagePath);
        if (faces.isNotEmpty) {
          final embedding = _generatePseudoEmbedding(faces.first);
          combinedEmbeddings.addAll(embedding);
        }
      }

      if (combinedEmbeddings.isNotEmpty) {
        final avgEmbedding = _averageEmbeddings(combinedEmbeddings);
        return _normalizeEmbedding(avgEmbedding);
      }

      return List.filled(embeddingDimension, 0.0);
    } catch (e) {
      print('Embedding generation error: $e');
      return List.filled(embeddingDimension, 0.0);
    }
  }

  List<double> _generatePseudoEmbedding(Face face) {
    List<double> embedding = [];

    embedding.add(face.boundingBox.width.toDouble());
    embedding.add(face.boundingBox.height.toDouble());
    embedding.add(face.boundingBox.left.toDouble());
    embedding.add(face.boundingBox.top.toDouble());

    embedding.add(face.headEulerAngleX ?? 0.0);
    embedding.add(face.headEulerAngleY ?? 0.0);
    embedding.add(face.headEulerAngleZ ?? 0.0);

    for (FaceLandmarkType type in FaceLandmarkType.values) {
      final landmark = face.landmarks[type];
      if (landmark != null) {
        embedding.add(landmark.position.x.toDouble());
        embedding.add(landmark.position.y.toDouble());
      } else {
        embedding.add(0.0);
        embedding.add(0.0);
      }
    }

    while (embedding.length < embeddingDimension) {
      embedding.add(0.0);
    }

    return embedding.take(embeddingDimension).toList();
  }

  List<double> _averageEmbeddings(List<double> embeddings) {
    final chunks = <List<double>>[];
    for (int i = 0; i < embeddings.length; i += embeddingDimension) {
      chunks.add(embeddings.skip(i).take(embeddingDimension).toList());
    }

    List<double> averaged = List.filled(embeddingDimension, 0.0);
    for (var chunk in chunks) {
      for (int i = 0; i < chunk.length; i++) {
        averaged[i] += chunk[i];
      }
    }

    for (int i = 0; i < averaged.length; i++) {
      averaged[i] /= chunks.length;
    }

    return averaged;
  }

  List<double> _normalizeEmbedding(List<double> embedding) {
    double magnitude = 0.0;
    for (double value in embedding) {
      magnitude += value * value;
    }
    magnitude = magnitude > 0 ? sqrt(magnitude) : 1.0;

    return embedding.map((value) => value / magnitude).toList();
  }

  double calculateSimilarity(List<double> embedding1, List<double> embedding2) {
    if (embedding1.length != embedding2.length) return 0.0;

    double dotProduct = 0.0;
    double magnitude1 = 0.0;
    double magnitude2 = 0.0;

    for (int i = 0; i < embedding1.length; i++) {
      dotProduct += embedding1[i] * embedding2[i];
      magnitude1 += embedding1[i] * embedding1[i];
      magnitude2 += embedding2[i] * embedding2[i];
    }

    magnitude1 = sqrt(magnitude1);
    magnitude2 = sqrt(magnitude2);

    if (magnitude1 == 0.0 || magnitude2 == 0.0) return 0.0;

    return dotProduct / (magnitude1 * magnitude2);
  }

  void dispose() {
    _faceDetector.close();
  }
}

extension FaceCaptureStepExtension on FaceCaptureStep {
  String get instruction {
    switch (this) {
      case FaceCaptureStep.center:
        return 'Look straight at the camera';
      case FaceCaptureStep.left:
        return 'Turn your head to the left';
      case FaceCaptureStep.right:
        return 'Turn your head to the right';
      case FaceCaptureStep.up:
        return 'Tilt your head up slightly';
      case FaceCaptureStep.down:
        return 'Tilt your head down slightly';
      case FaceCaptureStep.smile:
        return 'Smile for the camera';
    }
  }

  String get title {
    switch (this) {
      case FaceCaptureStep.center:
        return 'Center Position';
      case FaceCaptureStep.left:
        return 'Left Turn';
      case FaceCaptureStep.right:
        return 'Right Turn';
      case FaceCaptureStep.up:
        return 'Look Up';
      case FaceCaptureStep.down:
        return 'Look Down';
      case FaceCaptureStep.smile:
        return 'Smile';
    }
  }
}
