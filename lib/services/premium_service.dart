import 'package:hive/hive.dart';
import '../models/team.dart';
import '../models/game.dart';
import '../models/opponent.dart';
import '../models/player.dart';

class PremiumService {
  static const String _premiumKey = 'isPremium';
  static const int maxFreeTeams = 1;
  static const int maxFreeGames = 5;
  static const int maxFreeOpponents = 2;
  static const int maxFreePlayers = 6;

  static Future<bool> isPremium() async {
    try {
      final box = Hive.box('settings');
      final isPremium = box.get(_premiumKey);
      return isPremium == true;
    } catch (_) {
      return false;
    }
  }

  static Future<void> setPremium(bool value) async {
    try {
      final box = Hive.box('settings');
      await box.put(_premiumKey, value);
    } catch (_) {}
  }

  static Future<bool> canCreateTeam() async {
    final premium = await isPremium();
    if (premium) return true;
    
    try {
      final teamBox = Hive.box<Team>('teams');
      final currentCount = teamBox.length;
      final canCreate = currentCount < maxFreeTeams;
      return canCreate;
    } catch (e) {
      return false;
    }
  }

  static Future<bool> canCreateGame(String teamId) async {
    if (await isPremium()) return true;
    
    try {
      final gameBox = Hive.box<Game>('games');
      final teamGames = gameBox.values.where((game) => game.teamId == teamId).length;
      return teamGames < maxFreeGames;
    } catch (e) {
      return false;
    }
  }

  static int getTeamGameCount(String teamId) {
    try {
      final gameBox = Hive.box<Game>('games');
      return gameBox.values.where((game) => game.teamId == teamId).length;
    } catch (_) {
      return 0;
    }
  }

  static Future<bool> canExportPDF() async {
    return await isPremium();
  }

  static Future<bool> canAccessGoalieAnalysis() async {
    return await isPremium();
  }

  static Future<bool> canAccessZoneTracking() async {
    return await isPremium();
  }

  static Future<bool> canAccessSeasonTracking() async {
    return await isPremium();
  }

  static Future<int> getRemainingFreeGames(String teamId) async {
    if (await isPremium()) return -1;
    final used = getTeamGameCount(teamId);
    return (maxFreeGames - used).clamp(0, maxFreeGames);
  }

  static Future<int> getRemainingFreeTeams() async {
    if (await isPremium()) return -1;
    final teamBox = Hive.box<Team>('teams');
    return (maxFreeTeams - teamBox.length).clamp(0, maxFreeTeams);
  }

  static Future<bool> canCreateOpponent() async {
    if (await isPremium()) return true;
    
    try {
      final opponentBox = Hive.box<Opponent>('opponents');
      final currentCount = opponentBox.length;
      return currentCount < maxFreeOpponents;
    } catch (e) {
      return false;
    }
  }

  static int getOpponentCount() {
    try {
      final opponentBox = Hive.box<Opponent>('opponents');
      return opponentBox.length;
    } catch (_) {
      return 0;
    }
  }

  static Future<int> getRemainingFreeOpponents() async {
    if (await isPremium()) return -1;
    final opponentBox = Hive.box<Opponent>('opponents');
    return (maxFreeOpponents - opponentBox.length).clamp(0, maxFreeOpponents);
  }

  static Future<bool> canCreatePlayer(String teamId) async {
    if (await isPremium()) return true;
    
    try {
      final playerBox = Hive.box<Player>('players');
      final teamPlayerCount = playerBox.values.where((p) => p.teamId == teamId).length;
      return teamPlayerCount < maxFreePlayers;
    } catch (e) {
      return false;
    }
  }

  static int getPlayerCount(String teamId) {
    try {
      final playerBox = Hive.box<Player>('players');
      return playerBox.values.where((p) => p.teamId == teamId).length;
    } catch (_) {
      return 0;
    }
  }

  static Future<int> getRemainingFreePlayers(String teamId) async {
    if (await isPremium()) return -1;
    final used = getPlayerCount(teamId);
    return (maxFreePlayers - used).clamp(0, maxFreePlayers);
  }
}
