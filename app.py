from flask import Flask, request, jsonify, send_from_directory
from flask_cors import CORS
from groq import Groq
from transformers import pipeline
from dotenv import load_dotenv
from PIL import Image
import io, base64, os, json, re

load_dotenv()
app = Flask(__name__)
CORS(app)

client = Groq(api_key=os.getenv("GROQ_API_KEY"))

print("⏳ DinoV2 loading...")
classifier = pipeline(
    "image-classification",
    model="Jayanth2002/dinov2-base-finetuned-SkinDisease"
)
print("✅ Ready!")

# ─────────────────────────────────────────
# PAGES
# ─────────────────────────────────────────

@app.route('/')
def index():
    return send_from_directory('.', 'dermascan.html')

@app.route('/history')
def history():
    return send_from_directory('.', 'history.html')

@app.route('/find-dermat')
def find_dermat():
    return send_from_directory('.', 'find-dermat.html')

# ─────────────────────────────────────────
# ANALYZE
# ─────────────────────────────────────────

@app.route('/analyze', methods=['POST'])
def analyze():
    file = request.files['image']
    image = Image.open(file.stream).convert('RGB')

    # DinoV2 scan
    dino = classifier(image)
    top = dino[0]

    # Encode image for Groq vision
    buf = io.BytesIO()
    image.save(buf, format='JPEG')
    img_b64 = base64.b64encode(buf.getvalue()).decode()

    prompt = f"""You are an expert AI dermatologist. Analyze this skin image.
Initial scan: {top['label']} ({top['score']*100:.1f}% confidence)

Return ONLY a JSON object like this (no extra text):
{{
  "diagnosis": "Common name of condition",
  "scientific_name": "Scientific/medical name",
  "severity": "mild|moderate|severe",
  "confidence": {top['score']*100:.0f},
  "what_is_this": "Simple 2 sentence explanation for patient",
  "is_serious": "Is it serious? What should patient know?",
  "causes": ["cause1", "cause2", "cause3"],
  "symptoms": ["symptom1", "symptom2", "symptom3"],
  "home_remedies": "Home remedy instructions",
  "medicine": "OTC medicine recommendations",
  "ingredients_use": ["ing1", "ing2", "ing3"],
  "ingredients_avoid": ["ing1", "ing2", "ing3"],
  "doctor_advice": "When to see a doctor",
  "prevention": "Prevention tips",
  "uncertain": true
}}"""

    response = client.chat.completions.create(
        model="meta-llama/llama-4-scout-17b-16e-instruct",
        messages=[{
            "role": "user",
            "content": [
                {"type": "image_url", "image_url": {"url": f"data:image/jpeg;base64,{img_b64}"}},
                {"type": "text", "text": prompt}
            ]
        }],
        max_tokens=1000
    )

    text = response.choices[0].message.content
    match = re.search(r'\{.*\}', text, re.DOTALL)
    if match:
        result = json.loads(match.group())
    else:
        result = {
            "diagnosis": top['label'],
            "confidence": top['score'] * 100,
            "error": "Parse error"
        }

    return jsonify(result)

# ─────────────────────────────────────────
# CHAT
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
    app.run(debug=True, port=5000)