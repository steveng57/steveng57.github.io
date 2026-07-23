# frozen_string_literal: true

require 'rbconfig'

# Collect public, build-time diagnostics for the Site Stats page. Keeping this
# in a generator makes the same data available to Liquid locally and in CI.
module Jekyll
  class SiteStatsGenerator < Generator
    safe true
    priority :lowest

    IMAGE_EXTENSIONS = %w[.avif .gif .ico .jpeg .jpg .png .svg .webp].freeze
    HLS_EXTENSIONS = %w[.m3u8 .ts].freeze
    VIDEO_EXTENSIONS = %w[.m4v .mov .mp4 .webm].freeze

    def generate(site)
      posts = site.posts.docs
      static_assets = asset_inventory(site.static_files)
      static_assets['gallery_images'] = gallery_image_count(site, site.static_files)

      site.config['site_stats'] = {
        'build' => build_stats(site),
        'content' => content_stats(site, posts),
        'quality' => quality_stats(posts),
        'assets' => static_assets,
        'features' => feature_stats(site)
      }
    end

    private

    def build_stats(site)
      {
        'generated_at' => site.time,
        'environment' => Jekyll.env,
        'jekyll_version' => Jekyll::VERSION,
        'ruby_version' => RUBY_VERSION,
        'ruby_platform' => RbConfig::CONFIG['host_os'],
        'theme' => site.config['theme'],
        'theme_version' => gem_version(site.config['theme']),
        'commit' => first_environment_value('GITHUB_SHA', 'CF_PAGES_COMMIT_SHA'),
        'branch' => first_environment_value('GITHUB_HEAD_REF', 'GITHUB_REF_NAME', 'CF_PAGES_BRANCH'),
        'repository' => ENV['GITHUB_REPOSITORY'],
        'provider' => deployment_provider
      }
    end

    def content_stats(site, posts)
      dated_posts = posts.sort_by(&:date)
      {
        'posts' => posts.length,
        'pages' => site.pages.length,
        'categories' => site.categories.length,
        'tags' => site.tags.length,
        'words' => posts.sum { |post| word_count(post.content) },
        'first_post' => dated_posts.first&.date,
        'latest_post' => dated_posts.last&.date,
        'years' => posts.map { |post| post.date.year }.uniq.sort.reverse,
        'year_usage' => posts.group_by { |post| post.date.year }
                             .map { |year, items| { 'name' => year.to_s, 'count' => items.length } }
                             .sort_by { |row| -row['name'].to_i },
        'category_usage' => usage_rows(site.categories),
        'tag_usage' => usage_rows(site.tags)
      }
    end

    def quality_stats(posts)
      {
        'with_description' => posts.count { |post| present?(post.data['description']) },
        'with_image' => posts.count { |post| present?(post.data['image']) },
        'with_image_alt' => posts.count { |post| image_alt?(post.data['image']) },
        'with_last_modified' => posts.count { |post| present?(post.data['last_modified_at']) },
        'with_toc' => posts.count { |post| post.data.fetch('toc', true) != false }
      }
    end

    def asset_inventory(files)
      rows = Hash.new { |hash, key| hash[key] = { 'extension' => key, 'count' => 0, 'bytes' => 0 } }
      entries = []

      files.each do |file|
        next unless File.file?(file.path)

        extension = File.extname(file.path).downcase
        extension = '[no extension]' if extension.empty?
        bytes = File.size(file.path)
        rows[extension]['count'] += 1
        rows[extension]['bytes'] += bytes
        entries << { 'path' => file.relative_path, 'bytes' => bytes, 'size' => human_size(bytes) }
      rescue Errno::ENOENT, Errno::EACCES
        # A file can disappear during watch-mode rebuilds. The next build will
        # naturally pick it up again, so do not fail the whole site build.
        next
      end

      formats = rows.values.sort_by { |row| [-row['bytes'], row['extension']] }
      formats.each { |row| row['size'] = human_size(row['bytes']) }
      image_rows = formats.select { |row| IMAGE_EXTENSIONS.include?(row['extension']) }
      hls_rows = formats.select { |row| HLS_EXTENSIONS.include?(row['extension']) }
      video_rows = formats.select { |row| VIDEO_EXTENSIONS.include?(row['extension']) }
      hls_masters = entries.count { |entry| File.basename(entry['path']).downcase == 'master.m3u8' }
      video_bytes = (hls_rows + video_rows).sum { |row| row['bytes'] }

      {
        'files' => formats.sum { |row| row['count'] },
        'bytes' => formats.sum { |row| row['bytes'] },
        'size' => human_size(formats.sum { |row| row['bytes'] }),
        'images' => image_rows.sum { |row| row['count'] },
        'image_bytes' => image_rows.sum { |row| row['bytes'] },
        'image_size' => human_size(image_rows.sum { |row| row['bytes'] }),
        'videos' => hls_masters + video_rows.sum { |row| row['count'] },
        'hls_files' => hls_rows.sum { |row| row['count'] },
        'video_bytes' => video_bytes,
        'video_size' => human_size(video_bytes),
        'formats' => formats,
        'largest' => entries.sort_by { |entry| [-entry['bytes'], entry['path']] }.first(20)
      }
    end

    def gallery_image_count(site, files)
      image_info = site.data.fetch('img-info', {})
      media = site.data.fetch('media', {})

      files.count do |file|
        relative_path = file.relative_path.tr('\\', '/')
        match = relative_path.match(%r{\A/assets/img/posts/([^/]+)/tinyfiles/([^/]+\.avif)\z}i)
        next false unless match

        slug = match[1]
        filename = match[2]
        image_key = relative_path.sub('/tinyfiles', '').delete_prefix('/')
        image_metadata = image_info.fetch(image_key, {})
        media_item = media.dig(slug, 'images', filename)
        gallery_flag = media_item ? media_item['gallery'] : image_metadata['gallery']

        gallery_flag == true
      end
    end

    def feature_stats(site)
      config = site.config
      {
        'url' => config['url'],
        'baseurl' => config['baseurl'],
        'language' => config['lang'],
        'timezone' => config['timezone'],
        'permalink' => config.dig('defaults', 0, 'values', 'permalink'),
        'syntax_highlighter' => config.dig('kramdown', 'syntax_highlighter'),
        'pwa' => config.dig('pwa', 'enabled') == true,
        'toc' => config['toc'] == true,
        'pagination' => config.dig('pagination', 'enabled') == true,
        'pageviews' => config.dig('pageviews', 'provider'),
        'analytics' => enabled_analytics(config['analytics']),
        'plugins' => Array(config['plugins']).sort
      }
    end

    def usage_rows(collection)
      collection.map { |name, items| { 'name' => name.to_s, 'count' => items.length } }
                .sort_by { |row| [-row['count'], row['name'].downcase] }
    end

    def enabled_analytics(analytics)
      return [] unless analytics.is_a?(Hash)

      analytics.filter_map do |name, settings|
        name.to_s if settings.is_a?(Hash) && present?(settings['id'])
      end.sort
    end

    def image_alt?(image)
      image.is_a?(Hash) && present?(image['alt'])
    end

    def word_count(content)
      content.to_s.gsub(/\{%.+?%\}|\{\{.+?\}\}/m, ' ').scan(/[[:alnum:]][[:alnum:]'’-]*/).length
    end

    def human_size(bytes)
      units = %w[B KiB MiB GiB TiB]
      value = bytes.to_f
      unit = units.shift

      while value >= 1024 && !units.empty?
        value /= 1024
        unit = units.shift
      end

      value >= 10 || unit == 'B' ? format('%.0f %s', value, unit) : format('%.1f %s', value, unit)
    end

    def present?(value)
      !value.nil? && value != '' && value != false
    end

    def gem_version(name)
      Gem.loaded_specs[name]&.version&.to_s
    end

    def first_environment_value(*names)
      names.each do |name|
        value = ENV[name]
        return value unless value.nil? || value.empty?
      end
      nil
    end

    def deployment_provider
      return 'GitHub Actions' if ENV['GITHUB_ACTIONS'] == 'true'
      return 'Cloudflare Pages' if ENV['CF_PAGES'] == '1'

      'Local build'
    end
  end
end
