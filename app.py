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

# ─────────────────────────────────────────
# SHARED PROMPT
# ─────────────────────────────────────────

ANALYSIS_PROMPT = """You are an expert AI dermatologist with deep knowledge across ALL dermatology domains.
Analyze this skin/hair/scalp image carefully and identify every visible condition.

You can detect:
- Skin diseases (eczema, psoriasis, rosacea, infections, rashes, fungal)
- Pigmentation issues (melasma, hyperpigmentation, dark spots, vitiligo, sun damage)
- Acne & scarring (comedones, cysts, post-acne marks, PIH, PIE)
- Aging concerns (wrinkles, fine lines, sagging, loss of elasticity, age spots)
- Hair & scalp issues (dandruff, alopecia, scalp psoriasis, folliculitis)

Return ONLY a valid JSON object. No extra text, no markdown, no code fences. Just raw JSON:
{
  "diagnosis": "Primary condition name",
  "scientific_name": "Medical/scientific name",
  "category": "Disease | Pigmentation | Acne & Scarring | Aging | Hair & Scalp",
  "severity": "mild | moderate | severe",
  "confidence": 85,
  "what_is_this": "Simple 2-sentence explanation for the patient",
  "is_serious": "Is it serious? What should the patient know?",
  "causes": ["cause1", "cause2", "cause3"],
  "symptoms": ["symptom1", "symptom2", "symptom3"],
  "home_remedies": "Practical home remedy instructions",
  "medicine": "OTC medicine or ingredient recommendations",
  "ingredients_use": ["ingredient1", "ingredient2", "ingredient3"],
  "ingredients_avoid": ["ingredient1", "ingredient2", "ingredient3"],
  "doctor_advice": "Specific signs that mean they must see a dermatologist",
  "prevention": "Prevention and maintenance tips",
  "secondary_conditions": ["any other visible conditions if present"],
  "uncertain": false
}"""

ERROR_FALLBACK = {
    "diagnosis": "Analysis Failed",
    "scientific_name": "",
    "category": "",
    "severity": "mild",
    "confidence": 0,
    "what_is_this": "The AI could not analyze this image. Please try again with a clearer, well-lit photo.",
    "is_serious": "Unable to determine — please consult a dermatologist.",
    "causes": [],
    "symptoms": [],
    "home_remedies": "Please try again with a clearer photo.",
    "medicine": "",
    "ingredients_use": [],
    "ingredients_avoid": [],
    "doctor_advice": "Please consult a qualified dermatologist for an accurate diagnosis.",
    "prevention": "",
    "secondary_conditions": [],
    "uncertain": True
}

def parse_json(text):
    """Safely extract and parse JSON from model response."""
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

def analyze_with_groq(image: Image.Image):
    buffered = io.BytesIO()
    image.save(buffered, format="JPEG", quality=85)
    img_b64 = base64.b64encode(buffered.getvalue()).decode()

    response = groq_client.chat.completions.create(
        model="meta-llama/llama-4-scout-17b-16e-instruct",
        messages=[{
            "role": "user",
            "content": [
                {
                    "type": "image_url",
                    "image_url": {"url": f"data:image/jpeg;base64,{img_b64}"}
                },
                {
                    "type": "text",
                    "text": ANALYSIS_PROMPT
                }
            ]
        }],
        max_tokens=1500
    )
    text = response.choices[0].message.content
    return parse_json(text)

# ─────────────────────────────────────────
# ANALYZE — Gemini Vision (Fallback)
# ─────────────────────────────────────────

def analyze_with_gemini(image: Image.Image):
    response = gemini.generate_content([ANALYSIS_PROMPT, image])
    return parse_json(response.text)

# ─────────────────────────────────────────
# /analyze ROUTE
# ─────────────────────────────────────────

@app.route('/analyze', methods=['POST'])
def analyze():
    file = request.files['image']
    image = Image.open(file.stream).convert('RGB')

    # Try Groq first
    try:
        print("🔍 Analyzing with Groq Vision...")
        result = analyze_with_groq(image)
        print(f"✅ Groq success: {result.get('diagnosis')}")
        return jsonify(result)
    except Exception as e:
        print(f"⚠️ Groq Vision failed: {e}")

    # Fallback to Gemini
    try:
        print("🔁 Falling back to Gemini...")
        result = analyze_with_gemini(image)
        print(f"✅ Gemini success: {result.get('diagnosis')}")
        return jsonify(result)
    except Exception as e:
        print(f"❌ Gemini also failed: {e}")

    # Both failed
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

if __name__ == '__main__':
    app.run(debug=True, port=5001, host="0.0.0.0", use_reloader=False)