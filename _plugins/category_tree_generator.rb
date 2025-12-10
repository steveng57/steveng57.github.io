# Generates hierarchical category index pages like /woodworking/ and
# /woodworking/home-decor/.
#
# Each generated page mimics a manual "home" layout page with Jekyll
# Paginate v2-style front matter, for example:
#
# ---
# layout: home
# title: Workshop
# pagination:
#   enabled: true
#   collection: posts
#   per_page: 10
#   permalink: /page:num/
#   title: 'Workshop - page :num'
#   sort_field: 'date'
#   sort_reverse: true
#   indexpage: 'index'
#   category: 'Home & Garden'
# ---

module Jekyll
  class CategoryTreeGenerator < Generator
    safe true
    priority :low

    def generate(site)
      # Load defaults from _data/category_page.yml (if present) so that
      # the front matter for generated pages can be adjusted without
      # touching this plugin.
      template = site.data.fetch('category_page', {})
      pagination_defaults = template.fetch('pagination', {})

      # dir (e.g., "woodworking/home-decor/") => { 'names' => [..] }
      category_map = {}

      site.posts.docs.each do |post|
        categories = extract_categories(post)
        next if categories.empty?

        # Build all prefix paths: [a], [a,b], [a,b,c], ...
        categories.each_index do |idx|
          names = categories[0..idx]
          dir = build_dir(names)

          # Only need to store the names once per dir
          category_map[dir] ||= { 'names' => names }
        end
      end

      category_map.each do |dir, data|
        names = data['names']
        title = names.last.to_s

        page = Jekyll::PageWithoutAFile.new(site, site.source, dir, 'index.html')

        # Match the existing manual pagination-based pages but with
        # titles/categories derived from the category path and the
        # shared template in _data/category_page.yml.
        page.data['layout'] = template['layout'] || 'home'
        page.data['title'] = title
        page.data['category_path'] = names

        page.data['pagination'] = pagination_defaults.merge(
          'enabled' => true,
          # Always sort newest first unless explicitly overridden
          'sort_reverse' => pagination_defaults.fetch('sort_reverse', true),
          # Human-facing pagination title, can still be overridden in the
          # template if desired.
          'title' => "#{title} - page :num",
          # Filter on the most specific category name
          'category' => title
        )

        site.pages << page
      end
    end

    private

    def extract_categories(post)
      raw = post.data['category'] || post.data['categories']

      case raw
      when String
        [raw].compact
      when Array
        raw.compact.map(&:to_s).reject(&:empty?)
      else
        []
      end
    end

    def build_dir(names)
      slugs = names.map { |name| Utils.slugify(name.to_s) }
      # Ensure trailing slash so Jekyll treats it as a directory
      File.join(*slugs, '')
    end
  end
end
