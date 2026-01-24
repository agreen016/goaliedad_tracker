# Premium Paywall Locations - Quick Reference

## How to Test
1. **Run the app**
2. **Tap the bug icon (🐛)** in the top-right of the Teams screen
3. **Toggle Premium ON/OFF** to test free vs premium behavior

## Current Paywall Locations

### 1. Team Creation Limit
**File:** `lib/screens/teams_screen.dart`  
**Line:** ~18-40 (FloatingActionButton onPressed)  
**Limit:** 1 team for free users  
**Code:**
```dart
if (await PremiumService.canCreateTeam()) {
  // Allow creation
} else {
  showUpgradeDialog(...); // Block
}
```
**Test:** Try creating a 2nd team as free user

---

### 2. Game Creation Limit
**File:** `lib/screens/games_screen.dart`  
**Line:** ~46-66 (_addNewGame method)  
**Limit:** 5 games per team for free users  
**Code:**
```dart
if (await PremiumService.canCreateGame(widget.team.id)) {
  // Allow creation
} else {
  showUpgradeDialog(...); // Block
}
```
**Test:** Create 5 games, then try creating 6th game

---

### 3. PDF Export
**File:** `lib/screens/game_details_screen.dart`  
**Line:** ~258-275 (_exportGamePdf method)  
**Limit:** Premium only  
**Code:**
```dart
if (!await PremiumService.canExportPDF()) {
  showUpgradeDialog(...);
  return;
}
// Continue with export...
```
**Test:** Try exporting a game PDF as free user

---

### 4. Goalie Zone Analysis
**File:** `lib/screens/team_hub_screen.dart`  
**Line:** ~1014-1039 (Goalie Analysis button onPressed)  
**Limit:** Premium only  
**Code:**
```dart
if (!await PremiumService.canAccessGoalieAnalysis()) {
  showUpgradeDialog(...);
  return;
}
Navigator.push(...); // Navigate to analysis
```
**Test:** Try accessing Goalie Zone Analysis as free user

---

## Features NOT Currently Gated

These features work for both free and premium users. Add gates if you want to restrict them:

### Season Statistics
**Location:** Team Hub screen - Stats tab  
**Currently:** Available to all users  
**To Gate:** Add check before displaying season stats:
```dart
if (!await PremiumService.canAccessSeasonTracking()) {
  // Show upgrade message
  return;
}
```

### Player Management
**Location:** Players screen, Line editor  
**Currently:** Available to all users  
**Could Gate:** Limit number of players per team for free users

### Live Game Tracker
**Location:** `lib/screens/live_game_tracker_screen.dart`  
**Currently:** Available to all users (but limited by game count)  
**Note:** Already indirectly limited since you can only track 5 games

### Heat Maps
**Location:** Inside Goalie Analysis Screen  
**Currently:** Gated indirectly (can't access analysis screen without premium)  
**Note:** No additional gate needed since analysis screen is premium-only

---

## How to Add More Restrictions

### Example 1: Limit Players per Team (Free = 10 players)

1. **Add to PremiumService** (`lib/services/premium_service.dart`):
```dart
static const int maxFreePlayers = 10;

static Future<bool> canAddPlayer(String teamId) async {
  if (await isPremium()) return true;
  
  final playerBox = Hive.box('players');
  final teamPlayers = playerBox.values.where((p) => p.teamId == teamId).length;
  return teamPlayers < maxFreePlayers;
}
```

2. **Add check in create_player_screen.dart** (wherever player is created):
```dart
if (!await PremiumService.canAddPlayer(widget.team.id)) {
  showUpgradeDialog(
    context,
    title: 'Player Limit Reached',
    message: 'Free users can add up to 10 players per team. Upgrade for unlimited players!',
  );
  return;
}
```

---

### Example 2: Gate Season Stats View

In `lib/screens/team_hub_screen.dart`, find where season stats are displayed and add:

```dart
// Before showing stats
final canView = await PremiumService.canAccessSeasonTracking();
if (!canView) {
  return Center(
    child: Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(Icons.lock, size: 64, color: Colors.grey),
        SizedBox(height: 16),
        Text('Season Statistics are a Premium Feature'),
        SizedBox(height: 8),
        ElevatedButton(
          onPressed: () => Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => PurchaseScreen()),
          ),
          child: Text('Upgrade to Premium'),
        ),
      ],
    ),
  );
}
```

---

### Example 3: Limit Opponents

Add to PremiumService:
```dart
static const int maxFreeOpponents = 5;

static Future<bool> canAddOpponent() async {
  if (await isPremium()) return true;
  
  final opponentBox = Hive.box('opponents');
  return opponentBox.length < maxFreeOpponents;
}
```

---

## Testing Checklist

Use the Debug Premium Screen (bug icon) to toggle between free/premium:

**As FREE user (Premium OFF):**
- [ ] Can create 1 team
- [ ] CANNOT create 2nd team (shows upgrade dialog)
- [ ] Can create up to 5 games
- [ ] CANNOT create 6th game (shows upgrade dialog)
- [ ] CANNOT export PDF (shows upgrade dialog)
- [ ] CANNOT access goalie analysis (shows upgrade dialog)

**As PREMIUM user (Premium ON):**
- [ ] Can create unlimited teams
- [ ] Can create unlimited games
- [ ] Can export PDFs
- [ ] Can access goalie analysis
- [ ] All features work without restrictions

---

## Adjusting Free Tier Limits

Edit `lib/services/premium_service.dart`:

```dart
// Change these constants to adjust limits
static const int maxFreeTeams = 1;     // Change to 2, 3, etc.
static const int maxFreeGames = 5;     // Change to 3, 10, etc.
```

**Recommended limits for testing:**
- More restrictive: 1 team, 3 games (pushes users to upgrade faster)
- Current: 1 team, 5 games (good balance)
- More generous: 2 teams, 10 games (lets users really try it)

---

## Quick Debug Commands

Open debug screen: **Tap bug icon in Teams screen**

Toggle premium via code (for automated testing):
```dart
// Make user premium
await PremiumService.setPremium(true);

// Make user free
await PremiumService.setPremium(false);

// Check status
bool isPremium = await PremiumService.isPremium();
```
