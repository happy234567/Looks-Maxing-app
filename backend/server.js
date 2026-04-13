const express = require('express');
const cors = require('cors');
const multer = require('multer');
const { GoogleGenerativeAI } = require('@google/generative-ai');
const fs = require('fs');
const rateLimit = require('express-rate-limit');
const admin = require('firebase-admin');
require('dotenv').config();

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

app.use('/analyze', authGuard, analyzeLimiter);

// ─── Gemini Initialization ───────────────────────────
const genAI = new GoogleGenerativeAI(process.env.GEMINI_API_KEY);

// -----------------------------
// Multer Setup
// -----------------------------

// Auto-create uploads directory so multer never fails
const uploadsDir = 'uploads/';
if (!fs.existsSync(uploadsDir)) {
  fs.mkdirSync(uploadsDir, { recursive: true });
}

const upload = multer({
  dest: uploadsDir,
  limits: { fileSize: 10 * 1024 * 1024 }, // 10MB limit
  fileFilter: (req, file, cb) => {
    // Only accept image files
    if (file.mimetype.startsWith('image/')) {
      cb(null, true);
    } else {
      cb(new Error('Only image files are allowed'), false);
    }
  }
});

app.use(cors({
  origin: ['https://level-maxing-backend.onrender.com'],
  methods: ['POST', 'GET'],
  allowedHeaders: ['Content-Type', 'Authorization'],
}));
app.use(express.json({ limit: '50mb' }));
app.use(express.urlencoded({ limit: '50mb', extended: true }));

// -----------------------------
// Helper: Convert Image to Base64
// -----------------------------
const toBase64 = (filepath) => {
  const data = fs.readFileSync(filepath);
  return data.toString('base64');
};


// -----------------------------
// Analyze Route
// -----------------------------
app.post(
  '/analyze',
  upload.fields([
    { name: 'front' },
    { name: 'right' },
    { name: 'left' }
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
      let windowMs = 30 * 24 * 60 * 60 * 1000;

      if (plan === 'premium') {
        limit = 9;
        windowMs = 24 * 60 * 60 * 1000;
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
      const rightImg = req.files['right']?.[0];
      const leftImg = req.files['left']?.[0];

      filePaths.push(frontImg.path);
      if (rightImg) filePaths.push(rightImg.path);
      if (leftImg) filePaths.push(leftImg.path);

      // Validate image files are readable
      for (const fp of filePaths) {
        if (!fs.existsSync(fp)) {
          return res.status(400).json({ success: false, error: 'Failed to process uploaded images. Please try again.' });
        }
      }

      const model = genAI.getGenerativeModel({
        model: 'gemini-2.5-flash',
        generationConfig: {
          temperature: 0,
          responseMimeType: 'application/json'
        }
      });

      // 🔥 THE 50/50 HYBRID PROMPT (PSL + APPEAL)
      const prompt = `You are an elite facial aesthetics analysis AI. Your scoring system MUST strictly follow a 50/50 hybrid model.

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

      const imageParts = [
        { inlineData: { mimeType: frontImg.mimetype, data: toBase64(frontImg.path) } }
      ];

      if (rightImg) imageParts.push({ inlineData: { mimeType: rightImg.mimetype, data: toBase64(rightImg.path) } });
      if (leftImg) imageParts.push({ inlineData: { mimeType: leftImg.mimetype, data: toBase64(leftImg.path) } });

      let result;
      try {
        result = await model.generateContent({
          contents: [{ role: 'user', parts: [{ text: prompt }, ...imageParts] }]
        });
      } catch (geminiError) {
        console.error('Gemini API error:', geminiError.message || geminiError);
        // Check for safety / content filter blocks
        if (geminiError.message && (
          geminiError.message.includes('SAFETY') ||
          geminiError.message.includes('blocked') ||
          geminiError.message.includes('HARM') ||
          geminiError.message.includes('content filter')
        )) {
          filePaths.forEach(path => { if (fs.existsSync(path)) fs.unlinkSync(path); });
          return res.status(400).json({ success: false, error: 'Could not analyze this image. Please use a clear, well-lit photo of your face.' });
        }
        filePaths.forEach(path => { if (fs.existsSync(path)) fs.unlinkSync(path); });
        return res.status(500).json({ success: false, error: 'AI analysis failed. Please try again.' });
      }

      // Handle empty/blocked response
      if (!result || !result.response) {
        filePaths.forEach(path => { if (fs.existsSync(path)) fs.unlinkSync(path); });
        return res.status(500).json({ success: false, error: 'AI returned an empty response. Please try with a different photo.' });
      }

      let rawText;
      try {
        rawText = result.response.text();
      } catch (textError) {
        console.error('Failed to extract text from Gemini response:', textError.message);
        // This often means the response was blocked by safety filters
        filePaths.forEach(path => { if (fs.existsSync(path)) fs.unlinkSync(path); });
        return res.status(400).json({ success: false, error: 'Could not analyze this image. The photo may not contain a clear face.' });
      }

      if (!rawText || rawText.trim().length === 0) {
        filePaths.forEach(path => { if (fs.existsSync(path)) fs.unlinkSync(path); });
        return res.status(500).json({ success: false, error: 'AI returned an empty response. Please try again.' });
      }

      let parsed;
      try {
        const jsonMatch = rawText.match(/\{[\s\S]*\}/);
        if (!jsonMatch) throw new Error("No valid JSON found");
        parsed = JSON.parse(jsonMatch[0]);
      } catch (err) {
        console.error('JSON parse failed. Raw text:', rawText.substring(0, 200));
        filePaths.forEach(path => { if (fs.existsSync(path)) fs.unlinkSync(path); });
        return res.status(500).json({ success: false, error: 'AI returned an invalid response. Please try again.' });
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

      filePaths.forEach(path => { if (fs.existsSync(path)) fs.unlinkSync(path); });

      return res.json({ success: true, scores });

    } catch (error) {
      console.error('Analyze endpoint error:', error);
      filePaths.forEach(path => { if (fs.existsSync(path)) fs.unlinkSync(path); });
      // Sanitize error message — don't expose internals to the client
      const safeMessage = 'An unexpected error occurred. Please try again.';
      return res.status(500).json({ success: false, error: safeMessage });
    }
  }
);

// -----------------------------
// Root Route
// -----------------------------
app.get('/', (req, res) => {
  res.send('Level Maxing Backend Running 🚀');
});

// -----------------------------
// Start Server
// -----------------------------
const PORT = process.env.PORT || 3000;
app.listen(PORT, () => {
  console.log(`Server running on port ${PORT}`);
});