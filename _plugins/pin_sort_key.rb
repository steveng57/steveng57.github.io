# frozen_string_literal: true

require 'time'

# Compute a composite sort key for posts that encodes both
# pin status and date so jekyll-paginate-v2 (which only
# supports a single sort field) can order pinned posts first
# and then by recency.

Jekyll::Hooks.register :site, :post_read do |site|
  site.posts.docs.each do |post|
    pinned_flag = post.data['pin'] == true ? '1' : '0'
    post.data['sort_key'] = format('%s-%010d', pinned_flag, post.date.to_i)
  end
end
