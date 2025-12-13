# frozen_string_literal: true

require 'time'

# Compute a composite sort key for posts that encodes both
# pin status and date so jekyll-paginate-v2 (which only
# supports a single sort field) can order pinned posts first
# and then by recency.

Jekyll::Hooks.register :site, :post_read do |site|
  site.posts.docs.each do |post|
    raw_pin = post.data['pin']

    pinned_flag =
      case raw_pin
      when true, 'true', 'True', 'TRUE', 1, '1'
        '1'
      else
        '0'
      end

    # At :post_read time, post.date is already resolved from
    # front matter (or filename), so we can rely on it
    # directly for a stable per-post timestamp.
    timestamp = post.date.to_i

    # Single composite key so jekyll-paginate-v2 can sort by one field:
    #   - pinned first ("1-" > "0-")
    #   - within each group, newer posts first when sort_reverse: true
    post.data['sort_key'] = format('%s-%010d', pinned_flag, timestamp)
  end
end
