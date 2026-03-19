from flask import Flask, request, jsonify, send_from_directory
from flask_cors import CORS
from groq import Groq
import google.generativeai as genai
from dotenv import load_dotenv
from PIL import Image
import io, base64, os, json, re

load_dotenv()
app = Flask(__name__)
CORS(app)

# Groq for chat + image analysis (primary)
groq_client = Groq(api_key=os.getenv("GROQ_API_KEY"))

# Gemini for image analysis (fallback only)
genai.configure(api_key=os.getenv("GEMINI_API_KEY"))
gemini = genai.GenerativeModel("gemini-1.5-flash")

print("✅ DermaScan Ready!")

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

# ✅ Service Worker — must be served from root for full scope
@app.route('/sw.js')
def service_worker():
    response = send_from_directory('.', 'sw.js')
    response.headers['Service-Worker-Allowed'] = '/'
    response.headers['Cache-Control'] = 'no-cache'
    return response

# ─────────────────────────────────────────
# BUILD PROMPT — injects patient context
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
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
PATIENT HISTORY (provided before scan):
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
Age: {age}
Sex: {sex}
Skin type (self-reported): {skin_type}
Body location of concern: {body_location}
Duration of condition: {duration}
Symptoms experienced: {symptoms}
Treatments already tried: {tried}
Known skin conditions / allergies: {known_conditions}

Use this clinical history to make your diagnosis more precise.
"""

    return f"""You are a board-certified consultant dermatologist with 20+ years of clinical experience, trained at top institutions. You have seen thousands of patients across all skin types (Fitzpatrick I–VI), ages, and conditions. You are also a trichologist (hair & scalp specialist).

Your task: Perform a detailed, clinically accurate visual analysis of this skin/hair/scalp image combined with the patient history below — exactly as you would during a real dermatology consultation.

{patient_context}

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
VISUAL EXAMINATION — examine all of these:
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

MORPHOLOGY — Identify exact lesion type:
- Macule, papule, pustule, nodule, cyst, vesicle, bulla, plaque, wheal, scale, crust, erosion, ulcer, scar, comedone, excoriation, lichenification, telangiectasia, purpura

DISTRIBUTION — Note the pattern:
- Localized vs diffuse, symmetric vs asymmetric, follicular vs non-follicular, dermatomal, photo-distributed, intertriginous, acral, flexural, extensor

COLOR & TEXTURE:
- Erythema, hyperpigmentation, hypopigmentation, violaceous, yellowish, brownish, silvery scale, smooth, rough, verrucous, atrophic

DETECTABLE CONDITIONS:
Acne spectrum: comedonal, inflammatory, nodulocystic, acne conglobata, truncal acne
Post-acne: PIH, PIE, rolling scars, boxcar scars, ice pick scars, hypertrophic scars, keloids
Pigmentation: melasma, solar lentigines, ephelides, post-inflammatory changes, vitiligo, nevus, seborrheic keratosis, DPN
Eczema spectrum: atopic dermatitis, contact dermatitis, seborrheic dermatitis, nummular eczema, dyshidrotic eczema
Psoriasis: plaque, guttate, inverse, pustular
Rosacea: erythematotelangiectatic, papulopustular, phymatous
Infections: tinea (corporis/faciei/versicolor), bacterial (impetigo, cellulitis, folliculitis, furuncle), viral (herpes simplex, herpes zoster, molluscum, verruca, flat warts)
Inflammatory: lichen planus, pityriasis rosea, urticaria, granuloma annulare
Vascular: port wine stain, hemangioma, spider angioma, cherry angioma
Aging: photoaging, solar elastosis, rhytides, xanthelasma, senile purpura
Hair & scalp: androgenetic alopecia, alopecia areata, traction alopecia, telogen effluvium, tinea capitis, scalp psoriasis, folliculitis decalvans
Potentially serious — FLAG CLEARLY: melanoma (ABCDE criteria), BCC, SCC, actinic keratosis

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
OUTPUT — raw JSON only, no markdown, no fences:
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

{{
  "diagnosis": "Specific primary condition",
  "scientific_name": "Full Latin/medical name",
  "category": "Acne & Scarring | Pigmentation | Eczema | Psoriasis | Rosacea | Infection | Hair & Scalp | Aging | Vascular | Inflammatory | Potentially Serious",
  "severity": "mild | moderate | severe",
  "confidence": <integer 0-100>,
  "fitzpatrick_type": "Estimated Fitzpatrick skin type I–VI",
  "lesion_type": "Exact morphological lesion types visible",
  "distribution": "Pattern and distribution observed",
  "what_is_this": "Clear, warm 2-3 sentence explanation a patient can understand.",
  "is_serious": "Honest urgency assessment — risk if untreated?",
  "causes": ["cause 1", "cause 2", "cause 3", "cause 4"],
  "triggers": ["trigger 1", "trigger 2", "trigger 3"],
  "symptoms": ["symptom 1", "symptom 2", "symptom 3"],
  "progression": "What happens short and long term if untreated",
  "home_remedies": "Evidence-based home remedies with exact how-to instructions",
  "medicine": "Specific OTC medicines — exact names, concentrations, how to use",
  "prescription_options": "What a dermatologist would likely prescribe",
  "ingredients_use": ["Ingredient 1 — why it helps", "Ingredient 2", "Ingredient 3", "Ingredient 4"],
  "ingredients_avoid": ["Ingredient 1 — why avoid", "Ingredient 2", "Ingredient 3"],
  "morning_routine": ["Step 1", "Step 2", "Step 3", "Step 4", "Step 5"],
  "evening_routine": ["Step 1", "Step 2", "Step 3", "Step 4"],
  "lifestyle_tips": ["Diet tip", "Sleep/stress tip", "Habit tip"],
  "doctor_advice": "Specific red flag signs requiring urgent dermatologist visit",
  "prevention": "Detailed long-term prevention strategy",
  "secondary_conditions": ["Other visible conditions if any"],
  "differential_diagnosis": ["Alternative condition 1", "Alternative condition 2"],
  "prognosis": "Realistic healing timeline with proper treatment",
  "uncertain": <true if image quality poor or diagnosis ambiguous, false otherwise>
}}"""


ERROR_FALLBACK = {
    "diagnosis": "Analysis Failed",
    "scientific_name": "",
    "category": "",
    "severity": "mild",
    "confidence": 0,
    "what_is_this": "The AI could not analyze this image. Please try again with a clearer, well-lit photo.",
    "is_serious": "Unable to determine — please consult a dermatologist.",
    "causes": [],
    "triggers": [],
    "symptoms": [],
    "progression": "",
    "home_remedies": "Please try again with a clearer photo.",
    "medicine": "",
    "prescription_options": "",
    "ingredients_use": [],
    "ingredients_avoid": [],
    "morning_routine": [],
    "evening_routine": [],
    "lifestyle_tips": [],
    "doctor_advice": "Please consult a qualified dermatologist for an accurate diagnosis.",
    "prevention": "",
    "secondary_conditions": [],
    "differential_diagnosis": [],
    "prognosis": "",
    "uncertain": True
}

def parse_json(text):
    text = text.strip()
    text = re.sub(r'^```json\s*', '', text)
    text = re.sub(r'^```\s*', '', text)
    text = re.sub(r'\s*```$', '', text)
    match = re.search(r'\{.*\}', text, re.DOTALL)
    if match:
        return json.loads(match.group())
    raise ValueError("No valid JSON found in response")

# ─────────────────────────────────────────
# ANALYZE — Groq Vision (Primary)
# ─────────────────────────────────────────

def analyze_with_groq(image: Image.Image, prompt: str):
    buffered = io.BytesIO()
    image.save(buffered, format="JPEG", quality=92)
    img_b64 = base64.b64encode(buffered.getvalue()).decode()

    response = groq_client.chat.completions.create(
        model="meta-llama/llama-4-scout-17b-16e-instruct",
        messages=[
            {
                "role": "system",
                "content": "You are a board-certified dermatologist. Always respond with ONLY raw valid JSON. No markdown, no explanation, no code fences. Start your response with { and end with }."
            },
            {
                "role": "user",
                "content": [
                    {
                        "type": "image_url",
                        "image_url": {"url": f"data:image/jpeg;base64,{img_b64}"}
                    },
                    {
                        "type": "text",
                        "text": prompt
                    }
                ]
            }
        ],
        max_tokens=2000,
        temperature=0.2
    )
    text = response.choices[0].message.content
    return parse_json(text)

# ─────────────────────────────────────────
# ANALYZE — Gemini Vision (Fallback)
# ─────────────────────────────────────────

def analyze_with_gemini(image: Image.Image, prompt: str):
    response = gemini.generate_content([prompt, image])
    return parse_json(response.text)

# ─────────────────────────────────────────
# /analyze ROUTE
# ─────────────────────────────────────────

@app.route('/analyze', methods=['POST'])
def analyze():
    file = request.files['image']
    image = Image.open(file.stream).convert('RGB')

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

    prompt = build_prompt(patient)

    # Try Groq first
    try:
        print("🔍 Analyzing with Groq Vision...")
        result = analyze_with_groq(image, prompt)
        print(f"✅ Groq success: {result.get('diagnosis')} ({result.get('confidence')}% confidence)")
        return jsonify(result)
    except Exception as e:
        print(f"⚠️  Groq Vision failed: {e}")

    # Fallback to Gemini
    try:
        print("🔁 Falling back to Gemini...")
        result = analyze_with_gemini(image, prompt)
        print(f"✅ Gemini success: {result.get('diagnosis')}")
        return jsonify(result)
    except Exception as e:
        print(f"❌ Gemini also failed: {e}")

    return jsonify({**ERROR_FALLBACK, "error": "Both Groq and Gemini failed"})

# ─────────────────────────────────────────
# CHAT — Groq (fast)
# ─────────────────────────────────────────

from chatbot import chat

@app.route('/chat', methods=['POST'])
def chat_endpoint():
    data = request.json
    message = data.get('message', '')
    session_id = data.get('session_id', 'default')
    diagnosis = data.get('diagnosis', None)

    reply = chat(message, session_id, diagnosis)
    return jsonify({"reply": reply})

# ─────────────────────────────────────────
@app.route('/login')
def login():
    return send_from_directory('.', 'login.html')

if __name__ == '__main__':
    app.run(debug=True, port=5001, host="0.0.0.0", use_reloader=False)