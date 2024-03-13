---
layout: page
published: false
---

<h2>Pages</h2>
<ul>
{% for page in site.pages %}
  <li><a href="{{ page.url | relative_url }}">{{ page.title | default: page.url }}</a></li>
{% endfor %}
</ul>

<h2>Posts</h2>
<ul>
{% for post in site.posts %}
  <li><a href="{{ post.url | relative_url }}">{{ post.title | default: page.url }}</a></li>
{% endfor %}
</ul>