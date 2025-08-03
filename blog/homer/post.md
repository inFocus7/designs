---
title: "Homer: AI-Assisted Smart Home Management System"
description: "Manage a variety of smart home resources from multiple vendors."
author: "Fabian Gonzalez"
# draft-project: /blueprints/homer
date: 2025-08-03
tags:
  - system-design
  - ai
  - smart-home
---

# Homer

_This is just a POC. Not really a production-ready, or production-safe design. Having fun thinking about this._

## Purpose

Most people likely have all-in-one smart home solutions that are vendor-specific. But lazy me (and maybe cheap me) was wondering about buying cheap(er) smart devices from different vendors. Or what if I got some high-quality outdoor cameras for security from some vendor, and bought cheaper ones for indoors from a budget-friendly vendor. The main issue -- purely an annoyance -- would be going through various vendor apps to access those vendor-specific devices.

## Design

Below I attached the first iteration of Homer's design. Because I've been working with k8s a lot, I pictured this as a k8s implementation.

I didn't really include any 'advanced' concepts such as gateways/mesh routing, because this design is primarily a simple **local** network deployment which would mainly be communicating with existing vendor APIs. Envoy gateways _may_ make sense to securely handle extra-network communications. If so, that will be in a `v2` iteration of this design going through the networking aspects of this.

![Homer System Design (v1)](./assets/Homer%20Design%20v1.png)

_Note: The image **should** be embedded with Excalidraw information to load it in Excalidraw._

### Control Plane

Maybe a control plane isn't the right terminology as I still have to think of this purpose aside from exposing an interface (e.g. webapp) for user-friendly interactions.

### Discovery Service

The discovery service handles periodically using the enabled adapters to sync available smart home resources (e.g. thermostats, locks, alarms.)

_Note: I chose a discovery service to handle this because it could help avoid having the MCP/LLM waste tokens and time doing a "get_available_devices()" before trying to do whatever tool call it needs._ 

### Homer Assistant AI Agent

This is the AI agent which exposes the tools from our defined MCP adapters.

A user would hopefully be able to leverage this through some (unknown) client/interface and simply state "Lock all doors" or "Set living room temp to 68 degrees". Better yet would be to use voice assistance which would then be passed onto the Homer Assistant Agent and so on.

The more I thought about this, an AI agent could be an _additional_ good-to-have, where the main project is for having a centralized management plane for multi-vendor smart devices. The AI agent would just make it more agentic and easier for users to avoid going through the GUI or going through different apps.

### Custom Resource Definitions

Homer would install Custom Resource Definitions which represent the different smart home devices.

Devices would follow this basic CRD:
```yaml
apiVersion: devices.homer.io/v1alpha1
kind: Camera
metadata:
  name: <name>
  namespace: homer-system
annotations:
  category: security
  vendor: honeywell
spec:
  id: <identifier in vendor-owned api>
  name: <user friendly name to display (e.g. "front porch")>
  tags:
  - <tags mainly for ui (e.g. "outdoors")>
status:
  lastUpdated: <timestamp>
```

Each device would have additional `specs` based on needs (e.g. cameras may have a `stream: {url, streamType}` for streaming)

- Why CRDs?
  - Kubernetes native.
  - I wanted to avoid having the MCP handle _everything_ from getting devices to messing with them. Specifically the first, since I don't want each "do {this} to device {x}" to require a pre-cursor call of "does {vendor} have devices {x}". I could probably think of a better design though... 
    - But still, having custom resources could eventually allow for advanced usages, such as setting up custom connections to homemade/proprietary devices.

- Question: How would the api key be tied? based on vendor annotation?

### Secrets

There are two main types of secrets we'll handle:

1. Secret for LLM API Key [assuming external-based like Anthropic]
2. Secret for vendor API Key

### Adapters

There are two adapters:

1. Go Adapters
  - This is the main logic handler. The idea would be that each supported vendor would have a Go adapter that can communicate with their APIs.
  - The adapters would be used by the discovery service (by getting available devices + metadata from vendors), and the MCP adapters (by exposing ways to handle those.)
2. MCP Adapters
  - These would essentially be simple wrappers exposing the go adapter methods as `tools`.
  - It is solely for the Homer Assistant Agent to have an understanding of what and how it can do things.
  - A device/system would still be accessible without an MCP adapter through the GUI/control plane, but at the cost of no agentic-ness 😔. 

- Question: Is the Go adapter implementation extendable? I.e. how would someone implement a local custom adapter to handle custom devices like raspberry pie-based security cameras?

### Web Application

A simple GUI should suffice. It's purpose would be to expose the resources in a clean interface as well as to enable the adapaters and set up their connections (e.g. API Keys) so that the discovery service handles syncing.

## Unknowns

### Streaming

I'm not entirely sure how streaming works in systems (e.g. what libraries are used and if streams are usually exposed through vendor-owned APIs.) If they are, then it _should_ be possible to expose that functionality as part of this and through the **webapp**.

While I was thinking about this, I was primarily thinking of simpler non-streaming actions such as turning on/off devices, simple thermostat updates, etc.

### Implementation

I still need to think about implementation details, but `kagent` could at the very least be used for declarative K8s agents, specifically the Homer Assistant Agent. I'd need to investigate, but it _may_ be possible to declaratively spin up `kagent` with the Homer Assistant Agent defined + MCP connections.

It may be overkill since we would only require that one agent to exist, as this not a multi-agent/complex system. _But_ doing it this can help avoid defining the LLM secret/connection implementation as we'd let `kagent` handle agentic communication, while we focus on the actual implementation. It may also make it easy for someone to set up/test out custom MCP tooling for their own smart home environment. Will need to think about this possibility more. 

## Limitations

This would heavily be dependent on whether or not the smart home item can be accessed through an API. For instance, if you own a smart camera from vendor "ABC, inc.," and they do not have an API you can (preferably securely) access, then an adapter won't be able to be written to fit into this system.

There would also need to be a **big** focus on security, specifically ingress traffic. I wouldn't want a random person to attack my network, be able to enter these services and start (un)locking and messing with my smart devices.