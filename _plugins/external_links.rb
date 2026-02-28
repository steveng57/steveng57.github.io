# frozen_string_literal: true
require "uri"

external_link_hook = lambda do |doc|
  return unless doc.output_ext == ".html" && doc.output

  site = doc.site

  # Allow multiple internal hosts
  internal_hosts = []

  if site.config["url"]
    begin
      internal_hosts << URI.parse(site.config["url"]).host
    rescue URI::InvalidURIError
    end
  end

  # Add additional domains manually if needed
  internal_hosts << "steveng57.github.io"

  doc.output.gsub!(%r{<a\s+[^>]*href="([^"]+)"[^>]*>}i) do |a_tag|
    href = Regexp.last_match(1)
    next a_tag unless href.start_with?("http://", "https://")

    host = begin
      URI.parse(href).host
    rescue URI::InvalidURIError
      nil
    end
    next a_tag if host.nil?
    next a_tag if internal_hosts.compact.any? { |h| host.casecmp?(h) }

    next a_tag if a_tag =~ /\starget=/i
    next a_tag if a_tag =~ /\srel=/i

    a_tag.sub(/>$/,' target="_blank" rel="noopener noreferrer">')
  end
end

%i[documents pages].each do |type|
  Jekyll::Hooks.register type, :post_render, &external_link_hook
end