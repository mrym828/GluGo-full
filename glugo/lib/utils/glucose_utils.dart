
Map<String, dynamic>? getLatestGlucoseReading(List<dynamic> records) {
  if (records.isEmpty) return null;

  final validRecords = records.where((record) {
    final glucose = record['glucose_level']?.toDouble();
    final timestamp = record['timestamp'];
    return glucose != null && glucose > 0 && timestamp != null;
  }).toList();

  if (validRecords.isEmpty) return null;

  validRecords.sort((a, b) {
    final aTime = DateTime.parse(a['timestamp']);
    final bTime = DateTime.parse(b['timestamp']);
    return bTime.compareTo(aTime);
  });

  final latest = validRecords.first;
  print('🔍 Latest reading: ${latest['glucose_level']} mg/dL (source: ${latest['source']})');
  
  return latest;
}