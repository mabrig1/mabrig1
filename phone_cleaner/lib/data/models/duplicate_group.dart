import 'file_item.dart';

class DuplicateGroup {
  final String contentHash;
  final List<FileItem> files;

  DuplicateGroup({
    required this.contentHash,
    required this.files,
  });

  int get sizeBytes => files.isNotEmpty ? files.first.sizeBytes : 0;
  int get wastedBytes => sizeBytes * (files.length - 1);
  int get count => files.length;

  /// Returns the index of the file to keep (oldest by lastModified).
  int get keepIndex {
    int best = 0;
    for (int i = 1; i < files.length; i++) {
      if (files[i].lastModified.isBefore(files[best].lastModified)) {
        best = i;
      }
    }
    return best;
  }

  /// Files that are marked for deletion (all except keepIndex).
  List<FileItem> get selectedForDeletion {
    return [
      for (int i = 0; i < files.length; i++)
        if (i != keepIndex) files[i],
    ];
  }
}
