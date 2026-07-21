import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../utils/review_helper.dart';

/// Shows a warm, encouraging dialog before opening the Play Store review.
/// Gives dissatisfied users a path to report issues instead of leaving low ratings.
Future<void> showPreReviewDialog(BuildContext context, Color accent) async {
  final shouldRate = await showDialog<bool>(
    context: context,
    barrierDismissible: true,
    barrierColor: Colors.black.withValues(alpha: 0.65),
    builder: (ctx) => _PreReviewDialog(accent: accent),
  );
  if (shouldRate == true && context.mounted) {
    await requestSukoonReview();
  }
}

class _PreReviewDialog extends StatefulWidget {
  final Color accent;
  const _PreReviewDialog({required this.accent});
  @override
  State<_PreReviewDialog> createState() => _PreReviewDialogState();
}

class _PreReviewDialogState extends State<_PreReviewDialog>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _fade;
  late Animation<Offset> _slide;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 340));
    _fade = CurvedAnimation(parent: _ctrl, curve: Curves.easeOut);
    _slide = Tween<Offset>(begin: const Offset(0, 0.08), end: Offset.zero)
        .animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeOutCubic));
    _ctrl.forward();
  }

  @override
  void dispose() { _ctrl.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    final accent = widget.accent;
    return FadeTransition(
      opacity: _fade,
      child: SlideTransition(
        position: _slide,
        child: Dialog(
          backgroundColor: Colors.transparent,
          insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 40),
          child: Container(
            decoration: BoxDecoration(
              color: const Color(0xFF111111),
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
              boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.6), blurRadius: 40, spreadRadius: 4)],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(24, 28, 24, 0),
                  child: Column(
                    children: [
                      Container(
                        width: 56, height: 56,
                        decoration: BoxDecoration(
                          color: Colors.amber.withValues(alpha: 0.10),
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.amber.withValues(alpha: 0.20)),
                        ),
                        child: const Icon(Icons.star_rounded, color: Colors.amber, size: 28),
                      ),
                      const SizedBox(height: 16),
                      const Text('JazakAllah for using Sukoon',
                          textAlign: TextAlign.center,
                          style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w700, height: 1.3)),
                      const SizedBox(height: 8),
                      Text(
                        'Your rating helps other Muslims discover this app. We read every review and improve based on your feedback.',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: Colors.white.withValues(alpha: 0.50), fontSize: 13, height: 1.5),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),
                Container(
                  margin: const EdgeInsets.symmetric(horizontal: 20),
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: accent.withValues(alpha: 0.06),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: accent.withValues(alpha: 0.12)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(children: [
                        Icon(Icons.auto_awesome_rounded, size: 14, color: accent),
                        const SizedBox(width: 6),
                        Text("We're constantly improving",
                            style: TextStyle(color: accent, fontSize: 12.5, fontWeight: FontWeight.w700)),
                      ]),
                      const SizedBox(height: 12),
                      ...[
                        'Richer Quran & Seerah experience',
                        'Smarter app timer & focus tools',
                        'Dhikr, Dua & Islamic content growing',
                        'Bugs fixed in every single update',
                        'Your feedback directly shapes the app',
                      ].map((n) => Padding(
                            padding: const EdgeInsets.only(bottom: 7),
                            child: Text('•  $n', style: TextStyle(color: Colors.white.withValues(alpha: 0.70), fontSize: 12.5, height: 1.4)),
                          )),
                    ],
                  ),
                ),
                const SizedBox(height: 14),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Padding(padding: const EdgeInsets.only(top: 1),
                          child: Icon(Icons.info_outline_rounded, size: 13, color: Colors.white.withValues(alpha: 0.30))),
                      const SizedBox(width: 6),
                      Expanded(child: Text(
                        "Facing an issue? Share feedback first — we fix things fast, insha'Allah.",
                        style: TextStyle(color: Colors.white.withValues(alpha: 0.35), fontSize: 11.5, height: 1.4),
                      )),
                    ],
                  ),
                ),
                const SizedBox(height: 20),
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 20),
                  child: Column(children: [
                    SizedBox(
                      width: double.infinity,
                      child: GestureDetector(
                        onTap: () => Navigator.of(context).pop(true),
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          decoration: BoxDecoration(
                            gradient: LinearGradient(colors: [Colors.amber.shade600, Colors.amber.shade400]),
                            borderRadius: BorderRadius.circular(14),
                            boxShadow: [BoxShadow(color: Colors.amber.withValues(alpha: 0.25), blurRadius: 16, offset: const Offset(0, 4))],
                          ),
                          child: const Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.star_rounded, size: 17, color: Colors.white),
                              SizedBox(width: 7),
                              Text('Rate Sukoon', style: TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w700)),
                            ],
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 10),
                    SizedBox(
                      width: double.infinity,
                      child: GestureDetector(
                        onTap: () async {
                          Navigator.of(context).pop(false);
                          await launchUrl(
                            Uri.parse('https://chat.whatsapp.com/FY0RsAPri7sENTWFtxC1GK'),
                            mode: LaunchMode.externalApplication,
                          );
                        },
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 13),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.05),
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.forum_rounded, size: 16, color: Colors.white.withValues(alpha: 0.55)),
                              const SizedBox(width: 7),
                              Text('Share Feedback Instead',
                                  style: TextStyle(color: Colors.white.withValues(alpha: 0.55), fontSize: 14, fontWeight: FontWeight.w500)),
                            ],
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 4),
                    TextButton(
                      onPressed: () => Navigator.of(context).pop(false),
                      child: Text('Maybe later', style: TextStyle(color: Colors.white.withValues(alpha: 0.25), fontSize: 13)),
                    ),
                  ]),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
