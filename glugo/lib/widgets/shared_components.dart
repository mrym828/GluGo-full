import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../utils/theme.dart';

// Base Card Widget
class BaseCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry? padding;
  final Color? backgroundColor;
  final List<BoxShadow>? boxShadow;
  final BorderRadius? borderRadius;
  final Border? border;

  const BaseCard({
    super.key,
    required this.child,
    this.padding,
    this.backgroundColor,
    this.boxShadow,
    this.borderRadius,
    this.border,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: padding ?? const EdgeInsets.all(AppTheme.spacingM),
      decoration: BoxDecoration(
        color: backgroundColor ?? AppTheme.surface,
        borderRadius: borderRadius ?? AppTheme.radiusL,
        boxShadow: boxShadow ?? AppTheme.lightShadow,
        border: border ?? Border.all(color: AppTheme.borderLight, width: 0.5),
      ),
      child: child,
    );
  }
}

// Metric Card Widget
class MetricCard extends StatelessWidget {
  final String title;
  final String value;
  final String? unit;
  final String? subtitle;
  final IconData? icon;
  final Color? accentColor;
  final VoidCallback? onTap;

  const MetricCard({
    super.key,
    required this.title,
    required this.value,
    this.unit,
    this.subtitle,
    this.icon,
    this.accentColor,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final color = accentColor ?? AppTheme.primaryBlue;
    
    return GestureDetector(
      onTap: onTap,
      child: BaseCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  title,
                  style: AppTheme.labelMedium.copyWith(
                    color: AppTheme.textSecondary,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                if (icon != null)
                  Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: color.withOpacity(0.08),
                      borderRadius: AppTheme.radiusS,
                    ),
                    child: Icon(
                      icon,
                      size: 16,
                      color: color,
                    ),
                  ),
              ],
            ),
            const SizedBox(height: AppTheme.spacingM),
            Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  value,
                  style: AppTheme.headlineLarge.copyWith(
                    color: color,
                    fontWeight: FontWeight.w700,
                    fontSize: 28,
                  ),
                ),
                if (unit != null) ...[
                  const SizedBox(width: 4),
                  Padding(
                    padding: const EdgeInsets.only(bottom: 3),
                    child: Text(
                      unit!,
                      style: AppTheme.bodySmall.copyWith(
                        color: AppTheme.textSecondary,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ],
            ),
            if (subtitle != null) ...[
              const SizedBox(height: 4),
              Text(
                subtitle!,
                style: AppTheme.bodySmall.copyWith(
                  color: AppTheme.textTertiary,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

// Action Button Widget
class ActionButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final VoidCallback onPressed;
  final bool isPrimary;
  final Color? customColor;

  const ActionButton({
    super.key,
    required this.label,
    required this.icon,
    required this.onPressed,
    this.isPrimary = true,
    this.customColor,
  });

  @override
  Widget build(BuildContext context) {
    final color = customColor ?? AppTheme.primaryBlue;
    
    if (isPrimary) {
      return ElevatedButton.icon(
        onPressed: () {
          HapticFeedback.lightImpact();
          onPressed();
        },
        icon: Icon(icon, size: 18),
        label: Text(label),
        style: ElevatedButton.styleFrom(
          backgroundColor: color,
          foregroundColor: AppTheme.onPrimary,
          elevation: 0,
          padding: const EdgeInsets.symmetric(
            vertical: AppTheme.spacingM,
            horizontal: AppTheme.spacingL,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: AppTheme.radiusM,
          ),
          textStyle: AppTheme.labelMedium.copyWith(
            fontWeight: FontWeight.w600,
          ),
        ),
      );
    } else {
      return OutlinedButton.icon(
        onPressed: () {
          HapticFeedback.lightImpact();
          onPressed();
        },
        icon: Icon(icon, size: 18),
        label: Text(label),
        style: OutlinedButton.styleFrom(
          foregroundColor: color,
          backgroundColor: color.withOpacity(0.04),
          side: BorderSide(color: color.withOpacity(0.2)),
          padding: const EdgeInsets.symmetric(
            vertical: AppTheme.spacingM,
            horizontal: AppTheme.spacingL,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: AppTheme.radiusM,
          ),
          textStyle: AppTheme.labelMedium.copyWith(
            fontWeight: FontWeight.w600,
          ),
        ),
      );
    }
  }
}

// Section Header Widget
class SectionHeader extends StatelessWidget {
  final String title;
  final String? subtitle;
  final Widget? action;

  const SectionHeader({
    super.key,
    required this.title,
    this.subtitle,
    this.action,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: AppTheme.titleLarge.copyWith(
                  fontWeight: FontWeight.w700,
                  color: AppTheme.textPrimary,
                ),
              ),
              if (subtitle != null) ...[
                const SizedBox(height: 4),
                Text(
                  subtitle!,
                  style: AppTheme.bodyMedium.copyWith(
                    color: AppTheme.textSecondary,
                  ),
                ),
              ],
            ],
          ),
        ),
        if (action != null) action!,
      ],
    );
  }
}

// Status Badge Widget
class StatusBadge extends StatelessWidget {
  final String label;
  final Color color;
  final IconData? icon;
  final bool isOutlined;

  const StatusBadge({
    super.key,
    required this.label,
    required this.color,
    this.icon,
    this.isOutlined = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppTheme.spacingM,
        vertical: AppTheme.spacingS,
      ),
      decoration: BoxDecoration(
        color: isOutlined ? Colors.transparent : color.withOpacity(0.1),
        borderRadius: AppTheme.radiusS,
        border: Border.all(
          color: color.withOpacity(isOutlined ? 0.6 : 0.2),
          width: isOutlined ? 1.5 : 1,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(
              icon,
              size: 12,
              color: color,
            ),
            const SizedBox(width: 4),
          ],
          Text(
            label,
            style: AppTheme.labelSmall.copyWith(
              color: color,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

// Connection Status Widget
class ConnectionStatus extends StatelessWidget {
  final bool isConnected;

  const ConnectionStatus({
    super.key,
    this.isConnected = true,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppTheme.spacingM,
        vertical: AppTheme.spacingS,
      ),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.15),
        borderRadius: AppTheme.radiusS,
        border: Border.all(
          color: Colors.white.withOpacity(0.2),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 6,
            height: 6,
            decoration: BoxDecoration(
              color: isConnected ? AppTheme.successGreen : AppTheme.errorRed,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 6),
          Text(
            isConnected ? 'Connected' : 'Disconnected',
            style: AppTheme.labelSmall.copyWith(
              color: AppTheme.onPrimary,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

// List Item Widget
class CustomListItem extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String title;
  final String subtitle;
  final Widget? trailing;
  final VoidCallback? onTap;
  final bool showDivider;

  const CustomListItem({
    super.key,
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.subtitle,
    this.trailing,
    this.onTap,
    this.showDivider = true,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: onTap,
            borderRadius: AppTheme.radiusM,
            child: Padding(
              padding: const EdgeInsets.all(AppTheme.spacingL),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(AppTheme.spacingS),
                    decoration: BoxDecoration(
                      color: iconColor.withOpacity(0.1),
                      borderRadius: AppTheme.radiusS,
                    ),
                    child: Icon(
                      icon,
                      color: iconColor,
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: AppTheme.spacingL),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          title,
                          style: AppTheme.titleSmall.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          subtitle,
                          style: AppTheme.bodySmall.copyWith(
                            color: AppTheme.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (trailing != null) trailing!,
                ],
              ),
            ),
          ),
        ),
        if (showDivider)
          Divider(
            height: 1,
            thickness: 0.5,
            color: AppTheme.borderLight,
            indent: 64,
          ),
      ],
    );
  }
}

// Shared App Bar Widget
class SharedAppBar extends StatelessWidget implements PreferredSizeWidget {
  final String title;
  final bool showBackButton;
  final List<Widget>? actions;
  final bool showConnection;

  const SharedAppBar({
    super.key,
    required this.title,
    this.showBackButton = false,
    this.actions,
    this.showConnection = true,
  });

  @override
  Widget build(BuildContext context) {
    return AppBar(
      backgroundColor: AppTheme.primaryBlue,
      elevation: 0,
      automaticallyImplyLeading: false,
      flexibleSpace: Container(
        decoration: const BoxDecoration(
          gradient: AppTheme.primaryGradient,
        ),
      ),
      leading: showBackButton 
          ? IconButton(
              onPressed: () => Navigator.pop(context),
              icon: const Icon(Icons.arrow_back_rounded, color: Colors.white),
            )
          : Container(
              margin: const EdgeInsets.all(AppTheme.spacingXS),
              child: Image.asset(
                'assets/images/logo.png',
                width: AppTheme.iconSizeLarge,
                height: AppTheme.iconSizeLarge,
              ),
            ),
      title: Text(
        title,
        style: AppTheme.headlineMedium.copyWith(
          color: AppTheme.onPrimary,
          fontWeight: FontWeight.w800,
        ),
      ),
      actions: [
        ...?actions,
        if (showConnection)
          Container(
            margin: const EdgeInsets.only(right: AppTheme.spacingL),
            child: const ConnectionStatus(),
          ),
      ],
      systemOverlayStyle: SystemUiOverlayStyle.light,
    );
  }

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);
}

// Empty State Widget
class EmptyState extends StatelessWidget {
  final IconData icon;
  final String title;
  final String description;
  final String? actionLabel;
  final VoidCallback? onAction;

  const EmptyState({
    super.key,
    required this.icon,
    required this.title,
    required this.description,
    this.actionLabel,
    this.onAction,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppTheme.spacingXL),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(AppTheme.spacingL),
              decoration: BoxDecoration(
                color: AppTheme.neutralGrayLight.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(
                icon,
                size: 48,
                color: AppTheme.neutralGray,
              ),
            ),
            const SizedBox(height: AppTheme.spacingL),
            Text(
              title,
              style: AppTheme.titleLarge.copyWith(
                fontWeight: FontWeight.w600,
                color: AppTheme.textPrimary,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: AppTheme.spacingS),
            Text(
              description,
              style: AppTheme.bodyMedium.copyWith(
                color: AppTheme.textSecondary,
                height: 1.5,
              ),
              textAlign: TextAlign.center,
            ),
            if (actionLabel != null && onAction != null) ...[
              const SizedBox(height: AppTheme.spacingL),
              ActionButton(
                label: actionLabel!,
                icon: Icons.add_rounded,
                onPressed: onAction!,
              ),
            ],
          ],
        ),
      ),
    );
    
  }
}

class SharedButton extends StatelessWidget {
  final String text;
  final VoidCallback onPressed;
  final IconData? icon;
  final bool _isSecondary; // <-- stays final but has a value

  const SharedButton({
    super.key,
    required this.text,
    required this.onPressed,
    this.icon,
  }) : _isSecondary = false; // ✅ default primary

  const SharedButton._secondary({
    super.key,
    required this.text,
    required this.onPressed,
    this.icon,
  }) : _isSecondary = true; // ✅ secondary style

  factory SharedButton.secondary({
    required String text,
    required VoidCallback onPressed,
    IconData? icon,
  }) {
    return SharedButton._secondary(
      text: text,
      onPressed: onPressed,
      icon: icon,
    );
  }

  @override
  Widget build(BuildContext context) {
    return ElevatedButton.icon(
      onPressed: onPressed,
      icon: Icon(icon, size: 18),
      label: Text(text),
      style: ElevatedButton.styleFrom(
        backgroundColor: _isSecondary ? Colors.white : AppTheme.primaryBlue,
        foregroundColor: _isSecondary ? AppTheme.primaryBlue : Colors.white,
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: _isSecondary
              ? BorderSide(color: AppTheme.primaryBlue, width: 1.2)
              : BorderSide.none,
        ),
        textStyle: const TextStyle(fontWeight: FontWeight.w600),
      ),
    );
  }
}
