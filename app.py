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

# Groq for chat
groq_client = Groq(api_key=os.getenv("GROQ_API_KEY"))

# Gemini for image analysis
genai.configure(api_key=os.getenv("GEMINI_API_KEY"))
gemini = genai.GenerativeModel("gemini-2.0-flash")

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
# ANALYZE — Gemini Vision
# ─────────────────────────────────────────

@app.route('/analyze', methods=['POST'])
def analyze():
    file = request.files['image']
    image = Image.open(file.stream).convert('RGB')

    prompt = """You are an expert AI dermatologist with deep knowledge across ALL dermatology domains.
Analyze this skin/hair/scalp image carefully and identify every visible condition.

You can detect:
- Skin diseases (eczema, psoriasis, rosacea, infections, rashes, fungal)
- Pigmentation issues (melasma, hyperpigmentation, dark spots, vitiligo, sun damage)
- Acne & scarring (comedones, cysts, post-acne marks, PIH, PIE)
- Aging concerns (wrinkles, fine lines, sagging, loss of elasticity, age spots)
- Hair & scalp issues (dandruff, alopecia, scalp psoriasis, folliculitis)

Return ONLY a valid JSON object, no extra text, no markdown, no code fences:
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

    try:
        response = gemini.generate_content([prompt, image])
        text = response.text.strip()

        # Strip markdown fences if present
        text = re.sub(r'^```json\s*', '', text)
        text = re.sub(r'^```\s*', '', text)
        text = re.sub(r'\s*```$', '', text)

        match = re.search(r'\{.*\}', text, re.DOTALL)
        if match:
            result = json.loads(match.group())
        else:
            result = {"diagnosis": "Unable to analyze", "error": "Parse error", "raw": text}

    except Exception as e:
        result = {"diagnosis": "Error", "error": str(e)}

    return jsonify(result)

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