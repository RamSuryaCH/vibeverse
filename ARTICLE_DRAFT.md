# Weekend Creative Challenge: VibeVerse — AI Mood-to-Story Generator

**Tag:** #creative-expression

---

## Vision & What the App Does

Have you ever felt a powerful emotion — a rush of joy, a quiet sadness, a restless 3am energy — and wished you could just *live inside that feeling* for a moment, expressed beautifully?

That's exactly what **VibeVerse** does.

You type in a mood, a feeling, or a life moment — "I just got rejected from my dream job," "first morning of summer vacation," or "falling in love and everything feels surreal" — and VibeVerse generates a world around that feeling:

- A **personalized story or prose poem** written specifically for your mood — vivid, emotional, and human
- A **curated playlist concept** with an evocative title and five track themes that match the vibe
- A **color palette** of 4 hex codes and a poetic description of what those colors feel
- An **audio narration** of your story, read aloud in a warm voice

The result is a beautiful "vibe card" — a creative artifact of your emotional moment. You can close your eyes and listen to your story, stare at the colors, and feel understood by a machine for a few minutes. That's the magic of VibeVerse.

---

## How I Built It

### The Idea

I wanted to build something that felt *genuinely creative* — not just a chatbot wrapper. The mood-to-story idea came from a simple question: what if AI could translate emotions into multi-sensory experiences? Words, color, and sound together feel much richer than any one alone.

### Development Process

I started with the Lambda backend first. The key challenge was **prompt engineering** — getting Amazon Bedrock's Nova Lite model to consistently return structured JSON (story + playlist + palette + vibe tag) without markdown formatting breaking the JSON parse. My solution was a strict system prompt that explicitly says "respond with ONLY valid JSON, no markdown," combined with a defensive fence-stripping parser on the Python side.

For the color palette, I found that asking the model to generate hex codes alongside a poetic description worked surprisingly well — the model naturally associates emotional tones with color temperatures (warm ambers for nostalgia, cool blues for melancholy).

The **Amazon Polly** TTS integration was the smoothest part. The neural "Joanna" voice has a warmth that makes prose feel genuine rather than robotic. I return the audio as a base64-encoded MP3 directly in the API response, so the frontend doesn't need a second round trip or S3.

### Challenges

The biggest challenge was **JSON consistency from the LLM**. Sometimes the model would add a preamble like "Here is the JSON:" before the response. I handled this with a strip-and-split approach in Python. A temperature of 0.92 gave me creative, varied stories while staying coherent.

Another challenge: Polly has a 3,000-character limit per `SynthesizeSpeech` call. I added a slice at 2,999 characters to prevent silent failures.

---

## AWS Services Used / Architecture Overview

```
Browser (Amplify Hosted)
       │
       │ POST /
       ▼
AWS Lambda (Python 3.12, Function URL)
       │
       ├──► Amazon Bedrock (Nova Lite)
       │     • Mood → story + playlist + palette + vibe tag
       │     • Structured JSON output via system prompt
       │
       └──► Amazon Polly (Neural TTS)
             • Story text → MP3 audio
             • Returned as base64 in API response
```

| Service | Role | Free Tier |
|---|---|---|
| **Amazon Bedrock (Nova Lite)** | Story + playlist + palette generation | ~$0.0002/call |
| **AWS Lambda** | Serverless backend, Function URL | 1M requests/month free |
| **Amazon Polly** | Neural text-to-speech narration | 5M chars/month free |
| **AWS Amplify** | Frontend hosting (static HTML/JS) | 15 GB/month free |

No API Gateway, no database, no persistent storage — beautifully simple and cost-effective.

---

## What I Learned

**1. Nova Lite is impressively creative.** I expected a "lite" model to produce generic output, but with the right system prompt and a high temperature, the stories it generated were genuinely moving. The model understood emotional nuance — "3am restlessness" produced very different output than "peaceful morning."

**2. Function URLs are underrated.** Skipping API Gateway entirely and using a Lambda Function URL simplified the architecture dramatically. CORS configuration is handled natively without extra infrastructure.

**3. Multi-modal output elevates the experience.** Combining text + color + audio made VibeVerse feel like a *product*, not a demo. The audio especially — hearing a story about your own mood read aloud — creates an unexpected emotional resonance.

**4. Prompt engineering is engineering.** Crafting the system prompt took as long as writing the Python code. Being explicit, structured, and anticipating model failure modes (markdown leaking into JSON, long preambles) is a real skill.

---

## Try It / Source Code

🌐 **Live app:** https://main.d3dtpnmjar5d19.amplifyapp.com/

💻 **GitHub:** https://github.com/RamSuryaCH/vibeverse

---

*Built for the AWS Weekend Creative Challenge — August 14–17, 2026.*
*Powered by Amazon Bedrock, Amazon Polly, AWS Lambda, and AWS Amplify.*
