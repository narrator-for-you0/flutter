import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_cropper/image_cropper.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';

import '../providers/user_proverder.dart';
import '../themes/app_colors.dart';

/// First-launch setup: a welcome page, then name / course / avatar.
/// Once finished, [UserProfileProvider.hasOnboarded] flips to true and
/// main.dart swaps this screen for the main app.
class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  static const _green = Color(0xFF00C853);
  static Color get _greenSoft => AppColors.greenSoft;
  static Color get _dark => AppColors.text;
  static Color get _muted => AppColors.muted;

  static const _avatarOptions = ['👨‍💻', '👩‍💻', '🎓', '📚', '⚡', '💻', '🎒'];

  final _pageController = PageController();
  final _nameController = TextEditingController();
  final _infoController = TextEditingController();

  int _page = 0;
  String _emoji = '🎓';
  String? _photoPath; // cropped temp file; copied into app storage on finish
  bool _saving = false;

  bool get _canFinish => _nameController.text.trim().isNotEmpty && !_saving;
  bool get _canCrop => Platform.isAndroid || Platform.isIOS;

  @override
  void dispose() {
    _pageController.dispose();
    _nameController.dispose();
    _infoController.dispose();
    super.dispose();
  }

  void _goToPage(int page) {
    FocusScope.of(context).unfocus();
    setState(() => _page = page);
    _pageController.animateToPage(
      page,
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeOut,
    );
  }

  // ---------------------------------------------------------------- photo
  /// Square crop screen. Returns the cropped path, or null if cancelled.
  /// On desktop (no cropper available) the image is returned uncropped.
  Future<String?> _cropPhoto(String sourcePath) async {
    if (!_canCrop) return sourcePath;
    try {
      final cropped = await ImageCropper().cropImage(
        sourcePath: sourcePath,
        aspectRatio: const CropAspectRatio(ratioX: 1, ratioY: 1),
        maxWidth: 512,
        maxHeight: 512,
        compressQuality: 85,
        uiSettings: [
          AndroidUiSettings(
            toolbarTitle: 'Crop photo',
            toolbarColor: _green,
            toolbarWidgetColor: Colors.white,
            activeControlsWidgetColor: _green,
            cropStyle: CropStyle.circle,
            initAspectRatio: CropAspectRatioPreset.square,
            lockAspectRatio: true,
          ),
          IOSUiSettings(
            title: 'Crop photo',
            cropStyle: CropStyle.circle,
            aspectRatioLockEnabled: true,
            resetAspectRatioEnabled: false,
            aspectRatioPickerButtonHidden: true,
          ),
        ],
      );
      return cropped?.path;
    } catch (e) {
      debugPrint('Could not crop image: $e');
      return null;
    }
  }

  Future<void> _pickPhoto() async {
    try {
      final picked = await ImagePicker().pickImage(source: ImageSource.gallery);
      if (picked == null) return;
      final cropped = await _cropPhoto(picked.path);
      if (cropped == null || !mounted) return;
      setState(() => _photoPath = cropped);
    } catch (e) {
      debugPrint('Could not pick image: $e');
    }
  }

  Future<void> _recropPhoto() async {
    final current = _photoPath;
    if (current == null) return;
    final cropped = await _cropPhoto(current);
    if (cropped == null || !mounted) return;
    setState(() => _photoPath = cropped);
  }

  void _showPhotoOptions() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (sheetCtx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.photo_library_outlined, color: _green),
              title: const Text('Choose photo'),
              onTap: () {
                Navigator.pop(sheetCtx);
                _pickPhoto();
              },
            ),
            if (_photoPath != null && _canCrop)
              ListTile(
                leading: const Icon(Icons.crop, color: _green),
                title: const Text('Adjust crop'),
                onTap: () {
                  Navigator.pop(sheetCtx);
                  _recropPhoto();
                },
              ),
            if (_photoPath != null)
              ListTile(
                leading: const Icon(
                  Icons.delete_outline,
                  color: Color(0xFFDC2626),
                ),
                title: const Text('Remove photo'),
                onTap: () {
                  Navigator.pop(sheetCtx);
                  setState(() => _photoPath = null);
                },
              ),
          ],
        ),
      ),
    );
  }

  // --------------------------------------------------------------- finish
  Future<void> _finish() async {
    if (!_canFinish) return;
    setState(() => _saving = true);

    final provider = context.read<UserProfileProvider>();
    final messenger = ScaffoldMessenger.of(context);

    final photoOk = await provider.completeOnboarding(
      name: _nameController.text,
      studentInfo: _infoController.text,
      avatarEmoji: _emoji,
      photoPath: _photoPath,
    );

    // main.dart swaps this screen out as soon as onboarding completes, so
    // don't touch this State afterwards.
    if (!photoOk) {
      messenger.showSnackBar(
        const SnackBar(
          content: Text(
            'Welcome! Your photo could not be saved. You can add it again from your profile.',
          ),
        ),
      );
    }
  }

  // ------------------------------------------------------------------ UI
  @override
  Widget build(BuildContext context) {
    AppColors.sync(context);
    return Scaffold(
      backgroundColor: AppColors.bg,
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: PageView(
                controller: _pageController,
                physics: const NeverScrollableScrollPhysics(),
                children: [_welcomePage(), _setupPage()],
              ),
            ),
            Padding(
              padding: const EdgeInsets.only(bottom: 16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(2, (i) {
                  final active = i == _page;
                  return AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    margin: const EdgeInsets.symmetric(horizontal: 3),
                    width: active ? 20 : 8,
                    height: 8,
                    decoration: BoxDecoration(
                      color: active ? _green : AppColors.track,
                      borderRadius: BorderRadius.circular(4),
                    ),
                  );
                }),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _welcomePage() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 28),
      child: Column(
        children: [
          const Spacer(flex: 2),
          TweenAnimationBuilder<double>(
            tween: Tween(begin: 0.6, end: 1),
            duration: const Duration(milliseconds: 700),
            curve: Curves.elasticOut,
            builder: (context, scale, child) => Opacity(
              opacity: scale.clamp(0.0, 1.0),
              child: Transform.scale(scale: scale, child: child),
            ),
            child: Container(
              width: double.infinity,
              height: 150,
              clipBehavior: Clip.antiAlias,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(24),
                boxShadow: [
                  BoxShadow(
                    color: _green.withValues(alpha: 0.25),
                    blurRadius: 24,
                    offset: const Offset(0, 10),
                  ),
                ],
              ),
              child: Image.asset(
                'assets/images/gastogo_logo.png',
                fit: BoxFit.cover,
              ),
            ),
          ),
          const SizedBox(height: 28),
          Text(
            'Make your allowance last until the next one.',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: _dark,
              height: 1.3,
            ),
          ),
          const SizedBox(height: 32),
          _feature(
            Icons.receipt_long_outlined,
            'Log what you spend in seconds',
          ),
          _feature(Icons.speed, 'Stay under a daily limit'),
          _feature(Icons.savings_outlined, 'Keep what you don\'t spend'),
          const Spacer(flex: 3),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () => _goToPage(1),
              style: ElevatedButton.styleFrom(
                backgroundColor: _green,
                elevation: 0,
                padding: const EdgeInsets.symmetric(vertical: 15),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
              child: const Text(
                'Get started',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 15,
                ),
              ),
            ),
          ),
          const SizedBox(height: 20),
        ],
      ),
    );
  }

  Widget _feature(IconData icon, String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: _greenSoft,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: _green, size: 20),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Text(
              text,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: _dark,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _setupPage() {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(28, 12, 28, 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Align(
            alignment: Alignment.centerLeft,
            child: IconButton(
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(),
              icon: Icon(Icons.arrow_back, color: _muted),
              onPressed: () => _goToPage(0),
            ),
          ),
          const SizedBox(height: 12),
          Text(
            'Set up your profile',
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.bold,
              color: _dark,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'You can change all of this later.',
            style: TextStyle(fontSize: 13, color: _muted),
          ),
          const SizedBox(height: 24),
          Center(
            child: GestureDetector(
              onTap: _showPhotoOptions,
              child: Stack(
                children: [
                  CircleAvatar(
                    radius: 48,
                    backgroundColor: _greenSoft,
                    backgroundImage: _photoPath != null
                        ? FileImage(File(_photoPath!))
                        : null,
                    child: _photoPath == null
                        ? Text(_emoji, style: const TextStyle(fontSize: 40))
                        : null,
                  ),
                  Positioned(
                    right: 0,
                    bottom: 0,
                    child: Container(
                      padding: const EdgeInsets.all(7),
                      decoration: const BoxDecoration(
                        color: _green,
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.camera_alt,
                        size: 15,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 20),
          Text(
            'PICK AN AVATAR',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.bold,
              color: _muted,
              letterSpacing: 0.5,
            ),
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: _avatarOptions.map((emoji) {
              final selected = _photoPath == null && emoji == _emoji;
              return GestureDetector(
                onTap: () => setState(() {
                  _emoji = emoji;
                  _photoPath =
                      null; // choosing an emoji switches back from a photo
                }),
                child: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: selected ? _greenSoft : AppColors.card,
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: selected ? _green : Colors.transparent,
                      width: 2,
                    ),
                  ),
                  child: Text(emoji, style: const TextStyle(fontSize: 20)),
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: 24),
          TextField(
            controller: _nameController,
            textCapitalization: TextCapitalization.words,
            textInputAction: TextInputAction.next,
            onChanged: (_) => setState(() {}),
            decoration: InputDecoration(
              labelText: 'Your name',
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 14,
                vertical: 14,
              ),
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _infoController,
            textCapitalization: TextCapitalization.words,
            textInputAction: TextInputAction.done,
            decoration: InputDecoration(
              labelText: 'Course / school (optional)',
              hintText: 'e.g. BSIT Student',
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 14,
                vertical: 14,
              ),
            ),
          ),
          const SizedBox(height: 28),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _canFinish ? _finish : null,
              style: ElevatedButton.styleFrom(
                backgroundColor: _green,
                disabledBackgroundColor: AppColors.trackDisabled,
                elevation: 0,
                padding: const EdgeInsets.symmetric(vertical: 15),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
              child: _saving
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Text(
                      "Let's go",
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 15,
                      ),
                    ),
            ),
          ),
        ],
      ),
    );
  }
}
