/// Glob-style patterns relative to storage root (e.g., /storage/emulated/0).
/// Use '*' to match any single directory segment.
const List<String> kJunkDirectoryPatterns = [
  'Android/data/*/cache',
  'Android/data/*/code_cache',
  'Android/data/*/no_backup',
  '.thumbnails',
  'DCIM/.thumbnails',
  'Pictures/.thumbnails',
  'Android/data/*/files/temp',
  'Android/data/*/files/tmp',
];

/// These directories themselves should be cleaned of all contents.
const List<String> kJunkDirectoryExact = [
  'tmp',
  'temp',
  '.trash',
  'Trash',
  '.Trashes',
];

/// File extensions treated as junk.
const Set<String> kTempExtensions = {'.tmp', '.temp', '.bak', '.old', '.orig'};
const Set<String> kLogExtensions = {'.log', '.trace', '.crash', '.dmp', '.hprof'};
const Set<String> kApkExtension = {'.apk'};

/// Minimum file size in bytes to consider for duplicate detection (skip tiny files).
const int kMinDuplicateSizeBytes = 1024; // 1 KB

/// Maximum file size to fully hash synchronously (larger files use partial hash).
const int kLargeFileSizeBytes = 50 * 1024 * 1024; // 50 MB
