# Game Center setup

The game keeps its own progress (coins, stars, achievements) on the device and
mirrors it to Game Center when the player is signed in. For the Game Center side
to work, create these in **App Store Connect → your app → Services → Game Center**
(the app record must use the bundle ID `com.giusscos.ThumbestWar`).

The IDs below must match `ThumbWar/Game/Achievements.swift` exactly.

## Leaderboards

All: **Classic**, score format **Integer**, sort **High to Low**, keep the **best score**.

| Leaderboard ID | Name |
| --- | --- |
| `thumbwar.leaderboard.stars` | Thumb Tour Stars |
| `thumbwar.leaderboard.pins` | Lifetime Pins |
| `thumbwar.leaderboard.streak` | Best Win Streak |

## Achievements

Game Center allows 1000 points in total and at most 100 per achievement; the
points below add up to 965 and follow the in-game coin rewards. Each achievement
has a 512×512 badge image (drawn in the game's puffy style when they were created
in App Store Connect).

| Achievement ID | Title | Description | Points | Coins in game |
| --- | --- | --- | --- | --- |
| `thumbwar.achievement.first_win` | First Pin-Down | Beat the CPU once | 10 | 25 |
| `thumbwar.achievement.pins_25` | Pin Pal | Score 25 pins against the CPU | 20 | 50 |
| `thumbwar.achievement.pins_100` | Pin Pro | Score 100 pins against the CPU | 65 | 150 |
| `thumbwar.achievement.pins_300` | Pin Legend | Score 300 pins against the CPU | 100 | 300 |
| `thumbwar.achievement.jump_1` | Leap of Thumb | Pin with a jumping slam | 20 | 50 |
| `thumbwar.achievement.jump_20` | Frequent Flyer | Score 20 jumping pins | 65 | 150 |
| `thumbwar.achievement.escape_10` | Slippery Thumb | Escape 10 pins | 45 | 100 |
| `thumbwar.achievement.reversal_1` | Hook, Line & Sinker | Flip a pin from a hook | 45 | 100 |
| `thumbwar.achievement.flawless_1` | Untouchable | Beat a Normal or Hard CPU without being pinned | 45 | 100 |
| `thumbwar.achievement.hard_1` | Thumb Master | Beat a Hard CPU | 45 | 100 |
| `thumbwar.achievement.streak_5` | On Fire | Beat the CPU 5 times in a row | 65 | 150 |
| `thumbwar.achievement.overtime_1` | Buzzer Beater | Win with a pin in overtime | 30 | 75 |
| `thumbwar.achievement.halloween_1` | Trick or Treat | Win wearing a Halloween item | 20 | 50 |
| `thumbwar.achievement.friends_10` | Best Thumbs Forever | Play 10 two-player matches | 20 | 50 |
| `thumbwar.achievement.collector_10` | Dress to Impress | Own 10 items | 45 | 100 |
| `thumbwar.achievement.tour_5` | Backyard Champ | Beat Sheriff Sam | 45 | 100 |
| `thumbwar.achievement.tour_10` | City Slicker | Beat Merlin Thumb | 65 | 150 |
| `thumbwar.achievement.tour_15` | Captain of the Seas | Beat Unicorn Uma | 85 | 200 |
| `thumbwar.achievement.tour_20` | Thumb Royalty | Beat King Thumbert | 100 | 300 |
| `thumbwar.achievement.stars_60` | Superstar | Earn all 60 Thumb Tour stars | 30 | 100 |

## Coin economy

- Coins come only from Thumb Tour stars (challenge *n* pays `30 + 6n` per star,
  once per star: 5,580 in total) and achievements (2,300 in total).
- Coin items cost 6,900 in total, so owning everything takes nearly every star
  and most achievements.

## Testing

- Sign in with a Game Center sandbox account on the device (Settings → Game Center).
- Achievements and leaderboards only appear once the IDs above exist in App Store Connect.
- The game shows its own achievement toasts, so Game Center's banners are turned off.
