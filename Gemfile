# frozen_string_literal: true

source "https://rubygems.org"
gem 'csv', '~> 3.3'
gem 'base64', '~> 0.2.0'
gem 'bigdecimal', '~> 3.1', '>= 3.1.8'
gem 'logger', '~> 1.6', '>= 1.6.1'
gem 'fiddle', '~> 1.1', '>= 1.1.6'

gem 'jekyll-theme-chirpy', '~> 7.2', '>= 7.2.4'

group :test do
  gem 'html-proofer', '~> 5.0', '>= 5.0.9'
end

# Windows and JRuby does not include zoneinfo files, so bundle the tzinfo-data gem
# and associated library.
platforms :mingw, :x64_mingw, :mswin, :jruby do
  gem "tzinfo", ">= 1", "< 3"
  gem "tzinfo-data"
end

# Performance-booster for watching directories on Windows
gem "wdm", "~> 0.2.0", :platforms => [:mingw, :x64_mingw, :mswin]

# Lock `http_parser.rb` gem to `v0.6.x` on JRuby builds since newer versions of the gem
# do not have a Java counterpart.
gem 'http_parser.rb', '~> 0.8.0', :platforms => [:jruby]

group :jekyll_plugins do
  gem "jekyll-redirect-from", "~> 0.16"
end

gem 'jekyll-include-cache', '~> 0.2.1'

# Fixing the google-protobuf problem
gem 'google-protobuf', '~> 4.29', '= 4.29.2'