---
title: "ScriptMate: Your co-writer"
description: "Co-write a script, or have an AI write one to your liking. Your choice!"
author: "Fabian Gonzalez"
# draft-project: /blueprints/homer
date: 2025-08-08
tags:
  - system-design
  - ai
  - social-media
  - assistant
---

# ScriptMate

_(name change pending)_

## Idea

A co-writing assitant AI. Without thinking into what gets implemented in which version, there will be 3 primary features in this: full-agent script writing/editing, co-writing a script, script-to-voice generation.

1. AI Script Writer: A user would be able to define multiple "writers" (i.e. ai agents) that have specific writing styles.
    - e.g. I define a "horror story writer" that specializes in horror stories. I can use that writer any time I want a horror story written.
    - If using K8s + `kagent`, through the UI a user would create a writer with specific moods & topics, and that would translate to an Agent CR.
2. AI Script Editor: This would act as a follow-up process to a pre-written script, either written by the user or by another script writer. Multiple editors (i.e. ai agents) can be defined.
    - e.g. I define both a "proof-checker" and "short conciser" agents. Any pre-written material can be passed to these agents to handle proof-checks, then shortening the content to a format that best fits video shorts.
    - If using K8s + `kagent`, through the UI a user would create an edirot with specific jobs (e.g. proof check) & modifiers (e.g. short content), and that would translate to an Agent CR.
    - **NOTE**: Currently my idea here is to pass in a script and the editor modifies + returns the output. Ideally in the future, it would act more like Grammarly with real-time co-writing.
3. Voice Actor: A user would be able to define different voice acters (i.e. tts actors) to use for specific moods/tones they want.
    - e.g. I use a low quiet voice for spooky videos.
    - I'm not sure if ElevenLabs has an SDK/API I can configure, but if it does then I would use that. LiveKit implements ElevenLabs, so hopefully that means there is a way. LiveKit would probably be overkill, since an AI agent or transmission isn't needed, just the TTS portion.
    - I would likely create a net-new CRD to make this open to non-elevenlabs implementation. High-level to declaratively define something like `VoiceActor: {vendor: elevenlabs, id: id-here}`.

Because of the nature of this architecture, my idea would currently only works for locally-hosted deployments of this. I would need a cloud-based version that's less k8s-reliant (e.g. storing agents + actor configurations on a database for users) for this to be a webapp hosted online. This would come with more issues like: how to handle api keys (users likely wont trust the app to provide their keys, but i'm not sure how providing a token-usage based system would look like...)

## Design

~~Since I spent a sum amount of money to buy this domain on a whim (oops lol)~~ In case I follow through and expand on this, I'll need to think about how much more to give off here. To be honest this has probably already been implemented, but still. I'll likely work on this to get an MVP out some time within this quarter, then add the design here post-creation.
