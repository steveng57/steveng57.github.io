---
layout: post
---
Here we go!
{% assign filename = "IMG_0626.jpeg" %}
{% assign specific_entry = site.data.img-info[filename] %}

Title: {{ specific_entry.title }}
Subject: {{ specific_entry.subject }}
Date Taken: {{ specific_entry.datetaken }}

Real test:  {{ site.data.img-info[filename].title }}

Now for the pageviews

site.pageviews.provider: {{ site.pageviews.provider }}

site.analytics[site.pageviews.provider].id: {{ site.analytics[site.pageviews.provider].id }}