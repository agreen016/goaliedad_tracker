import 'package:flutter/material.dart';
import '../services/premium_service.dart';

/// Debug screen to test premium features and toggle premium status
class DebugPremiumScreen extends StatefulWidget {
  const DebugPremiumScreen({super.key});

  @override
  State<DebugPremiumScreen> createState() => _DebugPremiumScreenState();
}

class _DebugPremiumScreenState extends State<DebugPremiumScreen> {
  bool _isPremium = false;
  int _teamCount = 0;
  Map<String, int> _gameCountByTeam = {};

  @override
  void initState() {
    super.initState();
    _loadStatus();
  }

  Future<void> _loadStatus() async {
    final isPremium = await PremiumService.isPremium();
    setState(() {
      _isPremium = isPremium;
    });
  }

  Future<void> _togglePremium() async {
    await PremiumService.setPremium(!_isPremium);
    await _loadStatus();
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(_isPremium ? '✅ Premium ENABLED' : '❌ Premium DISABLED'),
          backgroundColor: _isPremium ? Colors.green : Colors.red,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('🧪 Premium Debug'),
        backgroundColor: Colors.orange,
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            color: _isPremium ? Colors.green.shade50 : Colors.red.shade50,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  Icon(
                    _isPremium ? Icons.check_circle : Icons.cancel,
                    size: 64,
                    color: _isPremium ? Colors.green : Colors.red,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    _isPremium ? 'PREMIUM ACTIVE' : 'FREE USER',
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: _isPremium ? Colors.green.shade900 : Colors.red.shade900,
                    ),
                  ),
                  const SizedBox(height: 16),
                  ElevatedButton.icon(
                    onPressed: _togglePremium,
                    icon: Icon(_isPremium ? Icons.remove_circle : Icons.add_circle),
                    label: Text(_isPremium ? 'Disable Premium' : 'Enable Premium'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _isPremium ? Colors.red : Colors.green,
                      foregroundColor: Colors.white,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 20),
          const Text(
            'Free Tier Limits',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 10),
          _buildLimitCard(
            'Teams',
            'Max ${PremiumService.maxFreeTeams} team(s)',
            Icons.group,
            Colors.blue,
          ),
          _buildLimitCard(
            'Games per Team',
            'Max ${PremiumService.maxFreeGames} games',
            Icons.sports_hockey,
            Colors.purple,
          ),
          const SizedBox(height: 20),
          const Text(
            'Gated Features (Premium Only)',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 10),
          _buildFeatureCard(
            'PDF Export',
            'Game reports and season summaries',
            Icons.picture_as_pdf,
            Colors.red,
            'lib/screens/game_details_screen.dart',
            'Line ~258 (_exportGamePdf method)',
          ),
          _buildFeatureCard(
            'Goalie Zone Analysis',
            'Advanced shot tracking and zone analysis',
            Icons.analytics,
            Colors.orange,
            'lib/screens/team_hub_screen.dart',
            'Line ~1014 (Goalie Analysis button)',
          ),
          _buildFeatureCard(
            'Heat Maps',
            'Shot pattern visualization (inherits from analysis)',
            Icons.grid_on,
            Colors.deepOrange,
            'lib/screens/goalie_analysis_screen.dart',
            'Inside zone analysis screen',
          ),
          _buildFeatureCard(
            'Season Tracking',
            'Full season statistics and history',
            Icons.calendar_today,
            Colors.green,
            'Future implementation',
            'Not yet gated - add check if needed',
          ),
          const SizedBox(height: 20),
          const Text(
            'Creation Limits (Free Users)',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 10),
          _buildFeatureCard(
            'Create Team',
            'Limited to 1 team',
            Icons.add_circle,
            Colors.indigo,
            'lib/screens/teams_screen.dart',
            'Line ~18 (FloatingActionButton onPressed)',
          ),
          _buildFeatureCard(
            'Create Game',
            'Limited to 5 games per team',
            Icons.add_circle_outline,
            Colors.teal,
            'lib/screens/games_screen.dart',
            'Line ~46 (_addNewGame method)',
          ),
          const SizedBox(height: 20),
          Card(
            color: Colors.blue.shade50,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.info, color: Colors.blue.shade700),
                      const SizedBox(width: 8),
                      const Text(
                        'How to Test',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  const Text('1. Toggle premium OFF (red status above)'),
                  const Text('2. Try creating 2nd team → should show upgrade dialog'),
                  const Text('3. Try creating 6th game → should show upgrade dialog'),
                  const Text('4. Try exporting PDF → should show upgrade dialog'),
                  const Text('5. Try goalie analysis → should show upgrade dialog'),
                  const SizedBox(height: 12),
                  const Text('6. Toggle premium ON (green status)'),
                  const Text('7. All features should now work without limits'),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLimitCard(String title, String limit, IconData icon, Color color) {
    return Card(
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: color.withOpacity(0.2),
          child: Icon(icon, color: color),
        ),
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
        subtitle: Text(limit),
      ),
    );
  }

  Widget _buildFeatureCard(
    String title,
    String description,
    IconData icon,
    Color color,
    String file,
    String location,
  ) {
    return Card(
      child: ExpansionTile(
        leading: CircleAvatar(
          backgroundColor: color.withOpacity(0.2),
          child: Icon(icon, color: color, size: 20),
        ),
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
        subtitle: Text(description, style: const TextStyle(fontSize: 12)),
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.code, size: 16, color: Colors.grey.shade600),
                    const SizedBox(width: 8),
                    const Text('Code Location:', style: TextStyle(fontWeight: FontWeight.bold)),
                  ],
                ),
                const SizedBox(height: 4),
                Text(file, style: TextStyle(fontSize: 12, color: Colors.blue.shade700)),
                const SizedBox(height: 4),
                Text(location, style: TextStyle(fontSize: 11, color: Colors.grey.shade600)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
