# VibeVerse — AI Mood-to-Story Generator

VibeVerse is a creative, multi-sensory AI application that translates user moods, feelings, or life moments into a personalized creative story, custom playlist themes, a matching color palette, and a text-to-speech audio readout.

Built for the **AWS Weekend Creative Challenge (August 14–17, 2026)**.

## 🚀 Live Demo
🌐 **[https://main.d3dtpnmjar5d19.amplifyapp.com/](https://main.d3dtpnmjar5d19.amplifyapp.com/)**

---

## 🏗️ Architecture Overview

```
Browser (AWS Amplify)
       │
       │ POST /
       ▼
API Gateway V2 (HTTP API)
       │
       ▼
AWS Lambda (Python 3.12, Sydney region)
       │
       ├──► Amazon Bedrock (Nova Lite)
       │     • Mood -> story + playlist + palette metadata
       │
       └──► Amazon Polly (Neural TTS)
             • Story text -> MP3 audio (base64)
```

- **Frontend:** Single-page app built with Vanilla HTML/CSS/JS (no framework overhead), hosted on **AWS Amplify**.
- **Backend API:** Managed **AWS Lambda** proxy integration exposed via **Amazon API Gateway HTTP API**.
- **Generative AI:** **Amazon Bedrock (Nova Lite)** for parsing mood and generating structured output.
- **Speech Synthesis:** **Amazon Polly** for generating neural narrative voiceovers.

---

## 🛠️ Local Setup & Deployment

### 1. Prerequisites
- Configure your AWS CLI:
  ```bash
  aws configure
  ```
- Ensure you have requested model access to **Amazon Nova Lite** in the Amazon Bedrock console (Sydney or US East regions).

### 2. Deploy Backend & API
Run the automated deploy scripts:
```bash
# 1. Deploy Lambda backend
bash deploy.sh

# 2. Deploy API Gateway V2 HTTP API
bash setup_apigateway.sh
```

### 3. Deploy Frontend to Amplify
Initialize and deploy the Amplify app using your preferred method (CLI or zip drag-and-drop on the AWS Amplify Console).
