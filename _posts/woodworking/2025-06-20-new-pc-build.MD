---
author: sjg
layout: post
title: Building a New PC
description: The old one went kaput, so time for a new computer
date: 2025-06-20 21:19:42 -0500
last_modified_at: 2025-06-26 21:48:08 -0500
categories: [Home & Garden, House Tech] 
tags: [Computer, PC, House Tech]
image:
  path: /thumbnails/IMG_1927.jpeg
  alt: Pool Mat Shelf
media_subpath: /assets/img/posts/new-pc-build
favorite: false
pin: false
---
## Background

So around the beginning of the month, my desktop PC began to give up the ghost.  I have my operating system (OS) on one drive and my data on another physical disk.  At first it just looked like the data drive was going, meaning one of the disks in the [RAID](https://en.wikipedia.org/wiki/RAID){:target='_blank'} array was snafu'd. 

However, things deteriorated rather rapidly from there, and all of a sudden the data drive was not reachable, and not long after that the OS itself disappeared.  I just got a flashing cursor on the screen, and eventually that stopped happening too.  No signs of life at all.  Admittedly, this was a strange failure that I had not seen before, but sometimes tech fails in odd ways.  I am pretty sure it was the motherboard that went south, though I guess it could have been the CPU too. It was 12 years old and had served me very, very well.  

Given that it was built in 2013, it did not make a lot of sense to try and salvage anything, I just went straight to a new build, started doing research etc.  I have built about a half dozen machines in my time, but there was a bit to learn here, since the last time I did a full build was over a decade ago.  Things have changed a lot in some places, not so much in others.  Details below.

## The Design

Just as in my previous builds, I had two main criteria:

### Speed

Everyone wants the fasted speed possible in their PC, but how you get then and the tech you choose can make the difference.  

I am not a gamer (nor am I a crypto minor), so GPU speed was not a big thing.  I do a lot of 3d modelling and the like though, so something CAD capable was needed.  

CPU and disk speed were paramount though, so I did splurge a bit on the latest gen i9 Intel chips and a good motherboard.  I also went pure [NVME M.2 SSD](https://en.wikipedia.org/wiki/M.2){:target='_blank'} throughout, which for those not in the business means **fast**.  Instead of spinning disks fetching your data over a slow connection, these drives have not moving parts and are all on chips connected to the CPU via a super fast bus.  This proved to be a great call, and I am super happy with the speed of the build.  But I will leave you in suspense for now, see the results section at the bottom for details!

### Silence

I really wanted a quiet machine.  My very first build did not take this requirement seriously, and as such, I ended up with a PC that sounded more like a small airplane than anything. It was hard to sit by the thing for more than an hour without getting frazzled and annoyed.  The fans were on high all the time and the disk drives seemed to whine at the worst possible frequency.  I was not happy.

In this build I made a number of decisions that were based on noise level, and I don't think I had to compromise too much. 

## The Purchase

One thing that has gotten a lot better since the last time I did this is the _'configurators'_ available on sites like Newegg.  These help make sure you buy compatible parts that all work together nicely.  It's no fun when you go to plug something in and realize it's the wrong pin configuration or something.  Ask me how I know!

{% include html-side.html img="IMG_1915.jpeg" align="center" %}

I give Newegg a **B-** rating overall.  The parts configurator was great, prices seemed competitive with Amazon etc.  My main complaint was that I paid for expedited shipping for the whole purchase (hey I am a geek, I cannot live without a PC for long), and while most of the order arrived pretty quick, the motherboard took almost a week longer than everything else to get here.  And you really can't do anything without a motherboard: literally everything plugs into it.  

## The Parts

{% include html-side.html img="Fractal-Case.png" align="right-50" %}

### The Case 

I went with the Fractal Design case, similar to the one pictured here.  

It's a great case and boasts a truly silent design, with sound dampening padding on all available interior surfaces.

{% include clear-float.html break=1 %}
{% include html-side.html img="intel_core_i9_14900k_3.jpeg" align="left-50" %}
### The CPU

For the CPU, I chose the latest from the Intel line, the i9 14th generation.  I like AMD too though, but I feel bad for Intel these days, so let's call it supporting an old partner.

{% include clear-float.html break=1 %}

{% include html-side.html img="gigabyte-motherboard.png" align="right" %}
### The Motherboard

This was a bit of a departure for me.  The Gigabyte brand of motherboards is targeted a bit more towards gamers, which means it has a lot of overclocking features and stuff for flashy RGB light do razzle-dazzle on all your components.  I don't need or even want those things as they can destabilize things, and my PC is hidden behind the desk anyway. 

Even so, I went for it as the specs were great: it has the latest and greatest everything, including PCIe 5.0 and M.2.

From their website:
- Supports Intel® Core™ 14th gen processors
- Dual Channel DDR5：4 DIMMs with XMP 3.0 memory module support
- PCIe UD Slot X： PCIe 5.0 x16 slot with 10X strength for graphics card
- UC BIOS：User-Centred intuitive UX with Quick Access function
- Ultra-Fast Storage：5 M.2 slots, including 1 PCIe 5.0 x4
- Efficient Overall Thermal：VRM Thermal Armor Advanced & M.2 Thermal Guard XL
- Fast Networking：5GbE LAN & Wi-Fi 7 with Ultra-high gain antenna
- Extended Connectivity：HDMI, DP IN, Front & Rear USB-C® 20Gb/s
- High-Res Audio：ALC1220 & Audiophile Grade Capacitors
{% include clear-float.html break=1 %}

{% include html-side.html img="corsair-ssd.png" align="left" %}
### NVME 2.0 SSD

This is where a lot of the speed came from. 

This is entirely new tech since my last build, and while I had heard of it before, I didn't think it was going to be such a game changer.  PCIe 5 NVME 2.0 SSD, write that one down! 

There are four of them in my setup, 2 terabytes each for a total of 8TB.  They are configured via the motherboard to be RAID 10, which is a combination of striping (for speed) and mirroring (for reliability).

This is what a modern "hard drive" looks like.  All chips, no disks.

{% include clear-float.html break=1 %}

{% include html-side.html img="T1000_3QTR-Front-Right.png" align="right" %}

### The Video Card

Now the hardcore gamers and the crypto kids are going to go for something like the Nvidia RTX 5090 or the like.  

For me though, that would be a waste of money and energy.  Those beasts require a lot of power, and power produces heat, and heat turns the fans on high.  Fans on high make noise: see requirement #2 above.

So I went with the Nvidia T1000.  Not sure why they felt the need to steal the model number from [The Terminator](https://en.wikipedia.org/wiki/T-1000){:target='_blank'}, but there you are.  It is a more "workstation" oriented video card, meaning that it is geared for 3d modeling, multiple monitors etc.  

And unlike its beefier counterparts, it is smaller only has one fan, which translates into less noise.  In summary, it seems perfect for my needs. 

{% include clear-float.html break=1 %}

## The Assembly

I took over the dining table for the assembly phase.  Lot of moving parts in any new PC build.  You even get a bunch of extra parts that you don't need, for example they send parts for Intel chips and for AMD chips, but you are only every going to use one of those.  Keeping tracking of the parts is super important.

> The Instructions are terrible.  It doesn't matter which part we are talking about, they are all atrocious. If you every want to try a PC build yourself, be prepared for that.  The manufacturers websites are sometime helpful, and YouTube is your friend here.
{: .prompt-warning .sjg-br}

{% include clear-float.html break=1 %}

{% include html-side.html img="IMG_1917.jpeg" align="left" %}
### The Layout

I started by getting all the parts together and laying them out on the table.  Opening boxes and pulling out the limited (very limited) instructions came next.

{% include clear-float.html break=1 %}

{% include html-side.html img="IMG_1920.jpeg" align="right" %}
### Diving In

Opened up the case, pulled out the parts that I wouldn't be using (no need for any old fashioned hard drives in this build!)

Got some sorting trays (the yellow trays here) from Lee Valley for keeping the screws and other small parts.  This seemingly trivial thing made a huge difference in keeping everything organized.

{% include clear-float.html break=1 %}

{% include html-side.html img="IMG_1928.jpeg" align="left" %}

### The Water Cooler

This was new for me.  

The standard mechanism for cooling a CPU is to hook up a big fan to the back of the CPU.  And that works, but those fans can be noisy (see requirement #2 above) so I figured I would give CPU water cooling a try.

It turns out to be easier than I thought, you hook up the cooling block to the CPU the same way you would a CPU fan, but there are hoses coming out of the block that run to a series of fans (quiet ones) across the top.  You can see two of them in the pic up high.

{% include clear-float.html break=1 %}

{% include html-side.html img="IMG_1926.jpeg" align="right" %}
### Power Supply

Last but not least was hooking up the power supply.  Nothing at all different here, this one had the same connections as the one I installed 12 years ago.
{% include clear-float.html break=1 %}

## Power On

{% include html-side.html img="IMG_1927.jpeg" align="center" %}

It is always a great moment after a build when you power things up and they all work properly.  

If there are problems, there are usually a series of angry beeps produced by the motherboard or the offending components, or in a worst case scenario...crickets.  In this case, everything worked great the first time, and I started configuring things in the BIOS and installing the operating system, Windows 11.

{% include clear-float.html break=1 %}

## The Results!

So let's get to it then.  How did all this turn out? 

I must confess to being a little giddy at the results, they far exceeded my expectations...I figured at best the average performance would be 2x or 3x my old setup, but this blew me away.  

Here is a key benchmark: when I build this website from scratch, that is I fire up the mechanisms that turn my raw pages into functioning HTML, it normally used to take around 90 seconds.  Now, on the new machine, it takes...less than 6 seconds.  I will save you from doing the math.  

That is...
<div style="font-size:4em; font-weight:bold; text-align:center; margin: 1em 0;">
  15x Faster
</div>
I could do a bar chart or something to drive the point home, but I hope you get it.  Yes, that's right, it is 15 times faster than my old machine at doing the standard stuff I do all the time.  Wow!  I attribute most of this speed increase to the NVME 2.0 SSD used for the OS and data drives.  They are speedy.

## Materials and Tools

- Most parts were bought at [Newegg.ca](https://www.newegg.ca){:target='_blank'}
- A Philips #2 head screwdriver, supplied from you local toolbox 
{:.sjg-list }
