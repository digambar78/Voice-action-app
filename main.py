from fastapi import FastAPI, HTTPException
from fastapi.middleware.cors import CORSMiddleware
from pydantic import BaseModel
import spacy

app = FastAPI()

# Enable CORS for Flutter App
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],  # Replace "*" with ["http://192.168.x.x:8080"] for more security
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

# Load SpaCy model
try:
    nlp = spacy.load("en_core_web_sm")
    print("✅ SpaCy model loaded successfully.")
except Exception as e:
    print(f"❌ Failed to load SpaCy model: {e}")

# Request model
class Transcription(BaseModel):
    text: str

# API endpoint to extract actions
@app.post("/extract-actions/")
def extract_actions(transcription: Transcription):
    try:
        if not transcription.text.strip():
            raise HTTPException(status_code=400, detail="Input text cannot be empty.")
        
        doc = nlp(transcription.text)
        tasks, dates, key_points = [], [], []

        # Process sentences
        for sent in doc.sents:
            if any(word in sent.text.lower() for word in ["do", "complete", "schedule", "create", "finish"]):
                tasks.append(sent.text)

            for ent in sent.ents:
                if ent.label_ == "DATE":
                    dates.append(ent.text)

            key_points.append(sent.text)

        # Log output for debugging
        print(f"🎤 Transcription: {transcription.text}")
        print(f"📝 Extracted Tasks: {tasks}")
        print(f"📅 Detected Dates: {dates}")
        print(f"🔑 Key Points: {key_points}")

        return {
            "tasks": tasks,
            "dates": dates,
            "key_points": key_points
        }

    except Exception as e:
        print(f"❌ Error processing request: {e}")
        raise HTTPException(status_code=500, detail=f"Failed to extract actions: {e}")

# Health check endpoint
@app.get("/")
def health_check():
    return {"message": "🚀 FastAPI server is running!"}
