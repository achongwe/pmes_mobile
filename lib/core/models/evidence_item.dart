import 'package:image_picker/image_picker.dart';

enum EvidenceType { photo, video, document }

class EvidenceItem {
  const EvidenceItem({
    required this.file,
    required this.type,
    required this.sizeBytes,
  });

  final XFile file;
  final EvidenceType type;
  final int sizeBytes;

  String get name => file.name;

  String get label => switch (type) {
    EvidenceType.photo => 'photo',
    EvidenceType.video => 'video',
    EvidenceType.document => 'document',
  };

  bool get isPdf => name.toLowerCase().endsWith('.pdf');

  String get formattedSize {
    const kb = 1024;
    const mb = kb * 1024;
    if (sizeBytes >= mb) return '${(sizeBytes / mb).toStringAsFixed(1)} MB';
    if (sizeBytes >= kb) return '${(sizeBytes / kb).toStringAsFixed(0)} KB';
    return '$sizeBytes B';
  }
}
