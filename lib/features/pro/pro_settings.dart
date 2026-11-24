import 'package:material_ui/material_ui.dart';

import '../../l10n/generated/app_localizations.dart';

class ProSettings extends StatelessWidget {
  const ProSettings({super.key, this.localizedPrice});

  final String? localizedPrice;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final price = localizedPrice;
    return Column(
      children: [
        ListTile(
          title: Text(l10n.proAnnualPlan),
          subtitle: Text(
            price == null
                ? l10n.proPriceUnavailable
                : l10n.proAnnualPrice(price),
          ),
        ),
        TextButton(onPressed: null, child: Text(l10n.proRestorePurchases)),
      ],
    );
  }
}
