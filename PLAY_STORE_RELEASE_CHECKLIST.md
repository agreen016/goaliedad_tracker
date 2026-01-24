# Play Store Release Checklist

## ✅ Completed - Freemium Implementation

### Premium Features Implemented
1. **Team Limits**: Free users limited to 1 team, premium unlimited
2. **Game Limits**: Free users limited to 5 games per team, premium unlimited
3. **Opponent Limits**: Free users limited to 2 opponents, premium unlimited
4. **Player Limits**: Free users limited to 6 players per team, premium unlimited
5. **Lines Management**: Premium only feature
6. **PDF Export**: Premium only feature
7. **Goalie Analysis**: Premium only feature
8. **Live Game Features**: Premium only
   - Face-Off tracking
   - Penalty tracking
   - Change Line
   - Clear Line
   - Pull Goalie

### Code Cleanup Completed
- ✅ Removed debug premium screen
- ✅ Removed debug button from Teams screen
- ✅ Removed debug status banner
- ✅ Removed all DEBUG print statements from PremiumService
- ✅ Clean production-ready code

## 🔄 Next Steps - Before Publishing

### 1. Google Play Console Setup
- [ ] Change app from PAID to FREE in Google Play Console
  - Go to: Setup > Pricing & Distribution
  - Change from "Paid" to "Free"
  
### 2. In-App Purchase Setup
- [ ] Create in-app product in Google Play Console
  - Go to: Monetize > In-app products
  - Click "Create product"
  - Product ID: `premium_upgrade` (must match code)
  - Product type: One-time purchase (not subscription)
  - Set price: **$4.99 - $9.99 recommended**
  - Title: "Premium Upgrade"
  - Description: "Unlock unlimited teams, games, players, PDF export, goalie analysis, and advanced live game features"
  - Status: Active

### 3. Version Management
- [ ] Update version in pubspec.yaml
  - Current: Check your pubspec.yaml
  - Recommended: Increment version for this release (e.g., 1.1.0+2)

### 4. Build & Upload
```bash
# Clean build
cd goaliedad_tracker
flutter clean
flutter pub get

# Build release APK
flutter build apk --release

# OR Build App Bundle (recommended for Play Store)
flutter build appbundle --release
```

- [ ] Upload to Google Play Console (Closed Testing track)
- [ ] Fill out "What's new" section mentioning new freemium model

### 5. Testing Requirements
- [ ] Recruit **12 testers** (minimum)
  - Free app = easier to recruit!
  - Hockey forums, Facebook groups, friends/family
- [ ] Run closed testing for **14 days** (minimum)
- [ ] Test all premium gates as free user
- [ ] Test premium upgrade flow
- [ ] Test all features after premium purchase

### 6. Store Listing Updates
Update your store listing to mention:
- Free to download with limited features
- Premium upgrade available
- List what's included in free vs premium

Example description:
```
Track your goalie's performance with GoalieDad Tracker!

FREE FEATURES:
• 1 team with up to 6 players
• Track up to 5 games per team
• Record goals and saves
• Basic statistics

PREMIUM UPGRADE:
• Unlimited teams, games, and players
• PDF game reports
• Advanced goalie analysis with heat maps
• Line management
• Face-off and penalty tracking
• Pull goalie feature
• Unlimited opponents
```

## 🔍 Pre-Release Verification

### Testing Checklist
- [ ] Install app on clean device
- [ ] Verify free tier limits work correctly:
  - [ ] Can create 1 team
  - [ ] Blocked from creating 2nd team
  - [ ] Can add 6 players
  - [ ] Blocked from adding 7th player
  - [ ] Can create 5 games
  - [ ] Blocked from creating 6th game
  - [ ] Can create 2 opponents
  - [ ] Blocked from creating 3rd opponent
  - [ ] Lines button shows paywall
  - [ ] PDF export shows paywall
  - [ ] Goalie analysis shows paywall
  - [ ] Live game features show paywall (Face-Off, Penalty, Change/Clear Line, Pull Goalie)
- [ ] Test premium upgrade flow (will work once Play Store product is active)
- [ ] Verify all premium features unlock after upgrade

## 📱 Google Play Console Configuration

### App Content
- [ ] Content rating questionnaire completed
- [ ] Target audience selected
- [ ] Privacy policy URL provided (if collecting data)
- [ ] Data safety form completed

### Release Management
- [ ] Internal testing → Closed testing → Open testing → Production
- [ ] Start with Closed testing (12+ testers, 14+ days)

## 💡 Marketing Strategy

Since app is now FREE, you can:
1. Post in hockey parent Facebook groups
2. Share on hockey forums
3. Reach out to local hockey associations
4. Ask coaches to share with parents
5. Much easier to get 12 testers!

## 📞 Support
After publishing:
- Monitor reviews
- Respond to user feedback
- Track conversion rate (free → premium)
- Consider adjusting free tier limits based on user behavior
