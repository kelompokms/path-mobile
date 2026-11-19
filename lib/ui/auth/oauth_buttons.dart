import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:path_mobile/data/login/login_model.dart';
import 'package:path_mobile/ui/core/app_theme.dart';

class OAuthButtons extends StatelessWidget {
  static const String googleIconAsset = 'assets/images/google.svg';

  final OAuthProvider? loadingProvider;
  final bool disabled;
  final ValueChanged<OAuthProvider> onProviderTap;
  final String dividerText;

  const OAuthButtons({
    super.key,
    required this.onProviderTap,
    this.loadingProvider,
    this.disabled = false,
    this.dividerText = 'atau masuk dengan',
  });

  @override
  Widget build(BuildContext context) {
    final isBusy = disabled || loadingProvider != null;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      spacing: 12,
      children: [
        Row(
          children: [
            Expanded(
              child: Divider(
                color: AppColors.secondaryText.withValues(alpha: 0.35),
              ),
            ),
            Flexible(
              flex: 3,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: Text(
                  dividerText,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 12,
                    color: AppColors.secondaryText,
                  ),
                ),
              ),
            ),
            Expanded(
              child: Divider(
                color: AppColors.secondaryText.withValues(alpha: 0.35),
              ),
            ),
          ],
        ),
        _OAuthProviderButton(
          label: OAuthProvider.google.label,
          iconAsset: googleIconAsset,
          isLoading: loadingProvider == OAuthProvider.google,
          onPressed: isBusy ? null : () => onProviderTap(OAuthProvider.google),
        ),
      ],
    );
  }
}

class _OAuthProviderButton extends StatelessWidget {
  final String label;
  final String iconAsset;
  final bool isLoading;
  final VoidCallback? onPressed;

  const _OAuthProviderButton({
    required this.label,
    required this.iconAsset,
    required this.isLoading,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return OutlinedButton(
      onPressed: onPressed,
      style: OutlinedButton.styleFrom(
        foregroundColor: AppColors.text,
        backgroundColor: AppColors.card,
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 12),
        side: BorderSide(
          color: AppColors.secondaryText.withValues(alpha: 0.35),
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppTheme.cardRadius),
        ),
      ),
      child: isLoading
          ? const SizedBox(
              height: 18,
              width: 18,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          : Row(
              mainAxisAlignment: MainAxisAlignment.center,
              spacing: 8,
              children: [
                SvgPicture.asset(
                  iconAsset,
                  width: 20,
                  height: 20,
                  excludeFromSemantics: true,
                ),
                Flexible(
                  child: Text(
                    label,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                ),
              ],
            ),
    );
  }
}
