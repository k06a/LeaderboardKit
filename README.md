# LeaderboardKit

iOS and OSX social leaderboards and highscore push notifications on top of Apple CloudKit

# Usage

1. `pod 'LeaderboardKit'`
2. `#import <LeaderboardKit/LeaderboardKit.h>`
3. Just call method `[LeaderboardKit shared]` or whole following code to activate Apple GameCenter:

  ```objective-c
  - (BOOL)application:(UIApplication *)application didFinishLaunchingWithOptions:(NSDictionary *)launchOptions
  {
      // ...
   
      [[LeaderboardKit shared] whenInitialized:^{
          if (![[LeaderboardKit shared] accountForIdentifier:LKAccountIdentifierGameCenter])
          {
              id<LKAccount> account = [[LKGameCenterAccount alloc] initWithUserRecord:[LeaderboardKit shared].userRecord];
              [account requestAuthWithViewController:self.window.rootViewController success:^{
                  [[LeaderboardKit shared] setAccount:account forIdentifier:LKAccountIdentifierGameCenter];
                  [[[UIAlertView alloc] initWithTitle:@"Success" message:@"GameCenter account connected" delegate:nil cancelButtonTitle:@"OK" otherButtonTitles:nil] show];
              } failure:^(NSError *error) {
                  [[[UIAlertView alloc] initWithTitle:@"Error" message:error.localizedDescription delegate:nil cancelButtonTitle:@"OK" otherButtonTitles:nil] show];
              }];
          }
      }];
    
      // ...
  }
  ```
4. When need to configure some button state:

  ```objective-c
  self.connectTwitterButton.enabled = NO;
  [[LeaderboardKit shared] whenInitialized:^{
      self.connectTwitterButton.enabled = ![[LeaderboardKit shared] accountForIdentifier:LKAccountIdentifierTwitter];
  }];
  ```
5. Connect new social when needed (Twitter, for example):

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
