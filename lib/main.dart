import 'dart:async';

import 'package:flutter/material.dart';

import 'core/theme/app_theme.dart';
import 'core/widgets/beacon_ring.dart';
import 'core/widgets/floating_sos_button.dart';
import 'core/widgets/nav_bar.dart';

void main() => runApp(const NariRakshakApp());

class NariRakshakApp extends StatelessWidget {
  const NariRakshakApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      home: const SafetyShell(),
    );
  }
}

enum AppScreen {
  onboarding,
  auth,
  home,
  pod,
  contacts,
  settings,
  sos,
  sosActive,
  decoy,
}

class SafetyShell extends StatefulWidget {
  const SafetyShell({super.key});

  @override
  State<SafetyShell> createState() => _SafetyShellState();
}

class _SafetyShellState extends State<SafetyShell> {
  AppScreen _screen = AppScreen.onboarding;
  AppScreen _previousScreen = AppScreen.home;
  String _userName = '';

  bool get _hasNavigation => switch (_screen) {
    AppScreen.home ||
    AppScreen.pod ||
    AppScreen.contacts ||
    AppScreen.settings => true,
    _ => false,
  };

  void _goTo(AppScreen screen) {
    if (_screen != AppScreen.sos && _screen != AppScreen.decoy) {
      _previousScreen = _screen;
    }
    setState(() => _screen = screen);
  }

  void _navigateToTab(int index) {
    _goTo(
      [
        AppScreen.home,
        AppScreen.pod,
        AppScreen.contacts,
        AppScreen.settings,
      ][index],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFE9E2F2),
      body: SafeArea(
        child: Stack(
          children: [
            Column(
              children: [
                _StatusBar(),
                Expanded(child: _screenView()),
                if (_hasNavigation)
                  AppNavBar(
                    currentIndex: [
                      AppScreen.home,
                      AppScreen.pod,
                      AppScreen.contacts,
                      AppScreen.settings,
                    ].indexOf(_screen),
                    onTap: _navigateToTab,
                  ),
              ],
            ),
            if (_hasNavigation)
              Positioned(
                right: 16,
                bottom: 82,
                child: FloatingSosButton(onPressed: () => _goTo(AppScreen.sos)),
              ),
          ],
        ),
      ),
    );
  }

  Widget _screenView() => switch (_screen) {
    AppScreen.onboarding => OnboardingView(
      onStart: () => _goTo(AppScreen.auth),
    ),
    AppScreen.auth => AuthView(
      onBack: () => _goTo(AppScreen.onboarding),
      onAuthenticated: (name) {
        setState(() => _userName = name);
        _goTo(AppScreen.home);
      },
    ),
    AppScreen.home => HomeView(
      userName: _userName,
      onStartCommute: () => _goTo(AppScreen.pod),
    ),
    AppScreen.pod => PodView(onReached: () => _goTo(AppScreen.home)),
    AppScreen.contacts => const ContactsView(),
    AppScreen.settings => const SettingsView(),
    AppScreen.sos => SosTriggerView(
      onActivate: () => _goTo(AppScreen.sosActive),
      onDecoy: () => _goTo(AppScreen.decoy),
      onCancel: () => _goTo(_previousScreen),
    ),
    AppScreen.sosActive => SosActiveView(
      onResolve: () => _goTo(AppScreen.home),
    ),
    AppScreen.decoy => DecoyView(onBack: () => _goTo(AppScreen.sos)),
  };
}

class _StatusBar extends StatelessWidget {
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(24, 8, 24, 2),
    child: Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text('9:41', style: AppTextStyles.mono(fontSize: 11)),
        Row(
          children: const [
            Icon(Icons.signal_cellular_alt_rounded, size: 14),
            SizedBox(width: 6),
            Icon(Icons.wifi_rounded, size: 14),
            SizedBox(width: 6),
            Icon(Icons.battery_full_rounded, size: 16),
          ],
        ),
      ],
    ),
  );
}

class OnboardingView extends StatelessWidget {
  final VoidCallback onStart;
  const OnboardingView({super.key, required this.onStart});

  @override
  Widget build(BuildContext context) => Container(
    decoration: const BoxDecoration(
      gradient: RadialGradient(
        center: Alignment.topCenter,
        radius: 1.2,
        colors: [AppColors.surface2, AppColors.bg],
      ),
    ),
    padding: const EdgeInsets.fromLTRB(32, 52, 32, 42),
    child: Column(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Column(
          children: [
            const BeaconRing(size: 104),
            const SizedBox(height: 22),
            Text(
              'NaariRakshak',
              style: AppTextStyles.display(
                fontSize: 30,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'Never alone. Never silent.\nNever undetected.',
              textAlign: TextAlign.center,
              style: AppTextStyles.display(
                fontSize: 15,
                color: AppColors.amber,
                fontStyle: FontStyle.italic,
              ),
            ),
          ],
        ),
        Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: const [
                _FeatureIcon(icon: Icons.people_alt_outlined, label: 'Pods'),
                _FeatureIcon(icon: Icons.radio_outlined, label: 'Silent SOS'),
                _FeatureIcon(icon: Icons.mic_none_rounded, label: 'AI Detect'),
              ],
            ),
            const SizedBox(height: 24),
            _PrimaryButton(label: 'Get started', onPressed: onStart),
            const SizedBox(height: 12),
            Text(
              'Three layers of protection for every commute.',
              style: AppTextStyles.body(fontSize: 11, color: AppColors.faint),
            ),
          ],
        ),
      ],
    ),
  );
}

class _FeatureIcon extends StatelessWidget {
  final IconData icon;
  final String label;
  const _FeatureIcon({required this.icon, required this.label});
  @override
  Widget build(BuildContext context) => Column(
    children: [
      Icon(icon, size: 18, color: AppColors.amber),
      const SizedBox(height: 6),
      Text(
        label,
        style: AppTextStyles.body(fontSize: 10, color: AppColors.muted),
      ),
    ],
  );
}

class AuthView extends StatefulWidget {
  final VoidCallback onBack;
  final ValueChanged<String> onAuthenticated;
  const AuthView({
    super.key,
    required this.onBack,
    required this.onAuthenticated,
  });

  @override
  State<AuthView> createState() => _AuthViewState();
}

class _AuthViewState extends State<AuthView> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _isSignUp = false;
  bool _obscurePassword = true;

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  void _submit() {
    if (_formKey.currentState!.validate()) {
      final enteredName = _nameController.text.trim();
      final emailName = _emailController.text.trim().split('@').first;
      final displayName = _isSignUp
          ? enteredName
          : emailName
                .replaceAll(RegExp(r'[._-]+'), ' ')
                .split(' ')
                .where((part) => part.isNotEmpty)
                .map((part) => '${part[0].toUpperCase()}${part.substring(1)}')
                .join(' ');
      widget.onAuthenticated(displayName);
    }
  }

  String? _required(String? value, String label) =>
      value == null || value.trim().isEmpty ? '$label is required' : null;

  @override
  Widget build(BuildContext context) => Container(
    color: AppColors.bg,
    child: SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(24, 18, 24, 32),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            IconButton(
              onPressed: widget.onBack,
              icon: const Icon(
                Icons.arrow_back_rounded,
                color: AppColors.muted,
              ),
              padding: EdgeInsets.zero,
              alignment: Alignment.centerLeft,
            ),
            const SizedBox(height: 28),
            Center(child: const BeaconRing(size: 70, ringCount: 2)),
            const SizedBox(height: 18),
            Center(
              child: Text(
                _isSignUp ? 'Create your account' : 'Welcome back',
                style: AppTextStyles.display(
                  fontSize: 25,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            const SizedBox(height: 6),
            Center(
              child: Text(
                _isSignUp
                    ? 'Build your safety circle today.'
                    : 'Your safety circle is ready when you are.',
                textAlign: TextAlign.center,
                style: AppTextStyles.body(fontSize: 12, color: AppColors.muted),
              ),
            ),
            const SizedBox(height: 28),
            if (_isSignUp) ...[
              _AuthField(
                controller: _nameController,
                label: 'Full name',
                hint: 'Your full name',
                icon: Icons.person_outline,
                validator: (v) => _required(v, 'Name'),
              ),
              const SizedBox(height: 14),
            ],
            _AuthField(
              controller: _emailController,
              label: 'Email address',
              hint: 'you@example.com',
              icon: Icons.mail_outline,
              keyboardType: TextInputType.emailAddress,
              validator: (v) {
                if (_required(v, 'Email') != null) return _required(v, 'Email');
                return RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(v!.trim())
                    ? null
                    : 'Enter a valid email';
              },
            ),
            const SizedBox(height: 14),
            _AuthField(
              controller: _passwordController,
              label: 'Password',
              hint: 'At least 8 characters',
              icon: Icons.lock_outline,
              obscureText: _obscurePassword,
              suffix: IconButton(
                onPressed: () =>
                    setState(() => _obscurePassword = !_obscurePassword),
                icon: Icon(
                  _obscurePassword
                      ? Icons.visibility_outlined
                      : Icons.visibility_off_outlined,
                  size: 18,
                ),
              ),
              validator: (v) {
                if (_required(v, 'Password') != null) {
                  return _required(v, 'Password');
                }
                return v!.length < 8 ? 'Use at least 8 characters' : null;
              },
            ),
            if (!_isSignUp)
              Align(
                alignment: Alignment.centerRight,
                child: TextButton(
                  onPressed: _noop,
                  child: Text(
                    'Forgot password?',
                    style: AppTextStyles.body(
                      fontSize: 11,
                      color: AppColors.amber,
                    ),
                  ),
                ),
              ),
            if (_isSignUp) ...[
              const SizedBox(height: 8),
              Text(
                'By continuing, you agree to keep your emergency contacts up to date.',
                style: AppTextStyles.body(
                  fontSize: 10.5,
                  color: AppColors.faint,
                ),
              ),
            ],
            const SizedBox(height: 20),
            _PrimaryButton(
              label: _isSignUp ? 'Create account' : 'Sign in',
              onPressed: _submit,
            ),
            const SizedBox(height: 18),
            Center(
              child: TextButton(
                onPressed: () => setState(() => _isSignUp = !_isSignUp),
                child: Text(
                  _isSignUp
                      ? 'Already have an account? Sign in'
                      : 'New to NaariRakshak? Create an account',
                  style: AppTextStyles.body(
                    fontSize: 11.5,
                    color: AppColors.muted,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

class _AuthField extends StatelessWidget {
  final TextEditingController controller;
  final String label, hint;
  final IconData icon;
  final TextInputType? keyboardType;
  final bool obscureText;
  final Widget? suffix;
  final String? Function(String?)? validator;
  const _AuthField({
    required this.controller,
    required this.label,
    required this.hint,
    required this.icon,
    this.keyboardType,
    this.obscureText = false,
    this.suffix,
    this.validator,
  });

  @override
  Widget build(BuildContext context) => TextFormField(
    controller: controller,
    keyboardType: keyboardType,
    obscureText: obscureText,
    validator: validator,
    style: AppTextStyles.body(fontSize: 13),
    decoration: InputDecoration(
      labelText: label,
      hintText: hint,
      prefixIcon: Icon(icon, size: 18, color: AppColors.amber),
      suffixIcon: suffix,
      filled: true,
      fillColor: AppColors.surface,
      labelStyle: AppTextStyles.body(fontSize: 12, color: AppColors.muted),
      hintStyle: AppTextStyles.body(fontSize: 12, color: AppColors.faint),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: AppColors.border),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: AppColors.border),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: AppColors.amber, width: 1.5),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: AppColors.coral),
      ),
    ),
  );
}

class HomeView extends StatelessWidget {
  final String userName;
  final VoidCallback onStartCommute;
  const HomeView({
    super.key,
    required this.userName,
    required this.onStartCommute,
  });
  @override
  Widget build(BuildContext context) => _Page(
    scrollable: false,
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Good evening,',
          style: AppTextStyles.body(fontSize: 12.5, color: AppColors.faint),
        ),
        Text(
          userName.isEmpty ? 'Welcome' : userName,
          style: AppTextStyles.display(fontSize: 22),
        ),
        const SizedBox(height: 22),
        _Panel(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Ready for your commute',
                    style: AppTextStyles.body(
                      fontSize: 12.5,
                      color: AppColors.muted,
                    ),
                  ),
                  const Icon(
                    Icons.verified_user_outlined,
                    size: 17,
                    color: AppColors.amber,
                  ),
                ],
              ),
              const SizedBox(height: 18),
              const _InfoLine(
                icon: Icons.location_on_outlined,
                text: 'Kalkaji → Cyber Hub, Gurugram',
              ),
              const _InfoLine(
                icon: Icons.access_time_rounded,
                text: 'Est. 38 min · Auto + Metro',
                mono: true,
              ),
              const SizedBox(height: 14),
              _PrimaryButton(
                label: 'Start commute',
                icon: Icons.navigation_rounded,
                onPressed: onStartCommute,
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),
        const Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            _Stat(value: '47', label: 'safe arrivals'),
            _Stat(value: '312 km', label: 'protected this month'),
            _Stat(value: '6', label: 'pod companions'),
          ],
        ),
        const SizedBox(height: 22),
        Text(
          'YOUR THREE LAYERS',
          style: AppTextStyles.body(fontSize: 11.5, color: AppColors.faint),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: const [
            _LayerChip(label: 'Pod matching', icon: Icons.people_alt_outlined),
            _LayerChip(label: 'Silent SOS armed', icon: Icons.radio_outlined),
            _LayerChip(label: 'Audio detection', icon: Icons.mic_none_rounded),
          ],
        ),
      ],
    ),
  );
}

class PodView extends StatelessWidget {
  final VoidCallback onReached;
  const PodView({super.key, required this.onReached});
  @override
  Widget build(BuildContext context) => _Page(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Your safety pod', style: AppTextStyles.display(fontSize: 19)),
        Text(
          'Matched by route · 4 of 5 checked in',
          style: AppTextStyles.body(fontSize: 12, color: AppColors.faint),
        ),
        const SizedBox(height: 14),
        Center(
          child: Column(
            children: [
              const BeaconRing(size: 130, ringCount: 2),
              Text(
                'ETA 14:32',
                style: AppTextStyles.mono(fontSize: 12, color: AppColors.amber),
              ),
              Text(
                'Live location shared with pod',
                style: AppTextStyles.body(fontSize: 11, color: AppColors.faint),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        _Panel(
          child: Column(
            children: const [
              _PodMember(initials: 'RS', reached: true),
              _PodMember(initials: 'MK', reached: true),
              _PodMember(initials: 'PJ', reached: true),
              _PodMember(initials: 'TN', reached: false),
            ],
          ),
        ),
        const SizedBox(height: 18),
        _PrimaryButton(
          label: "I've reached safely",
          icon: Icons.check_rounded,
          color: AppColors.green,
          onPressed: onReached,
        ),
        const SizedBox(height: 10),
        Center(
          child: Text(
            'Missed check-ins auto-alert your pod and emergency contacts.',
            textAlign: TextAlign.center,
            style: AppTextStyles.body(fontSize: 10.5, color: AppColors.faint),
          ),
        ),
      ],
    ),
  );
}

class SosTriggerView extends StatefulWidget {
  final VoidCallback onActivate, onDecoy, onCancel;
  const SosTriggerView({
    super.key,
    required this.onActivate,
    required this.onDecoy,
    required this.onCancel,
  });
  @override
  State<SosTriggerView> createState() => _SosTriggerViewState();
}

class _SosTriggerViewState extends State<SosTriggerView> {
  Timer? _timer;
  double _progress = 0;
  DateTime? _started;

  void _startHold() {
    _started = DateTime.now();
    _timer = Timer.periodic(const Duration(milliseconds: 16), (_) {
      final elapsed = DateTime.now().difference(_started!).inMilliseconds;
      setState(() => _progress = (elapsed / 1400).clamp(0, 1));
      if (_progress >= 1) {
        _stopHold(reset: false);
        widget.onActivate();
      }
    });
  }

  void _stopHold({bool reset = true}) {
    _timer?.cancel();
    _timer = null;
    if (reset && mounted) setState(() => _progress = 0);
  }

  @override
  void dispose() {
    _stopHold();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => _Page(
    child: Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            IconButton(
              onPressed: widget.onCancel,
              icon: const Icon(Icons.close_rounded, color: AppColors.muted),
            ),
            Text(
              'Silent SOS',
              style: AppTextStyles.body(fontSize: 12, color: AppColors.faint),
            ),
            const SizedBox(width: 48),
          ],
        ),
        Expanded(
          child: Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                SizedBox(
                  width: 210,
                  height: 210,
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      SizedBox.expand(
                        child: CircularProgressIndicator(
                          value: _progress,
                          strokeWidth: 6,
                          backgroundColor: AppColors.surface2,
                          color: AppColors.coral,
                        ),
                      ),
                      GestureDetector(
                        onTapDown: (_) => _startHold(),
                        onTapUp: (_) => _stopHold(),
                        onTapCancel: _stopHold,
                        child: Container(
                          width: 132,
                          height: 132,
                          decoration: const BoxDecoration(
                            shape: BoxShape.circle,
                            color: AppColors.coral,
                          ),
                          child: const Icon(
                            Icons.warning_rounded,
                            size: 34,
                            color: AppColors.bgDeep,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),
                Text(
                  'Press and hold for 3 seconds',
                  style: AppTextStyles.body(fontSize: 13),
                ),
                const SizedBox(height: 4),
                Text(
                  'Shares live location, audio and alerts your pod, contacts and control room',
                  textAlign: TextAlign.center,
                  style: AppTextStyles.body(
                    fontSize: 11,
                    color: AppColors.faint,
                  ),
                ),
              ],
            ),
          ),
        ),
        _TriggerRow(label: 'Power button pattern'),
        _TriggerRow(label: 'Shake gesture'),
        InkWell(
          onTap: widget.onDecoy,
          child: const _TriggerRow(label: 'Preview decoy screen'),
        ),
      ],
    ),
  );
}

class SosActiveView extends StatelessWidget {
  final VoidCallback onResolve;
  const SosActiveView({super.key, required this.onResolve});
  @override
  Widget build(BuildContext context) => Container(
    decoration: const BoxDecoration(
      gradient: LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [Color(0xFFFCE7E7), AppColors.bg],
      ),
    ),
    child: Column(
      children: [
        const SizedBox(height: 32),
        const BeaconRing(size: 92, color: AppColors.coral),
        const SizedBox(height: 12),
        Text(
          'Alert sent',
          style: AppTextStyles.display(
            fontSize: 19,
            fontWeight: FontWeight.w700,
          ),
        ),
        Text(
          'Live for 02:14',
          style: AppTextStyles.mono(fontSize: 11, color: AppColors.coral),
        ),
        const SizedBox(height: 20),
        _Panel(
          child: Column(
            children: const [
              _AlertRow('Pod notified', true),
              _AlertRow('Emergency contacts notified', true),
              _AlertRow('Live location sharing', true),
              _AlertRow('Control room (112) pinged', false),
            ],
          ),
        ),
        const SizedBox(height: 20),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Column(
            children: [
              _PrimaryButton(
                label: 'Call 112 now',
                icon: Icons.phone_in_talk_rounded,
                color: AppColors.coral,
                onPressed: _noop,
              ),
              const SizedBox(height: 10),
              OutlinedButton(
                onPressed: onResolve,
                style: OutlinedButton.styleFrom(
                  minimumSize: const Size.fromHeight(48),
                  foregroundColor: AppColors.muted,
                  side: const BorderSide(color: AppColors.border),
                ),
                child: Text(
                  "I'm safe — cancel alert",
                  style: AppTextStyles.body(fontSize: 13.5),
                ),
              ),
            ],
          ),
        ),
      ],
    ),
  );
}

void _noop() {}

class DecoyView extends StatelessWidget {
  final VoidCallback onBack;
  const DecoyView({super.key, required this.onBack});
  @override
  Widget build(BuildContext context) => GestureDetector(
    onDoubleTap: onBack,
    child: Container(
      color: const Color(0xFF0B0B10),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'double-tap to exit preview',
                style: AppTextStyles.mono(
                  fontSize: 10,
                  color: const Color(0xFF555555),
                ),
              ),
              IconButton(
                onPressed: onBack,
                icon: const Icon(
                  Icons.close,
                  color: Color(0xFF666666),
                  size: 16,
                ),
              ),
            ],
          ),
          Column(
            children: [
              Container(
                width: 92,
                height: 92,
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  color: Color(0xFF2A2A32),
                ),
                child: Center(
                  child: Text(
                    'M',
                    style: AppTextStyles.display(
                      fontSize: 30,
                      color: const Color(0xFF999999),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 20),
              Text(
                'Mom',
                style: AppTextStyles.body(
                  fontSize: 20,
                  fontWeight: FontWeight.w600,
                  color: Colors.white,
                ),
              ),
              Text(
                'mobile · calling…',
                style: AppTextStyles.body(
                  fontSize: 12.5,
                  color: const Color(0xFF888888),
                ),
              ),
            ],
          ),
          Padding(
            padding: const EdgeInsets.only(bottom: 30),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: const [
                _CallAction(
                  icon: Icons.call_end,
                  label: 'Decline',
                  color: Color(0xFFE5484D),
                ),
                _CallAction(
                  icon: Icons.phone,
                  label: 'Accept',
                  color: Color(0xFF30C85E),
                ),
              ],
            ),
          ),
        ],
      ),
    ),
  );
}

class ContactsView extends StatelessWidget {
  const ContactsView({super.key});
  @override
  Widget build(BuildContext context) => _Page(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Emergency contacts',
              style: AppTextStyles.display(fontSize: 19),
            ),
            const Icon(
              Icons.person_add_alt_1_rounded,
              color: AppColors.amber,
              size: 18,
            ),
          ],
        ),
        const SizedBox(height: 16),
        _Panel(
          child: Column(
            children: const [
              _ContactRow(
                initials: 'MA',
                name: 'Mother',
                relation: 'Primary · always alerted',
              ),
              _ContactRow(
                initials: 'RK',
                name: 'Rohan (brother)',
                relation: 'Secondary',
              ),
              _ContactRow(
                initials: 'SN',
                name: 'Neha (flatmate)',
                relation: 'Secondary',
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),
        OutlinedButton.icon(
          onPressed: _noop,
          icon: const Icon(Icons.add, size: 16),
          label: Text('Add contact', style: AppTextStyles.body(fontSize: 12.5)),
          style: OutlinedButton.styleFrom(
            minimumSize: const Size.fromHeight(48),
            foregroundColor: AppColors.muted,
            side: const BorderSide(color: AppColors.border),
          ),
        ),
      ],
    ),
  );
}

class SettingsView extends StatefulWidget {
  const SettingsView({super.key});
  @override
  State<SettingsView> createState() => _SettingsViewState();
}

class _SettingsViewState extends State<SettingsView> {
  final _values = [true, true, true, true];
  @override
  Widget build(BuildContext context) => _Page(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Safety settings', style: AppTextStyles.display(fontSize: 19)),
        const SizedBox(height: 16),
        _Panel(
          child: Column(
            children: [
              _SettingRow(
                icon: Icons.mic_none_rounded,
                title: 'Passive audio detection',
                sub: 'On-device only, opt-in, active during commutes',
                value: _values[0],
                onChanged: (v) => setState(() => _values[0] = v),
              ),
              _SettingRow(
                icon: Icons.people_alt_outlined,
                title: 'Auto pod matching',
                sub: 'Match with others on similar routes and timing',
                value: _values[1],
                onChanged: (v) => setState(() => _values[1] = v),
              ),
              _SettingRow(
                icon: Icons.location_on_outlined,
                title: 'Precise location sharing',
                sub: 'Share exact GPS instead of general area',
                value: _values[2],
                onChanged: (v) => setState(() => _values[2] = v),
              ),
              _SettingRow(
                icon: Icons.volume_up_outlined,
                title: 'Decoy call on SOS',
                sub: 'Show a fake incoming call when alert triggers',
                value: _values[3],
                onChanged: (v) => setState(() => _values[3] = v),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4),
          child: Text(
            'Audio is processed on your device. Nothing is uploaded unless an SOS is triggered.',
            style: AppTextStyles.body(fontSize: 10.5, color: AppColors.faint),
          ),
        ),
      ],
    ),
  );
}

class _Page extends StatelessWidget {
  final Widget child;
  final bool scrollable;
  const _Page({required this.child, this.scrollable = true});
  @override
  Widget build(BuildContext context) {
    final content = Padding(
      padding: const EdgeInsets.fromLTRB(20, 10, 20, 18),
      child: child,
    );
    return Container(
      color: AppColors.bg,
      child: scrollable
          ? SingleChildScrollView(
              physics: const ClampingScrollPhysics(),
              child: content,
            )
          : content,
    );
  }
}

class _Panel extends StatelessWidget {
  final Widget child;
  const _Panel({required this.child});
  @override
  Widget build(BuildContext context) => Container(
    width: double.infinity,
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      color: AppColors.surface,
      border: Border.all(color: AppColors.border),
      borderRadius: BorderRadius.circular(16),
    ),
    child: child,
  );
}

class _PrimaryButton extends StatelessWidget {
  final String label;
  final IconData? icon;
  final Color color;
  final VoidCallback onPressed;
  const _PrimaryButton({
    required this.label,
    required this.onPressed,
    this.icon,
    this.color = AppColors.amber,
  });
  @override
  Widget build(BuildContext context) => SizedBox(
    width: double.infinity,
    height: 48,
    child: ElevatedButton.icon(
      onPressed: onPressed,
      icon: icon == null ? const SizedBox.shrink() : Icon(icon, size: 15),
      label: Text(
        label,
        style: AppTextStyles.body(
          fontSize: 14,
          fontWeight: FontWeight.w700,
          color: AppColors.bgDeep,
        ),
      ),
      style: ElevatedButton.styleFrom(
        backgroundColor: color,
        foregroundColor: AppColors.bgDeep,
        elevation: 0,
        shape: const StadiumBorder(),
      ),
    ),
  );
}

class _InfoLine extends StatelessWidget {
  final IconData icon;
  final String text;
  final bool mono;
  const _InfoLine({required this.icon, required this.text, this.mono = false});
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 7),
    child: Row(
      children: [
        Icon(icon, size: 14, color: mono ? AppColors.faint : AppColors.amber),
        const SizedBox(width: 8),
        Text(
          text,
          style: mono
              ? AppTextStyles.mono(fontSize: 11.5, color: AppColors.faint)
              : AppTextStyles.body(fontSize: 13.5),
        ),
      ],
    ),
  );
}

class _Stat extends StatelessWidget {
  final String value, label;
  const _Stat({required this.value, required this.label});
  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(
        value,
        style: AppTextStyles.mono(fontSize: 19, fontWeight: FontWeight.w500),
      ),
      Text(
        label,
        style: AppTextStyles.body(fontSize: 10.5, color: AppColors.faint),
      ),
    ],
  );
}

class _LayerChip extends StatelessWidget {
  final String label;
  final IconData icon;
  const _LayerChip({required this.label, required this.icon});
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
    decoration: BoxDecoration(
      color: AppColors.amber.withValues(alpha: .1),
      border: Border.all(color: AppColors.amber),
      borderRadius: BorderRadius.circular(30),
    ),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 13, color: AppColors.amber),
        const SizedBox(width: 6),
        Text(
          label,
          style: AppTextStyles.body(fontSize: 10.5, color: AppColors.amber),
        ),
      ],
    ),
  );
}

class _PodMember extends StatelessWidget {
  final String initials;
  final bool reached;
  const _PodMember({required this.initials, required this.reached});
  @override
  Widget build(BuildContext context) => _ListLine(
    leading: CircleAvatar(
      radius: 17,
      backgroundColor: AppColors.surface2,
      foregroundColor: AppColors.text,
      child: Text(
        initials,
        style: AppTextStyles.body(fontSize: 12, fontWeight: FontWeight.w700),
      ),
    ),
    title: 'Companion $initials',
    subtitle: reached
        ? 'Reached safely · 8:52 PM'
        : 'En route · sharing location',
    trailing: reached
        ? const Icon(Icons.check, color: AppColors.green, size: 16)
        : Text(
            'live',
            style: AppTextStyles.mono(fontSize: 10, color: AppColors.amber),
          ),
  );
}

class _ContactRow extends StatelessWidget {
  final String initials, name, relation;
  const _ContactRow({
    required this.initials,
    required this.name,
    required this.relation,
  });
  @override
  Widget build(BuildContext context) => _ListLine(
    leading: CircleAvatar(
      radius: 17,
      backgroundColor: AppColors.surface2,
      foregroundColor: AppColors.amber,
      child: Text(
        initials,
        style: AppTextStyles.body(fontSize: 12, fontWeight: FontWeight.w700),
      ),
    ),
    title: name,
    subtitle: relation,
    trailing: const Icon(Icons.chevron_right, color: AppColors.faint, size: 16),
  );
}

class _ListLine extends StatelessWidget {
  final Widget leading, trailing;
  final String title, subtitle;
  const _ListLine({
    required this.leading,
    required this.title,
    required this.subtitle,
    required this.trailing,
  });
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 9),
    child: Row(
      children: [
        leading,
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: AppTextStyles.body(fontSize: 13)),
              Text(
                subtitle,
                style: AppTextStyles.body(
                  fontSize: 10.5,
                  color: AppColors.faint,
                ),
              ),
            ],
          ),
        ),
        trailing,
      ],
    ),
  );
}

class _TriggerRow extends StatelessWidget {
  final String label;
  const _TriggerRow({required this.label});
  @override
  Widget build(BuildContext context) => Container(
    width: double.infinity,
    decoration: const BoxDecoration(
      border: Border(top: BorderSide(color: AppColors.border)),
    ),
    padding: const EdgeInsets.symmetric(vertical: 11),
    child: Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: AppTextStyles.body(fontSize: 12.5, color: AppColors.muted),
        ),
        const Icon(Icons.chevron_right, size: 16, color: AppColors.faint),
      ],
    ),
  );
}

class _AlertRow extends StatelessWidget {
  final String label;
  final bool done;
  const _AlertRow(this.label, this.done);
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 8),
    child: Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: AppTextStyles.body(fontSize: 12.5)),
        done
            ? const Icon(Icons.check, color: AppColors.green, size: 16)
            : Text(
                'pending',
                style: AppTextStyles.mono(fontSize: 10, color: AppColors.faint),
              ),
      ],
    ),
  );
}

class _CallAction extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  const _CallAction({
    required this.icon,
    required this.label,
    required this.color,
  });
  @override
  Widget build(BuildContext context) => Column(
    children: [
      CircleAvatar(
        radius: 29,
        backgroundColor: color,
        child: Icon(icon, color: Colors.white, size: 22),
      ),
      const SizedBox(height: 7),
      Text(
        label,
        style: AppTextStyles.body(fontSize: 10, color: const Color(0xFF888888)),
      ),
    ],
  );
}

class _SettingRow extends StatelessWidget {
  final IconData icon;
  final String title, sub;
  final bool value;
  final ValueChanged<bool> onChanged;
  const _SettingRow({
    required this.icon,
    required this.title,
    required this.sub,
    required this.value,
    required this.onChanged,
  });
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 6),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 17, color: AppColors.amber),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: AppTextStyles.body(fontSize: 13)),
              const SizedBox(height: 2),
              Text(
                sub,
                style: AppTextStyles.body(
                  fontSize: 10.5,
                  color: AppColors.faint,
                ),
              ),
            ],
          ),
        ),
        Switch(
          value: value,
          onChanged: onChanged,
          activeThumbColor: AppColors.amber,
        ),
      ],
    ),
  );
}
