import 'package:material_ui/material_ui.dart';

import 'rules_screen.dart';

/// Opens the full rules screen.
Future<void> showRulesDialog(BuildContext context) =>
    Navigator.of(context).push(MaterialPageRoute(builder: (_) => const RulesScreen()));
