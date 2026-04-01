# MangaLens Privacy Policy

Last updated: March 31, 2026

## Overview
MangaLens is a Chrome extension that translates manga and webtoon panels using AI. 
This policy explains what data the extension handles and how.

## Data We Collect
MangaLens does not collect, transmit, or store any data on developer-owned servers.

### API Keys (Authentication Information)
- Users may enter API keys for Claude (Anthropic) or OpenAI
- These keys are stored locally on your device using Chrome's built-in storage API
- Keys are sent only to the respective AI provider's API when you request a translation
- Keys are never sent to the developer or any third party

### Panel Screenshots (Website Content)
- When you click the translate button, a screenshot of the manga panel is captured
- This screenshot is sent directly to your chosen AI provider (Anthropic, OpenAI, or your local Ollama instance)
- Screenshots are not stored, logged, or seen by the developer
- Translation results are cached locally on your device for 7 days to reduce API usage

## Data We Do NOT Collect
- No personal information
- No browsing history
- No usage analytics
- No crash reports
- No data of any kind is sent to the developer

## Third-Party Services
When you use MangaLens, your panel screenshots are sent to the AI provider you select:
- **Anthropic (Claude):** https://www.anthropic.com/privacy
- **OpenAI (GPT-4o, GPT-4.1 Nano):** https://openai.com/policies/privacy-policy
- **Ollama (local):** Runs entirely on your device — no data leaves your machine

## Contact
If you have questions about this privacy policy, open an issue on the GitHub repository.
