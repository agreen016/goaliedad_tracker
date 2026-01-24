import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import '../models/team.dart';
import 'create_team_screen.dart';
import 'team_hub_screen.dart';
import '../widgets/team_card.dart'; // New import

class TeamsScreen extends StatelessWidget {
  const TeamsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Teams')),
      body: const TeamList(),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => const CreateTeamScreen()),
          );
        },
        icon: const Icon(Icons.add),
        label: const Text('Create New Team'),
      ),
    );
  }
}

class TeamList extends StatelessWidget {
  const TeamList({super.key});

  @override
  Widget build(BuildContext context) {
    final Box<Team> teamBox = Hive.box<Team>('teams');

    return ValueListenableBuilder(
      valueListenable: teamBox.listenable(),
      builder: (context, Box<Team> box, _) {
        if (box.isEmpty) {
          return const Center(child: Text('No teams yet'));
        }

        return ListView.builder(
          itemCount: box.length,
          itemBuilder: (context, index) {
            final team = box.getAt(index);
            if (team == null) return const SizedBox();

            return TeamCard(
              team: team,
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => TeamHubScreen(team: team)),
                );
              },
            );
          },
        );
      },
    );
  }
}
