---
author: sjg
layout: post
title: Solar Pool Heater
description: A solar powered pool heater and solar powered pump
date: 2025-05-01 21:19:42 -0500
last_modified_at: 2025-05-22 21:48:08 -0500
categories: [Home & Garden, House Tech]
tags: [House Tech, Woodworking, Solar]
image:
  path: /thumbnails/IMG_1811.jpeg
  alt: Solar Pool Heater
media_subpath: /assets/img/posts/solar-pool-heater
favorite: false
---
{% assign pex_pipe = "[PEX pipe](https://www.familyhandyman.com/article/pex-connections/){:target='_blank'}" %}
## Background
This project was done a while ago actually, May of 2022.  I had to do a tune-up on it, so I figured while I was at that, I would take some pics an write a post.

I decided to some experimenting with solar, to get a better feel for how it works and how efficient it is etc.  Lots of online videos later, I took the plunge.

## The Design
Did the usual design work in Sketchup to make sure the plans were workable.  Didn't want to get it put together and not have enough room to tilt it towards the sun.  That would be a bad thing.

{% include html-side.html img="solar-panel-sketchup.jpeg" align="center" %}


## The Insides
The internals of this device are kept on the platform under the panel and water coil.  I still need to find a better way to hold these things in place and organize them better, but they seem to do okay this way for now.

From left to right:

{% include html-side.html img="IMG_1810.jpeg" align="left" %}

### The Battery
The battery is definitely over-capacity for this application, but hey, that's how I roll.  It's a lithium 12V battery, the same standard kind that would power a small tractor, but not as big as a car battery.  The battery directly powers the water pump (far right).

### The Controller
THe controller is a gizmo that takes power from the solar panel and regulates the current for charging the battery.  
So the solar panel actually charges the battery, but it doesn't feed power to the pump directly.

### The Water Pump

The water pump is powered directly by the battery, not the solar panel.  This pump is the kind found in RV's for moving water to the sink and shower.

{% include clear-float.html break=1 %}

## The Outsides
The solar panel and water coil are kept in a housing made from 2x4's.  This housing is mount on a steel tube (a beefy curtain rod if I am not mistaken) which can be rotated to follow the sun.

From left to right:

{% include html-side.html img="IMG_1809.jpeg" align="right" %}

### The Solar Panel
A modest solar panel.  It's 100 Watt solar panel from Renogy.  Meaning that, on a bright day, it can run a 100W light bulb.  

15 of these panels could power a blow-dryer.  Yes that's why you need so many panels to do anything useful.  In my case the panel just needs to keep the battery charged, which it does not have any problem doing, even on cloudy days.

### The Water Coil
This is where the magic happens.  The coils are made from a variety of {{ pex_pipe }} used for heating floors and things, and it is held in place by four long wooden rods.  The {{ pex_pipe }} is orange originally, but painted black with a heat tolerant black spray paint made for painting BBQs. 

Sunlight hits the coils, heats the coils and thusly the water inside.  Heat is trapped inside the coil housing by insulation on the sides and the back, and by plexiglass on the front.

{% include clear-float.html break=1 %}

## The Results

In terms of power savings, I would say that on a good sunny day, it can cut the natural gas used to heat the pool by about 1/3.  Not too bad.  Now, in practice, it's never perfect sunshine all day, and sometimes I forget to move it into a position to get maximum sunshine on the coil, so our savings are a bit less than that.  Overall, it works well enough and I am happy with it.

Having lived with this device for three pool seasons at the time of this writing, I can easily say I would do a few things differently if I were to do the project today.
- I have often said that I overbuild things, I use more glue than necessary, thicker boards than necessary etc.  This thing is pretty beefy and somewhat difficult to maneuver because of that.  I should have made it lighter weight, using 2x3's instead of 2x4's for example, and using 1/2 plywood on the back instead of 3/4 inch
- The side supports need to hold up a lot of weight (see previous bullet) and because of that the legs need to be really solid.  My design was ok in that regard, but not great.  By the third season, the legs were getting a little wobbly, so I had to beef them up by adding metal supports where the legs come over the bottom platform, and adding a cross support.  This latter fix added even more weight (see previous bullet)
- I should have figured out a way to make the whole thing waterproof.  By definition, this has to be in the sun to work, and when a sudden storm comes along, it is a panic to get it covered up

## Materials and Tools

- Standard pressure treated 2x4's and plywood from Home Depot
- {{ pex_pipe }}, also from Home Depot
- 100W Solar Panel Kit from [Renogy](https://www.renogy.com){:target='_blank'} via Amazon
- Dakota lithium battery from [Total Battery](https://www.totalbattery.com){:target='_blank'}
- 6 inch casters (with brakes) from {{ site.data.links.leevalley }}
{:.sjg-list }
