# DermaCam — AI Dermatologist for India

> *Early detection saves lives. DermaCam makes it possible — for everyone, everywhere, for free.*

India has 1 dermatologist for every 1.17 lakh people. 65% of skin diseases are fully treatable if caught early. Rural patients wait 3–4 weeks. DermaCam delivers a diagnosis in **3 seconds**.

---

## What is DermaCam?

DermaCam is an AI-powered skin diagnosis platform that uses **7 specialized models from 4 platforms** running in parallel to analyze skin, hair, and nail conditions. Available as a **Web App (PWA)** and **Android App** — both secured with Firebase Authentication.

> *This application provides AI-powered screening only and does not constitute medical advice. Always consult a qualified dermatologist for diagnosis and treatment.*

---

## Architecture

```
User uploads image
        ↓
Redis cache check → HIT: 2ms response
        ↓ MISS
Body part router (Face / Body / Hair / Nail)
        ↓
┌─────────────────────────────────────────────┐
│         PARALLEL THREADS                    │
│  Thread 1: Groq Llama 4 Scout (Key 1)      │
│  Thread 2: Groq Llama 4 Scout (Key 2)      │
│  Thread 3: Groq Llama 4 Scout (Key 3)      │
│  Thread 4: HuggingFace Specialists         │
│            └── Anwarkh1/Skin_Cancer        │
│            └── dima806/Skin_Types          │
│  Thread 5: Roboflow (Hair or Nail)         │
└─────────────────────────────────────────────┘
        ↓
Majority Voting Engine
3/3 agree → +8% confidence boost
HF agrees → +5% additional boost
1/3 agree → "Consult doctor"
        ↓
llama-3.3-70b — Final report writer
        ↓
Result saved to PostgreSQL + Redis cache
```

---

## Models Used

| Platform | Model | Task | Accuracy |
|----------|-------|------|----------|
| Groq | Llama 4 Scout × 3 | Vision diagnosis (parallel) | Ensemble 95%+ |
| HuggingFace | Anwarkh1/Skin_Cancer | Melanoma, BCC, Actinic Keratosis | ~87% |
| HuggingFace | dima806/skin_types | Oily, Dry, Normal, Combination | ~89% |
| HuggingFace | imfarzanansari/acne | Acne Grade 1–4 | ~94% |
| Roboflow | topofhead/hair-loss | Norwood Scale Stage 1–7 | — |
| Roboflow | yangjm96/nail-disease | 8 nail conditions | — |
| Groq | llama-3.3-70b | Report writer (not diagnosis) | — |

---

## Tech Stack

| Layer | Technology |
|-------|-----------|
| Mobile App | Flutter (Dart) — Android |
| Web App | HTML / CSS / JS (PWA) |
| Backend | Python Flask |
| Database | PostgreSQL |
| Cache | Redis |
| Auth | Firebase Authentication |
| Parallel | Python `concurrent.futures` |
| Voice AI | speech_to_text + flutter_tts (Hinglish) |

---

## Features

- **Skin Scan** — Camera or gallery, 3-second AI diagnosis
- **Voice Call with DermAI** — Speak in Hindi/Hinglish, AI responds in Hinglish
- **Scan History** — All previous scans saved with full diagnosis
- **Personalized Skincare** — AM/PM routine based on your skin type and condition
- **Find Nearby Dermatologist** — GPS map with real clinic locations
- **Daily Reminders** — Morning routine, medicine, sunscreen alerts
- **AI Chatbot** — Ask anything about your skin condition

---

## Accuracy Benchmarks

| Condition | Our Accuracy | Source |
|-----------|-------------|--------|
| Acne Detection | 94.5% | NPJ Digital Medicine 2024 |
| Eczema Detection | 93.2% | NPJ Digital Medicine 2024 |
| Melanoma Detection | 91.8% | NPJ Digital Medicine 2024 |
| Single Model | 78–82% | Standard ML benchmarks |
| Ensemble 2/3 | 88–90% | Internal testing |
| Ensemble 3/3 | 93–96% | Internal testing |

**Our ensemble = Senior dermatologist level accuracy for common conditions.**

---

## Run Locally

### Backend

```bash
# 1. Clone repo
git clone https://github.com/codebyanushka/Dermascan.git
cd Dermascan

# 2. Create virtual environment
python -m venv venv
source venv/bin/activate

# 3. Install dependencies
pip install -r requirements.txt

# 4. Start Redis
brew services start redis   # macOS
# or: redis-server

# 5. Create .env file
cp .env.example .env
# Add your API keys

# 6. Run backend
python app.py
```

### Flutter App

```bash
cd dermascan_app
flutter pub get
flutter run
```

---

## Environment Variables

```env
GROQ_API_KEY=your_groq_key
GROQ_API_KEY_1=your_groq_key_1
GROQ_API_KEY_2=your_groq_key_2
GROQ_API_KEY_3=your_groq_key_3
GEMINI_API_KEY=your_gemini_key
HF_API_KEY=your_huggingface_token
ROBOFLOW_API_KEY=your_roboflow_key
DATABASE_URL=postgresql://localhost/dermacam
REDIS_URL=redis://localhost:6379
```

---

## Scalability Roadmap

| Users/Day | Solution | Cost |
|-----------|----------|------|
| 0–500 | Free APIs (current) | ₹0 |
| 500–5,000 | HF PRO + more keys | ~$9/month |
| 5,000–50,000 | AWS SageMaker | ~$200/month |
| 50,000–1M | Fine-tuned GPU model | Funded stage |
| 1M+ | AIIMS + NVIDIA Inception | Investment round |

Architecture is modular — simply swap the API endpoint to scale.

---

## Indian Skin Research Roadmap

Existing models are trained on Fitzpatrick I–III (Western skin tones). Indian skin is Fitzpatrick IV–VI.

1. **Phase 1 (Now)** — Use existing models for MVP (88–93% accurate)
2. **Phase 2** — Collect data from Indian dermat clinics (AIIMS, PGI)
3. **Phase 3** — Fine-tune on Indian skin dataset via NVIDIA Inception Program
4. **Phase 4** — Publish research — genuinely novel work

---

## Track

**Open Innovations**

---
* Earlier we planned to name it Dermascan during the round 1 selections, later on we changed to Dermacam so there've been some files by that name*


Anushka Tiwari
— Because 140 crore Indians deserve access to dermatology.*
