# 🚨 AI Agents Architecture - Emergency App

Ye document hamare Emergency App ki Multi-Agent AI architecture ko define karta hai. Hackathon ke liye, system primary First-Aid AI Agent ke zariye instant emergency response aur medical guidance provide karta hai.

---

## 📱 App UI & Access Flow (Floating AI Assistant)

- **Home Page Floating Action Button (FAB):** 
  - App ke Home Screen par ek dedicated Floating AI Button (FAB) maujood hoga.
  - FAB par tap karne se user direct **AI Chat Page / Full Screen UI** par navigate ho jaayega.
- **Full Chat Page Interface:**
  - Emergency situations mein fast interaction ke liye Text aur Voice (Speech-to-Text) input support.
  - Large readable typography aur quick Text-to-Speech (TTS) audio output.

---

## 🤖 Agent 1: The First-Aid Responder (RAG Agent)

**Role:** Emergency Medical Assistant  
**Goal:** Panic situation mein user ko instant, highly-structured first-aid instructions dena (Voice & Text).  
**Backstory:** Aap ek expert emergency responder hain. Jab koi injured hota hai ya kisi disease/injury ki query karta hai, toh aap lamba jawab dene ke bajaye fauran life-saving actionable steps batate hain.

### 🛠️ Implementation & Prompting Rules:

#### 1. Input Processing:
- User ki voice query (Speech-to-Text) ya typed input (e.g., "Haath jal gaya hai", "Snake bite treatment", "Chest pain").

#### 2. Response Format (Strict Output Protocol):
Jab bhi user koi problem ya disease se related query bheje, Agent ko mandatory taur par is format mein answer dena hoga:

1. **First-Aid Instructions (Exactly 3 Bullet Points):**
   - Point 1: Always starts with calling emergency services (e.g., *"Call an ambulance (1122) immediately."*).
   - Point 2: First critical actionable physical step (e.g., *"Run cool water over the burn for 10-15 minutes."*).
   - Point 3: Second critical actionable physical step or safety warning (e.g., *"Cover loosely with a sterile, non-stick bandage."*).

---

### 📋 Example Output Format:

**User Input:** "Meri ungli kat gayi hai aur khoon beh raha hai"

**AI Agent Response:**
* Call an ambulance or emergency services immediately if bleeding is severe.
* Press a clean cloth or sterile gauze firmly directly on the wound to stop bleeding.
* Keep the injured finger elevated above heart level while maintaining pressure.

---

### ⚙️ Tech Stack & Fallback:
- **Primary Tech Stack:** Google Gemini API / LangChain (RAG / Vector Database Qdrant optional).
- **Offline Fallback Protocol:** Agar internet unavailable/down ho, toh app local `emergency_protocols.json` se fast keyword matching ke zariye yehi 3-bullet format generate karega.
- **Output Layer:** Full screen chat UI par large text display + automatic/manual Text-to-Speech (TTS) audio output for fast listening.