---
layout: page
icon: fas fa-tools
order: 5
title: Workshop
---

{% include header.html %}

Welcome to the workshop hub. You will find reference material, fixtures, and other shop-focused notes collected here.

{% assign workshop_items = site.workshop | sort: 'date' | reverse %}
{% if workshop_items == empty %}
<p>No workshop entries yet. Add Markdown files in <code>_workshop/</code> to populate this page.</p>
{% else %}
<ul>
  {% for item in workshop_items %}
  <li>
    <a href="{{ item.url | relative_url }}">{{ item.title | escape }}</a>
    {% if item.description %}
    &mdash; {{ item.description | strip_html | strip_newlines }}
    {% elsif item.excerpt %}
    &mdash; {{ item.excerpt | strip_html | strip_newlines | truncate: 140 }}
    {% endif %}
  </li>
  {% endfor %}
</ul>
{% endif %}
