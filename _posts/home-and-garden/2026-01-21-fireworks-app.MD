---
author: sjg
layout: post
title: Fireworks App
description: Something from my bucket list, a fireworks simulator app 
date: 2026-01-21 11:19:42 -0500
last_modified_at: 2026-01-21 11:48:08 -0500
category: [Home and Garden, House Tech] 
tags: [Computer, PC, House Tech]
image:
  path: /thumbnails/Square1024x1024Logo.avif
  alt: Fireworks Fun
media_subpath: /assets/img/posts/fireworks-app
favorite: false
pin: false
---
## Background

January 1st came around, and with all the cool fireworks displays, it got me to thinking about an old fascination I had with simulation software and fireworks.  It has been on my _bucket list_ to write a fireworks simulator for a while, but my software skill-set was more around server side development and video production.  I knew a little about game design and GPU coding, just enough to be dangerous.  With the advent of AI co-coders like Github Copilot and Codex (from OpenAI, the same folk who brought you ChatGPT), I figured I would give it a try.  This post will have some geek aspects to it, since it is largely about writing this app, but I think the non-software engineers out there might fight it interesting as I share some of my take on what it is like to code with an AI assistant (or two or three as you will see).

If you want to play along with any of this, see the app itself or look at the code, it is in a public Github repo here: [Fireworks App](https://www.github.com/steveng57/fireworksapp){:target='_blank'}.  A link to the most recent release and installation instructions can be found on the right side.  Enjoy!

## The Environment

### The Platform
I am a C# developer by trade, I spent a good chunk of my career in "devdiv" (developer division at Microsoft) working on developer tools focussed on C# and .NET.  It is a great platform, and while I haven't used enough of the competitor's platforms to offer a comparison, I know that it works for me, so I was down with that.

Once on the C# path, DirectX seemed the next logical step.  There are more sophisticated options out there (the Unreal Engine came up a lot), but it is pretty complex and has a super steep learning curve.  The AI recommended DirectX v11 over v12 which was surprising, as it cited a lot of unnecessary complexity in v12.  Ok.

Visual Studio was the dev env of choice.  As much as I like VS Code, nothing beats the power you get from the full Visual Studio experience when debugging and diving deep.

### The AI

I have used Github Copilot a lot over the last couple of years, it is billed as "Your AI pair programmer", and it is very good at that.  There are lots of things I just would not have attempted to do without it, so it was the natural choice here.  

As I was proceeding through the development stages however, I decided to add a couple of other AI to the mix, namely ChatGPT and GPT Codex.  More details on this below, but in general here is how they were used.
- **Github Copilot:** Github Copilot did most of the heavy lifting in writing code.  It was operating in "Agent Mode" most of the time, which lets it directly modify the code and make changes as it wants.  One must keep good point to "undo" however, as CP does gets things wrong occasionally.
- **ChatGPT:** ChatGPT was used as the conceptual AI, knowing about fireworks at the high level, as well as the high-level code behind it.
- **Codex:** Codex is OpenAI's developer centric AI, and it was used as a code review specialist.  Sometimes it was also used for a second opinion on complex coding efforts.  

> Author's note:  I know there is a lot of overlap between these AI and how they are used (ie ChatGPT is sometimes the brains behind GitHub Copilot etc, when I categorize them as above I am referring to the primary UI experience that comes with each of these AI.).
{:.prompt-info}

## Building the App

So I am going to dive into the creation of the app here, but I am going to focus on how it worked with the AI, as I think a post on my coding efforts might be a tad dry.

### Initial Setup

So to get started, I had a conversation with ChatGPT about options.  I asked some general question about how this kind of an app might be done, and it put out a list of a bunch of things: stuff gamers use, stuff animators use, stuff simulators use.  I was thinking it would guide me to using a "physics engine" or a "particle engine" for some of the work, but ChatGPT thought it was overkill and that we could make it work better and simpler without it.  I said "Ok", and went into Visual Studio to create the app and have Github Copilot (CP from here on in) generate me a skeleton, a code outline if you will that had the right folder structure and placeholders for the moving parts, though all were blank at this point.

### First builds

As mentioned, I am not a gamer or graphics developer, so I spent some time trying to understand what CP had created and how it worked.  The code didn't do much more than open up a blank window at this point, but it did work.

I gave CP the conceptual overview of what I was after, and we started simple, just generating a launch pad for the fireworks, which is really nothing more than a blue square.  This took a surprising amount of work since CP and I just were not on the same page.  It was training me (indirectly) as much as I was training it.  

## Thoughts


## Resources

- Github Copilot details can be found at  [Github Copilot](https://github.com/features/copilot){:target='_blank'}
{:.sjg-list }