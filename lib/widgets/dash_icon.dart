import 'package:flutter/widgets.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../theme/dash_theme.dart';

/// Material Symbols SVG from assets/icons/. Never use the Icons.* font.
class DashIcon extends StatelessWidget {
  const DashIcon(this.name, {super.key, this.size = 20, this.color});

  final String name;
  final double size;
  final Color? color;

  @override
  Widget build(BuildContext context) => SvgPicture.asset(
        'assets/icons/$name.svg',
        width: size,
        height: size,
        colorFilter: ColorFilter.mode(color ?? DashColors.text1, BlendMode.srcIn),
      );
}
