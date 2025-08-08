---
title: "Walkways.ai: Your career interview assistant"
description: "Keep track of your job search and get recommendations based on performance with the help of an agentic assistant."
author: "Fabian Gonzalez"
# draft-project: /blueprints/homer
date: 2025-08-08
tags:
  - system-design
  - ai
  - career
---

# Walkways.ai

## Idea

An app focusing on interview tracking and readiness based on the interview stage a user is in.

### Thought Process

Thought of this while browsing Reddit and those posts from [r/cscareerquestions](https://www.reddit.com/r/cscareerquestions/) that have that branching application status were showing up.

I've been doing some front-end(ish) work recently and I just realized how bad I've fallen on my front-end knowledge. I thought of writing up a small web-app that made these types of graphs to get some practice again, especially since it's small enough to be doable. 

It was late, so I jotted it down. But, before I could fall asleep, I thought: It'd be pretty neat if at each interview stage someone is in, that they could get dynamic/relevant recommendations on what they should brush up on.

E.g.: Someone applies to Google. They are at the interview stage, so the webapp recommends what to brush up on. They pass the interview stage and are in the first round of technical interview, so the webapp recommends what to study for this point. cont.
_I'm not sure how the actual interview process goes, so this may be wrong, but the idea stands._

After thinking of this, I thought that it would be hard to _manually_ keep track of each company and generate dynamic content for them, so a more rounded approach: AI, specifically LLM + helper agents. This means that on each stage, an agent would gather relevant details and recommendations.

After this, I thought, "Since it would have some 'AI' support, why not expand on this idea?" And so I did. This led to the following: having the agent "follow-up" with the user post-interview and application status update.

With this, then the agent can have knowledge on the applicant's skills, weaknesses, etc. to make better recommendations as they progress.

#### Post-v1 Addition

Aside from learning recommendations, what if there's a voice agent (via LiveKit) that can be used to give short mock interviews? Behavioral interviews make most sense, to gain feedback on answers, but technical interviews could also be possible. I think for simplicity, behavioral interview would make most sense here.

### Open Questions

- How can user context/knowledge like this be stored in an agent (or database, or elsewhere)?

## Design

Since I spent a sum amount of money to buy this domain on a whim (oops lol), I'll need to think about how much more to give off here. To be honest this has probably already been implemented, but still. I'll likely work on this to get an MVP out some time within this quarter, then add the design here post-creation.
