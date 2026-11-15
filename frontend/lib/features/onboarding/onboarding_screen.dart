import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';

import '../../core/theme.dart';

class _Page {
  const _Page(this.icon, this.color, this.title, this.body, this.example);
  final IconData icon;
  final Color color;
  final String title, body, example;
}

const _pages = <_Page>[
  _Page(
    Icons.storefront_rounded,
    Color(0xFF22C3A6),
    'See your shop clearly',
    'Dukaan360 shows your sales and your customers in one simple place. No notebooks, no guessing.',
    'Example: "This week you sold ₹60,029."',
  ),
  _Page(
    Icons.person_off_rounded,
    Color(0xFFFF8A8E),
    'Find customers who stopped coming',
    'Every regular customer has their own rhythm. When one goes quiet for too long, the app tells you.',
    'Example: "Meena used to come every 4 days. She has not come for 3 weeks."',
  ),
  _Page(
    Icons.send_rounded,
    Color(0xFFF5C451),
    'Win them back, you stay in control',
    'The AI writes a friendly offer in Hindi or Marathi. You read it, change it if you like, and press Send. Nothing is sent without you.',
    'Right now sending is a demo, so no real messages go out.',
  ),
];

/// Three short screens explaining the app in simple words. Used on first launch and from the "?" button.
class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key, required this.onDone});
  final VoidCallback onDone;

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final _controller = PageController();
  int _index = 0;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _next() {
    if (_index == _pages.length - 1) {
      widget.onDone();
    } else {
      _controller.nextPage(duration: const Duration(milliseconds: 380), curve: Curves.easeOutCubic);
    }
  }

  @override
  Widget build(BuildContext context) {
    final last = _index == _pages.length - 1;
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(gradient: Brand.heroGradient),
        child: SafeArea(
          child: Column(
            children: [
              Align(
                alignment: Alignment.centerRight,
                child: AnimatedOpacity(
                  duration: const Duration(milliseconds: 200),
                  opacity: last ? 0 : 1,
                  child: TextButton(
                    onPressed: last ? null : widget.onDone,
                    child: const Text('Skip', style: TextStyle(color: Colors.white70, fontSize: 15)),
                  ),
                ),
              ),
              Expanded(
                child: PageView.builder(
                  controller: _controller,
                  itemCount: _pages.length,
                  onPageChanged: (i) => setState(() => _index = i),
                  itemBuilder: (_, i) => _PageView(page: _pages[i], active: i == _index),
                ),
              ),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  for (var i = 0; i < _pages.length; i++)
                    AnimatedContainer(
                      duration: const Duration(milliseconds: 250),
                      margin: const EdgeInsets.symmetric(horizontal: 4),
                      width: i == _index ? 26 : 8,
                      height: 8,
                      decoration: BoxDecoration(
                        color: i == _index ? Colors.white : Colors.white30,
                        borderRadius: BorderRadius.circular(99),
                      ),
                    ),
                ],
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 22, 24, 26),
                child: FilledButton(
                  style: FilledButton.styleFrom(backgroundColor: Colors.white, foregroundColor: Brand.navy),
                  onPressed: _next,
                  child: Text(last ? 'Get started' : 'Next'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PageView extends StatelessWidget {
  const _PageView({required this.page, required this.active});
  final _Page page;
  final bool active;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 28),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 132,
            height: 132,
            decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.12), shape: BoxShape.circle),
            child: Icon(page.icon, size: 68, color: page.color),
          ).animate(target: active ? 1 : 0).scale(
                begin: const Offset(0.8, 0.8),
                end: const Offset(1, 1),
                duration: 500.ms,
                curve: Curves.easeOutBack,
              ),
          const SizedBox(height: 34),
          Text(
            page.title,
            textAlign: TextAlign.center,
            style: const TextStyle(color: Colors.white, fontSize: 27, fontWeight: FontWeight.w800, height: 1.2, letterSpacing: -0.4),
          ),
          const SizedBox(height: 16),
          Text(
            page.body,
            textAlign: TextAlign.center,
            style: const TextStyle(color: Colors.white, fontSize: 17, height: 1.5),
          ),
          const SizedBox(height: 18),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(16)),
            child: Text(
              page.example,
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.white70, fontSize: 14.5, height: 1.45),
            ),
          ),
        ],
      ).animate(target: active ? 1 : 0).fade(begin: 0.4, end: 1, duration: 350.ms),
    );
  }
}
