import gradio as gr
from transformers import pipeline
from groq import Groq
from PIL import Image
import io
import base64

# Groq Client
client = Groq(api_key="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")

print("⏳ DinoV2 Model load ho raha hai...")
model = pipeline(
    "image-classification",
    model="Jayanth2002/dinov2-base-finetuned-SkinDisease"
)
print("✅ Model ready!")

def analyze(image):
    # Step 1 - DinoV2
    dino_results = model(image)
    top = dino_results[0]
    
    # Step 2 - Image to base64 for Groq
    img_byte_arr = io.BytesIO()
    image.save(img_byte_arr, format='JPEG')
    img_base64 = base64.b64encode(img_byte_arr.getvalue()).decode('utf-8')

    prompt = f"""You are an expert AI dermatologist. Analyze this skin image carefully.
    
Initial AI scan detected: {top['label']} with {top['score']*100:.1f}% confidence.

Give a detailed dermatology report:
1. 🔍 DIAGNOSIS - Exact skin condition
2. 📊 TYPE - Specific type/variant
3. ⚠️ SEVERITY - Mild/Moderate/Severe and why
4. 🔎 ROOT CAUSE - Oily/hormonal/bacterial/fungal/allergic?
5. 😣 SYMPTOMS - What patient might feel
6. 💊 TREATMENT - Home remedies + OTC creams + Prescription
7. ✅ INGREDIENTS TO USE - Helpful skincare ingredients
8. ❌ INGREDIENTS TO AVOID - What makes it worse
9. 👨‍⚕️ DOCTOR VISIT - When to see dermatologist
10. 🛡️ PREVENTION - How to prevent recurrence

Be specific, accurate and helpful."""

    response = client.chat.completions.create(
        model="meta-llama/llama-4-scout-17b-16e-instruct",
        messages=[
            {
                "role": "user",
                "content": [
                    {
                        "type": "image_url",
                        "image_url": {
                            "url": f"data:image/jpeg;base64,{img_base64}"
                        }
                    },
                    {
                        "type": "text",
                        "text": prompt
                    }
                ]
            }
        ],
        max_tokens=1500
    )
    
    output = "━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n"
    output += "⚡ QUICK SCAN (DinoV2 96.48%)\n"
    output += "━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n\n"
    for i, r in enumerate(dino_results[:3]):
        output += f"{i+1}. {r['label']} — {r['score']*100:.1f}%\n"
    
    output += "\n━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n"
    output += "🧠 DEEP AI ANALYSIS (Llama 4)\n"
    output += "━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n\n"
    output += response.choices[0].message.content
    
    return output

gr.Interface(
    fn=analyze,
    inputs=gr.Image(type="pil", label="📸 Skin Image Upload karo"),
    outputs=gr.Textbox(label="🩺 Full Diagnosis Report", lines=35),
    title="🩺 DermAI — AI Dermatologist",
    description="DinoV2 (96.48%) + Llama 4 Vision | 200+ skin conditions"
).launch()