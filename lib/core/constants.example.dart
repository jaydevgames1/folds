const String kDevPassword = "DEV_PASSWORD";
const String kModPassword = "MODERATOR_PASSWORD";
final DateTime kFoldsLaunchDate = DateTime(2026, 11, 1);
int foldsDayNumberFor(DateTime date) {
  final clean = DateTime(date.year, date.month, date.day);
  final diff = clean.difference(kFoldsLaunchDate).inDays;
  return diff >= 0 ? diff + 1 : diff;
}