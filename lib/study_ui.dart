import 'app_strings.dart';

import 'package:flutter/material.dart';

import 'study_data.dart';

import 'app_theme.dart';
import 'app_header.dart';
import 'motion.dart';

export 'app_theme.dart';
export 'app_strings.dart';
export 'focus_screen.dart';
export 'app_header.dart';
export 'motion.dart';

Widget copy(
  String text,
  double size, {
  FontWeight weight = FontWeight.w400,
  Color color = ink,
  TextAlign? align,
}) => Builder(
  builder: (context) => Text(
    text,
    textAlign: align,
    style: TextStyle(
      fontFamily: 'GrowzaArabic',
      fontFamilyFallback: ['Roboto'],
      fontSize: size,
      fontWeight: weight,
      color: growzaColor(context, color),
      height: 1.35,
      letterSpacing: 0,
    ),
  ),
);

class ScreenList extends StatelessWidget {
  const ScreenList({super.key, required this.children, this.controller});
  final List<Widget> children;
  final ScrollController? controller;

  @override
  Widget build(BuildContext context) => Center(
    child: ConstrainedBox(
      constraints: BoxConstraints(maxWidth: 520),
      child: ListView.separated(
        controller: controller,
        padding: EdgeInsetsDirectional.fromSTEB(22, 10, 22, 28),
        itemBuilder: (context, index) => children[index],
        separatorBuilder: (context, index) => SizedBox(height: 16),
        itemCount: children.length,
      ),
    ),
  );
}

class PageHeading extends StatelessWidget {
  const PageHeading(
    this.title,
    this.subtitle, {
    super.key,
    this.size = 28,
    this.eyebrow,
  });
  final String title;
  final String subtitle;
  final double size;
  final String? eyebrow;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      if (eyebrow case final label?) ...[
        copy(
          label,
          10,
          weight: FontWeight.w500,
          color: growzaColor(context, muted),
        ),
        SizedBox(height: 8),
      ],
      copy(title, size, weight: FontWeight.w600),
      if (subtitle.isNotEmpty) ...[
        SizedBox(height: 4),
        copy(subtitle, 14, color: growzaColor(context, muted)),
      ],
    ],
  );
}

class Panel extends StatelessWidget {
  const Panel({
    super.key,
    required this.child,
    this.color,
    this.padding = const EdgeInsets.all(16),
    this.radius = 18,
    this.bordered = false,
  });
  final Widget child;
  final Color? color;
  final EdgeInsets padding;
  final double radius;
  final bool bordered;

  @override
  Widget build(BuildContext context) => Container(
    width: double.infinity,
    padding: padding,
    decoration: BoxDecoration(
      color: growzaColor(context, color ?? surface),
      borderRadius: BorderRadius.circular(radius),
      border: bordered
          ? Border.all(color: growzaColor(context, outline))
          : null,
    ),
    child: child,
  );
}

class StudyButton extends StatelessWidget {
  const StudyButton(
    this.label,
    this.onPressed, {
    super.key,
    this.secondary = false,
    this.compact = false,
  });
  final String label;
  final VoidCallback? onPressed;
  final bool secondary;
  final bool compact;

  @override
  Widget build(BuildContext context) => MotionPress(
    child: FilledButton(
      onPressed: onPressed,
      style: FilledButton.styleFrom(
        backgroundColor: secondary
            ? growzaColor(context, accentSoft)
            : growzaColor(context, accent),
        foregroundColor: secondary
            ? growzaColor(context, ink)
            : growzaColor(context, surface),
        minimumSize: Size(0, compact ? 38 : 48),
        padding: EdgeInsets.symmetric(
          horizontal: compact ? 12 : 16,
          vertical: 10,
        ),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
        textStyle: TextStyle(
          fontFamily: 'GrowzaArabic',
          fontFamilyFallback: ['Roboto'],
          fontSize: compact ? 13 : 15,
          fontWeight: FontWeight.w600,
        ),
      ),
      child: Text(label, textAlign: TextAlign.center),
    ),
  );
}

class Tag extends StatelessWidget {
  const Tag(this.label, {super.key, this.background, this.foreground});
  final String label;
  final Color? background;
  final Color? foreground;

  @override
  Widget build(BuildContext context) => DecoratedBox(
    decoration: BoxDecoration(
      color: growzaColor(context, background ?? accentSoft),
      borderRadius: BorderRadius.circular(20),
    ),
    child: Padding(
      padding: EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      child: copy(
        label,
        11,
        weight: FontWeight.w600,
        color: foreground ?? growzaColor(context, accent),
      ),
    ),
  );
}

class StudyHeader extends StatelessWidget {
  const StudyHeader({super.key, this.backLabel, this.onBack});
  final String? backLabel;
  final VoidCallback? onBack;
  @override
  Widget build(BuildContext context) =>
      AppHeader(backLabel: backLabel, onBack: onBack);
}

class SubjectBadge extends StatelessWidget {
  const SubjectBadge(this.subject, {super.key, this.small = false});
  final String subject;
  final bool small;

  @override
  Widget build(BuildContext context) {
    final symbol = switch (subject.toLowerCase()) {
      'calculus ii' => Icons.functions_rounded,
      'physics' => Icons.science_outlined,
      'biology' => Icons.eco_outlined,
      'english' => Icons.translate_rounded,
      _ => Icons.menu_book_outlined,
    };
    return Container(
      width: small ? 25 : 42,
      height: small ? 25 : 42,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: growzaColor(context, accentSoft),
        borderRadius: BorderRadius.circular(10),
      ),
      child: ExcludeSemantics(
        child: Icon(
          symbol,
          size: small ? 15 : 22,
          color: growzaColor(context, ink),
        ),
      ),
    );
  }
}

class SessionTile extends StatelessWidget {
  const SessionTile(
    this.session, {
    super.key,
    this.actionLabel,
    this.onAction,
    this.completed = false,
    this.status,
    this.menu,
  });
  final StudySession session;
  final String? actionLabel;
  final VoidCallback? onAction;
  final bool completed;
  final String? status;
  final Widget? menu;

  @override
  Widget build(BuildContext context) => Panel(
    radius: 19,
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(width: 62, child: Tag(clockLabel(session.start))),
        SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  SubjectBadge(session.subject, small: true),
                  SizedBox(width: 6),
                  Expanded(
                    child: copy(
                      subjectLabel(session.subject, context: context),
                      15,
                      weight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
              SizedBox(height: 5),
              copy(
                tr(context, "{0} · {1} د", [session.topic, session.minutes]),
                12,
                color: growzaColor(context, muted),
              ),
              if (completed)
                Padding(
                  padding: EdgeInsets.only(top: 6),
                  child: Tag(
                    tr(context, "مكتمل"),
                    background: growzaColor(context, greenLight),
                    foreground: growzaColor(context, greenInk),
                  ),
                )
              else ...[
                if (status case final label?)
                  Padding(
                    padding: EdgeInsets.only(top: 6),
                    child: Tag(
                      label,
                      background: label == tr(context, "فاتت")
                          ? growzaColor(context, amberLight)
                          : growzaColor(context, accentSoft),
                      foreground: label == tr(context, "فاتت")
                          ? growzaColor(context, amberInk)
                          : growzaColor(context, accent),
                    ),
                  ),
                if (actionLabel != null)
                  TextButton(onPressed: onAction, child: Text(actionLabel!)),
              ],
            ],
          ),
        ),
        ?menu,
      ],
    ),
  );
}
