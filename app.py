from flask import Flask, request, jsonify, send_from_directory
from flask_cors import CORS
from groq import Groq
from google import genai as google_genai
from google.genai import types as genai_types
from dotenv import load_dotenv
from PIL import Image
from openai import OpenAI
import psycopg2
from psycopg2.extras import RealDictCursor
import io, base64, os, json, re, itertools, hashlib
import requests as req
import redis
import concurrent.futures

from hf_specialist import run_hf_specialists, build_hf_context

load_dotenv()
app = Flask(__name__)
CORS(app)

# ─────────────────────────────────────────
# REDIS CACHE
# ─────────────────────────────────────────

REDIS_URL    = os.getenv("REDIS_URL", "redis://localhost:6379")
redis_client = None
try:
    redis_client = redis.from_url(REDIS_URL, decode_responses=True)
    redis_client.ping()
    print("✅ Redis connected!")
except Exception as e:
    print(f"⚠️  Redis not available: {e} — using in-memory cache")

mem_cache = {}

def cache_get(key):
    try:
        if redis_client:
            val = redis_client.get(key)
            return json.loads(val) if val else None
    except:
        pass
    return mem_cache.get(key)

def cache_set(key, value, ttl=3600):
    try:
        if redis_client:
            redis_client.setex(key, ttl, json.dumps(value))
            return
    except:
        pass
    mem_cache[key] = value

def get_cache_key(img_bytes, patient):
    img_hash = hashlib.md5(img_bytes).hexdigest()[:12]
    loc      = patient.get("body_location", "")
    age      = patient.get("age", "")
    return f"dermascan:{img_hash}:{loc}:{age}"

# ─────────────────────────────────────────
# DATABASE
# ─────────────────────────────────────────

def get_db():
    return psycopg2.connect(os.getenv("DATABASE_URL"))

# ─────────────────────────────────────────
# MULTI-PROVIDER SETUP
# ─────────────────────────────────────────

GROQ_KEYS = [k for k in [
    os.getenv("GROQ_API_KEY"),
    os.getenv("GROQ_API_KEY_1"),
    os.getenv("GROQ_API_KEY_2"),
    os.getenv("GROQ_API_KEY_3"),
] if k]
groq_cycle = itertools.cycle(GROQ_KEYS)

def get_groq():
    return Groq(api_key=next(groq_cycle))

GEMINI_KEYS = [k for k in [
    os.getenv("GEMINI_API_KEY"),
    os.getenv("GEMINI_API_KEY_1"),
    os.getenv("GEMINI_API_KEY_2"),
    os.getenv("GEMINI_API_KEY_3"),
] if k]
gemini_cycle = itertools.cycle(GEMINI_KEYS)

def get_gemini():
    return google_genai.Client(api_key=next(gemini_cycle))

HF_TOKEN     = os.getenv("HF_API_KEY") or os.getenv("HF_TOKEN")
ROBOFLOW_KEY = os.getenv("ROBOFLOW_API_KEY")

print(f"""
╔══════════════════════════════════════════╗
║         DermaScan AI — READY             ║
╠══════════════════════════════════════════╣
║  Groq keys:    {len(GROQ_KEYS)} (3 parallel Scout calls)  ║
║  Gemini keys:  {len(GEMINI_KEYS)}                        ║
║  HF Specialists: {'ON ' if HF_TOKEN else 'OFF'}                      ║
║  Roboflow:     {'ON ' if ROBOFLOW_KEY else 'OFF'} (Hair + Nails)      ║
║  Redis Cache:  {'ON ' if redis_client else 'OFF (fallback)'}                  ║
║  DB:           PostgreSQL                ║
╚══════════════════════════════════════════╝
""")

# ─────────────────────────────────────────
# ROBOFLOW
# ─────────────────────────────────────────

ROBOFLOW_MODELS = {
    "hair": {
        "workspace": "topofhead",
        "project":   "hair-loss-stages",
        "version":   1,
        "label":     "Hair Loss Specialist (Norwood Scale)",
    },
    "nail": {
        "workspace": "yangjm96",
        "project":   "nail-disease",
        "version":   1,
        "label":     "Nail Disease Specialist",
    }
}

def run_roboflow(category: str, img_bytes: bytes) -> dict:
    if not ROBOFLOW_KEY:
        return None
    try:
        model = ROBOFLOW_MODELS.get(category)
        if not model:
            return None
        img_b64  = base64.b64encode(img_bytes).decode()
        url      = (f"https://classify.roboflow.com/{model['project']}/{model['version']}"
                    f"?api_key={ROBOFLOW_KEY}")
        response = req.post(url, data=img_b64,
                            headers={"Content-Type": "application/x-www-form-urlencoded"},
                            timeout=15)
        if response.status_code == 200:
            data = response.json()
            top  = data.get("top", "")
            conf = round(data.get("confidence", 0) * 100, 1)
            print(f"🔭 Roboflow {model['label']}: {top} ({conf}%)")
            return {"label": top, "confidence": conf}
        else:
            print(f"⚠️  Roboflow {category}: {response.status_code}")
    except Exception as e:
        print(f"⚠️  Roboflow error: {e}")
    return None

# ─────────────────────────────────────────
# PROMPT BUILDER
# ─────────────────────────────────────────

def build_prompt(patient: dict, hf_context: str = "", roboflow_context: str = "") -> str:
    age              = patient.get("age",              "not provided")
    sex              = patient.get("sex",              "not provided")
    skin_type        = patient.get("skin_type",        "not provided")
    body_location    = patient.get("body_location",    "not provided")
    duration         = patient.get("duration",         "not provided")
    symptoms         = patient.get("symptoms",         "none mentioned")
    tried            = patient.get("tried",            "nothing")
    known_conditions = patient.get("known_conditions", "none")

    specialist_context = ""
    if hf_context:
        specialist_context += hf_context
    if roboflow_context:
        specialist_context += roboflow_context

    return f"""You are a board-certified consultant dermatologist with 20+ years of clinical experience across ALL skin types (Fitzpatrick I-VI), specializing in Indian skin tones (Fitzpatrick IV-VI).

PATIENT INFO:
  Age: {age} | Sex: {sex} | Skin Type: {skin_type}
  Location: {body_location} | Duration: {duration}
  Symptoms: {symptoms} | Tried: {tried} | Known: {known_conditions}
{specialist_context}

Analyze this skin/hair/nail image carefully. Consider Indian skin tone characteristics.
Respond ONLY with raw valid JSON (no markdown, no backticks) starting with {{ ending with }}:

{{"diagnosis":"Specific condition name","scientific_name":"Latin/medical name","category":"Acne & Scarring | Pigmentation | Eczema | Psoriasis | Rosacea | Infection | Hair & Scalp | Nail Disorder | Aging | Vascular | Inflammatory | Potentially Serious","severity":"mild | moderate | severe","confidence":<0-100>,"fitzpatrick_type":"Detected skin tone I-VI","lesion_type":"morphological description","distribution":"pattern/location","what_is_this":"2-3 sentence patient-friendly explanation","is_serious":"urgency assessment with red flags","causes":["cause1","cause2","cause3"],"triggers":["trigger1","trigger2"],"symptoms":["symptom1","symptom2","symptom3"],"progression":"what happens if untreated","home_remedies":"specific actionable instructions","medicine":"OTC names + concentrations available in India","prescription_options":"what dermatologist would prescribe","ingredients_use":["ingredient1","ingredient2","ingredient3"],"ingredients_avoid":["ingredient1","ingredient2"],"morning_routine":["step1","step2","step3"],"evening_routine":["step1","step2","step3"],"lifestyle_tips":["diet tip","sleep tip","habit tip"],"doctor_advice":"when to see doctor immediately","prevention":"long term prevention strategy","secondary_conditions":["related condition1"],"differential_diagnosis":["alternative diagnosis1","alternative diagnosis2"],"prognosis":"expected healing timeline","uncertain":<true/false>}}"""

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

def parse_json(text: str) -> dict:
    text = text.strip()
    text = re.sub(r'^```json\s*', '', text)
    text = re.sub(r'^```\s*',     '', text)
    text = re.sub(r'\s*```$',     '', text)
    match = re.search(r'\{.*\}', text, re.DOTALL)
    if match:
        return json.loads(match.group())
    raise ValueError("No valid JSON found")

# ─────────────────────────────────────────
# VISION ANALYZERS
# ─────────────────────────────────────────

def img_to_b64(image: Image.Image) -> tuple:
    buf = io.BytesIO()
    image.save(buf, format="JPEG", quality=85)
    b = buf.getvalue()
    return b, base64.b64encode(b).decode()

def analyze_groq_scout(image: Image.Image, prompt: str) -> dict:
    _, img_b64 = img_to_b64(image)
    client = get_groq()
    response = client.chat.completions.create(
        model="meta-llama/llama-4-scout-17b-16e-instruct",
        messages=[
            {"role": "system", "content": "You are a board-certified dermatologist. Respond ONLY with raw valid JSON starting with { ending with }."},
            {"role": "user", "content": [
                {"type": "image_url", "image_url": {"url": f"data:image/jpeg;base64,{img_b64}"}},
                {"type": "text",      "text": prompt}
            ]}
        ],
        max_tokens=2000, temperature=0.2
    )
    return parse_json(response.choices[0].message.content)

def analyze_groq_maverick(image: Image.Image, prompt: str) -> dict:
    _, img_b64 = img_to_b64(image)
    client = get_groq()
    response = client.chat.completions.create(
        model="meta-llama/llama-4-scout-17b-16e-instruct",
        messages=[
            {"role": "system", "content": "You are a board-certified dermatologist. Respond ONLY with raw valid JSON starting with { ending with }."},
            {"role": "user", "content": [
                {"type": "image_url", "image_url": {"url": f"data:image/jpeg;base64,{img_b64}"}},
                {"type": "text",      "text": prompt}
            ]}
        ],
        max_tokens=2000, temperature=0.2
    )
    return parse_json(response.choices[0].message.content)

# ─────────────────────────────────────────
# PARALLEL VOTING ENGINE
# ─────────────────────────────────────────

def parallel_vision_vote(image: Image.Image, prompt: str) -> dict:
    results = {}
    errors  = {}

    analyzers = {
        "Groq Llama4 Scout 1": analyze_groq_scout,
        "Groq Llama4 Scout 2": analyze_groq_scout,
        "Groq Llama4 Scout 3": analyze_groq_scout,
    }

    print(f"⚡ Running {len(analyzers)} vision models in PARALLEL...")

    with concurrent.futures.ThreadPoolExecutor(max_workers=3) as executor:
        futures = {
            executor.submit(fn, image, prompt): name
            for name, fn in analyzers.items()
        }
        for future in concurrent.futures.as_completed(futures):
            name = futures[future]
            try:
                result = future.result(timeout=30)
                results[name] = result
                print(f"  ✅ {name}: {result.get('diagnosis','?')} ({result.get('confidence',0)}%)")
            except Exception as e:
                errors[name] = str(e)
                print(f"  ⚠️  {name} failed: {e}")

    if not results:
        return None

    from collections import Counter
    diag_map = {}
    for name, r in results.items():
        key = r.get("diagnosis", "").lower().split()[0] if r.get("diagnosis") else "unknown"
        diag_map.setdefault(key, []).append((name, r))

    counts              = Counter({k: len(v) for k, v in diag_map.items()})
    top_diag, n         = counts.most_common(1)[0]
    agreed              = diag_map[top_diag]
    total               = len(results)
    agreement           = f"{n}/{total}"
    best_name, best_result = max(agreed, key=lambda x: x[1].get("confidence", 0))

    if n >= 2:
        all_confs    = [r.get("confidence", 0) for _, r in agreed]
        boosted_conf = min(99, round(sum(all_confs) / len(all_confs) * 1.08))
        best_result["confidence"] = boosted_conf
        print(f"🗳️  Vision Vote: {best_result.get('diagnosis')} — {agreement} agree → Boosted {boosted_conf}%")
    else:
        best_result["uncertain"] = True
        print(f"🗳️  Vision Vote: SPLIT — {agreement} — marking uncertain")

    best_result["vision_agreement"] = agreement
    best_result["models_voted"]     = list(results.keys())
    best_result["winning_model"]    = best_name
    return best_result

# ─────────────────────────────────────────
# FINAL REPORT — llama-3.3-70b (faster)
# ─────────────────────────────────────────

def generate_final_report(voted_result: dict, patient: dict) -> dict:
    try:
        report_prompt = f"""You are a senior dermatologist reviewing an AI ensemble diagnosis.

PATIENT: Age {patient.get('age')} | {patient.get('sex')} | Location: {patient.get('body_location')}

ENSEMBLE VOTING RESULT:
{json.dumps(voted_result, indent=2)}

Agreement: {voted_result.get('vision_agreement', '?')}

Review this diagnosis. Confirm if correct, else correct it.
Respond ONLY with raw valid JSON (same schema). Improve: what_is_this, home_remedies, medicine, doctor_advice, prevention."""

        client   = get_groq()
        response = client.chat.completions.create(
            model="llama-3.3-70b-versatile",   # ✅ faster than maverick
            messages=[
                {"role": "system", "content": "You are a senior dermatologist. Respond ONLY with raw valid JSON."},
                {"role": "user",   "content": report_prompt}
            ],
            max_tokens=2000, temperature=0.1
        )
        final = parse_json(response.choices[0].message.content)
        final["vision_agreement"] = voted_result.get("vision_agreement")
        final["models_voted"]     = voted_result.get("models_voted")
        print(f"📋 Final Report: {final.get('diagnosis')} ({final.get('confidence')}%)")
        return final
    except Exception as e:
        print(f"⚠️  Report failed: {e} — using voted result")
        return voted_result

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
    r = send_from_directory('.', 'sw.js')
    r.headers['Service-Worker-Allowed'] = '/'
    r.headers['Cache-Control']          = 'no-cache'
    return r

@app.route('/login')
def login():
    return send_from_directory('.', 'login.html')

@app.route('/stats')
def stats():
    cache_info = {}
    try:
        if redis_client:
            info = redis_client.info()
            cache_info = {
                "redis_hits":   info.get("keyspace_hits", 0),
                "redis_misses": info.get("keyspace_misses", 0),
                "memory_used":  info.get("used_memory_human", "?"),
            }
    except:
        pass
    return jsonify({
        "groq_keys":   len(GROQ_KEYS),
        "gemini_keys": len(GEMINI_KEYS),
        "hf_token":    "loaded" if HF_TOKEN else "missing",
        "roboflow":    "loaded" if ROBOFLOW_KEY else "missing",
        "redis":       "connected" if redis_client else "fallback",
        "cache_info":  cache_info,
        "architecture": "Parallel: 3x Groq Scout + HF + Roboflow | Reporter: llama-3.3-70b",
        "models": {
            "vision":   ["Groq Llama4 Scout ×3"],
            "reporter": ["llama-3.3-70b-versatile"],
            "skin_hf":  ["Anwarkh1/Skin_Cancer", "dima806/skin_types"],
            "hair":     ["Roboflow/Norwood Scale"],
            "nails":    ["Roboflow/nail-disease"],
        }
    })

# ─────────────────────────────────────────
# USER ROUTES
# ─────────────────────────────────────────

@app.route('/save-user', methods=['POST'])
def save_user():
    data = request.json
    try:
        conn = get_db(); cur = conn.cursor()
        cur.execute("""
            INSERT INTO users (uid, name, email, age, gender, skin_type, location, onboarded)
            VALUES (%s,%s,%s,%s,%s,%s,%s,%s)
            ON CONFLICT (uid) DO UPDATE SET
            name=EXCLUDED.name, email=EXCLUDED.email, age=EXCLUDED.age,
            gender=EXCLUDED.gender, skin_type=EXCLUDED.skin_type,
            location=EXCLUDED.location, onboarded=EXCLUDED.onboarded
        """, (
            data.get('uid'), data.get('name'), data.get('email'),
            data.get('age'), data.get('gender'), data.get('skin_type'),
            data.get('location'), data.get('onboarded', False)
        ))
        conn.commit(); cur.close(); conn.close()
        print(f"✅ User saved: {data.get('email')}")
        return jsonify({"success": True})
    except Exception as e:
        print(f"❌ Save user error: {e}")
        return jsonify({"error": str(e)}), 500

@app.route('/get-user', methods=['GET'])
def get_user():
    uid = request.args.get('uid')
    try:
        conn = get_db(); cur = conn.cursor(cursor_factory=RealDictCursor)
        cur.execute("SELECT * FROM users WHERE uid = %s", (uid,))
        user = cur.fetchone(); cur.close(); conn.close()
        return jsonify(dict(user) if user else {})
    except Exception as e:
        return jsonify({"error": str(e)}), 500

@app.route('/get-scans', methods=['GET'])
def get_scans_db():
    uid = request.args.get('uid')
    try:
        conn = get_db(); cur = conn.cursor(cursor_factory=RealDictCursor)
        cur.execute("SELECT * FROM scans WHERE uid=%s ORDER BY created_at DESC LIMIT 20", (uid,))
        scans = cur.fetchall(); cur.close(); conn.close()
        return jsonify([dict(s) for s in scans])
    except Exception as e:
        return jsonify({"error": str(e)}), 500

def save_scan_to_db(uid, result, img_bytes=None):
    try:
        img_b64 = base64.b64encode(img_bytes).decode()[:50000] if img_bytes else None
        conn = get_db(); cur = conn.cursor()

        cur.execute("""
            INSERT INTO users (uid, name, email, age, gender, skin_type, location, onboarded)
            VALUES (%s, %s, %s, %s, %s, %s, %s, %s)
            ON CONFLICT (uid) DO NOTHING
        """, (uid, '', '', None, '', '', '', False))

        causes   = result.get('causes',   [])
        symptoms = result.get('symptoms', [])
        causes   = causes   if isinstance(causes,   list) else []
        symptoms = symptoms if isinstance(symptoms, list) else []

        cur.execute("""
            INSERT INTO scans(uid, diagnosis, scientific_name, severity, confidence,
            category, what_is_this, is_serious, causes, symptoms, home_remedies,
            medicine, doctor_advice, prevention, img_data)
            VALUES (%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s)
        """, (
            uid, result.get('diagnosis'), result.get('scientific_name'),
            result.get('severity'), result.get('confidence'), result.get('category'),
            result.get('what_is_this'), result.get('is_serious'),
            causes, symptoms,
            result.get('home_remedies'), result.get('medicine'),
            result.get('doctor_advice'), result.get('prevention'), img_b64
        ))
        conn.commit(); cur.close(); conn.close()
        print(f"✅ Scan saved to DB for uid: {uid}")
    except Exception as e:
        print(f"⚠️  DB save failed: {e}")

# ─────────────────────────────────────────
# MAIN ANALYZE ENDPOINT
# ─────────────────────────────────────────

@app.route('/analyze', methods=['POST'])
def analyze():
    file      = request.files['image']
    img_bytes = file.read()

    # ✅ Resize image for faster processing
    image = Image.open(io.BytesIO(img_bytes)).convert('RGB')
    image = image.resize((512, 512), Image.LANCZOS)

    patient = {
        "age":              request.form.get("age",              "not provided"),
        "sex":              request.form.get("sex",              "not provided"),
        "skin_type":        request.form.get("skin_type",        "not provided"),
        "body_location":    request.form.get("body_location",    "not provided"),
        "duration":         request.form.get("duration",         "not provided"),
        "symptoms":         request.form.get("symptoms",         "not provided"),
        "tried":            request.form.get("tried",            "nothing"),
        "known_conditions": request.form.get("known_conditions", "none"),
    }
    uid           = request.form.get("uid")
    body_location = patient["body_location"]

    print(f"\n{'='*55}")
    print(f"👤 {patient['age']} | {patient['sex']} | {body_location} | {patient['duration']}")

    # ── CACHE CHECK ──
    cache_key = get_cache_key(img_bytes, patient)
    cached    = cache_get(cache_key)
    if cached:
        print(f"⚡ Redis cache HIT — 2ms response!")
        if uid:
            save_scan_to_db(uid, cached)
        return jsonify(cached)

    # ── ALL MODELS PARALLEL ──
    print(f"\n🚀 ALL THREADS RUNNING IN PARALLEL...")
    hf_result       = None
    roboflow_result = None
    loc             = body_location.lower()

    def run_specialist_thread():
        if any(x in loc for x in ["hair", "scalp", "head"]):
            print("💇 Thread 1: Roboflow Hair Specialist...")
            return "roboflow_hair", run_roboflow("hair", img_bytes)
        elif "nail" in loc or "finger" in loc:
            print("💅 Thread 1: Roboflow Nail Specialist...")
            return "roboflow_nail", run_roboflow("nail", img_bytes)
        else:
            print("🏥 Thread 1-2: HF Skin Specialists...")
            return "hf", run_hf_specialists(body_location, img_bytes)

    with concurrent.futures.ThreadPoolExecutor(max_workers=4) as pool:
        spec_future   = pool.submit(run_specialist_thread)
        vision_future = pool.submit(parallel_vision_vote, image, build_prompt(patient, "", ""))
        spec_type, spec_result = spec_future.result()
        voted = vision_future.result()

    if spec_type == "hf":
        hf_result = spec_result
    else:
        roboflow_result = spec_result

    hf_context       = build_hf_context(hf_result)
    roboflow_context = ""
    if roboflow_result:
        roboflow_context = f"""
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
ROBOFLOW SPECIALIST: {roboflow_result.get('label')} ({roboflow_result.get('confidence')}%)
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"""

    if not voted:
        print("❌ All vision models failed")
        return jsonify({**ERROR_FALLBACK, "error": "All providers failed"})

    # ── FINAL REPORT ──
    print(f"\n🏥 STEP 3: Writing final report (llama-3.3-70b)...")
    result = generate_final_report(voted, patient)

    # ── SPECIALIST AGREEMENT ──
    specialist_diag = None
    if hf_result:
        specialist_diag = hf_result.get("hf_diagnosis", "")
    elif roboflow_result:
        specialist_diag = roboflow_result.get("label", "")

    if specialist_diag:
        vision_diag = (result.get("diagnosis") or "").lower()
        spec_lower  = specialist_diag.lower()
        agree = any(word in vision_diag for word in spec_lower.split() if len(word) > 4)
        if agree:
            boosted = min(99, round(result.get("confidence", 70) + 5))
            result["confidence"]           = boosted
            result["specialist_agreement"] = True
            result["specialist_diagnosis"] = specialist_diag
            print(f"🎯 Specialist AGREES! Confidence: {boosted}%")
        else:
            result["specialist_disagreement"] = True
            result["specialist_diagnosis"]    = specialist_diag
            print(f"⚠️  Specialist DISAGREES — {specialist_diag} vs {result.get('diagnosis')}")

    print(f"\n{'='*55}")
    print(f"✅ FINAL: {result.get('diagnosis')} ({result.get('confidence')}%) | {result.get('vision_agreement')}")
    print(f"{'='*55}\n")

    cache_set(cache_key, result, ttl=3600)
    if uid:
        save_scan_to_db(uid, result, img_bytes)

    return jsonify(result)

# ─────────────────────────────────────────
# CHAT
# ─────────────────────────────────────────

from chatbot import chat

@app.route('/chat', methods=['POST'])
def chat_endpoint():
    data  = request.json
    reply = chat(
        data.get('message',    ''),
        data.get('session_id', 'default'),
        data.get('diagnosis',  None)
    )
    return jsonify({"reply": reply})

if __name__ == '__main__':
    app.run(debug=True, port=5001, host="0.0.0.0", use_reloader=False)