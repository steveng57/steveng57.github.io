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

Welcome to my photo blog of various "maker" things I am up to, mostly woodworking. The above picture is a sign hanging in my workshop, given to me by the family. It's a pretty cool gift. See the [About]({% link _tabs/about.md %}) page to learn more about this site and its author.

## My Latest Posts

Here are my three most recent posts:

{% include recent3.html eager_first=true %}

## Favorite Posts

Here are some of my favorite projects:

{% assign _latest3 = site.posts | slice: 0, 3 %}
{% capture _excl_latest %}{{ _latest3[0].url }}|{{ _latest3[1].url }}|{{ _latest3[2].url }}{% endcapture %}
{% include recent3.html mode="favorites" show_title=false limit=nil exclude=_excl_latest %}

## Recently Modified

And here are some other posts that have been updated recently with new content:

{% assign _fav_all = site.posts | where_exp: 'p', 'p.favorite' %}
{% assign _fav_pinned = _fav_all | where_exp: 'p', 'p.pin' %}
{% assign _fav_unpinned = _fav_all | where_exp: 'p', 'p.pin != true' %}
{% assign _favs_ordered = _fav_pinned | concat: _fav_unpinned %}
{% assign _excl_latest_arr = _excl_latest | split: '|' %}
{% assign _excl_modified = _excl_latest %}
{% for _p in _favs_ordered %}
  {% unless _excl_latest_arr contains _p.url %}
    {% assign _excl_modified = _excl_modified | append: '|' | append: _p.url %}
  {% endunless %}
{% endfor %}
{% include recent3.html mode='modified' limit=3 exclude=_excl_modified %}
