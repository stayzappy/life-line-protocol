import 'dart:io';
import 'dart:typed_data'; // FIX: Added this import for Uint8List
import 'package:minio/minio.dart';
import 'package:mime/mime.dart';
import 'package:path/path.dart' as path;
import '../config/constants.dart';

class StorageService {
  late Minio _minio;

  StorageService() {
    _minio = Minio(
      endPoint: AppConstants.s3Endpoint,
      accessKey: AppConstants.s3AccessKey,
      secretKey: AppConstants.s3SecretKey,
      useSSL: true,
    );
  }

  Future<String?> uploadFile(File file, String userId) async {
    try {
      final fileName = path.basename(file.path);
      final objectName = 'lifeline/users/$userId/${DateTime.now().millisecondsSinceEpoch}_$fileName';
      final contentType = lookupMimeType(file.path) ?? 'application/octet-stream';

      // FIX: Map the Stream<List<int>> into a Stream<Uint8List>
      final stream = file.openRead().map((chunk) => Uint8List.fromList(chunk));

      await _minio.putObject(
        AppConstants.s3Bucket,
        objectName,
        stream,
        chunkSize: 5 * 1024 * 1024,
        metadata: {'content-type': contentType},
      );
      
      // Return the object name (path), not the URL (since it's private)
      return objectName; 
    } catch (e) {
      print('Upload Error: $e');
      return null;
    }
  }
}