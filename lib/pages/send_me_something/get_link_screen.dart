import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:aurogram/services/anonymous_message_service.dart';
import 'package:aurogram/services/share/share_ui.dart';
import 'package:aurogram/utils/theme/app_theme.dart';
import 'package:aurogram/widgets/dialogs/login_bottom_sheet.dart';
import 'package:aurogram/widgets/universal/transparent_toolbox.dart';
import 'package:aurogram/services/anonymous_message_settings_service.dart';
import 'package:aurogram/pages/helpers/user_settings.dart';

class SecretMessagesGetLinkScreen extends StatefulWidget {
  const SecretMessagesGetLinkScreen({super.key});

  @override
  State<SecretMessagesGetLinkScreen> createState() =>
      _SecretMessagesGetLinkScreenState();
}

class _SecretMessagesGetLinkScreenState
    extends State<SecretMessagesGetLinkScreen> {
  final _service = AnonymousMessageService();
  String? _link;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadLink();
  }

  Future<void> _loadLink() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      setState(() => _loading = false);
      return;
    }

    try {
      final slug = await _service.getOrCreateSlug();
      setState(() {
        _link = _service.buildShareLink(slug);
        _loading = false;
      });
    } catch (e) {
      _service.logError('Failed to generate link', e);
      setState(() => _loading = false);
    }
  }

  void _copyLink() async {
    if (_link == null) return;
    await Clipboard.setData(ClipboardData(text: _link!));
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Text('Link copied'),
        backgroundColor: AppTheme.primaryColor,
      ),
    );
  }

  Future<void> _shareLink() async {
    if (_link == null) return;
    await ShareUi.showShareOptions(
      context: context,
      shareText: _service.buildSharePrefill(),
      shareUrl: _link,
      contentType: 'Anonymous messages',
    );
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      return Scaffold(
        backgroundColor: AppTheme.scaffoldColor,
        appBar: AppBar(
          title: const Text('Anonymous messages'),
          backgroundColor: AppTheme.scaffoldColor,
          elevation: 0,
        ),
        body: Center(
          child: ElevatedButton(
            onPressed: () => showLoginBottomSheet(context),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.primaryColor,
            ),
            child: const Text('Sign in to get your link'),
          ),
        ),
      );
    }

    return FutureBuilder<bool>(
      future: AnonymousMessageSettingsService().isEnabled(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return Scaffold(
            backgroundColor: AppTheme.scaffoldColor,
            appBar: AppBar(
              title: const Text('Anonymous messages'),
              backgroundColor: AppTheme.scaffoldColor,
              elevation: 0,
            ),
            body: const Center(child: CircularProgressIndicator()),
          );
        }

        final isEnabled = snapshot.data ?? true;

        if (!isEnabled) {
          return Scaffold(
            backgroundColor: AppTheme.scaffoldColor,
            appBar: AppBar(
              title: const Text('Anonymous messages'),
              backgroundColor: AppTheme.scaffoldColor,
              elevation: 0,
            ),
            body: SafeArea(
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.mail_outline,
                      size: 64,
                      color: AppTheme.primaryColor.withValues(alpha: 0.5),
                    ),
                    const SizedBox(height: 24),
                    Text(
                      'Anonymous messages are disabled',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w600,
                        color: AppTheme.textColor,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'Enable anonymous messages in Settings > Privacy to receive messages.',
                      style: TextStyle(
                        fontSize: 16,
                        color: AppTheme.textSecondaryColor,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 32),
                    ElevatedButton(
                      onPressed: () {
                        Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (context) => const UserSettingsPage(),
                          ),
                        );
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.primaryColor,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 32,
                          vertical: 14,
                        ),
                      ),
                      child: const Text('Open Settings'),
                    ),
                  ],
                ),
              ),
            ),
          );
        }

        return Scaffold(
          backgroundColor: AppTheme.scaffoldColor,
          appBar: AppBar(
            title: const Text('Anonymous messages'),
            backgroundColor: AppTheme.scaffoldColor,
            elevation: 0,
          ),
          body: SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: _loading
                  ? const Center(child: CircularProgressIndicator())
                  : Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Share your link. Anyone with the link can send you an anonymous message.',
                          style: TextStyle(
                            fontSize: 16,
                            color: AppTheme.textSecondaryColor,
                          ),
                        ),
                        const SizedBox(height: 12),
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: AppTheme.primaryColor.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                              color: AppTheme.primaryColor.withValues(alpha: 0.2),
                            ),
                          ),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Icon(
                                Icons.info_outline,
                                size: 18,
                                color: AppTheme.primaryColor,
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  'Safety tip: Only share your link with people you know. You can report or block any inappropriate messages.',
                                  style: TextStyle(
                                    fontSize: 13,
                                    color: AppTheme.primaryColor.withValues(alpha: 0.8),
                                    height: 1.4,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 16),
                        TransparentToolbox.buildCard(
                          context: context,
                          padding: const EdgeInsets.all(16),
                          child: Text(
                            _link ?? 'Link unavailable',
                            style: TextStyle(
                              color: AppTheme.textColor,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                        const SizedBox(height: 16),
                        Row(
                          children: [
                            Expanded(
                              child: ElevatedButton(
                                onPressed: _copyLink,
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: AppTheme.primaryColor,
                                  padding: const EdgeInsets.symmetric(vertical: 14),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                ),
                                child: const Text('Copy link'),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: OutlinedButton(
                                onPressed: _shareLink,
                                style: OutlinedButton.styleFrom(
                                  padding: const EdgeInsets.symmetric(vertical: 14),
                                  side: BorderSide(
                                    color: AppTheme.primaryColor,
                                  ),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                ),
                                child: Text(
                                  'Share',
                                  style: TextStyle(
                                    color: AppTheme.primaryColor,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
            ),
          ),
        );
      },
    );
  }
}
