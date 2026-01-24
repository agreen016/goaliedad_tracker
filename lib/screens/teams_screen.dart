import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import '../models/team.dart';
import 'create_team_screen.dart';
import 'team_hub_screen.dart';
import '../widgets/team_card.dart'; // New import
import '../services/premium_service.dart';
import '../widgets/upgrade_dialog.dart';

class TeamsScreen extends StatelessWidget {
  const TeamsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Teams'),
      ),
      body: const TeamList(),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () async {
          // Check if user can create more teams
          if (await PremiumService.canCreateTeam()) {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => const CreateTeamScreen()),
            );
          } else {
            // Show upgrade dialog
            showUpgradeDialog(
              context,
              title: 'Team Limit Reached',
              message: 'Free users can create 1 team. Upgrade to Premium to create unlimited teams!',
              onUpgrade: () {
                // TODO: Navigate to purchase screen
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Purchase screen coming soon!')),
                );
              },
            );
          }
        },
        icon: const Icon(Icons.add),
        label: const Text('Create New Team'),
      ),
    );
  }
}

class TeamList extends StatefulWidget {
  const TeamList({super.key});

  @override
  State<TeamList> createState() => _TeamListState();
}

class _TeamListState extends State<TeamList> {
  void _deleteTeam(Team team) {
    team.delete();
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final Box<Team> teamBox = Hive.box<Team>('teams');

    return ValueListenableBuilder(
      valueListenable: teamBox.listenable(),
      builder: (context, Box<Team> box, _) {
        if (box.values.isEmpty) {
          return const Center(child: Text('No teams yet'));
        }

        return ListView.builder(
          itemCount: box.length,
          itemBuilder: (context, index) {
            final team = box.getAt(index);
            if (team == null) return const SizedBox();

            return Dismissible(
              key: Key(team.id),
              direction: DismissDirection.endToStart,
              background: Container(
                color: Colors.red,
                alignment: Alignment.centerRight,
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: const Icon(Icons.delete, color: Colors.white),
              ),
              onDismissed: (_) => _deleteTeam(team),
              child: TeamCard(
                team: team,
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => TeamHubScreen(team: team)),
                  );
                },
              ),
            );
          },
        );
      },
    );
  }
}
