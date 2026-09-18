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
last_modified_at: 2026-09-18 00:00:00 -0400
---

{% include header.html %}

## Welcome

Welcome to my photo blog of various "maker" things I am up to, mostly woodworking. The above picture is a sign hanging in my workshop, given to me by the family. It's a pretty cool gift. 

Below you will find quick links to my most recent posts, my favorites, and some posts that have recently been updated with fresh content.  You can dive into those, or you can navigate the site with the category links on the sidebar.

See the [About]({% link _tabs/about.md %}) page to learn more about this site and its author.

{% assign latest_post_limit = 5 %}
{% assign favorites_limit = 5 %}
{% assign recently_modified_limit = 5 %}

{% include recent3.html mode='homepage' latest_limit=latest_post_limit favorites_limit=favorites_limit recently_modified_limit=recently_modified_limit %}
