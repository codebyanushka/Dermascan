"""
hf_specialist.py
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
HuggingFace Specialized Medical Models
3 confirmed live models — body part routing
Results passed to main app.py as context
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
"""

import requests
import os
from dotenv import load_dotenv

load_dotenv()

HF_TOKEN = os.getenv("HF_API_KEY") or os.getenv("HF_TOKEN")
HF_API   = "https://router.huggingface.co/hf-inference/models"

# ─────────────────────────────────────────
# 3 CONFIRMED LIVE SPECIALIST MODELS
# ─────────────────────────────────────────

MODELS = {
    "skin_cancer": {
        "id":      "Anwarkh1/Skin_Cancer-Image_Classification",
        "label":   "Skin Cancer Specialist",
        "emoji":   "🔬",
        "detects": ["Melanoma", "Basal Cell Carcinoma", "Actinic Keratosis", "Nevi"]
    },
    "acne": {
        "id":      "imfarzanansari/skintelligent-acne",
        "label":   "Acne Specialist",
        "emoji":   "😶",
        "detects": ["Acne Grade 1", "Acne Grade 2", "Acne Grade 3", "Acne Grade 4"]
    },
    "skin_type": {
        "id":      "dima806/skin_types_image_detection",
        "label":   "Skin Type Specialist",
        "emoji":   "🧬",
        "detects": ["Oily", "Dry", "Normal", "Combination"]
    }
}

# ─────────────────────────────────────────
# CORE CLASSIFIER
# ─────────────────────────────────────────

def hf_classify(model_id: str, img_bytes: bytes) -> dict:
    """Call HuggingFace inference API"""
    if not HF_TOKEN:
        return None
    try:
        response = requests.post(
            f"{HF_API}/{model_id}",
            headers={
                "Authorization": f"Bearer {HF_TOKEN}",
                "Content-Type":  "image/jpeg"
            },
            data=img_bytes,
            timeout=30
        )
        if response.status_code == 200:
            results = response.json()
            if isinstance(results, list) and results:
                top = results[0]
                return {
                    "label":      top.get("label", ""),
                    "confidence": round(top.get("score", 0) * 100, 1),
                    "all_results": results[:3]
                }
        else:
            print(f"⚠️  HF {model_id.split('/')[-1]}: {response.status_code}")
    except Exception as e:
        print(f"⚠️  HF error {model_id.split('/')[-1]}: {e}")
    return None

# ─────────────────────────────────────────
# INDIVIDUAL SPECIALISTS
# ─────────────────────────────────────────

def run_skin_cancer_specialist(img_bytes: bytes) -> dict:
    """Anwarkh1 — Melanoma, BCC, Actinic Keratosis"""
    r = hf_classify(MODELS["skin_cancer"]["id"], img_bytes)
    if r:
        print(f"🔬 Skin Cancer Specialist (Anwarkh1): {r['label']} ({r['confidence']}%)")
    return r

def run_acne_specialist(img_bytes: bytes) -> dict:
    """imfarzanansari — Acne grades 1-4, 94% accuracy"""
    r = hf_classify(MODELS["acne"]["id"], img_bytes)
    if r:
        print(f"😶 Acne Specialist (skintelligent): {r['label']} ({r['confidence']}%)")
    return r

def run_skin_type_specialist(img_bytes: bytes) -> dict:
    """dima806 — Oily, Dry, Normal, Combination"""
    r = hf_classify(MODELS["skin_type"]["id"], img_bytes)
    if r:
        print(f"🧬 Skin Type Specialist (dima806): {r['label']} ({r['confidence']}%)")
    return r

# ─────────────────────────────────────────
# VOTING ENGINE
# ─────────────────────────────────────────

def voting_engine(results: list) -> dict:
    """Majority vote across HF specialist results"""
    from collections import Counter

    valid = [r for r in results if r is not None]
    if not valid:
        return None

    # Single result
    if len(valid) == 1:
        return {
            "hf_diagnosis":   valid[0]["label"],
            "hf_confidence":  valid[0]["confidence"],
            "agreement":      "1/1",
            "uncertain":      False,
            "models_used":    1
        }

    # Extract primary keyword from label
    labels = [r["label"].lower().split(",")[0].strip() for r in valid]
    counts = Counter(labels)
    top_label, top_count = counts.most_common(1)[0]

    # Find matching results
    matched     = [r for r in valid if top_label in r["label"].lower()]
    avg_conf    = round(sum(r["confidence"] for r in matched) / len(matched), 1)
    full_label  = matched[0]["label"] if matched else valid[0]["label"]
    ratio       = top_count / len(valid)

    agreement_str = f"{top_count}/{len(valid)}"
    print(f"🗳️  HF Voting: {full_label} — {agreement_str} agree ({avg_conf}%)")

    return {
        "hf_diagnosis":  full_label,
        "hf_confidence": avg_conf,
        "agreement":     agreement_str,
        "uncertain":     ratio < 0.5,
        "models_used":   len(valid)
    }

# ─────────────────────────────────────────
# BODY PART ROUTER
# ─────────────────────────────────────────

def run_hf_specialists(body_location: str, img_bytes: bytes) -> dict:
    """
    Route to appropriate HF specialists based on body part.
    Returns voted result to pass as context to main engine.
    """
    if not HF_TOKEN:
        print("⚠️  HF token missing — skipping specialists")
        return None

    loc = body_location.lower()

    # NAILS — No good HF model, skip
    if "nail" in loc or "finger" in loc:
        print("💅 Nails → Roboflow handles in main engine")
        return None

    # HAIR/SCALP — No good HF model, skip
    elif any(x in loc for x in ["scalp", "hair", "head"]):
        print("💇 Hair → Roboflow handles in main engine")
        return None

    # FACE — Acne + Skin Type specialists
    elif "face" in loc or "cheek" in loc or "forehead" in loc or "chin" in loc:
        print("😶 Face → Running HF Acne + Skin Type specialists")
        return voting_engine([
            run_acne_specialist(img_bytes),
            run_skin_type_specialist(img_bytes),
        ])

    # SKIN/BODY — Cancer + Skin Type specialists
    else:
        print("🩺 Skin/Body → Running HF Cancer + Skin Type specialists")
        return voting_engine([
            run_skin_cancer_specialist(img_bytes),
            run_skin_type_specialist(img_bytes),
        ])

# ─────────────────────────────────────────
# CONTEXT BUILDER — for main engine prompt
# ─────────────────────────────────────────

def build_hf_context(hf_result: dict) -> str:
    """Format HF result as context string for main engine prompt"""
    if not hf_result:
        return ""

    uncertain_note = " (LOW CONFIDENCE — models disagreed)" if hf_result.get("uncertain") else ""

    return f"""
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
HUGGINGFACE SPECIALIST PRE-DIAGNOSIS{uncertain_note}:
  Condition:   {hf_result.get('hf_diagnosis')}
  Confidence:  {hf_result.get('hf_confidence')}%
  Agreement:   {hf_result.get('agreement')} specialist models
  Models used: {hf_result.get('models_used', 1)}

→ If your visual analysis AGREES: confirm and elaborate
→ If image evidence CONTRADICTS: explain in differential_diagnosis
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"""