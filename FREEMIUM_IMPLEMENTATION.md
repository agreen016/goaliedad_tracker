# Goaliedad Tracker - Freemium Implementation Guide

## Overview
The app has been converted to a **FREE** app with **Premium Upgrade** option (one-time purchase).

## Free Tier Limitations
**Free users can:**
- ✅ Create **1 team** only
- ✅ Record **goals and saves**
- ✅ Track up to **5 games** per team
- ✅ View basic game statistics

**Premium users get:**
- ✨ **Unlimited teams**
- ✨ **Unlimited games**
- ✨ **PDF reports** (game and season reports)
- ✨ **Goalie zone analysis** (advanced shot tracking)
- ✨ **Heat maps** and zone visualization
- ✨ **Full season statistics**

## What Was Implemented

### 1. New Files Created
- `lib/services/premium_service.dart` - Manages premium status and feature checks
- `lib/widgets/upgrade_dialog.dart` - Displays upgrade prompts
- `lib/screens/purchase_screen.dart` - In-app purchase screen

### 2. Modified Files
- `pubspec.yaml` - Added `in_app_purchase: ^3.1.13` dependency
- `lib/screens/teams_screen.dart` - Added team creation limit check
- `lib/screens/games_screen.dart` - Added game creation limit check
- `lib/screens/game_details_screen.dart` - Added PDF export gate
- `lib/screens/team_hub_screen.dart` - Added goalie analysis gate

### 3. Premium Checks Added
All premium features are gated with checks like:
```dart
if (!await PremiumService.canAccessFeature()) {
  showUpgradeDialog(context, ...);
  return;
}
```

## Next Steps - IMPORTANT!

### Step 1: Install Dependencies
```bash
cd goaliedad_tracker
flutter pub get
```

### Step 2: Change App to FREE in Google Play Console
1. Go to [Google Play Console](https://play.google.com/console)
2. Select your app
3. Go to **Setup → Pricing & Distribution**
4. Change from **Paid** to **Free**
5. Save changes

⚠️ **WARNING**: Once you change to free, you can NEVER change back to paid!

### Step 3: Create In-App Product in Google Play Console
1. Go to **Monetize with Play → In-app products**
2. Click **Create product**
3. Set up your product:
   - **Product ID**: `premium_upgrade` (must match the ID in `purchase_screen.dart` line 27)
   - **Name**: "Premium Upgrade" or "Full Access"
   - **Description**: "Unlock all premium features including unlimited teams, games, PDF reports, and advanced analytics"
   - **Status**: Active
   - **Price**: $4.99 to $9.99 (recommended range for niche sports apps)
   - **Type**: One-time (non-consumable)
4. Save and activate the product

### Step 4: Update Product ID (if needed)
If you use a different product ID in Google Play Console, update line 27 in:
`lib/screens/purchase_screen.dart`
```dart
static const String _productId = 'your_product_id_here';
```

### Step 5: Test the Implementation

#### Testing In-App Purchases
1. **Add Test Accounts**:
   - Go to Google Play Console → Setup → License testing
   - Add your Gmail account as a license tester
   - License testers can make test purchases without being charged

2. **Build and Test**:
   ```bash
   cd goaliedad_tracker
   flutter build appbundle
   ```

3. **Upload to Closed Testing**:
   - Upload the new .aab file to your closed testing track
   - Test the free features (1 team, 5 games)
   - Test hitting the limits and seeing upgrade prompts
   - Test the purchase flow (as a license tester, you won't be charged)

### Step 6: Verify All Features Work
- [ ] Can create 1 team as free user
- [ ] Cannot create 2nd team (shows upgrade prompt)
- [ ] Can create up to 5 games
- [ ] Cannot create 6th game (shows upgrade prompt)
- [ ] PDF export shows upgrade prompt
- [ ] Goalie analysis shows upgrade prompt
- [ ] Purchase screen loads correctly
- [ ] After "purchasing" (test), all features unlock
- [ ] Premium status persists after app restart

### Step 7: Get Your 12 Testers for FREE!
Now that your app is **FREE**, it's much easier:
1. Post in hockey parent Facebook groups
2. Post in youth hockey forums
3. Ask local hockey rinks to share with goalies/parents
4. Family and friends with Android can test for free
5. You only need them to:
   - Install the app
   - Try tracking a game or two
   - Stay opted-in for 14 days

They don't have to pay anything since the app is now free!

### Step 8: Testing Timeline
- Day 1: Upload free version to closed testing
- Day 1: Get 12+ testers to opt-in
- Day 14: All 12 testers still opted-in
- Day 14: Apply for production access in Google Play Console
- Day 21 (approx): Google approves and you can publish!

## Monetization Strategy

### Recommended Pricing
- **$4.99** - Conservative, easier to convert testers
- **$7.99** - Mid-range, balanced value
- **$9.99** - Premium pricing (only if app has proven value)

### Expected Conversion Rates
- Free app typically gets **100-1000x more downloads** than paid
- Conversion to premium: **2-5%** of engaged users
- If you get 1000 free downloads:
  - 20-50 purchases at $7.99 = **$160-$400**
  - vs. paid at $2.99 with maybe 20 downloads = **$60**

## Important Notes

### For Development
- The purchase flow is fully implemented
- Test with license testing accounts first
- All premium checks are in place

### For Google Play Submission
- App is now FREE (no barrier for testers)
- In-app purchase configured
- Testing requirements: 12 testers for 14 days
- Much easier to recruit testers now!

### For Future Updates
- Can adjust free limits in `premium_service.dart`
- Can add more premium features easily
- Can add analytics to track conversion rates

## Quick Reference

### Free Tier Limits (can be adjusted)
```dart
// In lib/services/premium_service.dart
static const int maxFreeTeams = 1;
static const int maxFreeGames = 5;
```

### Add New Premium Feature
```dart
// 1. Add check method to PremiumService
static Future<bool> canAccessNewFeature() async {
  return await isPremium();
}

// 2. In your screen
if (!await PremiumService.canAccessNewFeature()) {
  showUpgradeDialog(context,
    title: 'Premium Feature',
    message: 'This feature requires Premium...',
  );
  return;
}
```

## Support

If you encounter issues:
1. Check Google Play Console for error messages
2. Verify product ID matches between code and console
3. Ensure license testing is set up
4. Test on a physical Android device (emulators can have issues with IAP)

## Success Checklist
- [ ] Dependencies installed (`flutter pub get`)
- [ ] App changed to FREE in Play Console
- [ ] In-app product created with ID `premium_upgrade`
- [ ] Product is Active and priced
- [ ] License testing email added
- [ ] Build uploaded to closed testing
- [ ] Tested free limitations (1 team, 5 games)
- [ ] Tested upgrade prompts appear
- [ ] Tested purchase flow works
- [ ] Tested premium features unlock after purchase
- [ ] Ready to recruit 12 testers!

---

Good luck with your closed testing! The free app will make it MUCH easier to get your 12 testers. 🏒🥅
