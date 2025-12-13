# frozen_string_literal: true

require 'time'

Jekyll::Hooks.register :posts, :post_init do |post|
  # Derive pin state directly from the raw front-matter, since
  # post.data['pin'] is nil at :post_init time in this site.
  raw_pin = nil

  begin
    lines = File.foreach(post.path).take(50) # just the front matter region
    if lines.first&.start_with?('---')
      # Grab everything between the first and second '---' markers
      front_matter_lines = []
      lines[1..].each do |line|
        break if line.start_with?('---')
        front_matter_lines << line
      end

      fm_text = front_matter_lines.join
      # Match a standalone `pin: true` line (case-insensitive, allowing spaces)
      raw_pin = true if fm_text.match?(/^pin:\s*true\s*$/i)
    end
  rescue StandardError
    raw_pin = nil
  end

  pinned_flag = raw_pin ? '1' : '0'

  # Derive a stable per-post timestamp from the front-matter
  # or filename rather than relying on post.date, which appears
  # identical for all posts at :post_init time in this site.

  # 1) Prefer the YAML front-matter date if present.
  raw_date = post.data['date']

  if raw_date
    begin
      timestamp = Time.parse(raw_date.to_s).to_i
    rescue StandardError
      timestamp = nil
    end
  end

  # 2) If that didn't work, parse the date prefix from the filename
  #    e.g. "2019-12-17-daybed.MD" -> 2019-12-17.
  if timestamp.nil?
    basename = File.basename(post.path)
    if basename =~ /(\d{4})-(\d{2})-(\d{2})/
      begin
        y, m, d = Regexp.last_match.captures.map(&:to_i)
        timestamp = Time.new(y, m, d, 0, 0, 0).to_i
      rescue StandardError
        timestamp = nil
      end
    end
  end

  # 3) Final fallback: whatever Jekyll has in post.date.
  timestamp ||= post.date.to_i

  # Single composite key so jekyll-paginate-v2 can sort by one field:
  #   - pinned first ("1-" > "0-")
  #   - within each group, newer posts first when sort_reverse: true
  post.data['sort_key'] = format('%s-%010d', pinned_flag, timestamp)
end
