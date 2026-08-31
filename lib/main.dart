import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:sensors_plus/sensors_plus.dart';
import 'package:url_launcher/url_launcher.dart';

import 'package:latlong2/latlong.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'core/theme/app_theme.dart';
import 'core/widgets/auto_sos_overlay.dart';
import 'core/widgets/beacon_ring.dart';
import 'core/widgets/floating_sos_button.dart';
import 'core/widgets/nav_bar.dart';
import 'core/widgets/open_street_map_widget.dart';
import 'services/audio_detection_service.dart';
import 'services/auth_api_service.dart';
import 'services/contacts_api_service.dart';
import 'services/commute_api_service.dart';
import 'services/location_service.dart';
import 'services/sos_api_service.dart';
import 'services/live_location_socket_service.dart';

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
  autoSosCountdown,
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

  // Destination chosen by the user before commute
  String _destinationName = '';
  LatLng? _destinationLatLng;

  // Primary contact name (for DecoyView)
  String _primaryContactName = '';
  String? _commuteTrackingToken;
  bool _automaticSos = false;

  final _audioService = AudioDetectionService();
  bool _audioEnabled = true;
  double _triggerConfidence = 0.85;
  StreamSubscription? _distressSub;

  @override
  void initState() {
    super.initState();
    _distressSub = _audioService.onDistressDetected.listen((confidence) {
      if (_audioEnabled && mounted) {
        setState(() {
          _triggerConfidence = confidence;
          _automaticSos = true;
          _screen = AppScreen.autoSosCountdown;
        });
      }
    });
  }

  @override
  void dispose() {
    _distressSub?.cancel();
    _audioService.dispose();
    super.dispose();
  }

  bool get _hasNavigation => switch (_screen) {
    AppScreen.home ||
    AppScreen.pod ||
    AppScreen.contacts ||
    AppScreen.settings => true,
    _ => false,
  };

  bool get _showBackArrow => _screen == AppScreen.pod ||
      _screen == AppScreen.contacts || _screen == AppScreen.settings;

  void _goTo(AppScreen screen) {
    if (_screen != AppScreen.sos &&
        _screen != AppScreen.decoy &&
        _screen != AppScreen.autoSosCountdown) {
      _previousScreen = _screen;
    }
    if (screen == AppScreen.pod && _audioEnabled) {
      _audioService.startListening();
    } else if (_screen == AppScreen.pod && screen != AppScreen.autoSosCountdown) {
      _audioService.stopListening();
    }
    setState(() => _screen = screen);
  }

  Future<bool> _handleBack() async {
    if (_screen == AppScreen.onboarding) return true;
    if (_screen == AppScreen.auth) {
      _goTo(AppScreen.onboarding);
    } else if (_hasNavigation) {
      _goTo(_previousScreen == _screen ? AppScreen.home : _previousScreen);
    } else if (_screen == AppScreen.sosActive || _screen == AppScreen.sos) {
      _goTo(AppScreen.home);
    } else {
      _goTo(AppScreen.home);
    }
    return false;
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

  /// Called when user selects a destination on the home screen.
  Future<void> _startCommuteWithDestination(String name, LatLng latLng) async {
    setState(() {
      _destinationName = name;
      _destinationLatLng = latLng;
      _commuteTrackingToken = null;
    });
    _goTo(AppScreen.pod);

    try {
      final origin = await LocationService().getCurrentLocation();
      final result = await CommuteApiService.startCommute(
        originName: 'Current location', destinationName: name,
        originLat: origin.latitude, originLng: origin.longitude,
        destLat: latLng.latitude, destLng: latLng.longitude,
      );
      if (mounted) {
        setState(() => _commuteTrackingToken = result['trackingToken'] as String?);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.toString().replaceAll('Exception: ', ''))),
        );
      }
    }
  }

  /// Called from ContactsView when the primary contact changes.
  void _onPrimaryContactChanged(String name) {
    setState(() => _primaryContactName = name);
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (_, _) => _handleBack(),
      child: Scaffold(
      backgroundColor: const Color(0xFFE9E2F2),
      body: SafeArea(
        child: Stack(
          children: [
            Column(
              children: [
                if (_showBackArrow)
                  Align(
                    alignment: Alignment.centerLeft,
                    child: IconButton(
                      tooltip: 'Back',
                      onPressed: _handleBack,
                      icon: const Icon(Icons.arrow_back_rounded),
                    ),
                  ),
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
      onStartCommute: _startCommuteWithDestination,
    ),
    AppScreen.pod => PodView(
      audioService: _audioService,
      audioEnabled: _audioEnabled,
      destinationName: _destinationName,
      destinationLatLng: _destinationLatLng,
      trackingToken: _commuteTrackingToken,
      onReached: () {
        _audioService.stopListening();
        setState(() {
          _destinationName = '';
          _destinationLatLng = null;
        });
        _goTo(AppScreen.home);
      },
    ),
    AppScreen.contacts => ContactsView(
      onPrimaryContactChanged: _onPrimaryContactChanged,
    ),
    AppScreen.settings => SettingsView(
      audioEnabled: _audioEnabled,
      onAudioToggle: (val) => setState(() => _audioEnabled = val),
      audioService: _audioService,
      onNavigateContacts: () => _goTo(AppScreen.contacts),
    ),
    AppScreen.sos => SosTriggerView(
      onActivate: () { _automaticSos = false; _goTo(AppScreen.sosActive); },
      onDecoy: () => _goTo(AppScreen.decoy),
      onCancel: () => _goTo(_previousScreen),
    ),
    AppScreen.sosActive => SosActiveView(
      triggerType: _automaticSos ? 'AUDIO_DISTRESS' : 'MANUAL_SOS',
      confidenceScore: _triggerConfidence,
      onResolve: () => _goTo(AppScreen.home),
    ),
    AppScreen.decoy => DecoyView(
      primaryContactName: _primaryContactName,
      onBack: () => _goTo(AppScreen.sos),
    ),
    AppScreen.autoSosCountdown => AutoSosOverlay(
      confidence: _triggerConfidence,
      onCancel: () {
        _audioService.resetAfterCancel();
        _goTo(_previousScreen);
      },
      onTriggered: () {
        _audioService.stopListening();
        _goTo(AppScreen.sosActive);
      },
    ),
  };
}

// ─────────────────────────────────────────────────────────────────────────────
//  Onboarding View
// ─────────────────────────────────────────────────────────────────────────────

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

// ─────────────────────────────────────────────────────────────────────────────
//  Auth View
// ─────────────────────────────────────────────────────────────────────────────

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
  bool _isLoading = false;

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_formKey.currentState!.validate()) {
          setState(() {
            _isLoading = true;
          });
      final email = _emailController.text.trim();
      final password = _passwordController.text.trim();
      final fullName = _nameController.text.trim();

      try {
        if (_isSignUp) {
          final res = await AuthApiService.signUp(
            fullName: fullName,
            email: email,
            password: password,
          );
          final user = res['user'];
          final name = (user != null && user['full_name'] != null)
              ? user['full_name'] as String
              : fullName;
          if (mounted) {
            setState(() => _isLoading = false);
            widget.onAuthenticated(name);
          }
        } else {
          final res = await AuthApiService.signIn(
            email: email,
            password: password,
          );
          final user = res['user'];
          final name = (user != null && user['full_name'] != null)
              ? user['full_name'] as String
              : email.split('@').first;
          if (mounted) {
            setState(() => _isLoading = false);
            widget.onAuthenticated(name);
          }
        }
      } catch (e) {
        if (mounted) {
          setState(() => _isLoading = false);
          final errorMsg = e.toString().replaceAll('Exception: ', '');
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(errorMsg),
              backgroundColor: AppColors.coral,
              duration: const Duration(seconds: 4),
            ),
          );
        }
      }
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
                return RegExp(r'^[^\@\s]+@[^\@\s]+\.[^\@\s]+$').hasMatch(v!.trim())
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
                  onPressed: () {},
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
              label: _isLoading ? 'Connecting...' : (_isSignUp ? 'Create account' : 'Sign in'),
              onPressed: _isLoading ? () {} : _submit,
            ),
            const SizedBox(height: 18),
            Center(
              child: TextButton(
                onPressed: () => setState(() {
                  _isSignUp = !_isSignUp;
                  if (_isSignUp) {
                    _emailController.clear();
                    _passwordController.clear();
                  }
                }),
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

// ─────────────────────────────────────────────────────────────────────────────
//  Home View — no fake data, user picks destination
// ─────────────────────────────────────────────────────────────────────────────

class HomeView extends StatefulWidget {
  final String userName;
  final void Function(String name, LatLng latLng) onStartCommute;
  const HomeView({
    super.key,
    required this.userName,
    required this.onStartCommute,
  });

  @override
  State<HomeView> createState() => _HomeViewState();
}

class _HomeViewState extends State<HomeView> {
  /// Returns a friendly greeting based on the current hour.
  String _greeting() {
    final istNow = DateTime.now().toUtc().add(const Duration(hours: 5, minutes: 30));
    final hour = istNow.hour;
    if (hour < 12) return 'Good morning,';
    if (hour < 17) return 'Good afternoon,';
    return 'Good evening,';
  }

  Future<void> _openDestinationPicker() async {
    final destination = await showModalBottomSheet<_Destination>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _DestinationPickerSheet(
        onConfirm: (name, location) {
          Navigator.of(context).pop(_Destination(name, location));
        },
      ),
    );
    if (destination != null && mounted) {
      widget.onStartCommute(destination.name, destination.location);
    }
  }

  @override
  Widget build(BuildContext context) => _Page(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          _greeting(),
          style: AppTextStyles.body(fontSize: 12.5, color: AppColors.faint),
        ),
        Text(
          widget.userName.isEmpty ? 'Welcome' : widget.userName,
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
              const SizedBox(height: 14),
              Text(
                'Tap "Start commute" to choose your destination. Your live location will be tracked throughout.',
                style: AppTextStyles.body(fontSize: 12, color: AppColors.faint),
              ),
              const SizedBox(height: 14),
              const OpenStreetMapWidget(
                center: LocationService.defaultLocation,
                zoom: 13.5,
                height: 150,
                interactive: false,
                useLiveGps: true,
                titleLabel: 'Your location · OSM',
              ),
              const SizedBox(height: 14),
              _PrimaryButton(
                label: 'Start commute',
                icon: Icons.navigation_rounded,
                onPressed: _openDestinationPicker,
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),
      ],
    ),
  );
}

class _Destination {
  final String name;
  final LatLng location;
  const _Destination(this.name, this.location);
}

/// Bottom sheet for the user to type where they are heading.
class _DestinationPickerSheet extends StatefulWidget {
  final void Function(String name, LatLng location) onConfirm;
  const _DestinationPickerSheet({required this.onConfirm});

  @override
  State<_DestinationPickerSheet> createState() => _DestinationPickerSheetState();
}

class _DestinationPickerSheetState extends State<_DestinationPickerSheet> {
  final _controller = TextEditingController();
  Timer? _searchTimer;
  List<Map<String, dynamic>> _suggestions = [];
  bool _hasInput = false;

  /// Simple geocode-style suggestions (user can type freely — we use the
  /// text as the destination label and derive a mock LatLng offset from
  /// the user's live GPS as a placeholder until a real geocoding API is added).
  @override
  void initState() {
    super.initState();
    _controller.addListener(() {
      final query = _controller.text.trim();
      setState(() => _hasInput = query.isNotEmpty);
      _searchTimer?.cancel();
      if (query.length >= 3) {
        _searchTimer = Timer(const Duration(milliseconds: 450), () => _search(query));
      } else {
        setState(() => _suggestions = []);
      }
    });
  }

  Future<void> _search(String query) async {
    try {
      final response = await http.get(
        Uri.https('nominatim.openstreetmap.org', '/search', {
          'q': query, 'format': 'jsonv2', 'limit': '5', 'countrycodes': 'in',
        }),
        headers: const {'User-Agent': 'NaariRakshak/1.0'},
      );
      if (!mounted || response.statusCode != 200) return;
      final results = (jsonDecode(response.body) as List).cast<Map<String, dynamic>>();
      if (_controller.text.trim() == query) setState(() => _suggestions = results);
    } catch (_) {}
  }

  @override
  void dispose() {
    _controller.dispose();
    _searchTimer?.cancel();
    super.dispose();
  }

  void _confirm() {
    final name = _controller.text.trim();
    if (name.isEmpty) return;
    if (_suggestions.isEmpty) return;
    final selected = _suggestions.first;
    widget.onConfirm(
      selected['display_name'] as String? ?? name,
      LatLng(double.parse(selected['lat'] as String), double.parse(selected['lon'] as String)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.of(context).viewInsets.bottom;
    return Container(
      padding: EdgeInsets.fromLTRB(24, 24, 24, 24 + bottom),
      decoration: const BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: AppColors.border,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          if (_suggestions.isNotEmpty)
            Material(
              color: AppColors.surface,
              child: Column(
                children: _suggestions.map((suggestion) => ListTile(
                  dense: true,
                  leading: const Icon(Icons.place_outlined, color: AppColors.amber),
                  title: Text(suggestion['display_name'] as String, maxLines: 2, overflow: TextOverflow.ellipsis),
                  onTap: () {
                    widget.onConfirm(
                      suggestion['display_name'] as String,
                      LatLng(
                        double.parse(suggestion['lat'] as String),
                        double.parse(suggestion['lon'] as String),
                      ),
                    );
                  },
                )).toList(),
              ),
            ),
          const SizedBox(height: 20),
          Text(
            'Where are you going?',
            style: AppTextStyles.display(fontSize: 19, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 6),
          Text(
            'Your live location will be tracked throughout your commute.',
            style: AppTextStyles.body(fontSize: 12, color: AppColors.faint),
          ),
          const SizedBox(height: 18),
          TextField(
            controller: _controller,
            autofocus: true,
            style: AppTextStyles.body(fontSize: 14),
            textCapitalization: TextCapitalization.words,
            decoration: InputDecoration(
              hintText: 'e.g. Cyber Hub, Gurugram',
              hintStyle: AppTextStyles.body(fontSize: 13, color: AppColors.faint),
              prefixIcon: const Icon(Icons.location_on_outlined, color: AppColors.amber, size: 20),
              filled: true,
              fillColor: AppColors.bg,
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
            ),
            onSubmitted: (_) => _hasInput ? _confirm() : null,
          ),
          const SizedBox(height: 16),
          _PrimaryButton(
            label: 'Start commute',
            icon: Icons.navigation_rounded,
            onPressed: _hasInput ? _confirm : () {},
          ),
          const SizedBox(height: 4),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
//  Pod View — live GPS, real destination, no fake companions
// ─────────────────────────────────────────────────────────────────────────────

class PodView extends StatefulWidget {
  final VoidCallback onReached;
  final AudioDetectionService audioService;
  final bool audioEnabled;
  final String destinationName;
  final LatLng? destinationLatLng;
  final String? trackingToken;

  const PodView({
    super.key,
    required this.onReached,
    required this.audioService,
    required this.audioEnabled,
    required this.destinationName,
    required this.destinationLatLng,
    this.trackingToken,
  });

  @override
  State<PodView> createState() => _PodViewState();
}

class _PodViewState extends State<PodView> {
  final _locationService = LocationService();
  LatLng? _currentLocation;
  StreamSubscription<LatLng>? _locationSub;
  Timer? _telemetryTimer;
  DateTime? _commuteStartTime;

  @override
  void initState() {
    super.initState();
    _commuteStartTime = DateTime.now();
    _initLocation();
  }

  Future<void> _initLocation() async {
    final loc = await _locationService.getCurrentLocation();
    if (mounted) setState(() => _currentLocation = loc);
    _locationService.startTracking();
    _locationSub = _locationService.locationStream.listen((loc) {
      if (mounted) setState(() => _currentLocation = loc);
    });
    if (widget.trackingToken != null) {
      _startTelemetry(widget.trackingToken!, loc);
    }
  }

  void _startTelemetry(String trackingToken, LatLng fallback) {
    if (_telemetryTimer != null) return;
    final socket = LiveLocationSocketService();
    socket.connect();
    socket.joinTrackingRoom(trackingToken);
    _telemetryTimer = Timer.periodic(const Duration(seconds: 3), (_) {
      final current = _currentLocation ?? fallback;
      socket.sendTelemetry(
        trackingToken: trackingToken, incidentId: null,
        lat: current.latitude, lng: current.longitude,
      );
    });
  }

  @override
  void didUpdateWidget(covariant PodView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.trackingToken == null && widget.trackingToken != null) {
      _startTelemetry(widget.trackingToken!, _currentLocation ?? LocationService.defaultLocation);
    }
  }

  @override
  void dispose() {
    _locationSub?.cancel();
    _telemetryTimer?.cancel();
    _locationService.dispose();
    super.dispose();
  }

  String _elapsedTime() {
    if (_commuteStartTime == null) return '0 min';
    final diff = DateTime.now().difference(_commuteStartTime!);
    final mins = diff.inMinutes;
    if (mins < 60) return '$mins min elapsed';
    return '${diff.inHours}h ${mins % 60}min elapsed';
  }

  @override
  Widget build(BuildContext context) {
    final mapCenter = _currentLocation ?? LocationService.defaultLocation;
    final destination = widget.destinationLatLng;

    // Build route points: current location → destination (if set)
    final routePoints = destination != null ? [mapCenter, destination] : null;

    return _Page(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Commute active', style: AppTextStyles.display(fontSize: 19)),
              if (widget.audioEnabled)
                StreamBuilder<AudioDetectionSnapshot>(
                  stream: widget.audioService.snapshots,
                  builder: (context, snapshot) {
                    final data = snapshot.data;
                    final isListening = data?.state == DetectionState.listening ||
                        data?.state == DetectionState.detecting;
                    final isDetecting = data?.state == DetectionState.detecting;

                    return Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                      decoration: BoxDecoration(
                        color: isDetecting
                            ? AppColors.coral.withValues(alpha: 0.15)
                            : AppColors.amber.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: isDetecting ? AppColors.coral : AppColors.amber,
                          width: 1,
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            isDetecting ? Icons.graphic_eq : Icons.mic_rounded,
                            size: 13,
                            color: isDetecting ? AppColors.coral : AppColors.amber,
                          ),
                          const SizedBox(width: 5),
                          Text(
                            isDetecting
                                ? 'Distress sound?'
                                : (isListening ? 'AI Listening' : 'Audio Standby'),
                            style: AppTextStyles.mono(
                              fontSize: 10,
                              fontWeight: FontWeight.w600,
                              color: isDetecting ? AppColors.coral : AppColors.amber,
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
            ],
          ),
          const SizedBox(height: 4),
          if (widget.destinationName.isNotEmpty)
            Row(
              children: [
                const Icon(Icons.navigation_rounded, size: 13, color: AppColors.amber),
                const SizedBox(width: 5),
                Expanded(
                  child: Text(
                    'To: ${widget.destinationName}',
                    style: AppTextStyles.body(fontSize: 12, color: AppColors.muted),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          const SizedBox(height: 4),
          Text(
            _elapsedTime(),
            style: AppTextStyles.mono(fontSize: 11, color: AppColors.amber, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 12),
          // Live GPS commute map
          OpenStreetMapWidget(
            center: mapCenter,
            zoom: 14.5,
            height: 210,
            useLiveGps: true,
            routePoints: routePoints,
            titleLabel: 'Live GPS · OSM',
          ),
          const SizedBox(height: 12),
          _Panel(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: 8,
                      height: 8,
                      decoration: const BoxDecoration(
                        color: AppColors.green,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'Live location sharing active',
                      style: AppTextStyles.body(fontSize: 12.5, fontWeight: FontWeight.w600),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                if (_currentLocation != null)
                  Text(
                    '${_currentLocation!.latitude.toStringAsFixed(5)}°N, ${_currentLocation!.longitude.toStringAsFixed(5)}°E',
                    style: AppTextStyles.mono(fontSize: 10, color: AppColors.faint),
                  ),
                const SizedBox(height: 4),
                Text(
                  'Emergency contacts & pod can see your real-time position.',
                  style: AppTextStyles.body(fontSize: 11, color: AppColors.faint),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          _PrimaryButton(
            label: "I've reached safely",
            icon: Icons.check_rounded,
            color: AppColors.green,
            onPressed: widget.onReached,
          ),
          const SizedBox(height: 10),
          Center(
            child: Text(
              'Missed check-ins auto-alert your emergency contacts.',
              textAlign: TextAlign.center,
              style: AppTextStyles.body(fontSize: 10.5, color: AppColors.faint),
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
//  SOS Trigger View
// ─────────────────────────────────────────────────────────────────────────────

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
  StreamSubscription<AccelerometerEvent>? _shakeSubscription;
  double _progress = 0;
  DateTime? _started;

  @override
  void initState() {
    super.initState();
    _shakeSubscription = accelerometerEventStream().listen((event) {
      final force = event.x * event.x + event.y * event.y + event.z * event.z;
      if (force > 55 && mounted) widget.onActivate();
    });
  }

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
    _shakeSubscription?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => _Page(
    scrollable: false,
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
                  'Shares live location, audio and alerts your emergency contacts',
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

// ─────────────────────────────────────────────────────────────────────────────
//  SOS Active View — uses real GPS coordinates
// ─────────────────────────────────────────────────────────────────────────────

class SosActiveView extends StatefulWidget {
  final VoidCallback onResolve;
  final String triggerType;
  final double confidenceScore;
  const SosActiveView({super.key, required this.onResolve, this.triggerType = 'MANUAL_SOS', this.confidenceScore = 1.0});

  @override
  State<SosActiveView> createState() => _SosActiveViewState();
}

class _SosActiveViewState extends State<SosActiveView> {
  String? _incidentId;
  String? _trackingToken;
  Timer? _telemetryTimer;
  Timer? _elapsedTimer;
  final _socketService = LiveLocationSocketService();
  final _locationService = LocationService();

  LatLng? _currentLocation;
  StreamSubscription<LatLng>? _locationSub;
  Duration _elapsed = Duration.zero;
  final _startTime = DateTime.now();

  @override
  void initState() {
    super.initState();
    _elapsedTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) {
        setState(() => _elapsed = DateTime.now().difference(_startTime));
      }
    });
    _triggerSosAndStartTelemetry();
  }

  Future<void> _triggerSosAndStartTelemetry() async {
    // Get real GPS coordinates
    final loc = await _locationService.getCurrentLocation();
    if (mounted) setState(() => _currentLocation = loc);

    // Start continuous tracking
    _locationService.startTracking();
    _locationSub = _locationService.locationStream.listen((newLoc) {
      if (mounted) setState(() => _currentLocation = newLoc);
    });

    try {
      final res = await SosApiService.triggerSos(
        triggerType: widget.triggerType,
        lat: loc.latitude,
        lng: loc.longitude,
        confidenceScore: widget.confidenceScore,
      );

      _incidentId = res.incidentId;
      _trackingToken = res.trackingToken;

      if (kDebugMode) {
        print('SOS alert dispatched. Tracking location from $_currentLocation');
      }

      _socketService.connect();
      _socketService.joinTrackingRoom(_trackingToken!);

      void sendCurrentLocation() {
        final currentLoc = _currentLocation ?? loc;
        _socketService.sendTelemetry(
          trackingToken: _trackingToken!,
          incidentId: _incidentId!,
          lat: currentLoc.latitude,
          lng: currentLoc.longitude,
          speed: 0.0,
          batteryLevel: 100,
        );
      }

      sendCurrentLocation();
      _telemetryTimer = Timer.periodic(const Duration(seconds: 3), (_) => sendCurrentLocation());
    } catch (e) {
      if (kDebugMode) print('SOS API dispatch note: $e');
    }
  }

  Future<void> _handleResolve() async {
    _telemetryTimer?.cancel();
    _elapsedTimer?.cancel();
    if (_incidentId != null) {
      try {
        await SosApiService.resolveSos(_incidentId!);
      } catch (e) {
        if (kDebugMode) print('Resolve SOS note: $e');
      }
    }
    _socketService.disconnect();
    widget.onResolve();
  }

  String _formatElapsed() {
    final m = _elapsed.inMinutes.toString().padLeft(2, '0');
    final s = (_elapsed.inSeconds % 60).toString().padLeft(2, '0');
    return 'Live for $m:$s';
  }

  @override
  void dispose() {
    _telemetryTimer?.cancel();
    _elapsedTimer?.cancel();
    _locationSub?.cancel();
    _locationService.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final mapCenter = _currentLocation ?? LocationService.defaultLocation;
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFFFCE7E7), AppColors.bg],
        ),
      ),
      child: SingleChildScrollView(
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
              _formatElapsed(),
              style: AppTextStyles.mono(fontSize: 11, color: AppColors.coral),
            ),
            const SizedBox(height: 16),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: OpenStreetMapWidget(
                center: mapCenter,
                zoom: 14.5,
                height: 190,
                isSosActive: true,
                useLiveGps: true,
                titleLabel: 'LIVE EMERGENCY BEACON · OSM',
              ),
            ),
            const SizedBox(height: 16),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: _Panel(
                child: Column(
                  children: const [
                    _AlertRow('Pod notified', true),
                    _AlertRow('Emergency contacts notified', true),
                    _AlertRow('Live location sharing', true),
                    _AlertRow('Control room (112) pinged', true),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Column(
                children: [
                  _PrimaryButton(
                    label: 'Call 112 now',
                    icon: Icons.phone_in_talk_rounded,
                    color: AppColors.coral,
                    onPressed: () => launchUrl(Uri(scheme: 'tel', path: '112')),
                  ),
                  const SizedBox(height: 10),
                  OutlinedButton(
                    onPressed: _handleResolve,
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
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
//  Decoy View — uses real primary contact name
// ─────────────────────────────────────────────────────────────────────────────

class DecoyView extends StatelessWidget {
  final VoidCallback onBack;
  final String primaryContactName;
  const DecoyView({
    super.key,
    required this.onBack,
    this.primaryContactName = '',
  });

  @override
  Widget build(BuildContext context) {
    final displayName = primaryContactName.isNotEmpty
        ? primaryContactName.split(' ').first
        : 'Contact';
    final initial = displayName.isNotEmpty ? displayName[0].toUpperCase() : 'C';

    return GestureDetector(
      onDoubleTap: onBack,
      child: Container(
        color: const Color(0xFF0B0B10),
        child: SingleChildScrollView(
          child: SizedBox(
            height: MediaQuery.of(context).size.height,
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
                          initial,
                          style: AppTextStyles.display(
                            fontSize: 30,
                            color: const Color(0xFF999999),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),
                    Text(
                      displayName,
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
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
//  Contacts View — real CRUD with form dialog, swipe-to-delete, empty state
// ─────────────────────────────────────────────────────────────────────────────

class ContactsView extends StatefulWidget {
  final ValueChanged<String>? onPrimaryContactChanged;
  const ContactsView({super.key, this.onPrimaryContactChanged});

  @override
  State<ContactsView> createState() => _ContactsViewState();
}

class _ContactsViewState extends State<ContactsView> {
  List<EmergencyContactItem> _contacts = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadContacts();
  }

  Future<void> _loadContacts() async {
    setState(() => _isLoading = true);
    try {
      final list = await ContactsApiService.fetchContacts();
      if (mounted) {
        setState(() {
          _contacts = list;
          _isLoading = false;
        });
        _notifyPrimaryContact();
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  void _notifyPrimaryContact() {
    final primary = _contacts.where((c) => c.isPrimary).firstOrNull;
    final name = primary?.name ?? (_contacts.isNotEmpty ? _contacts.first.name : '');
    widget.onPrimaryContactChanged?.call(name);
  }

  void _openAddContactDialog() {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _AddContactSheet(
        onSaved: (newContact) async {
          Navigator.of(ctx).pop();
          try {
            final saved = await ContactsApiService.addContact(
              name: newContact.name,
              phone: newContact.phone,
              relation: newContact.relation,
              isPrimary: newContact.isPrimary,
            );
            if (mounted) {
              setState(() {
                if (saved.isPrimary) {
                  _contacts = _contacts.map((c) => EmergencyContactItem(
                    id: c.id,
                    name: c.name,
                    phone: c.phone,
                    relation: c.relation,
                    isPrimary: false,
                  )).toList();
                }
                final existingIdx = _contacts.indexWhere((c) => c.id == saved.id || (c.phone == saved.phone && saved.phone.isNotEmpty));
                if (existingIdx >= 0) {
                  _contacts[existingIdx] = saved;
                } else {
                  _contacts.add(saved);
                }
              });
              _notifyPrimaryContact();
              _showSnack('Contact saved successfully', isError: false);
            }
          } catch (e) {
            if (mounted) {
              final msg = e.toString().replaceAll('Exception: ', '');
              _showSnack('Failed to save contact: $msg');
            }
          }
        },
      ),
    );
  }

  Future<void> _deleteContact(EmergencyContactItem contact) async {
    // Optimistic removal
    setState(() => _contacts.remove(contact));
    _notifyPrimaryContact();
    try {
      final success = await ContactsApiService.deleteContact(contact.id);
      if (!success && mounted) {
        // Re-add if server failed
        setState(() => _contacts.add(contact));
        _showSnack('Could not delete contact. Please try again.');
      } else if (success && mounted) {
        _showSnack('${contact.name} removed', isError: false);
      }
    } catch (e) {
      if (mounted) {
        setState(() => _contacts.add(contact));
        _showSnack('Could not delete contact. Please try again.');
      }
    }
  }

  void _showSnack(String message, {bool isError = true}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message, style: AppTextStyles.body(fontSize: 13, color: Colors.white)),
        backgroundColor: isError ? AppColors.coral : AppColors.green,
        duration: const Duration(seconds: 3),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

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
            IconButton(
              onPressed: _openAddContactDialog,
              icon: const Icon(
                Icons.person_add_alt_1_rounded,
                color: AppColors.amber,
                size: 22,
              ),
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(),
              tooltip: 'Add contact',
            ),
          ],
        ),
        const SizedBox(height: 6),
        Text(
          'These contacts are alerted instantly when you trigger an SOS.',
          style: AppTextStyles.body(fontSize: 11.5, color: AppColors.faint),
        ),
        const SizedBox(height: 16),
        if (_isLoading)
          const Center(
            child: Padding(
              padding: EdgeInsets.all(32),
              child: CircularProgressIndicator(color: AppColors.amber),
            ),
          )
        else if (_contacts.isEmpty)
          _EmptyContactsState(onAdd: _openAddContactDialog)
        else
          _Panel(
            child: Column(
              children: _contacts.map((c) {
                final initials = c.name
                    .split(' ')
                    .map((e) => e.isNotEmpty ? e[0] : '')
                    .take(2)
                    .join()
                    .toUpperCase();
                return Dismissible(
                  key: Key(c.id),
                  direction: DismissDirection.endToStart,
                  background: Container(
                    alignment: Alignment.centerRight,
                    padding: const EdgeInsets.only(right: 16),
                    decoration: BoxDecoration(
                      color: AppColors.coral.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(Icons.delete_outline_rounded, color: AppColors.coral, size: 20),
                  ),
                  confirmDismiss: (_) async {
                    return await showDialog<bool>(
                      context: context,
                      builder: (ctx) => AlertDialog(
                        title: Text('Remove contact?', style: AppTextStyles.display(fontSize: 17)),
                        content: Text(
                          'Remove ${c.name} from your emergency contacts?',
                          style: AppTextStyles.body(fontSize: 13),
                        ),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.pop(ctx, false),
                            child: Text('Cancel', style: AppTextStyles.body(color: AppColors.muted)),
                          ),
                          TextButton(
                            onPressed: () => Navigator.pop(ctx, true),
                            child: Text('Remove', style: AppTextStyles.body(color: AppColors.coral)),
                          ),
                        ],
                      ),
                    ) ?? false;
                  },
                  onDismissed: (_) => _deleteContact(c),
                  child: _ContactRow(
                    initials: initials.isEmpty ? 'EC' : initials,
                    name: c.name,
                    phone: c.phone,
                    relation: c.relation,
                    isPrimary: c.isPrimary,
                  ),
                );
              }).toList(),
            ),
          ),
        const SizedBox(height: 14),
        OutlinedButton.icon(
          onPressed: _openAddContactDialog,
          icon: const Icon(Icons.add, size: 16),
          label: Text('Add contact', style: AppTextStyles.body(fontSize: 12.5)),
          style: OutlinedButton.styleFrom(
            minimumSize: const Size.fromHeight(48),
            foregroundColor: AppColors.muted,
            side: const BorderSide(color: AppColors.border),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          ),
        ),
        if (_contacts.isNotEmpty) ...[
          const SizedBox(height: 10),
          Center(
            child: Text(
              'Swipe left on a contact to remove them.',
              style: AppTextStyles.body(fontSize: 11, color: AppColors.faint),
            ),
          ),
        ],
      ],
    ),
  );
}

class _EmptyContactsState extends StatelessWidget {
  final VoidCallback onAdd;
  const _EmptyContactsState({required this.onAdd});

  @override
  Widget build(BuildContext context) => _Panel(
    child: Padding(
      padding: const EdgeInsets.symmetric(vertical: 24),
      child: Column(
        children: [
          Icon(Icons.people_outline_rounded, size: 44, color: AppColors.faint.withValues(alpha: 0.6)),
          const SizedBox(height: 12),
          Text(
            'No emergency contacts yet',
            style: AppTextStyles.body(fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.muted),
          ),
          const SizedBox(height: 6),
          Text(
            'Add trusted contacts who will be\nalerted if you trigger an SOS.',
            textAlign: TextAlign.center,
            style: AppTextStyles.body(fontSize: 12, color: AppColors.faint),
          ),
          const SizedBox(height: 16),
          ElevatedButton.icon(
            onPressed: onAdd,
            icon: const Icon(Icons.person_add_alt_1_rounded, size: 16),
            label: Text('Add first contact', style: AppTextStyles.body(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.bgDeep)),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.amber,
              foregroundColor: AppColors.bgDeep,
              elevation: 0,
              shape: const StadiumBorder(),
            ),
          ),
        ],
      ),
    ),
  );
}

/// Bottom sheet form for adding a new emergency contact.
class _AddContactSheet extends StatefulWidget {
  final void Function(EmergencyContactItem contact) onSaved;
  const _AddContactSheet({required this.onSaved});

  @override
  State<_AddContactSheet> createState() => _AddContactSheetState();
}

class _AddContactSheetState extends State<_AddContactSheet> {
  final _formKey = GlobalKey<FormState>();
  final _nameCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  final _relationCtrl = TextEditingController();
  bool _isPrimary = false;

  @override
  void dispose() {
    _nameCtrl.dispose();
    _phoneCtrl.dispose();
    _relationCtrl.dispose();
    super.dispose();
  }

  void _submit() {
    if (_formKey.currentState!.validate()) {
      widget.onSaved(EmergencyContactItem(
        id: '', // Will be set by server
        name: _nameCtrl.text.trim(),
        phone: _phoneCtrl.text.trim(),
        relation: _relationCtrl.text.trim().isEmpty ? 'Contact' : _relationCtrl.text.trim(),
        isPrimary: _isPrimary,
      ));
    }
  }

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.of(context).viewInsets.bottom;
    return Container(
      padding: EdgeInsets.fromLTRB(24, 24, 24, 24 + bottom),
      decoration: const BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: AppColors.border,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 20),
            Text(
              'Add emergency contact',
              style: AppTextStyles.display(fontSize: 18, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 18),
            _SheetField(
              controller: _nameCtrl,
              label: 'Full name',
              hint: 'e.g. Priya Sharma',
              icon: Icons.person_outline,
              validator: (v) => (v == null || v.trim().isEmpty) ? 'Name is required' : null,
            ),
            const SizedBox(height: 12),
            _SheetField(
              controller: _phoneCtrl,
              label: 'Phone number',
              hint: 'e.g. +919876543210',
              icon: Icons.phone_outlined,
              keyboardType: TextInputType.phone,
              inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9+]'))],
              validator: (v) {
                if (v == null || v.trim().isEmpty) return 'Phone number is required';
                if (v.trim().length < 10) return 'Enter a valid phone number';
                return null;
              },
            ),
            const SizedBox(height: 12),
            _SheetField(
              controller: _relationCtrl,
              label: 'Relation (optional)',
              hint: 'e.g. Mother, Sister, Friend',
              icon: Icons.favorite_border_rounded,
            ),
            const SizedBox(height: 14),
            GestureDetector(
              onTap: () => setState(() => _isPrimary = !_isPrimary),
              child: Row(
                children: [
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    width: 20,
                    height: 20,
                    decoration: BoxDecoration(
                      color: _isPrimary ? AppColors.amber : Colors.transparent,
                      border: Border.all(
                        color: _isPrimary ? AppColors.amber : AppColors.muted,
                        width: 1.5,
                      ),
                      borderRadius: BorderRadius.circular(5),
                    ),
                    child: _isPrimary
                        ? const Icon(Icons.check_rounded, size: 14, color: AppColors.bgDeep)
                        : null,
                  ),
                  const SizedBox(width: 10),
                  Text(
                    'Set as primary contact (always alerted first)',
                    style: AppTextStyles.body(fontSize: 12.5),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            _PrimaryButton(label: 'Save contact', onPressed: _submit),
            const SizedBox(height: 4),
          ],
        ),
      ),
    );
  }
}

class _SheetField extends StatelessWidget {
  final TextEditingController controller;
  final String label, hint;
  final IconData icon;
  final TextInputType? keyboardType;
  final List<TextInputFormatter>? inputFormatters;
  final String? Function(String?)? validator;

  const _SheetField({
    required this.controller,
    required this.label,
    required this.hint,
    required this.icon,
    this.keyboardType,
    this.inputFormatters,
    this.validator,
  });

  @override
  Widget build(BuildContext context) => TextFormField(
    controller: controller,
    keyboardType: keyboardType,
    inputFormatters: inputFormatters,
    validator: validator,
    style: AppTextStyles.body(fontSize: 13),
    decoration: InputDecoration(
      labelText: label,
      hintText: hint,
      prefixIcon: Icon(icon, size: 18, color: AppColors.amber),
      filled: true,
      fillColor: AppColors.bg,
      labelStyle: AppTextStyles.body(fontSize: 12, color: AppColors.muted),
      hintStyle: AppTextStyles.body(fontSize: 12, color: AppColors.faint),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: AppColors.border),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: AppColors.border),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: AppColors.amber, width: 1.5),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: AppColors.coral),
      ),
    ),
  );
}

// ─────────────────────────────────────────────────────────────────────────────
//  Settings View — all toggles persisted via shared_preferences
// ─────────────────────────────────────────────────────────────────────────────

class SettingsView extends StatefulWidget {
  final bool audioEnabled;
  final ValueChanged<bool> onAudioToggle;
  final AudioDetectionService audioService;
  final VoidCallback? onNavigateContacts;

  const SettingsView({
    super.key,
    required this.audioEnabled,
    required this.onAudioToggle,
    required this.audioService,
    this.onNavigateContacts,
  });

  @override
  State<SettingsView> createState() => _SettingsViewState();
}

class _SettingsViewState extends State<SettingsView> {
  static const _keyPodMatching = 'setting_pod_matching';
  static const _keyPreciseLocation = 'setting_precise_location';
  static const _keyDecoyCall = 'setting_decoy_call';
  static const _keySensitivity = 'setting_sensitivity';

  bool _podMatching = true;
  bool _preciseLocation = true;
  bool _decoyCall = true;
  SensitivityLevel _sensitivity = SensitivityLevel.medium;
  bool _loadedPrefs = false;

  @override
  void initState() {
    super.initState();
    _loadPreferences();
  }

  Future<void> _loadPreferences() async {
    final prefs = await SharedPreferences.getInstance();
    if (mounted) {
      setState(() {
        _podMatching = prefs.getBool(_keyPodMatching) ?? true;
        _preciseLocation = prefs.getBool(_keyPreciseLocation) ?? true;
        _decoyCall = prefs.getBool(_keyDecoyCall) ?? true;
        final sensitivityIndex = prefs.getInt(_keySensitivity) ?? SensitivityLevel.medium.index;
        _sensitivity = SensitivityLevel.values[sensitivityIndex.clamp(0, SensitivityLevel.values.length - 1)];
        _loadedPrefs = true;
      });
    }
  }

  Future<void> _saveBool(String key, bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(key, value);
  }

  Future<void> _saveInt(String key, int value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(key, value);
  }

  @override
  Widget build(BuildContext context) {
    if (!_loadedPrefs) {
      return const Center(child: CircularProgressIndicator(color: AppColors.amber));
    }

    return _Page(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Account & settings', style: AppTextStyles.display(fontSize: 19)),
          const SizedBox(height: 16),
          _Panel(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _SettingRow(
                  icon: Icons.mic_none_rounded,
                  title: 'Passive audio detection',
                  sub: 'On-device only, opt-in, active during commutes',
                  value: widget.audioEnabled,
                  onChanged: widget.onAudioToggle,
                ),
                if (widget.audioEnabled) ...[
                  const Padding(
                    padding: EdgeInsets.only(left: 28, top: 4, bottom: 8),
                    child: Text(
                      'Detection Sensitivity',
                      style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: AppColors.muted),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.only(left: 28, bottom: 12),
                    child: Row(
                      children: SensitivityLevel.values.map((lvl) {
                        final selected = _sensitivity == lvl;
                        return Padding(
                          padding: const EdgeInsets.only(right: 8),
                          child: ChoiceChip(
                            label: Text(
                              lvl.name.toUpperCase(),
                              style: AppTextStyles.mono(
                                fontSize: 10,
                                color: selected ? AppColors.bgDeep : AppColors.muted,
                              ),
                            ),
                            selected: selected,
                            selectedColor: AppColors.amber,
                            onSelected: (_) {
                              setState(() => _sensitivity = lvl);
                              widget.audioService.sensitivity = lvl;
                              _saveInt(_keySensitivity, lvl.index);
                            },
                          ),
                        );
                      }).toList(),
                    ),
                  ),
                ],
                _SettingRow(
                  icon: Icons.people_alt_outlined,
                  title: 'Auto pod matching',
                  sub: 'Match with others on similar routes and timing',
                  value: _podMatching,
                  onChanged: (v) {
                    setState(() => _podMatching = v);
                    _saveBool(_keyPodMatching, v);
                  },
                ),
                _SettingRow(
                  icon: Icons.location_on_outlined,
                  title: 'Precise location sharing',
                  sub: 'Share exact GPS instead of general area',
                  value: _preciseLocation,
                  onChanged: (v) {
                    setState(() => _preciseLocation = v);
                    _saveBool(_keyPreciseLocation, v);
                  },
                ),
                _SettingRow(
                  icon: Icons.volume_up_outlined,
                  title: 'Decoy call on SOS',
                  sub: 'Show a fake incoming call when alert triggers',
                  value: _decoyCall,
                  onChanged: (v) {
                    setState(() => _decoyCall = v);
                    _saveBool(_keyDecoyCall, v);
                  },
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          // Emergency Contacts shortcut
          _Panel(
            child: InkWell(
              onTap: widget.onNavigateContacts,
              borderRadius: BorderRadius.circular(12),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Row(
                  children: [
                    const Icon(Icons.people_alt_outlined, size: 17, color: AppColors.amber),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Manage emergency contacts', style: AppTextStyles.body(fontSize: 13)),
                          const SizedBox(height: 2),
                          Text(
                            'Add or remove contacts who get alerted on SOS',
                            style: AppTextStyles.body(fontSize: 10.5, color: AppColors.faint),
                          ),
                        ],
                      ),
                    ),
                    const Icon(Icons.chevron_right, size: 18, color: AppColors.faint),
                  ],
                ),
              ),
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
}

// ─────────────────────────────────────────────────────────────────────────────
//  Shared Layout Widgets
// ─────────────────────────────────────────────────────────────────────────────

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

class _ContactRow extends StatelessWidget {
  final String initials, name, phone, relation;
  final bool isPrimary;
  const _ContactRow({
    required this.initials,
    required this.name,
    required this.phone,
    required this.relation,
    this.isPrimary = false,
  });
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 9),
    child: Row(
      children: [
        CircleAvatar(
          radius: 17,
          backgroundColor: isPrimary
              ? AppColors.amber.withValues(alpha: 0.18)
              : AppColors.surface2,
          foregroundColor: isPrimary ? AppColors.amber : AppColors.muted,
          child: Text(
            initials,
            style: AppTextStyles.body(fontSize: 12, fontWeight: FontWeight.w700),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Text(name, style: AppTextStyles.body(fontSize: 13)),
                  if (isPrimary) ...[
                    const SizedBox(width: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: AppColors.amber.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        'Primary',
                        style: AppTextStyles.mono(fontSize: 9, color: AppColors.amber, fontWeight: FontWeight.w600),
                      ),
                    ),
                  ],
                ],
              ),
              Text(
                '$relation · $phone',
                style: AppTextStyles.body(fontSize: 10.5, color: AppColors.faint),
              ),
            ],
          ),
        ),
        const Icon(Icons.chevron_right, color: AppColors.faint, size: 16),
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
