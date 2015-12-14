Pod::Spec.new do |s|
  s.name        = "LeaderboardKit"
  s.version     = "0.0.3"
  s.summary     = "iOS and OSX social leaderboards and highscore push notifications on top of Apple CloudKit"
  s.description = <<-DESC
                   Leaderboards with GameCenter, Twitter, Facebook friends and others.
                   Friends highscore push notifications on top of Apple CloudKit.
                   DESC
  s.homepage    = "https://github.com/k06a/LeaderboardKit"

  s.license          = "MIT"
  s.author           = { "Anton Bukov" => "k06aaa@gmail.com" }
  s.social_media_url = "http://twitter.com/k06a"
  s.platform         = :ios, "6.0"
  s.source           = { :git => "https://github.com/k06a/LeaderboardKit.git", :tag => "#{s.version}" }

  s.source_files  = "Classes", "Classes/**/*.{h,m}"
  s.exclude_files = "Classes/Exclude"
  s.resources     = "Resources/**/*.*"
  s.frameworks    = "GameKit", "Accounts", "Social"
  s.requires_arc  = true

  s.dependency "SAMCache"
  s.dependency "VK-ios-sdk", "1.2.2"
end
