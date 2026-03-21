const express = require('express');
const cors = require('cors');
const multer = require('multer');
const { GoogleGenerativeAI } = require('@google/generative-ai');
const fs = require('fs');
require('dotenv').config();

const app = express();

// -----------------------------
// Gemini Initialization
// -----------------------------
const genAI = new GoogleGenerativeAI(process.env.GEMINI_API_KEY);

// -----------------------------
// Multer Setup
// -----------------------------
const upload = multer({
  dest: 'uploads/',
  limits: { fileSize: 10 * 1024 * 1024 } // 10MB limit
});

app.use(cors());
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
      if (!req.files || !req.files['front']) {
        return res.status(400).json({ success: false, error: 'Front image is required' });
      }

      const frontImg = req.files['front'][0];
      const rightImg = req.files['right']?.[0];
      const leftImg = req.files['left']?.[0];

      filePaths.push(frontImg.path);
      if (rightImg) filePaths.push(rightImg.path);
      if (leftImg) filePaths.push(leftImg.path);

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

      const result = await model.generateContent({
        contents: [{ role: 'user', parts: [{ text: prompt }, ...imageParts] }]
      });

      const rawText = result.response.text();
      
      let parsed;
      try {
        const jsonMatch = rawText.match(/\{[\s\S]*\}/);
        if (!jsonMatch) throw new Error("No valid JSON found");
        parsed = JSON.parse(jsonMatch[0]);
      } catch (err) {
        filePaths.forEach(path => { if (fs.existsSync(path)) fs.unlinkSync(path); });
        return res.status(500).json({ success: false, error: 'Gemini returned invalid JSON' });
      }

// Calculate overall as average of 7 traits
      const skin = Math.round(parsed.skin ?? 0);
      const cheekbones = Math.round(parsed.cheekbones ?? 0);
      const jawline = Math.round(parsed.jawline ?? 0);
      const neck = Math.round(parsed.neck ?? 0);
      const masculinityFemininity = Math.round(parsed.masculinityFemininity ?? 0);
      const eyes = Math.round(parsed.eyes ?? 0);
      const symmetry = Math.round(parsed.symmetry ?? 0);
      let maxPotential = Math.round(parsed.maxPotential ?? 0);

      const calculatedOverall = Math.round(
        (skin + cheekbones + jawline + neck + masculinityFemininity + eyes + symmetry) / 7
      );

      if (maxPotential < calculatedOverall) {
        maxPotential = Math.min(calculatedOverall + 3, 99);
      }

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
        faceShape: parsed.faceShape || 'Unable to determine',
        canthalTilt: parsed.canthalTilt || 'Unable to determine',
        eyeShape: parsed.eyeShape || 'Unable to determine',
        eyeType: parsed.eyeType || 'Unable to determine',
      };

      filePaths.forEach(path => { if (fs.existsSync(path)) fs.unlinkSync(path); });

      return res.json({ success: true, scores });

    } catch (error) {
      console.error(error);
      filePaths.forEach(path => { if (fs.existsSync(path)) fs.unlinkSync(path); });
      return res.status(500).json({ success: false, error: error.message });
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