---
# the default layout is 'page'
layout: page
author: sjg
icon: fas fa-user
order: 5
image:
  path: IMG_0697.jpeg
  alt: The most precious thing in my shop.  A gift from the family.
media_subpath: /assets/img/about
date: 2024-01-28 10:59:55 -0500
last_modified_at: 2024-08-15 17:46:53 -0400
toc: true
---

{% include header.html %}

Welcome to my photo blog of various "maker" things I am up to, mostly woodworking. The above picture is a sign hanging in my workshop, given to me by the family. It's pretty cool.

## About this site

### Home Page

The [Home Page]({% link index.html %}) is an reverse chronological listing (also known as "newest first" in non-geek speak) of the various projects I have taken on. As you go further back in time, the projects get a little more primitive...not that my more recent things are perfect, but you learn a lot over time in this craft. Some of those learnings I have actually managed to apply in my more recent efforts.

The home page, or home pages, are paginated into about eight to ten posts per page. Each entry has a summary of the project, along with a thumbnail pic that will drive everyone wild with anticipation of the upcoming experience.
{: .sjg-br}

### The Posts

The posts are usually, but not always, broken up into the following sections:
- **Background.**  Reasons why this project was done in the first place, along with cheesy stories to back up the rationale.  This section is sometimes labelled **Origins**, or **Introduction**, to keep things fresh.
- **Design.**  The planning behind the projects, sometimes include screenshots from whatever design software and processes I may have used.
- **Construction.**  The actual build.  Yeah, this section is kind of important, and also self-explanatory. 
- **In-use.**  I try to wrap up each post with a pic or two showing the piece in actual use, in its native habitat.
- **Materials.** A listing of tools and materials, and their suppliers, used in the project.  This section for the nerdy amongst us.

In the early days, I did not take many pictures of the shop or the projects as they were in progress, so a lot of the pics will be of the finished product. I will be taking more "under construction" photos as time progresses, hopefully that will make the posts more interesting to those who like a bit of the "behind-the-scenes" thing.

> **Note:** In any post, you can click on any pic and it will launch you into a mini-gallery where you can full-screen scroll thru all the pics in that post.  This is not to be confused with the [Image Gallery](#image-gallery).
{: .prompt-info .sjg-br}

### Image Gallery

The [Image Gallery]({% link _tabs/gallery.md %}) is an alphabetical listing of the best images from all the posts on the site, the top three or four per post. This is meant to be a purely visual experience, and it's a fun way to go through things.

> **Note:** If you see something of interest in the image gallery, you can click on the **image caption** to drill down into the original post. Also note that if you are viewing on a mobile device, an _up or down swipe_ can close the gallery. That way you don't have to hunt for the tiny "close" button.
{: .prompt-info .sjg-br}

### Timeline

For an interesting layout of the posts in chronological order, be sure to check out the [Timeline View.]({% link _tabs/timeline.md %}) The "Posted" date at the top of each blog post is actually the rough date of when the project took place, and this view is sorted by that timestamp.
{: .sjg-br}

### Categories

The [Categories]({% link _tabs/categories.md %}) link shows the posts group by their categories and sub-categories. I am just getting these categories sorted as of this writing. For now, there are two major categories: [Woodworking](/categories/woodworking), which is where the vast majority of posts exist, and [Home & Garden](/categories/home-garden), which only has a couple of posts right now, but I expect more to go there as things progress.
{: .sjg-br}

### Tags

The [Tags]({% link _tabs/tags.md %}) link will display a _tag wall_ splattered with every tag from every post. Click on a random one to see what fun that brings.
{: .sjg-br}

To all the fans of this website, pictured below, please be [let me know](mailto:steveng57@outlook.com) if you find any bugs or other inaccuracies. This is very much a work in progress.

## Favorite Posts

Here are some of my favorite projects:

<ul>
  {% for post in site.posts %}
    {% if post.favorite %}
      <li><a href="{{ post.url }}">{{ post.title }}:</a> {{ post.description }}.</li>
    {% endif %}
  {% endfor %}
</ul>

## Odds and Ends

I've started a subsite called **'pages'**, just a place to put various thoughts and sometimes rants on things.  It started as a place for me talk about the goings-on in the world, without disrupting the flow of this site, and seems to be evolving into a random mishmash of things coming out of my brain.  You can find it here at:  
[https://pages.stevengoulet.com](https://pages.stevengoulet.com){:target='_blank' rel='www.stevengoulet.com'}

## About the author

I have been focussing more and more on _maker_ type things, including woodworking for the last decade or so. While woodworking is my primary focus, I also like to include other things...anything high tech or gadgety will do quite nicely. Also fair game are life-hacks, yard / garden / house projects and other _maker_ things...but mostly woodworking.

Sometime in late 2016, I started to setup a workshop in the basement. Retirement was around the corner, and one of my father's favorite wisdoms was to _"retire to something, don't retire from something"_. My father is very wise.

I live in a rural suburb of Ottawa called Manotick with my wife Debbie and two boys, Riley and Ozzie.

{% include html-side.html img="20150131_134612.jpeg" align="center" caption="Debbie took this great shot of the boys" %}

{% include clear-float.html break = 2 %}

{% include html-side.html img="steven-sticker.png" caption="Enjoy the Blog!" align="left-33"%}

I am also a Pisces, which is silly because there is no science behind that stuff at all. The other thing you should know about me is that I am all about science. Actually, that one fact probably tells you a lot about me, from my political leanings, to my thoughts on religion, climate change, and more.

But if you must know, politics wise, I am fiscally conservative (you can't spend money you don't have), and socially liberal (the only thing I am truly intolerant of, is intolerance). Wait, TMI alert! Way too much information already!

If you'd like to drop me a note with a comment or connect, please use the [contact form](/contact/) here.

{% include clear-float.html break = 2 %}

{% include mydatetime.html date = site.time lang = lang prefix=  "This site was last generated on: "%}{: .post-meta .text-muted}
