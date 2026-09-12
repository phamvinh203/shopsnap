import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../database/daos/item_dao.dart';
import '../models/summary_model.dart';
import 'database_provider.dart';

final summaryProvider = FutureProvider.family<SummaryModel, DateTime>((ref, date) async {
  final db = await ref.watch(databaseProvider.future);
  return ItemDao(db).getSummaryForDay(date);
});
