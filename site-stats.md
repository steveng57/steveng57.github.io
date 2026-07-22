---
layout: page
title: Site Stats
description: Build, content, asset, and browser diagnostics for Steve's Stuff.
permalink: /site-stats/
toc: true
last_modified_at: 2026-07-22 13:30:00 -0400
---

{% assign stats = site.site_stats %}
{% assign build = stats.build %}
{% assign content_stats = stats.content %}
{% assign quality = stats.quality %}
{% assign assets = stats.assets %}
{% assign features = stats.features %}

<div class="site-stats" data-generated-at="{{ build.generated_at | date_to_xmlschema }}" markdown="1">

This page is a technical snapshot of the site. Build and content figures are captured when Jekyll generates the site; browser diagnostics are calculated locally when you open this page. Nothing in the browser section is sent back to the site.
{: .stats-intro}

## At a glance

<div class="stats-grid" aria-label="Site summary">
  <div class="stats-card"><span class="stats-value">{{ content_stats.posts }}</span><span class="stats-label">Published posts</span></div>
  <div class="stats-card"><span class="stats-value">{{ content_stats.categories }}</span><span class="stats-label">Categories</span></div>
  <div class="stats-card"><span class="stats-value">{{ content_stats.tags }}</span><span class="stats-label">Tags</span></div>
  <div class="stats-card"><span class="stats-value">{{ assets.images }}</span><span class="stats-label">Published images</span></div>
  <div class="stats-card"><span class="stats-value">{{ assets.size }}</span><span class="stats-label">Static assets</span></div>
  <div class="stats-card"><span class="stats-value">{{ build.generated_at | date: "%b %-d, %Y" }}</span><span class="stats-label">Last generated</span></div>
</div>

## Build and deployment

<table class="stats-table" id="build-stats" data-diagnostics-section="Build and deployment">
  <tbody>
    <tr><th scope="row">Generated</th><td>{{ build.generated_at | date: "%Y-%m-%d %H:%M:%S %Z" }}</td></tr>
    <tr><th scope="row">Environment</th><td>{{ build.environment }}</td></tr>
    <tr><th scope="row">Build provider</th><td>{{ build.provider }}</td></tr>
    <tr><th scope="row">Jekyll</th><td>{{ build.jekyll_version }}</td></tr>
    <tr><th scope="row">Theme</th><td>{{ build.theme }}{% if build.theme_version %} {{ build.theme_version }}{% endif %}</td></tr>
    <tr><th scope="row">Ruby</th><td>{{ build.ruby_version }} · {{ build.ruby_platform }}</td></tr>
    <tr><th scope="row">Branch</th><td>{{ build.branch | default: "Unavailable in this build" }}</td></tr>
    <tr><th scope="row">Commit</th><td><code>{% if build.commit %}{{ build.commit | slice: 0, 12 }}{% else %}Unavailable in this build{% endif %}</code></td></tr>
    <tr><th scope="row">Repository</th><td>{{ build.repository | default: site.github.username | default: "Unavailable in this build" }}</td></tr>
  </tbody>
</table>

## Content inventory

<table class="stats-table">
  <tbody>
    <tr><th scope="row">Published posts</th><td>{{ content_stats.posts }}</td></tr>
    <tr><th scope="row">Generated/source pages</th><td>{{ content_stats.pages }}</td></tr>
    <tr><th scope="row">Approximate post words</th><td>{{ content_stats.words }}</td></tr>
    <tr><th scope="row">Archive span</th><td>{{ content_stats.first_post | date: "%B %Y" }} – {{ content_stats.latest_post | date: "%B %Y" }}</td></tr>
    <tr><th scope="row">Years represented</th><td>{{ content_stats.years | join: ", " }}</td></tr>
    <tr><th scope="row">Posts with descriptions</th><td>{{ quality.with_description }} / {{ content_stats.posts }}</td></tr>
    <tr><th scope="row">Posts with lead images</th><td>{{ quality.with_image }} / {{ content_stats.posts }}</td></tr>
    <tr><th scope="row">Lead images with alt text</th><td>{{ quality.with_image_alt }} / {{ content_stats.posts }}</td></tr>
    <tr><th scope="row">Posts marked as modified</th><td>{{ quality.with_last_modified }} / {{ content_stats.posts }}</td></tr>
    <tr><th scope="row">Posts with a table of contents</th><td>{{ quality.with_toc }} / {{ content_stats.posts }}</td></tr>
  </tbody>
</table>

<details class="stats-details">
  <summary>Posts by year ({{ content_stats.year_usage.size }})</summary>
  <div class="stats-details-body">
    {% assign largest_year = content_stats.year_usage | map: "count" | sort | last %}
    {% for item in content_stats.year_usage %}
      {% assign bar_width = item.count | times: 100.0 | divided_by: largest_year %}
      <div class="stats-bar-row"><span>{{ item.name }}</span><span class="stats-bar-track"><span class="stats-bar" style="width: {{ bar_width }}%"></span></span><span>{{ item.count }}</span></div>
    {% endfor %}
  </div>
</details>

<details class="stats-details">
  <summary>Category usage ({{ content_stats.category_usage.size }})</summary>
  <div class="stats-details-body">
    {% assign largest_category = content_stats.category_usage.first.count %}
    {% for item in content_stats.category_usage %}
      {% assign bar_width = item.count | times: 100.0 | divided_by: largest_category %}
      <div class="stats-bar-row"><span>{{ item.name }}</span><span class="stats-bar-track"><span class="stats-bar" style="width: {{ bar_width }}%"></span></span><span>{{ item.count }}</span></div>
    {% endfor %}
  </div>
</details>

<details class="stats-details">
  <summary>Tag usage ({{ content_stats.tag_usage.size }})</summary>
  <div class="stats-details-body">
    {% assign largest_tag = content_stats.tag_usage.first.count %}
    {% for item in content_stats.tag_usage %}
      {% assign bar_width = item.count | times: 100.0 | divided_by: largest_tag %}
      <div class="stats-bar-row"><span>{{ item.name }}</span><span class="stats-bar-track"><span class="stats-bar" style="width: {{ bar_width }}%"></span></span><span>{{ item.count }}</span></div>
    {% endfor %}
  </div>
</details>

## Published assets

These totals cover static files selected for publication. Original photos, source videos, scripts, and other files intentionally excluded from the generated site are not counted.
{: .stats-note}

<div class="stats-grid">
  <div class="stats-card"><span class="stats-value">{{ assets.files }}</span><span class="stats-label">Static files</span></div>
  <div class="stats-card"><span class="stats-value">{{ assets.images }}</span><span class="stats-label">Images · {{ assets.image_size }}</span></div>
  <div class="stats-card"><span class="stats-value">{{ assets.videos }} videos</span><span class="stats-label">{{ assets.hls_files }} HLS delivery files · {{ assets.video_size }}</span></div>
  <div class="stats-card"><span class="stats-value">{{ assets.size }}</span><span class="stats-label">Total static footprint</span></div>
</div>

<details class="stats-details">
  <summary>Static file formats ({{ assets.formats.size }})</summary>
  <div class="stats-details-body">
    <table class="stats-table">
      <thead><tr><th scope="col">Extension</th><th scope="col">Files</th><th scope="col">Size</th></tr></thead>
      <tbody>
        {% for format in assets.formats %}
          <tr><td><code>{{ format.extension }}</code></td><td>{{ format.count }}</td><td>{{ format.size }}</td></tr>
        {% endfor %}
      </tbody>
    </table>
  </div>
</details>

<details class="stats-details">
  <summary>Largest published assets (top {{ assets.largest.size }})</summary>
  <div class="stats-details-body">
    <table class="stats-table">
      <thead><tr><th scope="col">Public path</th><th scope="col">Size</th></tr></thead>
      <tbody>
        {% for asset in assets.largest %}
          <tr><td><code>{{ asset.path }}</code></td><td>{{ asset.size }}</td></tr>
        {% endfor %}
      </tbody>
    </table>
  </div>
</details>

## Site configuration

<table class="stats-table" id="site-config-stats" data-diagnostics-section="Site configuration">
  <tbody>
    <tr><th scope="row">Canonical URL</th><td>{{ features.url }}</td></tr>
    <tr><th scope="row">Base URL</th><td><code>{{ features.baseurl | default: "/" }}</code></td></tr>
    <tr><th scope="row">Language / timezone</th><td>{{ features.language }} · {{ features.timezone }}</td></tr>
    <tr><th scope="row">Post permalink</th><td><code>{{ features.permalink }}</code></td></tr>
    <tr><th scope="row">Syntax highlighting</th><td>{{ features.syntax_highlighter }}</td></tr>
    <tr><th scope="row">Progressive Web App</th><td>{% if features.pwa %}Enabled{% else %}Disabled{% endif %}</td></tr>
    <tr><th scope="row">Pagination</th><td>{% if features.pagination %}Enabled{% else %}Disabled{% endif %}</td></tr>
    <tr><th scope="row">Tables of contents</th><td>{% if features.toc %}Enabled by default{% else %}Disabled by default{% endif %}</td></tr>
    <tr><th scope="row">Page views</th><td>{{ features.pageviews | default: "Disabled" }}</td></tr>
    <tr><th scope="row">Analytics</th><td>{% if features.analytics.size > 0 %}{{ features.analytics | join: ", " }}{% else %}Disabled{% endif %}</td></tr>
    <tr><th scope="row">Jekyll plugins</th><td>{{ features.plugins | join: ", " }}</td></tr>
  </tbody>
</table>

## Your browser

These values describe this browser tab and can change as you resize the window, change theme, go offline, or update the site. They stay on your device unless you choose **Copy diagnostics**.
{: .stats-note}

<div class="stats-actions">
  <button type="button" class="btn btn-outline-primary" id="copy-site-diagnostics">Copy diagnostics</button>
  <span class="stats-status" id="copy-site-diagnostics-status" role="status" aria-live="polite"></span>
</div>

<table class="stats-table" id="browser-stats" data-diagnostics-section="Browser">
  <tbody>
    <tr><th scope="row">Page URL</th><td data-stat="url">Checking…</td></tr>
    <tr><th scope="row">Referrer</th><td data-stat="referrer">Checking…</td></tr>
    <tr><th scope="row">Local time</th><td data-stat="localTime">Checking…</td></tr>
    <tr><th scope="row">Browser timezone</th><td data-stat="timezone">Checking…</td></tr>
    <tr><th scope="row">Language</th><td data-stat="language">Checking…</td></tr>
    <tr><th scope="row">Viewport</th><td data-stat="viewport">Checking…</td></tr>
    <tr><th scope="row">Screen</th><td data-stat="screen">Checking…</td></tr>
    <tr><th scope="row">Pixel ratio</th><td data-stat="pixelRatio">Checking…</td></tr>
    <tr><th scope="row">Colour / contrast</th><td data-stat="colorPreferences">Checking…</td></tr>
    <tr><th scope="row">Site theme</th><td data-stat="theme">Checking…</td></tr>
    <tr><th scope="row">Online</th><td data-stat="online">Checking…</td></tr>
    <tr><th scope="row">Network hints</th><td data-stat="network">Checking…</td></tr>
    <tr><th scope="row">Cookies</th><td data-stat="cookies">Checking…</td></tr>
    <tr><th scope="row">Do Not Track</th><td data-stat="doNotTrack">Checking…</td></tr>
    <tr><th scope="row">Logical processors</th><td data-stat="processors">Checking…</td></tr>
    <tr><th scope="row">Device memory hint</th><td data-stat="memory">Checking…</td></tr>
    <tr><th scope="row">Touch support</th><td data-stat="touch">Checking…</td></tr>
    <tr><th scope="row">Service worker</th><td data-stat="serviceWorker">Checking…</td></tr>
    <tr><th scope="row">Site storage</th><td data-stat="storage">Checking…</td></tr>
    <tr><th scope="row">Browser identification</th><td data-stat="userAgent">Checking…</td></tr>
  </tbody>
</table>

</div>

<script defer src="{{ '/assets/js/site-stats.js' | relative_url }}"></script>
