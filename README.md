# LeaderboardKit

iOS and OSX social leaderboards and highscore push notifications on top of Apple CloudKit

# Installation

1. `pod 'LeaderboardKit'`
2. `#import <LeaderboardKit/LeaderboardKit.h>`
3. Setup leaderboards inside `application:didFinishLaunchingWithOptions:`:

   ```objective-c
   LKGameCenterIdentifierToNameTranform = ^NSString *(NSString *identifier){
       return [identifier substringFromIndex:@"scores.".length];
   };
   LKGameCenterNameToIdentifierTranform = ^NSString *(NSString *name){
       return [@"scores." stringByAppendingString:name];
   };
   [[LeaderboardKit shared] setupLeaderboardNames:@[@"3x3",@"4x4",@"5x5"]];
   ```
   for leaderboard identifiers: `scores.3x3`, `scores.4x4` and `scores.5x5`
   
## Integrate GameCenter when LeaderboardKit become ready

```objective-c
[[LeaderboardKit shared] whenInitialized:^{
    id<LKAccount> account = [[LeaderboardKit shared] accountWithClass:[LKGameCenter class]];
    if (!account) {
        account = [[LKGameCenter alloc] init];
        [[LeaderboardKit shared] addAccount:account];
    }
    
    [account requestAuthWithViewController:self success:^{
        [[[UIAlertView alloc] initWithTitle:@"Success" message:@"GameCenter account connected" delegate:nil cancelButtonTitle:@"OK" otherButtonTitles:nil] show];
    } failure:^(NSError *error) {
        [[[UIAlertView alloc] initWithTitle:@"Error" message:error.localizedDescription delegate:nil cancelButtonTitle:@"OK" otherButtonTitles:nil] show];
    }];
}];
```

## Integrate social networks

1. When need to configure some button state:

  ```objective-c
  self.connectTwitterButton.enabled = NO;
  [[LeaderboardKit shared] whenInitialized:^{
      self.connectTwitterButton.enabled = ![[LeaderboardKit shared] accountForIdentifier:LKAccountIdentifierTwitter];
  }];
  ```
2. Connect ane social when player wants (Twitter, for example):

  ```objective-c
  if ([LeaderboardKit shared].isInitialized && ![[LeaderboardKit shared] accountForIdentifier:LKAccountIdentifierTwitter])
  {
      id<LKAccount> account = [[LKTwitterAccount alloc] initWithUserRecord:[LeaderboardKit shared].userRecord];
      [account requestAuthWithViewController:self success:^{
          [[LeaderboardKit shared] setAccount:account forIdentifier:LKAccountIdentifierTwitter];
          [[[UIAlertView alloc] initWithTitle:@"Success" message:@"Twitter account connected" delegate:nil cancelButtonTitle:@"OK" otherButtonTitles:nil] show];
      } failure:^(NSError *error) {
          [[[UIAlertView alloc] initWithTitle:@"Error" message:error.localizedDescription delegate:nil cancelButtonTitle:@"OK" otherButtonTitles:nil] show];
      }];
  }
  ```
  
# Contribute

1. Create fork
2. Create new branch
3. Add some commits to your branch
4. Create Pull Request
5. When pull request merged, delete brach
