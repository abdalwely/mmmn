import 'package:flutter/material.dart';

/// 🎨 Bottom Navigation Bar حديث مع Animations
/// يتميز بتصميم عصري وحركات ناعمة وإبراز الأيقونة النشطة
class ModernBottomNavBar extends StatelessWidget {
  final int currentIndex;
  final Function(int) onTap;
  final List<BottomNavItem> items;

  const ModernBottomNavBar({
    Key? key,
    required this.currentIndex,
    required this.onTap,
    required this.items,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    return Container(
      // ✅ ظل علوي لإضفاء عمق
      decoration: BoxDecoration(
        boxShadow: [
          BoxShadow(
            color: theme.shadowColor.withOpacity(0.12),
            blurRadius: 10,
            offset: const Offset(0, -5),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(20),
          topRight: Radius.circular(20),
        ),
        child: BottomAppBar(
          elevation: 0,
          color: colorScheme.surface,
          shape: const CircularNotchedRectangle(),
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: List.generate(
                items.length,
                    (index) => _buildNavItem(
                  context: context,
                  index: index,
                  isActive: index == currentIndex,
                  item: items[index],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  /// ✅ بناء عنصر الملاح الواحد
  Widget _buildNavItem({
    required BuildContext context,
    required int index,
    required bool isActive,
    required BottomNavItem item,
  }) {
    final colorScheme = Theme.of(context).colorScheme;
    final onSurfaceVariant = colorScheme.onSurfaceVariant;
    return GestureDetector(
      onTap: () => onTap(index),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
        padding: EdgeInsets.symmetric(
          horizontal: isActive ? 20 : 12,
          vertical: 8,
        ),
        decoration: BoxDecoration(
          color: isActive
              ? colorScheme.primary.withOpacity(0.12)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            // ✅ الأيقونة
            AnimatedSize(
              duration: const Duration(milliseconds: 300),
              child: Icon(
                item.icon,
                color: isActive
                    ? colorScheme.primary
                    : onSurfaceVariant.withOpacity(0.7),
                size: isActive ? 26 : 24,
              ),
            ),

            // ✅ التسميات (تظهر فقط للعنصر النشط)
            if (isActive) ...[
              const SizedBox(width: 8),
              AnimatedOpacity(
                opacity: isActive ? 1 : 0,
                duration: const Duration(milliseconds: 300),
                child: Text(
                  item.label,
                  style: TextStyle(
                    color: colorScheme.primary,
                    fontWeight: FontWeight.bold,
                    fontSize: 12,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// 📋 نموذج عنصر الملاح
class BottomNavItem {
  final String label;
  final IconData icon;

  BottomNavItem({
    required this.label,
    required this.icon,
  });
}

/// 🎨 Bottom Navigation Bar بديل - نسخة متقدمة جداً
class AdvancedBottomNavBar extends StatefulWidget {
  final int currentIndex;
  final Function(int) onTap;
  final List<BottomNavItem> items;

  const AdvancedBottomNavBar({
    Key? key,
    required this.currentIndex,
    required this.onTap,
    required this.items,
  }) : super(key: key);

  @override
  State<AdvancedBottomNavBar> createState() => _AdvancedBottomNavBarState();
}

class _AdvancedBottomNavBarState extends State<AdvancedBottomNavBar>
    with TickerProviderStateMixin {
  late List<AnimationController> _animationControllers;

  @override
  void initState() {
    super.initState();
    _animationControllers = List.generate(
      widget.items.length,
          (index) => AnimationController(
        duration: const Duration(milliseconds: 600),
        vsync: this,
      ),
    );
    _animationControllers[widget.currentIndex].forward();
  }

  @override
  void didUpdateWidget(AdvancedBottomNavBar oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.currentIndex != widget.currentIndex) {
      _animationControllers[oldWidget.currentIndex].reverse();
      _animationControllers[widget.currentIndex].forward();
    }
  }

  @override
  void dispose() {
    for (var controller in _animationControllers) {
      controller.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    return Container(
      decoration: BoxDecoration(
        boxShadow: [
          BoxShadow(
            color: theme.shadowColor.withOpacity(0.15),
            blurRadius: 20,
            offset: const Offset(0, -5),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(25),
          topRight: Radius.circular(25),
        ),
        child: BottomAppBar(
          elevation: 0,
          color: colorScheme.surface,
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: List.generate(
                widget.items.length,
                    (index) => _buildAdvancedNavItem(
                  context: context,
                  index: index,
                  isActive: index == widget.currentIndex,
                  controller: _animationControllers[index],
                  item: widget.items[index],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  /// ✅ عنصر الملاح المتقدم مع Animations
  Widget _buildAdvancedNavItem({
    required BuildContext context,
    required int index,
    required bool isActive,
    required AnimationController controller,
    required BottomNavItem item,
  }) {
    final colorScheme = Theme.of(context).colorScheme;
    final onSurfaceVariant = colorScheme.onSurfaceVariant;
    return GestureDetector(
      onTap: () => widget.onTap(index),
      child: ScaleTransition(
        scale: Tween<double>(begin: 0.8, end: 1).animate(
          CurvedAnimation(parent: controller, curve: Curves.elasticOut),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // ✅ الأيقونة مع تأثير لوني
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: isActive
                    ? colorScheme.primary.withOpacity(0.18)
                    : Colors.transparent,
                borderRadius: BorderRadius.circular(12),
                border: isActive
                    ? Border.all(
                  color: colorScheme.primary.withOpacity(0.45),
                  width: 2,
                )
                    : null,
              ),
              child: Icon(
                item.icon,
                color: isActive
                    ? colorScheme.primary
                    : onSurfaceVariant.withOpacity(0.75),
                size: isActive ? 28 : 24,
              ),
            ),
            const SizedBox(height: 4),
            // ✅ التسميات مع تأثير الفيد
            AnimatedOpacity(
              opacity: isActive ? 1 : 0.6,
              duration: const Duration(milliseconds: 300),
              child: Text(
                item.label,
                style: TextStyle(
                  color: isActive
                      ? colorScheme.primary
                      : onSurfaceVariant.withOpacity(0.8),
                  fontWeight: isActive
                      ? FontWeight.bold
                      : FontWeight.normal,
                  fontSize: 10,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            if (isActive) ...[
              const SizedBox(height: 2),
              // ✅ مؤشر النشاط
              AnimatedContainer(
                duration: const Duration(milliseconds: 300),
                width: 30,
                height: 3,
                decoration: BoxDecoration(
                  color: colorScheme.primary,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// 🎨 Bottom Navigation Bar بسيط وأنيق
class SimpleBottomNavBar extends StatelessWidget {
  final int currentIndex;
  final Function(int) onTap;
  final List<BottomNavItem> items;

  const SimpleBottomNavBar({
    Key? key,
    required this.currentIndex,
    required this.onTap,
    required this.items,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final onSurfaceVariant = colorScheme.onSurfaceVariant;
    return BottomNavigationBar(
      currentIndex: currentIndex,
      onTap: onTap,
      type: BottomNavigationBarType.fixed,
      elevation: 20,
      backgroundColor: colorScheme.surface,
      selectedItemColor: colorScheme.primary,
      unselectedItemColor: onSurfaceVariant.withOpacity(0.75),
      selectedLabelStyle: const TextStyle(
        fontWeight: FontWeight.bold,
        fontSize: 12,
      ),
      unselectedLabelStyle: const TextStyle(
        fontSize: 12,
      ),
      items: items
          .map(
            (item) => BottomNavigationBarItem(
          icon: Icon(item.icon),
          label: item.label,
        ),
      )
          .toList(),
    );
  }
}