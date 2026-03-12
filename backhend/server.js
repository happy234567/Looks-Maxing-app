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
    try {
      if (!req.files || !req.files['front']) {
        return res.status(400).json({
          success: false,
          error: 'Front image is required'
        });
      }

      const frontImg = req.files['front'][0];
      const rightImg = req.files['right']?.[0];
      const leftImg = req.files['left']?.[0];

      const model = genAI.getGenerativeModel({
        model: 'gemini-2.5-flash',
        generationConfig: {
          temperature: 0,
          responseMimeType: 'application/json' // 🔥 FORCE STRICT JSON
        }
      });

      const prompt = `You are a highly objective facial aesthetics analysis AI.

Your job is to evaluate facial structure scientifically, proportionally, and consistently.
Remain neutral, analytical, and realistic.

SCORING DISTRIBUTION RULES:

- 40-50 = below average with noticeable flaws.
- 50–59 = average but not severely flawed.
- 60–69 = average to moderately attractive.
- 70–79 = clearly attractive with good structure.
- 80–89 = highly attractive .
- 90–100 = elite-level faces very very attractive.


IMPORTANT:
- Do not over-penalize minor imperfections.
- Evaluate the face holistically.
- Structural harmony matters more than small surface flaws.
- Maintain consistency across all categories.
- Scores should reflect realistic real-world perception.

FACE SHAPE - look at the actual face in the photo and pick ONE:
- Oval: forehead slightly wider than jaw, face length greater than width
- Round: equal width and length, soft jaw, full cheeks
- Square: strong jaw, wide forehead, similar width throughout
- Heart: wide forehead, narrow pointed chin
- Diamond: narrow forehead, wide cheekbones, narrow chin
- Oblong: face much longer than wide, long straight sides
- Triangle: narrow forehead, wide jaw

CANTHAL TILT - examine the angle of the eyes carefully:
- Positive: outer corner of eye is higher than inner corner (upward slant)
- Neutral: outer and inner corners at same level
- Negative: outer corner is lower than inner corner (downward slant)

EYE SHAPE - look at the actual eye shape:
- Almond: tapered at both ends, visible crease
- Round: circular, white visible above/below iris
- Hooded: skin folds over crease, lid appears smaller
- Monolid: no visible crease
- Upturned: outer corners point upward
- Downturned: outer corners point downward

EYE TYPE - based on orbital bone and eye positioning:
- Hunter: deep set, smaller appearing, forward facing, intimidating look
- Prey: larger appearing, more exposed, open and wide
- Neutral: balanced between hunter and prey

Carefully analyze the actual photos provided and return accurate values based on what you SEE.

Return ONLY this exact JSON. No explanation. No markdown. No extra text.

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
        {
          inlineData: {
            mimeType: frontImg.mimetype,
            data: toBase64(frontImg.path)
          }
        }
      ];

      if (rightImg) {
        imageParts.push({
          inlineData: {
            mimeType: rightImg.mimetype,
            data: toBase64(rightImg.path)
          }
        });
      }

      if (leftImg) {
        imageParts.push({
          inlineData: {
            mimeType: leftImg.mimetype,
            data: toBase64(leftImg.path)
          }
        });
      }

      const result = await model.generateContent({
        contents: [
          {
            role: 'user',
            parts: [{ text: prompt }, ...imageParts]
          }
        ]
      });

      const rawText = result.response.text();

      console.log("RAW GEMINI RESPONSE:");
      console.log(rawText);

      let parsed;

      try {
        parsed = JSON.parse(rawText);
      } catch (err) {
        return res.status(500).json({
          success: false,
          error: 'Gemini returned invalid JSON',
          raw: rawText
        });
      }

      // 🔥 Ensure all keys exist (NO more 0 bugs from missing fields)
      const scores = {
        overall: Math.round(parsed.overall ?? 0),
        skin: Math.round(parsed.skin ?? 0),
        cheekbones: Math.round(parsed.cheekbones ?? 0),
        jawline: Math.round(parsed.jawline ?? 0),
        neck: Math.round(parsed.neck ?? 0),
        masculinityFemininity: Math.round(parsed.masculinityFemininity ?? 0),
        eyes: Math.round(parsed.eyes ?? 0),
        symmetry: Math.round(parsed.symmetry ?? 0),
        maxPotential: Math.round(parsed.maxPotential ?? 0),
        faceShape: parsed.faceShape || 'Unable to determine',
        canthalTilt: parsed.canthalTilt || 'Unable to determine',
        eyeShape: parsed.eyeShape || 'Unable to determine',
        eyeType: parsed.eyeType || 'Unable to determine',
      };

      // Cleanup uploaded files
      fs.unlinkSync(frontImg.path);
      if (rightImg) fs.unlinkSync(rightImg.path);
      if (leftImg) fs.unlinkSync(leftImg.path);

      return res.json({
        success: true,
        scores
      });

    } catch (error) {
      console.error(error);
      return res.status(500).json({
        success: false,
        error: error.message
      });
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