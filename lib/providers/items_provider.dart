import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../database/daos/item_dao.dart';
import '../models/item_model.dart';
import '../services/notification_service.dart';
import 'database_provider.dart';
import 'budget_provider.dart';

// Selected date for viewing (default = today)
final selectedDateProvider = StateProvider<DateTime>((ref) => DateTime.now());

class ItemsNotifier extends AsyncNotifier<List<ItemModel>> {
  @override
  Future<List<ItemModel>> build() async {
    final db   = await ref.watch(databaseProvider.future);
    final date = ref.watch(selectedDateProvider);
    return ItemDao(db).findByDay(date);
  }

  Future<void> addItem(CreateItemDto dto) async {
    final db = await ref.read(databaseProvider.future);
    await ItemDao(db).insert(dto);
    ref.invalidateSelf();
    // Check budget after adding
    await ref.read(budgetStatusProvider.notifier).checkAndAlert();
  }

  Future<void> deleteItem(String id) async {
    final db = await ref.read(databaseProvider.future);
    await ItemDao(db).softDelete(id);
    ref.invalidateSelf();
  }
}

final itemsProvider = AsyncNotifierProvider<ItemsNotifier, List<ItemModel>>(ItemsNotifier.new);
