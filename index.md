---
# the default layout is 'page'
layout: page
title: Steve's Stuff
description: A collection of woodworking things and other stuff.
author: sjg
image:
  path: /assets/img/about/IMG_0697.avif
  alt: The most precious thing in my shop.  A gift from the family.
date: 2024-01-28 10:59:55 -0500
last_modified_at: 2026-08-04 00:00:00 -0400
---

{% include header.html %}

## Welcome

Welcome to my photo blog of various "maker" things I am up to, mostly woodworking. The above picture is a sign hanging in my workshop, given to me by the family. It's a pretty cool gift. 

Below you will find quick links to my most recent posts, my favorites, and some posts that have recently been updated with fresh content.  You can dive into those, or you can navigate the site with the category links on the sidebar.

See the [About]({% link _tabs/about.md %}) page to learn more about this site and its author.

{% assign latest_post_limit = 5 %}
{% assign favorites_limit = 5 %}
{% assign recently_modified_limit = 5 %}

## My Latest Posts

Here are my {{ latest_post_limit }} most recent posts:

{% include recent3.html eager_first=true limit=latest_post_limit %}

## Favorite Posts

Here are some of my favorite projects:

{% assign _latest_posts = site.posts | slice: 0, latest_post_limit %}
{% capture _excl_latest %}{% for _post in _latest_posts %}{% unless forloop.first %}|{% endunless %}{{ _post.url }}{% endfor %}{% endcapture %}
{% include recent3.html mode="favorites" show_title=false limit=favorites_limit exclude=_excl_latest %}

## Recently Modified

And here are some other posts that have been updated recently with new content:

{% assign _fav_all = site.posts | where_exp: 'p', 'p.favorite' %}
{% assign _fav_pinned = _fav_all | where_exp: 'p', 'p.pin' %}
{% assign _fav_unpinned = _fav_all | where_exp: 'p', 'p.pin != true' %}
{% assign _favs_ordered = _fav_pinned | concat: _fav_unpinned %}
{% assign _excl_latest_arr = _excl_latest | split: '|' %}
{% assign _displayed_favorites = '' | split: '' %}
{% for _p in _favs_ordered %}
  {% unless _excl_latest_arr contains _p.url %}
    {% assign _displayed_favorites = _displayed_favorites | push: _p %}
  {% endunless %}
{% endfor %}
{% assign _displayed_favorites = _displayed_favorites | slice: 0, favorites_limit %}
{% assign _excl_modified = _excl_latest %}
{% for _p in _displayed_favorites %}
  {% assign _excl_modified = _excl_modified | append: '|' | append: _p.url %}
{% endfor %}
{% include recent3.html mode='modified' limit=recently_modified_limit exclude=_excl_modified %}
