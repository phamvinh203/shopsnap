/// Shared component library của ShopSnap (Phase 2 UI redesign).
///
/// Nguyên tắc: stateless, nhận data + callback, KHÔNG tự gọi provider,
/// consume tokens/SnapColors — không hardcode màu/kích thước.
///
/// ```dart
/// import 'package:shopsnap/widgets/ui/ui.dart';
/// ```
library;

export 'app_bottom_nav.dart';
export 'app_bottom_sheet.dart';
export 'app_button.dart';
export 'app_card.dart';
export 'app_scaffold.dart';
export 'app_snack_bar.dart';
export 'app_states.dart';
export 'app_text_field.dart';
export 'budget_insights_strip.dart';
export 'budget_progress_bar.dart';
export 'category_chip.dart';
export 'confirm_dialog.dart';
export 'loading_skeleton.dart';
export 'money_text.dart';
export 'price_tag.dart';
export 'section_header.dart';
