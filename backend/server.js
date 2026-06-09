const express = require('express');
const cors = require('cors');
const multer = require('multer');
const { VertexAI } = require('@google-cloud/vertexai');
const fs = require('fs');
const path = require('path');
const sharp = require('sharp');
const rateLimit = require('express-rate-limit');
const admin = require('firebase-admin');
require('dotenv').config();

// ─── Memory-safe concurrency limit (Render free = 512MB) ───────────
let activeRequests = 0;
const MAX_CONCURRENT = 2; // max simultaneous /analyze requests

// ─── Firebase Admin Setup ───────────────────────────
try {
  if (process.env.FIREBASE_SERVICE_ACCOUNT) {
    const serviceAccount = JSON.parse(process.env.FIREBASE_SERVICE_ACCOUNT);
    admin.initializeApp({
      credential: admin.credential.cert(serviceAccount)
    });
    console.log("Firebase Admin initialized using FIREBASE_SERVICE_ACCOUNT env variable");
  } else {
    admin.initializeApp();
    console.log("Firebase Admin initialized using default credentials");
  }
} catch (error) {
  console.error("Firebase Admin initialization error:", error);
}

const app = express();

app.set('trust proxy', 1);

// ─── Firebase Auth Guard ───────────────────────────
const authGuard = async (req, res, next) => {
  const authHeader = req.headers.authorization;
  if (!authHeader || !authHeader.startsWith('Bearer ')) {
    return res.status(401).json({ success: false, error: 'Unauthorized: missing or invalid token' });
  }

  const token = authHeader.split('Bearer ')[1].trim();

  try {
    const decodedToken = await admin.auth().verifyIdToken(token);
    req.user = decodedToken;
    next();
  } catch (error) {
    console.error('Firebase token verification failed:', error.code || error.message);
    if (error.code === 'auth/id-token-expired') {
      return res.status(401).json({ success: false, error: 'Unauthorized: token expired' });
    }
    return res.status(401).json({ success: false, error: 'Unauthorized: token verification failed' });
  }
};

// ─── Security & Rate Limiting ───────────────────────────
const analyzeLimiter = rateLimit({
  windowMs: 5 * 60 * 1000,
  max: 50,
  standardHeaders: true,
  legacyHeaders: false,
  message: { success: false, error: 'Too many requests, please try again later.' },
  keyGenerator: (req) => {
    return req.user?.uid || req.ip;
  },
});

const foodAnalyzeLimiter = rateLimit({
  windowMs: 15 * 60 * 1000, // 15 minutes per IP
  max: 30, // 30 requests
  standardHeaders: true,
  legacyHeaders: false,
  message: { success: false, error: 'Too many requests, please try again later.' },
  keyGenerator: (req) => {
    return req.user?.uid || req.ip;
  },
});

app.use('/analyze', authGuard, analyzeLimiter);
app.use('/food-analyze', authGuard, foodAnalyzeLimiter);

// ─── Vertex AI Initialization ───────────────────────────
// Uses Application Default Credentials (ADC) — no API key needed.
// Set GOOGLE_APPLICATION_CREDENTIALS env var to your service account key JSON,
// or rely on the default service account when running on Google Cloud.
const vertexAI = new VertexAI({
  project: process.env.GOOGLE_CLOUD_PROJECT || 'looks-maxing-app-a8f7c',
  location: process.env.GOOGLE_CLOUD_LOCATION || 'us-central1',
});

// -----------------------------
// Multer Setup
// -----------------------------

// Auto-create uploads directory so multer never fails
const uploadsDir = 'uploads/';
if (!fs.existsSync(uploadsDir)) {
  fs.mkdirSync(uploadsDir, { recursive: true });
}

// Clean up any leftover temp files from previous crashes
try {
  const staleFiles = fs.readdirSync(uploadsDir);
  for (const f of staleFiles) {
    try { fs.unlinkSync(path.join(uploadsDir, f)); } catch (_) { }
  }
  if (staleFiles.length > 0) console.log(`[Startup] Cleaned ${staleFiles.length} stale upload(s)`);
} catch (_) { }

const upload = multer({
  dest: uploadsDir,
  limits: { fileSize: 5 * 1024 * 1024 }, // 5MB limit (images are compressed client-side to 1024x1024 q80)
});

app.use(cors());
app.use(express.json({ limit: '5mb' }));
app.use(express.urlencoded({ limit: '5mb', extended: true }));

// -----------------------------
// Helper: Compress Image to ≤1MB (single-pass, memory-efficient)
// -----------------------------
const MAX_IMAGE_BYTES = 1 * 1024 * 1024; // 1 MB

const compressImageIfNeeded = async (filepath) => {
  const stats = fs.statSync(filepath);
  if (stats.size <= MAX_IMAGE_BYTES) {
    return; // Already under 1MB, no compression needed
  }

  console.log(`Compressing image: ${filepath} (${(stats.size / 1024 / 1024).toFixed(2)} MB)`);

  // Single-pass: resize to max 1024px AND compress to q60 in one operation.
  // Avoids the old iterative loop that created multiple large buffers.
  const compressedBuffer = await sharp(filepath)
    .resize(1024, 1024, { fit: 'inside', withoutEnlargement: true })
    .jpeg({ quality: 60, mozjpeg: true })
    .toBuffer();

  fs.writeFileSync(filepath, compressedBuffer);
  console.log(`Compressed to ${(compressedBuffer.length / 1024 / 1024).toFixed(2)} MB (single-pass)`);
};

// -----------------------------
// Helper: Convert Image to Base64 (stream-based, avoids double-buffering)
// -----------------------------
const toBase64 = (filepath) => {
  const data = fs.readFileSync(filepath);
  const b64 = data.toString('base64');
  // Let the raw buffer be GC'd immediately
  return b64;
};


// -----------------------------
// Analyze Route
// -----------------------------
app.post(
  '/analyze',
  // Concurrency gate: reject if too many requests are already in-flight
  (req, res, next) => {
    if (activeRequests >= MAX_CONCURRENT) {
      console.warn(`[Memory] Rejecting request — ${activeRequests} already in-flight (max ${MAX_CONCURRENT})`);
      return res.status(503).json({ success: false, error: 'Server is busy. Please try again in a few seconds.' });
    }
    activeRequests++;
    // Ensure counter is decremented when the response finishes (success or error)
    res.on('finish', () => { activeRequests--; });
    res.on('close', () => { activeRequests = Math.max(0, activeRequests - 1); });
    next();
  },
  upload.fields([
    { name: 'front' },
    { name: 'side' }
  ]),
  async (req, res) => {
    let filePaths = [];
    try {
      if (!req.user || !req.user.uid) {
        return res.status(401).json({ success: false, error: 'Unauthorized' });
      }

      const uid = req.user.uid;
      const userRef = admin.firestore().collection('users').doc(uid);
      const userDoc = await userRef.get();

      let plan = 'free';
      let uploads = { count: 0, lastReset: admin.firestore.Timestamp.now() };

      if (userDoc.exists) {
        const data = userDoc.data();
        plan = data.plan || 'free';
        // Also check isPremium flag set by the billing service
        if (data.isPremium === true) plan = 'premium';
        if (data.uploads) uploads = data.uploads;
      }

      const now = new Date();
      const lastResetDate = uploads.lastReset && uploads.lastReset.toDate ? uploads.lastReset.toDate() : new Date();

      let limit = 6;
      let windowMs = 24 * 60 * 60 * 1000; // 24 hours for all plans

      if (plan === 'premium') {
        limit = 9;
      }

      if (now.getTime() - lastResetDate.getTime() > windowMs) {
        uploads.count = 0;
        uploads.lastReset = admin.firestore.Timestamp.fromDate(now);
      }

      if (uploads.count >= limit) {
        return res.status(429).json({ success: false, error: 'Upload limit reached for your plan.' });
      }

      if (!req.files || !req.files['front']) {
        return res.status(400).json({ success: false, error: 'Front image is required.' });
      }

      const frontImg = req.files['front'][0];
      const sideImg = req.files['side']?.[0];

      filePaths.push(frontImg.path);
      if (sideImg) filePaths.push(sideImg.path);

      // Validate image files are readable
      for (const fp of filePaths) {
        if (!fs.existsSync(fp)) {
          return res.status(400).json({ success: false, error: 'Failed to process uploaded images. Please try again.' });
        }
      }

      // Compress images >1MB before sending to Gemini
      for (const fp of filePaths) {
        await compressImageIfNeeded(fp);
      }

      const model = vertexAI.getGenerativeModel({
        model: 'gemini-2.5-flash',
        generationConfig: {
          temperature: 0,
          responseMimeType: 'application/json'
        }
      });

      // 🔥 THE 50/50 HYBRID PROMPT (PSL + APPEAL)
      const prompt = `You are an elite facial aesthetics analysis AI. Your scoring system MUST strictly follow a 50/50 hybrid model.

CRITICAL PRE-CHECK (HUMAN FACE VERIFICATION):
Before performing any analysis, you MUST verify if the uploaded photo(s) contain a clear, identifiable human face.
If the photo does not contain a human face (for example, if it is a hand, a foot, an animal, an object, scenery, blank space, text, or if the face is completely obscured), you MUST return EXACTLY this JSON and nothing else:
{
  "error": "No clear human face detected. Please upload a clear photo of your face."
}

If a human face is present, proceed with the analysis.

THE 50/50 SCORING FORMULA:
Your final scores must be an equal blend of two metrics:
1. 50% Objective PSL (Scientific/Mathematical): Bone structure, midface ratio, interpupillary distance, zygomatic prominence, gonial angle, canthal tilt, and extreme biological dimorphism.
2. 50% Subjective Appeal (Aesthetic/Halo): Overall facial harmony, perceived beauty/handsomeness, skin health, styling, and general "model halo" effect.

Never Hesitate to use the full scale from 0 to 100. If someone has elite features, they should get a high score. If they have significant flaws, they should get a low score.
Never Hesitate to use the full range of scores. If someone is average, they should get an average score. If they have noticeable flaws, they should get a below average score. Do not be afraid to give low scores if warranted.

Mentally evaluate both aspects out of 100, then average them to get the final scores.

CRITICAL OVERRIDE - THE SUPERMODEL RULE:
If a face possesses top 0.1% PSL traits (e.g., hollow cheeks, square jaw) AND high subjective appeal, you MUST NOT safety-cap the score.

SCORING CALIBRATION:
- 40-59: Average. Common proportions, soft jawline, low PSL traits, average appeal.
- 60-79: Good looking. Strong harmony, visible bone structure, high appeal.
- 80-89: Model tier. Sharp PSL features, highly attractive aesthetic appeal.
- 90-99: World Class / Supermodel (e.g., top 0.1%). Perfect 50/50 blend of elite math (PSL) and extreme aesthetic appeal. DO NOT hesitate to give 90+ for flawless faces.

FACE SHAPE - pick ONE based on the actual image:
- Oval: forehead slightly wider than jaw, face length greater than width
- Round: equal width and length, soft jaw, full cheeks
- Square: strong jaw, wide forehead, similar width throughout
- Heart: wide forehead, narrow pointed chin
- Diamond: narrow forehead, wide cheekbones, narrow chin
- Oblong: face much longer than wide, long straight sides
- Triangle: narrow forehead, wide jaw

CANTHAL TILT:
- Positive: outer corner higher than inner
- Neutral: outer and inner level
- Negative: outer corner lower than inner

EYE SHAPE:
- Almond, Round, Hooded, Monolid, Upturned, Downturned

EYE TYPE:
- Hunter: deep set, hooded, forward facing
- Prey: large, open, high sclera show
- Neutral: balanced

IMPORTANT: You MUST return valid JSON with ALL fields. Every numeric field must be an integer between 0 and 100.

Return EXACTLY this JSON. No extra text.
{
  "overall": <number>,
  "skin": <number>,
  "cheekbones": <number>,
  "jawline": <number>,
  "neck": <number>,
  "masculinityFemininity": <number>,
  "eyes": <number>,
  "symmetry": <number>,
  "maxPotential": <number>,
  "faceShape": "<Oval|Round|Square|Heart|Diamond|Oblong|Triangle>",
  "canthalTilt": "<Positive|Neutral|Negative>",
  "eyeShape": "<Almond|Round|Hooded|Monolid|Upturned|Downturned>",
  "eyeType": "<Hunter|Prey|Neutral>"
}`;

      // Build image parts and immediately release file handles
      const frontBase64 = toBase64(frontImg.path);
      const imageParts = [
        { inlineData: { mimeType: 'image/jpeg', data: frontBase64 } }
      ];

      if (sideImg) {
        const sideBase64 = toBase64(sideImg.path);
        imageParts.push({ inlineData: { mimeType: 'image/jpeg', data: sideBase64 } });
      }

      // Delete temp files NOW (before the Gemini API call) to free disk + page cache
      filePaths.forEach(fp => { try { if (fs.existsSync(fp)) fs.unlinkSync(fp); } catch (_) { } });
      const filesAlreadyCleaned = true;

      let result;
      let attempt = 0;
      let maxRetries = 3;
      let success = false;

      while (attempt < maxRetries && !success) {
        try {
          result = await model.generateContent({
            contents: [{ role: 'user', parts: [{ text: prompt }, ...imageParts] }]
          });
          // Vertex AI SDK returns a response wrapper; unwrap it
          result = result.response;
          success = true; // It worked! Break the loop.
        } catch (geminiError) {
          attempt++;
          console.error(`Gemini API error (Attempt ${attempt}):`, geminiError.message || geminiError);

          // If it's a 503 overload error, wait 3 seconds and try again
          if (geminiError.message && geminiError.message.includes('503')) {
            if (attempt < maxRetries) {
              console.log('Server overloaded. Waiting 3 seconds before retrying...');
              await new Promise(resolve => setTimeout(resolve, 3000));
              continue;
            }
          }

          // Check for safety / content filter blocks
          if (geminiError.message && (
            geminiError.message.includes('SAFETY') ||
            geminiError.message.includes('blocked') ||
            geminiError.message.includes('HARM') ||
            geminiError.message.includes('content filter')
          )) {
            if (!filesAlreadyCleaned) filePaths.forEach(p => { try { if (fs.existsSync(p)) fs.unlinkSync(p); } catch (_) { } });
            return res.status(400).json({ success: false, error: 'Could not analyze this image. Please use a clear, well-lit photo of your face.' });
          }

          // If it fails all 3 times, tell the user
          if (attempt >= maxRetries) {
            if (!filesAlreadyCleaned) filePaths.forEach(p => { try { if (fs.existsSync(p)) fs.unlinkSync(p); } catch (_) { } });
            return res.status(500).json({ success: false, error: 'AI analysis failed due to high demand. Please try again later.' });
          }
        }
      }

      // Handle empty/blocked response
      if (!result) {
        if (!filesAlreadyCleaned) filePaths.forEach(p => { try { if (fs.existsSync(p)) fs.unlinkSync(p); } catch (_) { } });
        return res.status(500).json({ success: false, error: 'AI returned an empty response. Please try with a different photo.' });
      }

      let rawText;
      try {
        // Vertex AI SDK: text() may be a method on the response object directly
        const candidates = result.candidates;
        if (!candidates || candidates.length === 0) throw new Error('No candidates in response');
        rawText = candidates[0].content?.parts?.map(p => p.text).join('') || '';
      } catch (textError) {
        console.error('Failed to extract text from Gemini response:', textError.message);
        // This often means the response was blocked by safety filters
        if (!filesAlreadyCleaned) filePaths.forEach(p => { try { if (fs.existsSync(p)) fs.unlinkSync(p); } catch (_) { } });
        return res.status(400).json({ success: false, error: 'Could not analyze this image. The photo may not contain a clear face.' });
      }

      if (!rawText || rawText.trim().length === 0) {
        if (!filesAlreadyCleaned) filePaths.forEach(p => { try { if (fs.existsSync(p)) fs.unlinkSync(p); } catch (_) { } });
        return res.status(500).json({ success: false, error: 'AI returned an empty response. Please try again.' });
      }

      let parsed;
      try {
        const jsonMatch = rawText.match(/\{[\s\S]*\}/);
        if (!jsonMatch) throw new Error("No valid JSON found");
        parsed = JSON.parse(jsonMatch[0]);
      } catch (err) {
        console.error('JSON parse failed. Raw text:', rawText.substring(0, 200));
        if (!filesAlreadyCleaned) filePaths.forEach(p => { try { if (fs.existsSync(p)) fs.unlinkSync(p); } catch (_) { } });
        return res.status(500).json({ success: false, error: 'AI returned an invalid response. Please try again.' });
      }

      if (parsed.error) {
        if (!filesAlreadyCleaned) filePaths.forEach(p => { try { if (fs.existsSync(p)) fs.unlinkSync(p); } catch (_) { } });
        return res.status(400).json({ success: false, error: parsed.error });
      }

      // Validate and clamp all required numeric fields (defaults to 50 if missing/NaN)
      const clamp = (val, min, max) => Math.max(min, Math.min(max, Math.round(Number(val) || 50)));

      const skin = clamp(parsed.skin, 0, 100);
      const cheekbones = clamp(parsed.cheekbones, 0, 100);
      const jawline = clamp(parsed.jawline, 0, 100);
      const neck = clamp(parsed.neck, 0, 100);
      const masculinityFemininity = clamp(parsed.masculinityFemininity, 0, 100);
      const eyes = clamp(parsed.eyes, 0, 100);
      const symmetry = clamp(parsed.symmetry, 0, 100);
      let maxPotential = clamp(parsed.maxPotential, 0, 100);

      const calculatedOverall = Math.round(
        (skin + cheekbones + jawline + neck + masculinityFemininity + eyes + symmetry) / 7
      );

      if (maxPotential < calculatedOverall) {
        maxPotential = Math.min(calculatedOverall + 3, 99);
      }

      // Validate string fields with strict allowed values
      const validFaceShapes = ['Oval', 'Round', 'Square', 'Heart', 'Diamond', 'Oblong', 'Triangle'];
      const validCanthalTilts = ['Positive', 'Neutral', 'Negative'];
      const validEyeShapes = ['Almond', 'Round', 'Hooded', 'Monolid', 'Upturned', 'Downturned'];
      const validEyeTypes = ['Hunter', 'Prey', 'Neutral'];

      const scores = {
        overall: calculatedOverall,
        skin,
        cheekbones,
        jawline,
        neck,
        masculinityFemininity,
        eyes,
        symmetry,
        maxPotential,
        faceShape: validFaceShapes.includes(parsed.faceShape) ? parsed.faceShape : 'Oval',
        canthalTilt: validCanthalTilts.includes(parsed.canthalTilt) ? parsed.canthalTilt : 'Neutral',
        eyeShape: validEyeShapes.includes(parsed.eyeShape) ? parsed.eyeShape : 'Almond',
        eyeType: validEyeTypes.includes(parsed.eyeType) ? parsed.eyeType : 'Neutral',
      };

      uploads.count += 1;
      if (!uploads.lastReset || !uploads.lastReset.toDate) {
        uploads.lastReset = admin.firestore.Timestamp.fromDate(now);
      }
      await userRef.set({ uploads: uploads }, { merge: true });

      if (!filesAlreadyCleaned) filePaths.forEach(p => { try { if (fs.existsSync(p)) fs.unlinkSync(p); } catch (_) { } });

      return res.json({ success: true, scores });

    } catch (error) {
      console.error('Analyze endpoint error:', error);
      filePaths.forEach(p => { try { if (fs.existsSync(p)) fs.unlinkSync(p); } catch (_) { } });
      // Sanitize error message — don't expose internals to the client
      const safeMessage = 'An unexpected error occurred. Please try again.';
      return res.status(500).json({ success: false, error: safeMessage });
    }
  }
);

// -----------------------------
// Food Analyze Route
// -----------------------------
app.post(
  '/food-analyze',
  (req, res, next) => {
    if (activeRequests >= MAX_CONCURRENT) {
      console.warn(`[Memory] Rejecting food request — ${activeRequests} already in-flight (max ${MAX_CONCURRENT})`);
      return res.status(503).json({ success: false, error: 'Server is busy. Please try again in a few seconds.' });
    }
    activeRequests++;
    res.on('finish', () => { activeRequests--; });
    res.on('close', () => { activeRequests = Math.max(0, activeRequests - 1); });
    // Handle multer errors explicitly
    upload.single('frontImage')(req, res, (multerErr) => {
      if (multerErr) {
        console.error('[food-analyze] Multer error:', multerErr.message);
        return res.status(400).json({ success: false, error: `Upload error: ${multerErr.message}` });
      }
      next();
    });
  },
  async (req, res) => {
    console.log('[food-analyze] Handler entered. req.file:', !!req.file, 'req.user:', !!req.user);
    let filePath = null;
    try {
      if (!req.user || !req.user.uid) {
        return res.status(401).json({ success: false, error: 'Unauthorized' });
      }

      if (!req.file) {
        return res.status(400).json({ success: false, error: 'frontImage is required.' });
      }

      filePath = req.file.path;
      const mealType = req.body.mealType || 'snack';

      if (!fs.existsSync(filePath)) {
        return res.status(400).json({ success: false, error: 'Failed to process uploaded image.' });
      }

      // Compress if needed
      await compressImageIfNeeded(filePath);

      const model = vertexAI.getGenerativeModel({
        model: 'gemini-2.5-flash',
        generationConfig: {
          temperature: 0,
          responseMimeType: 'application/json'
        }
      });

      const base64Data = toBase64(filePath);
      const imagePart = {
        inlineData: { mimeType: 'image/jpeg', data: base64Data }
      };

      const promptText = `You are a world-class nutrition AI. Analyze this food image with forensic precision.

CRITICAL INSTRUCTIONS:
1. EXACT PORTIONS: Do NOT default to 100g. Look at plate sizes, hands, or utensils to establish 3D volume. 1 standard roti = 40g. 1 cup cooked rice = 150g. 1 standard chicken breast = 170g. Dense foods (meat, wet rice) weigh more than light foods (bread, leaves). Give exact weights (e.g., 145g, 85g).
2. CALORIES & MACROS: Calculate the precise total calories, protein, carbs, fats, and fiber based on your calculated gram weight.
3. NAMING: Use simple English and Indian terms (e.g., "white rice cooked", "roti wheat chapati", "chicken breast grilled", "dal moong cooked").
4. COST SAVING (STRICT OUTPUT): Return ONLY a raw JSON object. NO markdown formatting like \`\`\`json. NO explanations. Start immediately with {.

{
  "foods": [
    {
      "name": "roti wheat chapati",
      "estimated_grams": 80,
      "calories": 237,
      "protein": 7.2,
      "carbs": 48.0,
      "fats": 2.4,
      "fiber": 2.8,
      "confidence": "high"
    }
  ],
  "meal_description": "2 rotis",
  "image_quality": "good"
}

If image does not contain food: {"foods": [], "meal_description": "No food detected", "image_quality": "no_food"}
If image is too blurry: {"foods": [], "meal_description": "Image too blurry", "image_quality": "poor"}`;

      // Clean up temp file before model invocation to free space/cache
      try {
        if (fs.existsSync(filePath)) {
          fs.unlinkSync(filePath);
          filePath = null;
        }
      } catch (err) {
        console.error('Failed to unlink file early:', err);
      }

      let result;
      let attempt = 0;
      let maxRetries = 3;
      let success = false;

      while (attempt < maxRetries && !success) {
        try {
          const geminiResponse = await model.generateContent({
            contents: [{ role: 'user', parts: [{ text: promptText }, imagePart] }]
          });
          result = geminiResponse.response;
          success = true;
        } catch (geminiError) {
          attempt++;
          console.error(`Gemini API error (Attempt ${attempt}):`, geminiError.message || geminiError);
          if (geminiError.message && geminiError.message.includes('503')) {
            if (attempt < maxRetries) {
              await new Promise(resolve => setTimeout(resolve, 3000));
              continue;
            }
          }
          if (attempt >= maxRetries) {
            return res.status(500).json({ success: false, error: 'AI analysis failed due to high demand. Please try again later.' });
          }
        }
      }

      if (!result) {
        return res.status(500).json({ success: false, error: 'AI returned an empty response. Please try with a different photo.' });
      }

      let rawText;
      try {
        const candidates = result.candidates;
        if (!candidates || candidates.length === 0) throw new Error('No candidates in response');
        rawText = candidates[0].content?.parts?.map(p => p.text).join('') || '';
      } catch (textError) {
        console.error('Failed to extract text from Gemini response:', textError.message);
        return res.status(400).json({ success: false, error: 'Could not analyze this image. The photo may not contain food.' });
      }

      if (!rawText || rawText.trim().length === 0) {
        return res.status(500).json({ success: false, error: 'AI returned an empty response. Please try again.' });
      }

      let parsed;
      try {
        const jsonMatch = rawText.match(/\{[\s\S]*\}/);
        if (!jsonMatch) throw new Error("No valid JSON found");
        parsed = JSON.parse(jsonMatch[0]);
      } catch (err) {
        console.error('JSON parse failed. Raw text:', rawText.substring(0, 200));
        return res.status(500).json({ success: false, error: 'AI returned an invalid response. Please try again.' });
      }

      return res.json({
        success: true,
        foods: parsed.foods || [],
        meal_description: parsed.meal_description || '',
        mealType: mealType
      });

    } catch (error) {
      console.error('Food-analyze endpoint error:', error);
      if (filePath && fs.existsSync(filePath)) {
        try { fs.unlinkSync(filePath); } catch (_) { }
      }
      // Include actual error message for debugging
      const debugMsg = error && error.message ? error.message : String(error);
      console.error('Food-analyze FULL error:', debugMsg);
      return res.status(500).json({ success: false, error: `Server error: ${debugMsg.substring(0, 200)}` });
    }
  }
);

// -----------------------------
// Diagnostic endpoint (no auth needed)
// -----------------------------
app.get('/food-analyze-test', (req, res) => {
  try {
    const model = vertexAI.getGenerativeModel({ model: 'gemini-2.5-flash' });
    res.json({
      success: true,
      message: 'food-analyze route is live',
      modelReady: !!model,
      nodeVersion: process.version,
      memoryMB: Math.round(process.memoryUsage().rss / 1024 / 1024)
    });
  } catch (err) {
    res.status(500).json({ success: false, error: err.message });
  }
});

// -----------------------------
// Root Route
// -----------------------------
app.get('/', (req, res) => {
  res.send('Level Maxing Backend Running 🚀');
});

// -----------------------------
// Global JSON error handler (catches Express/middleware errors)
// Must have 4 args for Express to recognize it as error handler
app.use((err, req, res, next) => {
  console.error('[GLOBAL ERROR HANDLER]', err.message || err);
  if (!res.headersSent) {
    res.status(err.status || 500).json({
      success: false,
      error: `Server error: ${(err.message || 'Unknown error').substring(0, 300)}`
    });
  }
});

// Start Server
// -----------------------------
// ─── Graceful OOM prevention ────────────────────────────────────
process.on('uncaughtException', (err) => {
  console.error('[FATAL] Uncaught exception:', err.message);
  // Clean up uploads dir on crash
  try {
    const files = fs.readdirSync(uploadsDir);
    files.forEach(f => { try { fs.unlinkSync(path.join(uploadsDir, f)); } catch (_) { } });
  } catch (_) { }
});

const PORT = process.env.PORT || 3000;
app.listen(PORT, () => {
  console.log(`Server running on port ${PORT} (max ${MAX_CONCURRENT} concurrent analyze requests)`);
  console.log(`Memory limit: ~512MB (Render Free). Optimizations active.`);
});