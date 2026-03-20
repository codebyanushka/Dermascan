from flask import Flask, request, jsonify, send_from_directory
from flask_cors import CORS
from groq import Groq
import google.generativeai as genai
from dotenv import load_dotenv
from PIL import Image
from openai import OpenAI
import io, base64, os, json, re, itertools, hashlib
import requests as req

load_dotenv()
app = Flask(__name__)
CORS(app)

# ─────────────────────────────────────────
# MULTI-PROVIDER SETUP
# ─────────────────────────────────────────

# 4 Groq keys — round robin
GROQ_KEYS = [k for k in [
    os.getenv("GROQ_API_KEY"),
    os.getenv("GROQ_API_KEY_1"),
    os.getenv("GROQ_API_KEY_2"),
    os.getenv("GROQ_API_KEY_3"),
] if k]

groq_cycle = itertools.cycle(GROQ_KEYS)

def get_groq_client():
    return Groq(api_key=next(groq_cycle))

# Gemini
genai.configure(api_key=os.getenv("GEMINI_API_KEY"))
gemini = genai.GenerativeModel("gemini-1.5-flash")

# HuggingFace
HF_TOKEN = os.getenv("HF_API_KEY") or os.getenv("HF_TOKEN")

# ─────────────────────────────────────────
# IN-MEMORY CACHE
# ─────────────────────────────────────────

cache = {}
cache_hits = 0
total_requests = 0

def get_cache_key(img_bytes, patient):
    img_hash = hashlib.md5(img_bytes).hexdigest()[:8]
    location = patient.get('body_location', '')
    return f"{img_hash}_{location}"

print(f"✅ DermaScan Ready! Groq keys: {len(GROQ_KEYS)} | Cache: ON | Providers: Groq + Gemini + HuggingFace")

# ─────────────────────────────────────────
# PAGES
# ─────────────────────────────────────────

@app.route('/')
def index():
    return send_from_directory('.', 'Dermascan.html')

@app.route('/history')
def history():
    return send_from_directory('.', 'history.html')

@app.route('/find-dermat')
def find_dermat():
    return send_from_directory('.', 'find-dermat.html')

@app.route('/sw.js')
def service_worker():
    response = send_from_directory('.', 'sw.js')
    response.headers['Service-Worker-Allowed'] = '/'
    response.headers['Cache-Control'] = 'no-cache'
    return response

@app.route('/login')
def login():
    return send_from_directory('.', 'login.html')

@app.route('/stats')
def stats():
    return jsonify({
        "total_requests": total_requests,
        "cache_hits": cache_hits,
        "cache_hit_rate": f"{(cache_hits/total_requests*100):.1f}%" if total_requests > 0 else "0%",
        "groq_keys_loaded": len(GROQ_KEYS),
        "providers": ["Groq (multi-key round robin)", "Gemini 1.5 Flash", "HuggingFace"],
        "effective_capacity": "300+ req/min free"
    })

# ─────────────────────────────────────────
# BUILD PROMPT
# ─────────────────────────────────────────

def build_prompt(patient: dict) -> str:
    age           = patient.get("age", "not provided")
    sex           = patient.get("sex", "not provided")
    skin_type     = patient.get("skin_type", "not provided")
    body_location = patient.get("body_location", "not provided")
    duration      = patient.get("duration", "not provided")
    symptoms      = patient.get("symptoms", "none mentioned")
    tried         = patient.get("tried", "nothing")
    known_conditions = patient.get("known_conditions", "none")

    patient_context = f"""
PATIENT HISTORY:
Age: {age} | Sex: {sex} | Skin type: {skin_type}
Body location: {body_location} | Duration: {duration}
Symptoms: {symptoms} | Tried: {tried}
Known conditions: {known_conditions}
"""

    return f"""You are a board-certified consultant dermatologist with 20+ years of clinical experience across all skin types (Fitzpatrick I-VI).

{patient_context}

Analyze this skin image. Respond ONLY with raw valid JSON starting with {{ and ending with }}:

{{"diagnosis":"Specific condition","scientific_name":"Latin name","category":"Acne & Scarring | Pigmentation | Eczema | Psoriasis | Rosacea | Infection | Hair & Scalp | Aging | Vascular | Inflammatory | Potentially Serious","severity":"mild | moderate | severe","confidence":<0-100>,"fitzpatrick_type":"I-VI","lesion_type":"morphology","distribution":"pattern","what_is_this":"2-3 sentence patient explanation","is_serious":"urgency assessment","causes":["c1","c2","c3"],"triggers":["t1","t2"],"symptoms":["s1","s2","s3"],"progression":"if untreated","home_remedies":"instructions","medicine":"OTC names + concentrations","prescription_options":"what dermat would prescribe","ingredients_use":["i1","i2","i3"],"ingredients_avoid":["i1","i2"],"morning_routine":["step1","step2","step3"],"evening_routine":["step1","step2"],"lifestyle_tips":["diet","sleep","habit"],"doctor_advice":"red flags","prevention":"long term strategy","secondary_conditions":["other"],"differential_diagnosis":["alt1","alt2"],"prognosis":"healing timeline","uncertain":<true/false>}}"""


ERROR_FALLBACK = {
    "diagnosis": "Analysis Failed", "scientific_name": "", "category": "",
    "severity": "mild", "confidence": 0,
    "what_is_this": "Could not analyze. Please try with a clearer, well-lit photo.",
    "is_serious": "Unable to determine — consult a dermatologist.",
    "causes": [], "triggers": [], "symptoms": [], "progression": "",
    "home_remedies": "Try again with clearer photo.", "medicine": "",
    "prescription_options": "", "ingredients_use": [], "ingredients_avoid": [],
    "morning_routine": [], "evening_routine": [], "lifestyle_tips": [],
    "doctor_advice": "Please consult a qualified dermatologist.",
    "prevention": "", "secondary_conditions": [],
    "differential_diagnosis": [], "prognosis": "", "uncertain": True
}

def parse_json(text):
    text = text.strip()
    text = re.sub(r'^```json\s*', '', text)
    text = re.sub(r'^```\s*', '', text)
    text = re.sub(r'\s*```$', '', text)
    match = re.search(r'\{.*\}', text, re.DOTALL)
    if match:
        return json.loads(match.group())
    raise ValueError("No valid JSON found")

# ─────────────────────────────────────────
# PROVIDER 1 — Groq Vision (round robin)
# ─────────────────────────────────────────

def analyze_with_groq(image: Image.Image, prompt: str):
    buffered = io.BytesIO()
    image.save(buffered, format="JPEG", quality=92)
    img_b64 = base64.b64encode(buffered.getvalue()).decode()

    client = get_groq_client()
    response = client.chat.completions.create(
        model="meta-llama/llama-4-scout-17b-16e-instruct",
        messages=[
            {
                "role": "system",
                "content": "You are a board-certified dermatologist. Respond with ONLY raw valid JSON. Start with { end with }."
            },
            {
                "role": "user",
                "content": [
                    {"type": "image_url", "image_url": {"url": f"data:image/jpeg;base64,{img_b64}"}},
                    {"type": "text", "text": prompt}
                ]
            }
        ],
        max_tokens=2000,
        temperature=0.2
    )
    return parse_json(response.choices[0].message.content)

# ─────────────────────────────────────────
# PROVIDER 2 — Gemini Vision
# ─────────────────────────────────────────

def analyze_with_gemini(image: Image.Image, prompt: str):
    response = gemini.generate_content([prompt, image])
    return parse_json(response.text)

# ─────────────────────────────────────────
# PROVIDER 3 — HuggingFace (LLaMA via HF router)
# ─────────────────────────────────────────

def analyze_with_huggingface(image: Image.Image, prompt: str):
    if not HF_TOKEN:
        raise ValueError("No HuggingFace token")

    buffered = io.BytesIO()
    image.save(buffered, format="JPEG", quality=92)
    img_b64 = base64.b64encode(buffered.getvalue()).decode()

    client = OpenAI(
        base_url="https://router.huggingface.co/v1",
        api_key=HF_TOKEN,
    )

    response = client.chat.completions.create(
        model="meta-llama/Llama-4-Scout-17B-16E-Instruct",
        messages=[
            {
                "role": "system",
                "content": "You are a board-certified dermatologist. Respond with ONLY raw valid JSON. Start with { end with }."
            },
            {
                "role": "user",
                "content": [
                    {"type": "image_url", "image_url": {"url": f"data:image/jpeg;base64,{img_b64}"}},
                    {"type": "text", "text": prompt}
                ]
            }
        ],
        max_tokens=2000,
    )
    return parse_json(response.choices[0].message.content)

# ─────────────────────────────────────────
# /analyze — Cache + 3 Provider Fallback
# ─────────────────────────────────────────

@app.route('/analyze', methods=['POST'])
def analyze():
    global cache_hits, total_requests
    total_requests += 1

    file = request.files['image']
    img_bytes = file.read()
    image = Image.open(io.BytesIO(img_bytes)).convert('RGB')

    patient = {
        "age":              request.form.get("age", "not provided"),
        "sex":              request.form.get("sex", "not provided"),
        "skin_type":        request.form.get("skin_type", "not provided"),
        "body_location":    request.form.get("body_location", "not provided"),
        "duration":         request.form.get("duration", "not provided"),
        "symptoms":         request.form.get("symptoms", "not provided"),
        "tried":            request.form.get("tried", "nothing"),
        "known_conditions": request.form.get("known_conditions", "none"),
    }

    print(f"👤 Patient: {patient['age']} | {patient['sex']} | {patient['body_location']} | {patient['duration']}")

    # Cache check
    cache_key = get_cache_key(img_bytes, patient)
    if cache_key in cache:
        cache_hits += 1
        print(f"⚡ Cache hit! ({cache_hits}/{total_requests} = {int(cache_hits/total_requests*100)}%)")
        return jsonify(cache[cache_key])

    prompt = build_prompt(patient)

    # Provider 1 — Groq (4 keys round robin)
    try:
        print("🔍 [1/3] Groq Vision...")
        result = analyze_with_groq(image, prompt)
        print(f"✅ Groq: {result.get('diagnosis')} ({result.get('confidence')}%)")
        cache[cache_key] = result
        return jsonify(result)
    except Exception as e:
        print(f"⚠️  Groq failed: {e}")

    # Provider 2 — Gemini
    try:
        print("🔁 [2/3] Gemini Vision...")
        result = analyze_with_gemini(image, prompt)
        print(f"✅ Gemini: {result.get('diagnosis')}")
        cache[cache_key] = result
        return jsonify(result)
    except Exception as e:
        print(f"⚠️  Gemini failed: {e}")

    # Provider 3 — HuggingFace
    try:
        print("🔁 [3/3] HuggingFace...")
        result = analyze_with_huggingface(image, prompt)
        print(f"✅ HuggingFace: {result.get('diagnosis')}")
        cache[cache_key] = result
        return jsonify(result)
    except Exception as e:
        print(f"❌ All providers failed: {e}")

    return jsonify({**ERROR_FALLBACK, "error": "All providers failed"})

# ─────────────────────────────────────────
# CHAT — Groq round robin
# ─────────────────────────────────────────

from chatbot import chat

@app.route('/chat', methods=['POST'])
def chat_endpoint():
    data = request.json
    reply = chat(
        data.get('message', ''),
        data.get('session_id', 'default'),
        data.get('diagnosis', None)
    )
    return jsonify({"reply": reply})

# ─────────────────────────────────────────

if __name__ == '__main__':
    app.run(debug=True, port=5001, host="0.0.0.0", use_reloader=False)