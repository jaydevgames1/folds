import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:folds/state/app_store.dart';
import 'package:folds/main.dart';
import 'package:folds/screens/settings/dev_screen.dart';
import 'package:supabase_flutter/supabase_flutter.dart';


class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});
  @override
  State<ProfileScreen> createState() => ProfileScreenState();
}

class ProfileScreenState extends State<ProfileScreen> {
  int _tab = 0;
  int _unreadCount = 0;

  @override
  void initState() {
    super.initState();
    _loadUnreadCount();
  }

  Future<void> _loadUnreadCount() async {
    try {
      final username = AppStore.displayUsername;
      final isMod = AppStore.isModerator;
      final filters = ['recipient.eq.all', 'recipient.eq.$username'];
      if (isMod) filters.add('recipient.eq.@Moderators');
      dynamic query = Supabase.instance.client
          .from('notifications')
          .select('id')
          .or(filters.join(','));
      final lastSeen = AppStore.lastReceiptsSeen;
      if (lastSeen != null) {
        query = query.gt('created_at', lastSeen.toIso8601String());
      }
      final data = await query;
      if (mounted) setState(() => _unreadCount = (data as List).length);
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
          child: Column(
            children: [
              Row(
                children: [
                  GestureDetector(
                    onTap: () => Navigator.pop(context),
                    child: Container(
                      width: 40, height: 40,
                      decoration: const BoxDecoration(color: Color(0xFFE8E8E8), shape: BoxShape.circle),
                      child: Center(
                        child: Transform.rotate(
                          angle: 3.1416 / 4,
                          child: Container(
                            width: 14, height: 14,
                            decoration: const BoxDecoration(
                              border: Border(
                                left: BorderSide(color: Colors.black, width: 2.5),
                                bottom: BorderSide(color: Colors.black, width: 2.5),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ProfileTabBar(
                      selected: _tab,
                      onChanged: (i) => setState(() => _tab = i),
                    ),
                  ),
                  
                ],
              ),
              const SizedBox(height: 10),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  if (AppStore.isDevProfile)
                    GestureDetector(
                      onTap: () => Navigator.push(context,
                        MaterialPageRoute(builder: (_) => const DevPanelScreen())),
                      child: Container(
                        width: 40, height: 40,
                        decoration: const BoxDecoration(color: Color(0xFFE8E8E8), shape: BoxShape.circle),
                        child: const Icon(Icons.build_rounded, color: Color(0xFF2C2C2C), size: 18),
                      ),
                    )
                  else
                    const SizedBox(width: 40, height: 40),
                  GestureDetector(
                    onTap: () async {
                      await Navigator.push(context, MaterialPageRoute(builder: (_) => const ReceiptsScreen()));
                      _loadUnreadCount();
                    },
                    child: Stack(clipBehavior: Clip.none, children: [
                      Container(
                        width: 40, height: 40,
                        decoration: const BoxDecoration(color: Color(0xFFE8E8E8), shape: BoxShape.circle),
                        child: const Icon(Icons.notifications_rounded, color: Color(0xFF2C2C2C), size: 20),
                      ),
                      if (_unreadCount > 0)
                        Positioned(
                          top: -4, right: -4,
                          child: Container(
                            padding: const EdgeInsets.all(4),
                            constraints: const BoxConstraints(minWidth: 18, minHeight: 18),
                            decoration: const BoxDecoration(color: Colors.red, shape: BoxShape.circle),
                            child: Center(child: Text(_unreadCount > 99 ? '99+' : '$_unreadCount',
                              style: GoogleFonts.dmSans(fontSize: 10, fontWeight: FontWeight.w800, color: Colors.white))),
                          ),
                        ),
                    ]),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Expanded(
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 200),
                  child: _tab == 0 
                      ? const ProfileTab(key: ValueKey('profile')) 
                      : _tab == 1 
                          ? const SafeArea(
                              key: ValueKey('stats'),
                              child: StatsTab(), 
                            ) 
                          : const AchievementsTab(key: ValueKey('achievements')),
                ),
              ),

            ],
          ),
        ),
      ),
    );
  }
}

class ProfileTabBar extends StatelessWidget {
  final int selected;
  final ValueChanged<int> onChanged;
  const ProfileTabBar({required this.selected, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    const labels = ['PROFILE', 'STATS', 'ACHIEVEMENTS'];
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: const Color(0xFFEFEFEF),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        children: List.generate(labels.length, (i) {
          final isSelected = i == selected;
          return Expanded(
            child: GestureDetector(
              onTap: () => onChanged(i),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding: const EdgeInsets.symmetric(vertical: 10),
                decoration: BoxDecoration(
                  color: isSelected ? const Color(0xFFD6D6D6) : Colors.transparent,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Center(
                  child: Text(labels[i],
                    style: GoogleFonts.dmSans(
                      fontSize: 12,
                      fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
                      color: isSelected ? Colors.black : Colors.black38,
                      letterSpacing: 0.5,
                    )),
                ),
              ),
            ),
          );
        }),
      ),
    );
  }
}

