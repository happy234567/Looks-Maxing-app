import 'package:flutter/material.dart';

// ignore_for_file: prefer_const_constructors, prefer_const_literals_to_create_immutables

// ── MODELS (embedded to avoid Windows import resolution issues) ──────────────

class GuideSection {
  final String emoji;
  final String title;
  final String body;
  final Color accentColor;

  const GuideSection({
    required this.emoji,
    required this.title,
    required this.body,
    required this.accentColor,
  });
}

class GuideArticle {
  final String id;
  final String title;
  final String subtitle;
  final String emoji;
  final bool isPremium;
  final List<GuideSection> sections;
  final String? keyRule;

  const GuideArticle({
    required this.id,
    required this.title,
    required this.subtitle,
    required this.emoji,
    required this.isPremium,
    required this.sections,
    this.keyRule,
  });
}

// ── CONTENT DATA ─────────────────────────────────────────────────────────────

List<GuideArticle> get freeArticles => [
  GuideArticle(
    id: 'basic_skincare',
    title: 'Basic Skincare',
    subtitle: 'Clear, healthy skin with a simple daily routine',
    emoji: '🧴',
    isPremium: false,
    keyRule: 'Consistency matters more than using lots of products. A simple routine done every day will improve your skin much more than constantly changing products.',
    sections: [
      GuideSection(
        emoji: '📖',
        title: 'Introduction',
        accentColor: Color(0xFF4CAF50),
        body:
            'If you want clear, healthy skin, you don\'t need a complicated routine.\n\n'
            'Consistency with a few simple habits will improve your skin over time.\n\n'
            'The foundation of good skin comes down to **three things: cleansing, moisturizing, and protecting your skin**.',
      ),
      GuideSection(
        emoji: '🌅',
        title: 'Morning Routine',
        accentColor: Color(0xFFFF9800),
        body:
            '**1. Wash Your Face**\n'
            'Start your day by washing your face with a gentle cleanser. '
            'This removes oil, sweat, and bacteria that build up overnight. '
            'Use **lukewarm water**, not hot water, because hot water can dry out your skin.\n\n'
            '**2. Moisturize**\n'
            'After washing your face, apply a lightweight moisturizer. '
            'Moisturizer keeps your skin hydrated and prevents dryness or excess oil production. '
            'Even people with oily skin should moisturize.\n\n'
            '**3. Apply Sunscreen**\n'
            'Sunscreen is one of the most important steps in skincare.\n'
            'Sun exposure causes:\n'
            '* premature aging\n'
            '* wrinkles\n'
            '* dark spots\n'
            '* skin damage\n\n'
            'Use **SPF 30 or higher** every morning, even on cloudy days.',
      ),
      GuideSection(
        emoji: '🌙',
        title: 'Night Routine',
        accentColor: Color(0xFF7C5CBF),
        body:
            '**1. Cleanse Your Face Again**\n'
            'Wash your face before going to bed to remove dirt, oil, and pollution that built up during the day. '
            'If you wore sunscreen or sweat a lot, cleansing at night is especially important.\n\n'
            '**2. Moisturize Again**\n'
            'Apply moisturizer again before sleep. '
            'Your skin repairs itself during the night, so hydration helps support that process.',
      ),
      GuideSection(
        emoji: '📅',
        title: 'Weekly Habits',
        accentColor: Color(0xFF2196F3),
        body:
            '**Exfoliation – 1 to 2 times per week**\n'
            'Exfoliating removes dead skin cells and helps keep pores clear. '
            'Use a **gentle chemical exfoliant** or a mild exfoliating product. '
            'Avoid over-exfoliating because it can irritate your skin.',
      ),
      GuideSection(
        emoji: '💡',
        title: 'Habits That Improve Skin Over Time',
        accentColor: Color(0xFFFFD700),
        body:
            'Good skin is not just about products. Your lifestyle also matters.\n\n'
            '**Stay Hydrated**\n'
            'Drink about **2–3 liters of water per day** to support skin hydration.\n\n'
            '**Sleep Well**\n'
            'Aim for **7–9 hours of sleep** each night. Your skin repairs and regenerates during sleep.\n\n'
            '**Avoid Touching Your Face**\n'
            'Your hands carry bacteria that can cause breakouts.\n\n'
            '**Keep Pillowcases Clean**\n'
            'Change your pillowcase regularly (every few days if possible) to prevent oil and bacteria buildup.\n\n'
            '**Eat Nutrient-Dense Foods**\n'
            'Healthy foods support skin health. Focus on:\n'
            '* fruits and vegetables\n'
            '* healthy fats\n'
            '* protein\n'
            '* foods rich in vitamins A, C, and E',
      ),
      GuideSection(
        emoji: '📈',
        title: 'What to Expect Over Time',
        accentColor: Color(0xFF4CAF50),
        body:
            '**1–2 weeks**\n'
            'Skin starts feeling cleaner and more balanced.\n\n'
            '**1–2 months**\n'
            'Breakouts may reduce and skin texture may improve.\n\n'
            '**3–6 months**\n'
            'Skin often appears healthier, clearer, and more even.',
      ),
    ],
  ),
  GuideArticle(
    id: 'basic_health',
    title: 'Basic Health Routine',
    subtitle: 'Five habits that build a strong foundation',
    emoji: '💪',
    isPremium: false,
    keyRule: 'Small healthy habits done every day will improve your health over time.',
    sections: [
      GuideSection(
        emoji: '😴',
        title: 'Sleep',
        accentColor: Color(0xFF7C5CBF),
        body:
            'Get **7–9 hours of sleep** every night.\n\n'
            'Sleep helps your body recover, balance hormones, and improve energy.\n\n'
            'Try to sleep and wake up at the **same time each day**.',
      ),
      GuideSection(
        emoji: '💧',
        title: 'Hydration',
        accentColor: Color(0xFF2196F3),
        body:
            'Drink around **2–3 liters of water** per day.\n\n'
            'Water supports energy, digestion, skin health, and overall body function.',
      ),
      GuideSection(
        emoji: '🥗',
        title: 'Nutrition',
        accentColor: Color(0xFF4CAF50),
        body:
            'Eat mostly **whole foods**.\n\n'
            'Focus on:\n'
            '* protein (eggs, fish, meat, beans)\n'
            '* fruits and vegetables\n'
            '* healthy fats (nuts, olive oil)\n'
            '* complex carbs (rice, oats, potatoes)\n\n'
            'Limit **processed and sugary foods**.',
      ),
      GuideSection(
        emoji: '🏃',
        title: 'Movement',
        accentColor: Color(0xFFFF9800),
        body:
            'Move your body **every day**.\n\n'
            'Aim for **20–30 minutes** of activity like walking, exercise, or sports.',
      ),
      GuideSection(
        emoji: '☀️',
        title: 'Sunlight',
        accentColor: Color(0xFFFFD700),
        body:
            'Get **10–20 minutes of sunlight daily** when possible.\n\n'
            'Sunlight helps your body produce **vitamin D** and regulate your sleep cycle.',
      ),
    ],
  ),
];

List<GuideArticle> get premiumArticles => [
  GuideArticle(
    id: 'facial_symmetry',
    title: 'Facial Symmetry',
    subtitle: 'How to improve your facial balance and structure',
    emoji: '⚖️',
    isPremium: true,
    keyRule: 'The biggest changes won\'t come from one intense day. They\'ll come from small habits repeated daily. Start now. Commit to the process. Track your progress. And watch the results compound over time.',
    sections: [
      GuideSection(
        emoji: '📖',
        title: 'Understanding Facial Asymmetry',
        accentColor: Color(0xFF2196F3),
        body:
            'Facial symmetry is one of the biggest indicators of attractiveness.\n\n'
            'Yes, all of us have some level of asymmetry — that\'s completely normal. But the good news is, there are ways to significantly improve it.\n\n'
            'Symmetry has always been associated with health, balance, and overall attractiveness. It\'s something people subconsciously notice right away.\n\n'
            'You don\'t need a **100% symmetrical face**. If you can correct or improve even **80–90% of your visible asymmetries**, you\'ll look noticeably better.',
      ),
      GuideSection(
        emoji: '🔍',
        title: 'Where Asymmetry Comes From',
        accentColor: Color(0xFFFF9800),
        body:
            'Sometimes, it\'s simply **genetic** — you were born with certain structural differences.\n\n'
            'But a lot of asymmetry develops from everyday habits:\n'
            '* Poor posture\n'
            '* Constantly sleeping on one side\n'
            '* The way you sit\n'
            '* Past injuries or facial trauma\n'
            '* Chewing only on one side\n'
            '* Smiling unevenly\n'
            '* Making the same dominant facial expression repeatedly\n\n'
            'Over time, these small repeated patterns lead to noticeable muscle imbalances.\n\n'
            'Before you fix anything, you have to **understand the root cause**.',
      ),
      GuideSection(
        emoji: '🧬',
        title: 'The Science Behind Fixing It',
        accentColor: Color(0xFF7C5CBF),
        body:
            'Your face isn\'t just skin. It\'s supported by a combination of **bone structure, muscles, and soft tissue**. If you want real improvement, you have to address all three.\n\n'
            'The methods focus on:\n'
            '* Correcting muscle imbalances\n'
            '* Encouraging better structural alignment\n'
            '* Improving tissue tone and firmness\n\n'
            '**Consistency is everything.** This isn\'t an overnight transformation. Results won\'t appear instantly. It takes time, patience, and repetition.\n\n'
            'But if you stay consistent, the changes add up — and it\'s absolutely worth it.',
      ),
      GuideSection(
        emoji: '🧍',
        title: 'Method #1: Posture Correction',
        accentColor: Color(0xFF4CAF50),
        body:
            'Poor posture can seriously affect your facial symmetry. Especially **forward head posture** — that rounded upper back, chin slightly lifted, neck pushing forward look — can throw off your jaw alignment over time.\n\n'
            '**How to fix it:**\n'
            '* Stand or sit tall with a straight spine\n'
            '* Keep your ears aligned directly over your shoulders\n'
            '* Gently tuck your chin back\n'
            '* Make sure your neck is not tilted to one side\n\n'
            'This isn\'t something you do for 5 minutes — it\'s something you **maintain throughout the day**.\n\n'
            'Take it a step further: start training your **neck and upper back** in the gym. A stronger neck supports better posture, and better posture supports better facial alignment.\n\n'
            'Over a few months, consistently fixing your posture can noticeably improve your facial balance.',
      ),
      GuideSection(
        emoji: '🦷',
        title: 'Method #2: Alternate Your Chewing',
        accentColor: Color(0xFFFF5722),
        body:
            'This one is simple — but you need to do it correctly.\n\n'
            'Avoid fixing this with gum. Repetitive chewing with such a small range of motion can increase your risk of **TMJ issues** over time.\n\n'
            'Instead, stick to natural, tougher foods — crusty bread, carrots, steak — foods that require real chewing effort.\n\n'
            '**How to find your weaker side:**\n'
            'Take a straight front-facing photo and look at your masseter muscles (jaw muscles near the back of your cheeks). One side is usually more developed.\n\n'
            '**Aim for 60–70%** chewing on the weaker side, and the rest on the stronger side.\n\n'
            'This takes months of consistent correction — not weeks. But if you\'re already seeing uneven masseter development, that imbalance will only get worse if you ignore it.',
      ),
      GuideSection(
        emoji: '💪',
        title: 'Method #3: Facial Exercises',
        accentColor: Color(0xFF2196F3),
        body:
            'Facial exercises can help activate underused muscles and relax overworked ones — bringing better overall balance to your face.\n\n'
            '**Resistance Smiling:**\n'
            'Place your fingers lightly on the outer corners of your mouth. Try to smile upward, lifting both sides evenly. At the same time, gently push back with your fingers to create resistance.\n\n'
            'You should feel tension around your mouth area — this helps wake up weaker muscles contributing to imbalance.\n\n'
            '* Hold for about **20 seconds**, then relax\n'
            '* Repeat for around **10 minutes a day**\n'
            '* Make sure both sides are working evenly\n\n'
            'Small daily activation can gradually improve muscle balance over time.',
      ),
      GuideSection(
        emoji: '👁️',
        title: 'Method #4: Eye Area Balance',
        accentColor: Color(0xFF9C27B0),
        body:
            'Independent eyebrow control is a very underrated skill for facial symmetry.\n\n'
            '**Practice in front of a mirror:**\n'
            'Try lifting one eyebrow while keeping the other relaxed. Then switch sides.\n\n'
            'At first, it might feel awkward — that\'s normal. If one side is weaker or harder to control, give it extra reps.\n\n'
            'Also add this movement: gently pull the **outer ends of your eyebrows upward**, while keeping the base of the brows relaxed. Don\'t tense your forehead too much — the goal is controlled activation.\n\n'
            'With consistent practice, you\'ll notice improved muscle awareness and better symmetry around the eyes.',
      ),
      GuideSection(
        emoji: '🛌',
        title: 'Fix Your Sleep Habits',
        accentColor: Color(0xFF607D8B),
        body:
            'Constantly sleeping on one side can increase **fluid retention** on that lower side of the face. Over time, it can also create slight compression — especially if you\'re younger and still developing.\n\n'
            'Don\'t just switch to the opposite side. That\'s just shifting the problem.\n\n'
            'Instead, aim to **sleep on your back**. Back sleeping keeps pressure evenly distributed and prevents unnecessary compression or fluid imbalance.\n\n'
            '**If you struggle with it:**\n'
            '* Place pillows on both sides of your body so you physically can\'t roll over\n'
            '* Do a hard workout before bed so you\'re completely exhausted — when you\'re that tired, you\'ll fall asleep fast and stay in position',
      ),
      GuideSection(
        emoji: '👅',
        title: 'Mewing',
        accentColor: Color(0xFFFFD700),
        body:
            'When done correctly and consistently, proper tongue posture can gradually improve jaw alignment and overall facial balance.\n\n'
            '**How to mew properly:**\n'
            '* Rest your **entire tongue flat** against the roof of your mouth — not just the tip, the whole surface\n'
            '* Keep your lips sealed\n'
            '* Let your teeth lightly touch or stay very slightly apart\n\n'
            'If you can maintain gentle **upward tongue pressure** throughout the day, even better. The consistency is what matters.\n\n'
            'Over time, proper tongue posture can support better alignment of the jaw, improve facial definition, and contribute to a more balanced appearance.\n\n'
            'This isn\'t magic. It\'s posture. And posture only works if you stay consistent.',
      ),
      GuideSection(
        emoji: '📈',
        title: 'What Results to Expect',
        accentColor: Color(0xFF4CAF50),
        body:
            '**Week 1–2**\n'
            'You\'ll start noticing small changes in muscle activation and posture. Your face may feel more balanced, even if visual changes are subtle.\n\n'
            '**Month 1–2**\n'
            'Things become more noticeable. You may start seeing improvements in your jawline definition, cheekbone structure, and overall facial alignment.\n\n'
            '**6–12 Months**\n'
            'With real consistency, this is where significant, long-lasting changes happen. Your face can look more structured, more balanced, and naturally more attractive.',
      ),
      GuideSection(
        emoji: '💎',
        title: 'Added Tips',
        accentColor: Color(0xFF00BCD4),
        body:
            '**Gua Sha**\n'
            'Use a gua sha tool with oil — it helps get rid of face fluid retention which will give you a temporarily more symmetrical look.\n\n'
            '**Fix Your Bite**\n'
            'If you have a bad bite, this will create asymmetry in your face and it will get worse with time. As soon as possible, get **braces** — it will fix your jaw asymmetry perfectly. It costs about 30k–50k but it\'s definitely worth it.',
      ),
    ],
  ),
  GuideArticle(
    id: 'beard_growth',
    title: 'Beard Growth',
    subtitle: 'Grow a fuller, thicker beard with proven methods',
    emoji: '🧔',
    isPremium: true,
    keyRule: 'Consistency and time are what create real progress. Stick with it. Be patient. Stay disciplined.',
    sections: [
      GuideSection(
        emoji: '📖',
        title: 'The Foundation',
        accentColor: Color(0xFF8D6E63),
        body:
            'Growing a beard isn\'t just about genetics.\n\n'
            'It\'s about giving your body the right tools to perform at its best — and properly stimulating your hair follicles so they can reach their full genetic potential.\n\n'
            '**Genetics** play a major role in how your beard develops. If the men in your family can grow thick, full beards, there\'s a strong chance you can too.\n\n'
            '**Hormones** like testosterone and DHT are the main drivers behind beard growth. Optimizing these naturally can make a noticeable difference.\n\n'
            'Beard growth happens in three stages:\n'
            '* **Anagen** — the growth phase\n'
            '* **Catagen** — the transition phase\n'
            '* **Telogen** — the resting phase\n\n'
            'The goal is simple: **extend the anagen phase** for as long as possible. The longer your hairs stay in the growth phase, the thicker and fuller your beard can become.',
      ),
      GuideSection(
        emoji: '🫙',
        title: 'Oils & Topical Solutions',
        accentColor: Color(0xFF4CAF50),
        body:
            '**Castor Oil**\n'
            'Rich in ricinoleic acid, castor oil may help increase blood circulation to hair follicles. Better circulation means better nutrient delivery — supporting healthier growth over time.\n\n'
            '**Emu Oil**\n'
            'Known for deep penetration into the skin. Helps reduce inflammation and delivers nutrients directly to the follicles — especially helpful for patchy or slow-growing areas.\n\n'
            '**Rosemary Oil**\n'
            'Research suggests rosemary oil can support hair growth comparably to certain commercial treatments — without the common side effects. Always mix with a carrier oil like jojoba, almond, or olive oil.\n\n'
            '**Beard Balms**\n'
            'Look for natural ingredients like shea butter, beeswax, and essential oils. They keep hair healthy, hydrated, and thicker-looking.\n\n'
            'Consistency is what makes these oils effective. Apply regularly. Massage properly. Give it time.\n\n'
            '🛒 **My Personal Recommendation**\n'
            'I personally use a mix of rosemary oil, olive oil, and castor oil — it\'s affordable and has worked well for me. This is not sponsored. I recommend it because I actually use it myself and have seen results. **You can buy it directly from the Shop tab inside the app.**',
      ),
      GuideSection(
        emoji: '🪡',
        title: 'Derma Rollers vs Derma Stamps',
        accentColor: Color(0xFF2196F3),
        body:
            'Creating tiny micro-injuries in the skin increases blood flow and triggers your body\'s natural healing response. This boosts collagen production and can stimulate dormant hair follicles.\n\n'
            '**Derma Roller** — faster, covers the beard area in about a minute.\n\n'
            '**Derma Stamp** — takes 3–5 minutes but gives more precise, controlled application. Usually the better option for beard growth.\n\n'
            'Use needles in the **0.5mm to 1mm range**.\n\n'
            '**How to use properly:**\n'
            '* Disinfect the tool with rubbing alcohol before and after every use\n'
            '* Gently stamp across the beard area in multiple directions\n'
            '* Pay extra attention to patchy spots\n'
            '* Use **1–2 times per week** — no more\n'
            '* On non-stamping days, apply beard oils nightly\n\n'
            'Consistency + proper technique + quality tools = real results.\n\n'
            '🛒 **My Personal Recommendation**\n'
            'I personally use a derma stamp and have had great results. Don\'t go for the cheapest option — quality matters when needles are touching your skin. This is not a sponsorship, just sharing what has worked for me. **You can buy the exact one I use from the Shop tab inside the app.**',
      ),
      GuideSection(
        emoji: '🥩',
        title: 'Nutrition & Supplements',
        accentColor: Color(0xFFFF9800),
        body:
            'What you put into your body directly impacts how your beard grows. If your body doesn\'t have the right nutrients, your follicles won\'t perform at their best.\n\n'
            '**Biotin** — aim for around 2.5mg daily. Supports keratin production essential for hair strength. Found naturally in eggs, nuts, and avocados.\n\n'
            '**Zinc & Magnesium** — support healthy testosterone levels, a major driver of beard growth.\n\n'
            '**Protein** — your beard is made of keratin, and keratin is a protein. Focus on lean meats, fish, and eggs.\n\n'
            '**Omega-3 Fatty Acids** — found in fish, walnuts, and flaxseeds. Support healthy skin and reduce inflammation, creating a better environment for beard growth.\n\n'
            'A high-quality multivitamin can help fill gaps if your diet isn\'t perfectly balanced.',
      ),
      GuideSection(
        emoji: '🏋️',
        title: 'Lifestyle Factors',
        accentColor: Color(0xFF7C5CBF),
        body:
            'You can use all the oils and tools in the world, but if your daily habits are bad, your beard growth will suffer.\n\n'
            '**Sleep** — 7 to 9 hours every night. This is when your body repairs itself, regulates hormones, and supports hair growth.\n\n'
            '**Stress Control** — chronic stress increases cortisol, which negatively impacts testosterone. Train hard. Meditate. Go outside.\n\n'
            '**Exercise** — lifting weights and staying active supports healthy testosterone levels and improves blood circulation.\n\n'
            '**Hydration** — 2–3 liters of water daily keeps skin healthy and supports nutrient delivery to follicles.\n\n'
            '**Avoid smoking and limit alcohol** — both interfere with hormone balance and reduce nutrient absorption.',
      ),
      GuideSection(
        emoji: '💊',
        title: 'What About Minoxidil?',
        accentColor: Color(0xFFFF5722),
        body:
            'If you\'ve tried everything — lifestyle, nutrition, oils, derma stamping — and you\'re still really struggling, then consider Minoxidil.\n\n'
            'Minoxidil is commonly used for scalp hair loss but some people also use it to stimulate beard growth.\n\n'
            '**Important warnings:**\n'
            '* Can cause dryness, irritation, and skin sensitivity\n'
            '* Consult a doctor before using\n'
            '* When you stop using it, some hair grown during use may shed\n'
            '* Requires long-term consistency — missing applications affects results\n\n'
            'Natural methods — hormone optimization, derma stamping, essential oils, nutrition, and lifestyle — take more patience but don\'t carry the same potential side effects.',
      ),
      GuideSection(
        emoji: '💡',
        title: 'Added Tips',
        accentColor: Color(0xFFFFD700),
        body:
            '**Sunlight**\n'
            'Get as much daily sunlight as possible. Sunlight helps a lot with beard growth. Also, if you\'re naturally dark-haired, you may notice your beard getting darker over time with regular sun exposure — try it yourself.\n\n'
            '**Cardio**\n'
            'Cardio helps with blood circulation, which directly supports beard growth. Add it to your routine consistently.',
      ),
    ],
  ),
  GuideArticle(
    id: 'bone_smashing',
    title: 'Bone Smashing',
    subtitle: 'The truth behind the most dangerous looksmaxing trend',
    emoji: '💀',
    isPremium: true,
    keyRule: 'Self-improvement should come from self-respect — not self-harm. You don\'t need to injure yourself to become better. Stay smart. Stay patient. Stay safe.',
    sections: [
      GuideSection(
        emoji: '⚠️',
        title: 'What Is Bone Smashing?',
        accentColor: Color(0xFFFF5722),
        body:
            'Bone smashing is one of the most talked-about, yet most **dangerous trends** in the looksmaxing space.\n\n'
            'The idea: repeatedly hitting your facial bones with a hard object to "stimulate bone growth" and supposedly improve facial structure.\n\n'
            'People justify it using **Wolff\'s Law** — the principle that bone adapts to stress.\n\n'
            'But here\'s the reality: **bone smashing does not work the way people think it does.**\n\n'
            'Wolff\'s Law refers to controlled, gradual mechanical stress — like resistance training. It does not mean randomly hitting your face will reshape it. That\'s a complete misunderstanding of the science.',
      ),
      GuideSection(
        emoji: '🔬',
        title: 'The Science — What Wolff\'s Law Actually Says',
        accentColor: Color(0xFF2196F3),
        body:
            'Wolff\'s Law states that bones adapt to the stress placed on them over time. For example:\n'
            '* Weightlifters develop denser bones from lifting heavy loads\n'
            '* Astronauts lose bone density in space because gravity isn\'t placing stress on their skeleton\n\n'
            'So yes — bones do respond to pressure.\n\n'
            'But here\'s the key detail people ignore:\n\n'
            'Wolff\'s Law applies to **slow, controlled, consistent pressure** placed on bones over time. It does not apply to random trauma or blunt force to your face.\n\n'
            'There\'s a massive difference between progressive resistance training and repeatedly hitting your cheekbones with a hard object.',
      ),
      GuideSection(
        emoji: '❌',
        title: 'Why It Doesn\'t Work — 4 Reasons',
        accentColor: Color(0xFFFF9800),
        body:
            '**1. Controlled Stress vs. Trauma**\n'
            'Wolff\'s Law describes the body adapting to controlled, functional stress. Bone smashing creates chaotic, uncontrolled trauma — risking fractures, chronic inflammation, and improper healing. That\'s not optimization. That\'s damage.\n\n'
            '**2. Irregular Healing**\n'
            'Microfractures don\'t heal in a perfectly sculpted, aesthetic way. The body heals injuries in the safest way possible — often leading to a **callus**, a bulky, uneven buildup of bone tissue. Instead of sharp features, you risk uneven contours, misshapen structure, and asymmetry.\n\n'
            '**3. Facial Bones Aren\'t Built for Impact**\n'
            'Wolff\'s Law is often observed in weight-bearing bones like the femur. Your facial bones are thinner, more delicate, and surrounded by nerves and soft tissue. The adaptation principle simply doesn\'t apply.\n\n'
            '**4. Soft Tissue Damage**\n'
            'Even if bone adaptation were possible, your skin and soft tissue would still suffer. Repeated impact can cause permanent scarring, sagging, cartilage damage, discoloration, and accelerated aging.',
      ),
      GuideSection(
        emoji: '🚨',
        title: 'The Real Risks',
        accentColor: Color(0xFFE53935),
        body:
            'Let\'s be clear about what you\'re gambling with:\n'
            '* Permanent bone deformities\n'
            '* Nerve damage\n'
            '* Chronic inflammation\n'
            '* Increased infection risk\n'
            '* Accelerated aging\n'
            '* Psychological harm\n\n'
            'The psychological toll is real. This trend often pulls people into a rabbit hole of self-criticism and self-harm disguised as "self-improvement."\n\n'
            'At some point, it stops being about optimization… and starts becoming **self-punishment**.',
      ),
      GuideSection(
        emoji: '✅',
        title: 'What Actually Works Instead',
        accentColor: Color(0xFF4CAF50),
        body:
            'If you want to improve your facial aesthetics safely, focus on things that actually work:\n\n'
            '**Orthotropics & Proper Tongue Posture**\n'
            'Good posture, neck alignment, and mewing.\n\n'
            '**Weight Loss & Fitness**\n'
            'Lower body fat = more facial definition.\n\n'
            '**Skincare & Collagen Support**\n'
            'Healthy skin dramatically changes appearance.\n\n'
            '**Jaw Development & Myofunctional Work**\n'
            'Chewing exercises and functional therapy — safely.\n\n'
            'Real improvement comes from **consistency, not trauma**.',
      ),
    ],
  ),
  GuideArticle(
    id: 'eye_bags',
    title: 'Eye Bags',
    subtitle: 'Understand the types and fix them properly',
    emoji: '👁️',
    isPremium: true,
    keyRule: 'Treating eye bags isn\'t an overnight process. But with consistency, temporary puffiness, dark circles, and even fat-related bags can be reduced. Small daily habits. Long-term results.',
    sections: [
      GuideSection(
        emoji: '🔍',
        title: 'Why Do We Get Eye Bags?',
        accentColor: Color(0xFF2196F3),
        body:
            'Your eye bags can make you look tired, stressed, and older than you actually are.\n\n'
            'Not all eye bags are the same — there are different types, each with different causes and different treatments.\n\n'
            'Eye bags usually form because of:\n'
            '* Fluid retention\n'
            '* Fat displacement\n'
            '* Thinning skin under the eyes\n\n'
            'If you want to treat them effectively, you first need to understand what\'s causing yours.',
      ),
      GuideSection(
        emoji: '💧',
        title: 'Type 1: Temporary Puffiness',
        accentColor: Color(0xFF42A5F5),
        body:
            'The classic swollen, puffy look under the eyes.\n\n'
            '**Causes:**\n'
            '* Fluid retention\n'
            '* Allergies\n'
            '* Lack of sleep\n'
            '* High sodium intake\n\n'
            '**Long-Term Fix:**\n'
            '* Reduce sodium intake, especially in the evening\n'
            '* Drink 2–3 liters of water daily\n'
            '* Sleep with your head elevated (add an extra pillow)\n\n'
            '**Quick Fixes:**\n'
            '* Cold compress\n'
            '* Chilled spoons\n'
            '* Cucumber slices\n'
            '* Lymphatic drainage massage (gently in circular motions with moisturizer)\n'
            '* Caffeine eye creams (helps constrict blood vessels)',
      ),
      GuideSection(
        emoji: '🧬',
        title: 'Type 2: Fat-Related Eye Bags',
        accentColor: Color(0xFFFF9800),
        body:
            'These look more structural and permanent.\n\n'
            '**Causes:**\n'
            '* Aging (muscle weakening around the eyes)\n'
            '* Genetics\n'
            '* Natural fat pad displacement\n\n'
            '**Long-Term Solutions:**\n'
            '* Topical retinoids (stimulate collagen production)\n'
            '* Skin-tightening treatments like radiofrequency or ultrasound therapy\n\n'
            '⚠️ Cold compresses won\'t fix this type long-term. They may reduce swelling slightly, but they don\'t address the underlying fat pads.',
      ),
      GuideSection(
        emoji: '🌑',
        title: 'Type 3: Dark Eye Bags',
        accentColor: Color(0xFF7C5CBF),
        body:
            'These look darker rather than puffy.\n\n'
            '**Causes:** Thinning skin, pigmentation, genetics, sun exposure, or hollowing.\n\n'
            '**If caused by thinning skin:**\n'
            '* Vitamin C serum\n'
            '* Hyaluronic acid\n'
            '* Retinol creams\n\n'
            '**If caused by pigmentation:**\n'
            '* Daily sunscreen\n'
            '* Niacinamide creams\n'
            '* Kojic acid products\n\n'
            '**If caused by hollowing:**\n'
            '* Improve diet\n'
            '* Increase Vitamin K intake (spinach, kale)\n'
            '* Support healthy circulation',
      ),
      GuideSection(
        emoji: '😴',
        title: 'Type 4: Lifestyle-Driven Eye Bags',
        accentColor: Color(0xFF4CAF50),
        body:
            'Caused entirely by daily habits.\n\n'
            '**Causes:**\n'
            '* Stress\n'
            '* Poor sleep\n'
            '* Dehydration\n'
            '* Excessive screen time\n\n'
            '**Fix It By:**\n'
            '* Sleeping **7–9 hours** nightly with a consistent schedule\n'
            '* Avoiding screens 1–2 hours before bed\n'
            '* Practicing stress management (meditation, breathwork, yoga)\n'
            '* Drinking **2–3 liters of water** daily\n'
            '* Using the **20-20-20 rule** for screens — every 20 minutes, look 20 feet away for 20 seconds',
      ),
      GuideSection(
        emoji: '💡',
        title: 'Holistic Tips',
        accentColor: Color(0xFFFFD700),
        body:
            '* Use a **gentle cleanser** in your skincare routine\n'
            '* Apply **moisturizing eye cream** twice daily — always pat, never rub the delicate under-eye skin\n'
            '* Wear **broad-spectrum sunscreen** daily. Sunglasses help too\n'
            '* Focus on **antioxidant-rich foods** and omega-3 fatty acids\n'
            '* Avoid smoking and limit alcohol — smoking accelerates collagen breakdown and alcohol dehydrates the skin and worsens puffiness\n\n'
            '🛒 **Product Recommendations**\n'
            'Here are some products you can use while treating your eye bags and dark circles. I\'ve added the ones I personally use and have seen results with myself. **Check them out in the Shop tab inside the app.**',
      ),
    ],
  ),
  GuideArticle(
    id: 'face_debloating',
    title: 'Face Debloating',
    subtitle: 'Reveal a sharper, leaner face with the right habits',
    emoji: '🫧',
    isPremium: true,
    keyRule: 'Facial debloating doesn\'t take years. It can improve over days to weeks if you implement the right habits. Small adjustments in diet, hydration, sleep, and training reveal the sharper, leaner face already underneath.',
    sections: [
      GuideSection(
        emoji: '📖',
        title: 'The Foundation',
        accentColor: Color(0xFF2196F3),
        body:
            'If you\'re lean but still feel like your face doesn\'t look lean, there are two possibilities:\n\n'
            'Either you\'re not as lean as you think…\n\n'
            'Or you\'re dealing with **facial bloat.**\n\n'
            'The foundation of a lean face is a low body fat percentage. For men, ideally around **9–12%** — that\'s typically where facial definition becomes most noticeable.\n\n'
            'But if you\'re already lean and your face still looks puffy, this guide breaks down every method you can use to debloat your face and reveal that slimmer, hollowed-cheek look.',
      ),
      GuideSection(
        emoji: '🔍',
        title: 'Why Facial Bloat Happens',
        accentColor: Color(0xFFFF9800),
        body:
            'Facial bloat doesn\'t just appear randomly. Specific triggers cause it:\n'
            '* **High sodium intake** — too much salt makes your body retain water\n'
            '* **Dehydration** — ironically, not drinking enough water makes your body hold onto more fluid\n'
            '* **Poor sleep** — inadequate rest increases puffiness and water retention\n'
            '* **Alcohol** — dehydrates you and causes rebound fluid retention\n'
            '* **Hormonal fluctuations** — temporary swelling from hormonal shifts\n'
            '* **Food sensitivities** — dairy or gluten intolerance can trigger inflammation\n'
            '* **Lymphatic stagnation** — poor lymph circulation leads to fluid buildup',
      ),
      GuideSection(
        emoji: '🥗',
        title: 'Nutrition Fixes',
        accentColor: Color(0xFF4CAF50),
        body:
            '**1. Reduce Sodium**\n'
            'Processed snacks and fast food are major culprits. Stick to fresh, home-cooked foods and control your salt intake. The excessive sodium in processed foods causes bloating — don\'t confuse that with small amounts of natural mineral salts in a balanced diet.\n\n'
            '**2. Hydrate Properly**\n'
            'Drink **2–3 liters of water daily.** Proper hydration helps flush excess sodium and reduce fluid retention. Include balanced electrolytes if needed — coconut water is a simple natural option. Avoid overdoing it though — too much water without proper balance can worsen bloating.\n\n'
            '**3. Avoid Inflammatory Foods**\n'
            'Limit refined sugars, excess dairy (if sensitive), and fried or heavily processed foods.\n\n'
            'Add berries, turmeric, ginger, and leafy greens — these help reduce inflammation and support fluid balance.\n\n'
            '**4 Debloating Superfoods:**\n'
            '* **Cucumber** — natural diuretic\n'
            '* **Pineapple** — contains bromelain (anti-inflammatory)\n'
            '* **Watermelon** — hydrating and helps flush sodium\n'
            '* **Parsley & dandelion greens** — support natural detox pathways',
      ),
      GuideSection(
        emoji: '🏃',
        title: 'Lifestyle Adjustments',
        accentColor: Color(0xFF7C5CBF),
        body:
            '* Sleep **7–9 hours** nightly\n'
            '* Limit alcohol\n'
            '* Exercise regularly — physical activity improves circulation and reduces water retention\n\n'
            '**Added Tip:**\n'
            'If you\'re doing cardio and you\'re not sweating, that means you\'re not doing enough. If you ARE sweating, that means you\'re actually debloating yourself.',
      ),
      GuideSection(
        emoji: '💆',
        title: 'Lymphatic Drainage',
        accentColor: Color(0xFF00BCD4),
        body:
            'Your lymphatic system plays a major role in facial puffiness. This is **highly underrated.**\n\n'
            '**1. Facial Massage**\n'
            'Use fingertips or a jade roller. Massage upwards and outwards, starting from the center of the face toward the ears.\n\n'
            '**2. Gua Sha**\n'
            'Apply oil or moisturizer. Gently glide along jawline, cheeks, and forehead. Helps encourage fluid movement.\n\n'
            '**3. Neck Massage**\n'
            'Lymphatic drainage begins in the neck. Massage gently downward along the sides of your neck to stimulate flow.\n\n'
            '🛒 **Personal Recommendation**\n'
            'If you\'re planning to try gua sha, I\'ve added the exact one I personally used and had a good experience with. If you want to keep it simple and not overthink which one to choose, you can go with that one. **Check it out in the Shop tab inside the app.**',
      ),
      GuideSection(
        emoji: '🧊',
        title: 'Quick Fix: Cold Therapy',
        accentColor: Color(0xFF42A5F5),
        body:
            'If you need an instant de-puff:\n'
            '* Cold water splash\n'
            '* Chilled spoons\n'
            '* Ice rollers\n\n'
            'This is **temporary** — but effective before events or photos.',
      ),
      GuideSection(
        emoji: '❌',
        title: 'Common Debloating Mistakes',
        accentColor: Color(0xFFE53935),
        body:
            '* Overhydrating without electrolytes\n'
            '* Skipping meals (hormonal disruption increases fluid retention)\n'
            '* Sleeping completely flat\n'
            '* Crash dieting\n\n'
            'Rapid changes shock your system and can **temporarily worsen bloating.**',
      ),
      GuideSection(
        emoji: '🏆',
        title: 'Long-Term Slim Face Strategy',
        accentColor: Color(0xFFFFD700),
        body:
            'If you want permanent definition:\n'
            '* Maintain a healthy, low body fat percentage\n'
            '* Follow a balanced diet\n'
            '* Train consistently\n'
            '* Improve gut health\n'
            '* Manage stress\n\n'
            'Chronic stress increases cortisol, and elevated cortisol increases water retention.\n\n'
            'Meditation, breathwork, yoga, even simple gratitude practices — don\'t knock them until you try them.',
      ),
    ],
  ),
  GuideArticle(
    id: 'hair_style',
    title: 'Hair Style',
    subtitle: 'Find the perfect hairstyle for your face shape',
    emoji: '💇',
    isPremium: true,
    keyRule: 'Face analysis helps. Structure helps. But confidence is what makes it work. Experiment. Refine. Own your look.',
    sections: [
      GuideSection(
        emoji: '📖',
        title: 'Why Your Hairstyle Matters',
        accentColor: Color(0xFF2196F3),
        body:
            'Your hairstyle plays a massive role in framing your face and highlighting your best features.\n\n'
            'Picking the wrong cut can throw off your proportions — while the right one can **dramatically enhance them.**\n\n'
            'The goal is simple: highlight your best features and balance out disproportionate areas.\n\n'
            'Examples:\n'
            '* A longer face benefits from added width\n'
            '* A round face benefits from added height\n'
            '* A square, angular face benefits from softer texture',
      ),
      GuideSection(
        emoji: '🔍',
        title: 'The Six Main Face Shapes',
        accentColor: Color(0xFFFF9800),
        body:
            '**1. Oval** — Balanced proportions, slightly longer than it is wide\n\n'
            '**2. Round** — Equal width and height, with softer rounded edges\n\n'
            '**3. Square** — Equal proportions with a strong, defined jawline\n\n'
            '**4. Diamond** — Broad cheekbones with a narrower forehead and jaw\n\n'
            '**5. Heart** — Wider forehead and cheekbones with a narrow, pointed chin\n\n'
            '**6. Rectangular/Oblong** — Longer face with similar width at forehead, cheeks, and jaw',
      ),
      GuideSection(
        emoji: '🪞',
        title: 'How to Assess Your Face Shape',
        accentColor: Color(0xFF4CAF50),
        body:
            'Look straight into a mirror and pull your hair back. Notice:\n'
            '* Which part of your face is the widest\n'
            '* Whether your jawline is rounded or angular\n'
            '* Whether your face is longer than it is wide\n\n'
            'Or, make it even easier — just use the **Scan Face feature inside our app.** Slide in, and you\'ll instantly see your current face shape, eye shape, eye type, and more. It breaks everything down for you automatically.',
      ),
      GuideSection(
        emoji: '🥚',
        title: 'Oval Face',
        accentColor: Color(0xFF9C27B0),
        body:
            'You can pull off **almost any cut.**\n\n'
            'Just avoid heavy fringes — they can make your face look shorter.',
      ),
      GuideSection(
        emoji: '⭕',
        title: 'Round Face',
        accentColor: Color(0xFF2196F3),
        body:
            'Add **height**. Remove width from the sides.\n\n'
            'Fades and undercuts elongate your face.\n\n'
            'Avoid round styles like buzz cuts or bowl cuts — they exaggerate the roundness.',
      ),
      GuideSection(
        emoji: '⬛',
        title: 'Square Face',
        accentColor: Color(0xFF607D8B),
        body:
            'Go for **textured crops, side parts, or longer layered styles** to soften strong angles.\n\n'
            'Avoid flat, boxy cuts — they\'ll make your face look even more square.',
      ),
      GuideSection(
        emoji: '📏',
        title: 'Rectangular / Oblong Face',
        accentColor: Color(0xFFFF5722),
        body:
            'Add **volume to the sides.**\n\n'
            'If your face is longer, side volume helps balance proportions.\n\n'
            'Avoid overly long styles — they\'ll make your face look even longer.',
      ),
      GuideSection(
        emoji: '💎',
        title: 'Diamond Face',
        accentColor: Color(0xFF00BCD4),
        body:
            'Add **width where you\'re narrow.**\n\n'
            'If your jaw narrows sharply, build volume around the back and lower sides.\n\n'
            'If your upper area is narrow, add width near the temples.\n\n'
            'The goal: **balance.**',
      ),
      GuideSection(
        emoji: '🫀',
        title: 'Heart-Shaped Face',
        accentColor: Color(0xFFE91E63),
        body:
            'Avoid very short cuts — they emphasize your forehead.\n\n'
            'Add **volume around the lower third** of your face, especially toward the back, to balance the chin area.',
      ),
      GuideSection(
        emoji: '🌊',
        title: 'Adapting to Your Hair Type',
        accentColor: Color(0xFF4CAF50),
        body:
            '**Straight Hair**\n'
            'Works well with structured styles like slick backs or pompadours.\n\n'
            '**Wavy Hair**\n'
            'Go for textured cuts to emphasize natural movement.\n\n'
            '**Curly Hair**\n'
            'Shorter sides with volume on top creates strong contrast.\n\n'
            '**Coily Hair**\n'
            'Cropped or tightly shaped styles tend to work best.',
      ),
      GuideSection(
        emoji: '📐',
        title: 'Hairline & Final Tips',
        accentColor: Color(0xFFFFD700),
        body:
            'Your hairline matters too.\n\n'
            'If you have a **receding hairline**, go for textured styles that draw attention away from the corners.\n\n'
            'If you have a **widow\'s peak**, you have two options:\n'
            '* Hide it with a fringe or curtains\n'
            '* Or own it confidently with a strong, masculine style\n\n'
            'Both can work — it depends on how you carry it.\n\n'
            'If you\'re unsure about your face shape, start with something versatile — like a **medium fade or layered cut** — and adjust from there.\n\n'
            'Get second opinions. Experiment subtly. Pay attention to what gets the best reactions.\n\n'
            'Ultimately, your hairstyle reflects your personality. With the knowledge from here, you\'re fully equipped to upgrade your style.',
      ),
    ],
  ),
  GuideArticle(
    id: 'gut_health_skin',
    title: 'Gut Health For Clear Skin',
    subtitle: 'Fix your skin from the inside out',
    emoji: '🫁',
    isPremium: true,
    keyRule: 'You don\'t fix acne at the surface. You fix it at the source. Address the root cause — inflammation, gut imbalance, nutrient absorption — and your skin will reflect your internal health. Stay consistent. Let your glow come from within.',
    sections: [
      GuideSection(
        emoji: '📖',
        title: 'The Gut–Skin Connection',
        accentColor: Color(0xFF4CAF50),
        body:
            'Your skin is a mirror of your gut. If your gut isn\'t functioning properly, your skin will show it.\n\n'
            'An imbalanced gut leads to **chronic inflammation** — and that inflammation shows up as:\n'
            '* Puffiness\n'
            '* Acne\n'
            '* Eczema\n'
            '* Psoriasis\n'
            '* Rosacea\n'
            '* Redness\n\n'
            'When your gut barrier becomes compromised (often called "leaky gut"), toxins enter the bloodstream — triggering systemic inflammation that leads to breakouts and skin irritation.\n\n'
            'Your gut also absorbs key nutrients needed for skin health: **Vitamin A, Vitamin E, Zinc, and Omega-3 fatty acids.** If your gut isn\'t healthy, your skin isn\'t getting what it needs to repair and regenerate.\n\n'
            'Your gut contains trillions of bacteria. The beneficial ones reduce inflammation and strengthen your skin barrier. When harmful bacteria dominate, that\'s when acne and redness flare up.',
      ),
      GuideSection(
        emoji: '🚨',
        title: 'Signs Your Gut Might Be Imbalanced',
        accentColor: Color(0xFFFF5722),
        body:
            'If you struggle with any of these, your gut microbiome likely needs attention:\n'
            '* Persistent breakouts\n'
            '* Dry, flaky skin\n'
            '* Redness or rosacea\n'
            '* Eczema or psoriasis flare-ups\n'
            '* Dull or uneven skin tone',
      ),
      GuideSection(
        emoji: '🥗',
        title: 'Dietary Foundations',
        accentColor: Color(0xFF4CAF50),
        body:
            'Your diet is the foundation of gut health. This is **non-negotiable.**\n\n'
            '**Probiotic-Rich Foods** — introduce beneficial bacteria:\n'
            '* Yogurt\n'
            '* Kefir\n'
            '* Sauerkraut\n'
            '* Kimchi\n'
            '* Miso\n'
            '* Kombucha\n\n'
            '**Prebiotic Foods** — feed the good bacteria already in your gut:\n'
            '* Garlic\n'
            '* Onions\n'
            '* Bananas\n'
            '* Asparagus\n'
            '* Oats\n\n'
            '**Fiber-Rich Foods** — support digestion and detoxification:\n'
            '* Leafy greens\n'
            '* Beans\n'
            '* Lentils\n'
            '* Whole grains\n\n'
            '**Anti-Inflammatory Foods** — reduce gut inflammation:\n'
            '* Fatty fish (salmon, mackerel)\n'
            '* Turmeric\n'
            '* Ginger\n'
            '* Berries',
      ),
      GuideSection(
        emoji: '❌',
        title: 'Foods to Avoid',
        accentColor: Color(0xFFE53935),
        body:
            'If you\'re serious about fixing your skin, you need discipline.\n\n'
            'Avoid:\n'
            '* Processed foods\n'
            '* Refined carbs\n'
            '* Refined sugars\n'
            '* Excessive alcohol\n\n'
            'These damage your gut and your skin reflects it.\n\n'
            'Dairy and gluten can also trigger inflammation — but this varies per person.',
      ),
      GuideSection(
        emoji: '🔧',
        title: 'Practical Habits for Gut Restoration',
        accentColor: Color(0xFF2196F3),
        body:
            'Diet comes first — always. But you can also:\n'
            '* Take a **broad-spectrum probiotic** (multiple strains)\n'
            '* Eat fermented foods daily\n'
            '* Only use antibiotics when absolutely necessary\n\n'
            '**To strengthen your gut barrier:**\n'
            '* Consume collagen or bone broth\n'
            '* Add **L-glutamine** (supports gut lining repair)\n'
            '* Eat polyphenol-rich foods like green tea, dark chocolate, and berries\n\n'
            'Polyphenols feed beneficial bacteria and reduce inflammation.',
      ),
      GuideSection(
        emoji: '🏃',
        title: 'Lifestyle Matters More Than You Think',
        accentColor: Color(0xFF7C5CBF),
        body:
            '* Drink enough water\n'
            '* Manage stress\n'
            '* Sleep **7–9 hours** in a dark room\n'
            '* Test for food sensitivities\n\n'
            'Undiagnosed intolerances can destroy your skin.\n\n'
            'An **elimination diet** can help identify triggers — remove common irritants, then slowly reintroduce and monitor your skin\'s response.',
      ),
      GuideSection(
        emoji: '📈',
        title: 'What Results Can You Expect?',
        accentColor: Color(0xFF4CAF50),
        body:
            '**Week 1**\n'
            'Less bloating. Reduced inflammation.\n\n'
            '**Month 1**\n'
            'Fewer breakouts. Improved skin texture.\n\n'
            '**3–6 Months**\n'
            'Clearer, more radiant, even-toned skin as your gut fully stabilizes.',
      ),
      GuideSection(
        emoji: '⭐',
        title: '5 Simple Daily Staples',
        accentColor: Color(0xFFFFD700),
        body:
            '* Start your morning with **warm water and lemon**\n'
            '* Eat fermented foods daily\n'
            '* Chew your food thoroughly\n'
            '* Limit constant snacking — let your gut rest\n'
            '* Try **12–16 hours of overnight fasting** to support repair',
      ),
    ],
  ),
  GuideArticle(
    id: 'hormone_height',
    title: 'Hormone Optimisation for Height',
    subtitle: 'Maximize your genetic height potential',
    emoji: '📏',
    isPremium: true,
    keyRule: 'Height optimization isn\'t magic. It\'s about supporting your hormones, protecting your growth plates, and building healthy habits. The time will pass anyway — you might as well use it to maximize your potential. Stay consistent. Stay patient.',
    sections: [
      GuideSection(
        emoji: '📖',
        title: 'Introduction',
        accentColor: Color(0xFF2196F3),
        body:
            'Have you ever wondered why some people grow taller while others don\'t seem to reach their full height potential?\n\n'
            'Yes, genetics play a major role. But there are still things you can do to make sure you reach your **maximum genetic potential.**\n\n'
            'One of the biggest factors? **Your hormones.**\n\n'
            'Especially during your developing years, your hormone levels directly influence how tall you end up.',
      ),
      GuideSection(
        emoji: '🦴',
        title: 'Growth Plates & Key Hormones',
        accentColor: Color(0xFF9C27B0),
        body:
            'Your height is primarily determined by the **growth plates** in your bones — areas of cartilage at the ends of long bones. During childhood and adolescence, these plates allow bones to lengthen. Once they close (typically in your late teens or early twenties) — height growth stops.\n\n'
            'These growth plates are influenced by four key hormones:\n\n'
            '**Human Growth Hormone (HGH)**\n'
            'Produced in the pituitary gland. The main driver of bone growth.\n\n'
            '**IGF-1 (Insulin-like Growth Factor 1)**\n'
            'Works alongside HGH and promotes bone and muscle development.\n\n'
            '**Testosterone & Estrogen**\n'
            'Fuel growth spurts during puberty. However, high levels also signal growth plate closure — which eventually ends height growth.\n\n'
            '**Cortisol**\n'
            'Chronic stress increases cortisol. High cortisol suppresses growth hormone, which can slow development.',
      ),
      GuideSection(
        emoji: '⏰',
        title: 'Best Time for Optimization',
        accentColor: Color(0xFFFF9800),
        body:
            'Timing matters. Hormone optimization is most effective during:\n\n'
            '**Childhood & Adolescence**\n'
            'This is when growth plates are fully open.\n\n'
            '**Ages 12–18 (Puberty)**\n'
            'HGH production peaks. Growth spurts happen here. Optimization during this window makes the biggest difference.\n\n'
            '**Ages 18–21**\n'
            'Growth plates begin closing. Growth slows down.\n\n'
            'After closure, you won\'t grow taller — but you can still improve bone density and overall health.\n\n'
            'If your growth plates are closed, this won\'t increase your height. But it will support **stronger bones and better posture.**',
      ),
      GuideSection(
        emoji: '😴',
        title: 'Strategy 1: Prioritize Sleep',
        accentColor: Color(0xFF7C5CBF),
        body:
            'Your body releases the most HGH during **deep sleep.**\n\n'
            '* Aim for **8–10 hours** per night\n'
            '* Keep a consistent sleep schedule\n'
            '* Avoid screens before bed\n\n'
            'Sleep is non-negotiable.',
      ),
      GuideSection(
        emoji: '🥗',
        title: 'Strategy 2: Height-Friendly Diet',
        accentColor: Color(0xFF4CAF50),
        body:
            '**Protein-Rich Foods**\n'
            'Eggs, chicken, fish, legumes. Protein provides amino acids essential for growth.\n\n'
            '**Calcium & Vitamin D**\n'
            'Found in dairy, leafy greens, and sunlight. Critical for bone strength.\n\n'
            '**Zinc & Magnesium**\n'
            'Support hormone balance. Found in nuts, seeds, and whole grains.\n\n'
            '**Healthy Fats**\n'
            'Avocados, nuts, olive oil. Support hormone production.\n\n'
            'Nutrition is the foundation.',
      ),
      GuideSection(
        emoji: '🏃',
        title: 'Strategy 3: Growth-Stimulating Exercise',
        accentColor: Color(0xFFFF5722),
        body:
            '**High-Intensity Interval Training (HIIT)**\n'
            'Short bursts of intense activity can stimulate HGH:\n'
            '* Sprints\n'
            '* Bodyweight circuits\n'
            '* Jump training\n\n'
            '**Strength Training**\n'
            'Focus on compound movements:\n'
            '* Squats\n'
            '* Deadlifts\n'
            '* Bench press\n\n'
            'If you\'re in your early teens, avoid extremely heavy loads. Focus on **form and safety.**',
      ),
      GuideSection(
        emoji: '🚫',
        title: 'Strategy 4: Avoid Stimulants & Processed Foods',
        accentColor: Color(0xFFE53935),
        body:
            'Too much sugar and caffeine can disrupt hormone balance.\n\n'
            'Moderation is key. You don\'t need to eliminate everything — just avoid overload.',
      ),
      GuideSection(
        emoji: '🧘',
        title: 'Strategy 5: Manage Stress',
        accentColor: Color(0xFF00BCD4),
        body:
            'Chronic stress increases cortisol.\n\n'
            'High cortisol suppresses growth hormone.\n\n'
            '**Lower stress = better hormonal environment.**',
      ),
      GuideSection(
        emoji: '📈',
        title: 'Expected Results',
        accentColor: Color(0xFF4CAF50),
        body:
            'If you\'re **under 18** and apply these strategies consistently, you\'ll likely maximize your genetic height potential.\n\n'
            'Will you gain 6 inches? There\'s no guaranteed number. Genetics still set the upper limit. But these habits ensure you don\'t fall short of your natural potential.\n\n'
            'During puberty, you may notice stronger, more noticeable growth spurts.\n\n'
            'If you\'re **21+ with closed growth plates**, you won\'t grow taller — but you\'ll improve bone health, posture, and overall performance.',
      ),
      GuideSection(
        emoji: '⚠️',
        title: 'Common Mistakes to Avoid',
        accentColor: Color(0xFFFFD700),
        body:
            '* Neglecting sleep\n'
            '* Overtraining without recovery\n'
            '* Ignoring nutrition\n'
            '* Expecting height increase after growth plates close\n\n'
            'Also remember: **posture correction doesn\'t make you physically taller.** It simply removes compression and allows you to stand at your true height.',
      ),
    ],
  ),
  GuideArticle(
    id: 'insulin_optimisation',
    title: 'Insulin Optimisation',
    subtitle: 'Master your insulin for a leaner, clearer, sharper you',
    emoji: '⚡',
    isPremium: true,
    keyRule: 'Insulin isn\'t just about blood sugar. It affects how you feel, how you perform, and how you look. Master it — and you unlock better energy, clearer skin, and a leaner, sharper physique.',
    sections: [
      GuideSection(
        emoji: '📖',
        title: 'What Is Insulin and Why Does It Matter?',
        accentColor: Color(0xFF2196F3),
        body:
            'Insulin is one of the most powerful hormones in your body. It doesn\'t just control blood sugar — it directly impacts **how you look and how you feel.**\n\n'
            'Insulin is produced by the pancreas. When you eat — especially carbohydrates — your body releases insulin to move glucose from your bloodstream into your cells for energy or storage.\n\n'
            'Insulin:\n'
            '* Provides energy to your cells\n'
            '* Works alongside hormones like IGF-1 to stimulate protein synthesis\n'
            '* Signals your body to store excess glucose as fat\n'
            '* Impacts collagen production and skin elasticity\n\n'
            'When insulin is well regulated, your body thrives. When it\'s out of balance — problems start to appear.',
      ),
      GuideSection(
        emoji: '⚖️',
        title: 'What Happens When Insulin Is Out of Balance?',
        accentColor: Color(0xFFFF5722),
        body:
            '**Too Much Insulin (Chronically Elevated)**\n'
            'Often caused by frequent carb-heavy meals. Can lead to:\n'
            '* Weight gain\n'
            '* Inflammation\n'
            '* Skin issues\n'
            '* Energy crashes\n\n'
            '**Too Little Insulin**\n'
            'Can lead to:\n'
            '* Chronic fatigue\n'
            '* Difficulty building or maintaining muscle\n'
            '* Increased appetite\n'
            '* Accelerated aging\n\n'
            '**Balance is key.**',
      ),
      GuideSection(
        emoji: '😮',
        title: 'How Insulin Affects Your Face',
        accentColor: Color(0xFF9C27B0),
        body:
            'Signs of poorly managed insulin can show up directly in your face:\n'
            '* Puffiness and swelling\n'
            '* Breakouts and oily skin\n'
            '* Wrinkles and sagging\n'
            '* Dark patches or skin tags\n\n'
            'It\'s similar to cortisol in how visibly it can impact your appearance.',
      ),
      GuideSection(
        emoji: '🌅',
        title: 'Mastering Your Morning Insulin',
        accentColor: Color(0xFFFF9800),
        body:
            'Like cortisol, insulin follows a natural rhythm. **Morning nutrition sets the tone for the entire day.**\n\n'
            '**The Problem**\n'
            'Eating refined carbs or sugary foods first thing in the morning causes a sharp insulin spike — leading to energy crashes, fat storage, and increased hunger later.\n\n'
            '**The Solution**\n'
            'Pair carbs with protein and healthy fats to smooth the insulin response. Start your day with:\n'
            '* Protein (eggs, Greek yogurt)\n'
            '* Healthy fats (avocado, nuts)\n'
            '* Complex carbs (oats, sweet potatoes)\n\n'
            'This combination stabilizes blood sugar and keeps insulin steady.\n\n'
            '**What About Skipping Breakfast?**\n'
            'If you delay eating too long after waking, blood sugar can drop — triggering a stress response and cortisol release. This can lead to overeating later, poor food choices, and energy instability. A balanced, nutrient-dense first meal prevents that spiral.',
      ),
      GuideSection(
        emoji: '🍽️',
        title: 'Controlling Insulin Throughout the Day',
        accentColor: Color(0xFF4CAF50),
        body:
            '**1. Prioritize Low Glycemic Foods**\n'
            'Leafy greens, berries, quinoa.\n\n'
            '**2. Add Fiber to Every Meal**\n'
            'Fiber slows digestion and sugar absorption. Instead of fruit alone, have fruit with nuts or Greek yogurt.\n\n'
            '**3. Combine Macronutrients**\n'
            'Always pair carbs with protein and fats. This prevents sharp spikes.',
      ),
      GuideSection(
        emoji: '🏋️',
        title: 'When Should You Spike Insulin?',
        accentColor: Color(0xFF00BCD4),
        body:
            '**Post-workout.**\n\n'
            'After training, your body is more insulin sensitive. That means glucose is directed toward **muscle repair** instead of fat storage.\n\n'
            'If you\'re going to spike insulin, that\'s the strategic time.',
      ),
      GuideSection(
        emoji: '🔥',
        title: 'How to Lower Insulin for Fat Loss',
        accentColor: Color(0xFFE53935),
        body:
            'If fat loss and hormonal balance are the goal:\n'
            '* Try intermittent fasting (e.g., 12-hour fasting window)\n'
            '* Strength train regularly\n'
            '* Avoid late-night snacking\n'
            '* Sleep well\n'
            '* Cut refined sugars and processed carbs\n\n'
            'Lower insulin when it\'s not needed — especially outside of training windows.',
      ),
      GuideSection(
        emoji: '✅',
        title: 'The Result of Balanced Insulin',
        accentColor: Color(0xFF4CAF50),
        body:
            'When insulin is controlled, you get:\n'
            '* Easier fat loss\n'
            '* Clearer skin\n'
            '* More defined features\n'
            '* Better energy\n'
            '* More stable mood',
      ),
      GuideSection(
        emoji: '⭐',
        title: 'Quick Recap',
        accentColor: Color(0xFFFFD700),
        body:
            '* Eat whole foods\n'
            '* Move after meals\n'
            '* Hydrate properly\n'
            '* Strength train\n'
            '* Manage stress',
      ),
    ],
  ),
  GuideArticle(
    id: 'jawline_pitfalls',
    title: 'Jawline Pitfalls',
    subtitle: 'Mistakes that are ruining your jawline progress',
    emoji: '🦷',
    isPremium: true,
    keyRule: 'Your jawline is a reflection of body fat levels, posture, hormonal health, muscle balance, and consistent habits. You don\'t need gimmicks. Focus on natural chewing, getting lean, balanced muscle use, and proper posture. Over time, you\'ll sculpt a defined jawline — safely.',
    sections: [
      GuideSection(
        emoji: '📖',
        title: 'Introduction',
        accentColor: Color(0xFF2196F3),
        body:
            'Improving your jawline can completely transform your look.\n\n'
            'But if you go about it the wrong way, you can end up with **injuries, imbalances, or long-term damage.**\n\n'
            'Here are the biggest mistakes people make when trying to build a sharp, defined jawline.',
      ),
      GuideSection(
        emoji: '❌',
        title: 'Mistake #1: Overusing Jaw Trainers',
        accentColor: Color(0xFFE53935),
        body:
            'Those rubber balls or pads you bite down on — honestly, I wouldn\'t recommend using them at all.\n\n'
            'Overloading your masseters (your main jaw muscles) can cause **unnatural hypertrophy** — creating a bulky, square look instead of a sharp, aesthetic one.\n\n'
            'Even worse, excessive use massively increases your risk of **TMJ (Temporomandibular Joint dysfunction).**\n\n'
            'TMJ can cause:\n'
            '* Jaw pain\n'
            '* Clicking or popping\n'
            '* Locking\n'
            '* Chronic discomfort\n\n'
            'In severe cases, it may require medical intervention.\n\n'
            'Jaw trainers don\'t mimic natural chewing mechanics. They force unnatural movement patterns.\n\n'
            '**If you want safe resistance, chew tough natural foods:**\n'
            '* Crusty bread\n'
            '* Steak\n'
            '* Carrots\n\n'
            'If you chew consciously, you\'ll feel your masseters activate and burn after a meal. Do that consistently and you\'re covered.',
      ),
      GuideSection(
        emoji: '❌',
        title: 'Mistake #2: The Towel Method',
        accentColor: Color(0xFFFF5722),
        body:
            'This is where you bite down on a towel and pull downward. Sounds intense. It\'s also risky.\n\n'
            'The towel method:\n'
            '* Places uneven force on jaw joints\n'
            '* Stresses ligaments\n'
            '* Can cause misalignment\n'
            '* Doesn\'t replicate natural chewing\n\n'
            'Worse — it can affect your teeth. Just like braces use pressure to shift teeth over time, excessive force from this method can alter alignment in ways you don\'t want.\n\n'
            'It\'s unnatural. It\'s unnecessary. And it\'s risky.',
      ),
      GuideSection(
        emoji: '❌',
        title: 'Mistake #3: Ignoring Body Fat',
        accentColor: Color(0xFFFF9800),
        body:
            'This is the **biggest one.**\n\n'
            'Jaw exercises alone will not give you a sharp jawline if your body fat is high.\n\n'
            'You could have strong masseters, ideal bone structure, and perfect hyoid position — but if there\'s too much fat covering the area, **none of it will show.**\n\n'
            'Getting lean is absolutely vital.\n\n'
            'The only sustainable way:\n'
            '* Nutrient-dense foods\n'
            '* Caloric deficit\n'
            '* Consistent training\n\n'
            'Not starving yourself. Not crash dieting. Not gimmicks.\n\n'
            'Simple. Healthy. Consistent.',
      ),
      GuideSection(
        emoji: '❌',
        title: 'Mistake #4: Asymmetrical Chewing',
        accentColor: Color(0xFF9C27B0),
        body:
            'If you constantly chew on one side, you\'re building imbalance.\n\n'
            'Make sure you:\n'
            '* Chew evenly\n'
            '* Feel equal activation on both sides\n'
            '* Correct asymmetries early\n\n'
            'Muscle imbalance in the jaw shows up fast.',
      ),
      GuideSection(
        emoji: '❌',
        title: 'Mistake #5: Ignoring Neck & Posture',
        accentColor: Color(0xFF607D8B),
        body:
            'You can\'t isolate the jaw and expect magic.\n\n'
            'Forward head posture compresses the neck and weakens surrounding muscles. This can lead to:\n'
            '* Recessed appearance\n'
            '* Double chin look\n'
            '* Poor side profile\n\n'
            '**Posture is foundational.**\n\n'
            'Fix your neck alignment. Strengthen your upper back. Keep your head positioned properly.',
      ),
      GuideSection(
        emoji: '❌',
        title: 'Mistake #6: Believing Quick-Fix Myths',
        accentColor: Color(0xFFE53935),
        body:
            'There is no "7-day jawline."\n\n'
            'If you see that, your scam detector should be going off.\n\n'
            'Real jawline improvement takes:\n'
            '* Time\n'
            '* Discipline\n'
            '* Consistency\n\n'
            'Anyone promising instant results is selling insecurity. Commit to **long-term habits** instead.',
      ),
      GuideSection(
        emoji: '✅',
        title: 'The Real Truth',
        accentColor: Color(0xFF4CAF50),
        body:
            'Your jawline is a reflection of body fat levels, posture, hormonal health, muscle balance, and consistent habits.\n\n'
            'You don\'t need gimmicks. You don\'t need risky methods. You don\'t need jaw trainers.\n\n'
            'Focus on:\n'
            '* Natural chewing\n'
            '* Getting lean\n'
            '* Balanced muscle use\n'
            '* Proper posture\n\n'
            'And over time, you\'ll sculpt a defined jawline — safely.',
      ),
    ],
  ),
  GuideArticle(
    id: 'joint_suture_theory',
    title: 'Joint Suture Theory',
    subtitle: 'The biggest misconceptions around mewing & facial remodeling',
    emoji: '🦴',
    isPremium: true,
    keyRule: 'This is a long-term process. Think of it as gradual structural optimization rather than a fast transformation. Patience and consistency are essential.',
    sections: [
      GuideSection(
        emoji: '📖',
        title: 'Introduction',
        accentColor: Color(0xFF2196F3),
        body:
            'Joint suture theory has gained a lot of attention for its potential to naturally enhance facial structure through practices like **mewing, thumb pulling, and zygomatic pushing.**\n\n'
            'The concept is fascinating. But there are still many misunderstandings about how it actually works.\n\n'
            'Here we break down the biggest misconceptions, the most common mistakes people make, and how to avoid the pitfalls that hold most people back.',
      ),
      GuideSection(
        emoji: '❌',
        title: 'Misconception #1: Sutures Stay Highly Flexible in Adults',
        accentColor: Color(0xFFFF5722),
        body:
            'One of the biggest misconceptions is that skull sutures remain highly flexible as you age.\n\n'
            'Yes, sutures do retain a small degree of malleability throughout life — but their flexibility **decreases significantly over time.**\n\n'
            'Children and teenagers respond much better to external forces because their bones are still growing.\n\n'
            'Think about why sutures exist in the first place. As the brain grows, it pushes against the inner walls of the skull. This pressure signals the skull to expand and grow. Once growth stops and adulthood begins, those sutures gradually fuse.\n\n'
            '**The key takeaway:** If you\'re over 25, you shouldn\'t expect dramatic skeletal changes from these practices. Small changes might still occur, but they\'re often minimal.\n\n'
            'That said, there are still many other ways to improve your appearance — this concept just isn\'t as powerful after skeletal maturity.',
      ),
      GuideSection(
        emoji: '❌',
        title: 'Misconception #2: It\'s a Quick Fix',
        accentColor: Color(0xFFFF9800),
        body:
            'A common belief is that if you start thumb pulling, zygomatic pushing, or mewing consistently, you\'ll see major changes within a few months.\n\n'
            'That\'s not how skeletal remodeling works. Bone adaptation is **extremely slow.**\n\n'
            'Even when changes occur, they\'re often subtle and take **months or even years** to appear.\n\n'
            'Many people give up after a few weeks simply because they expected faster results.\n\n'
            'These practices should be treated as **long-term investments**, not quick fixes. Patience and consistency are essential.',
      ),
      GuideSection(
        emoji: '❌',
        title: 'Misconception #3: More Pressure Means Better Results',
        accentColor: Color(0xFFE53935),
        body:
            'Many people believe applying stronger pressure will speed up results. This is both **incorrect and potentially harmful.**\n\n'
            'Excessive force can cause:\n'
            '* Jaw tension\n'
            '* Tooth misalignment\n'
            '* Soft tissue damage\n'
            '* Pain or inflammation\n\n'
            'Sutures respond best to **gentle, consistent pressure over long periods of time.**\n\n'
            'That\'s one reason why many people prefer mewing over aggressive methods like thumb pulling.\n\n'
            'Think about how slowly the brain grows during development. The pressure it creates is subtle but consistent — and that\'s what drives bone adaptation.',
      ),
      GuideSection(
        emoji: '❌',
        title: 'Misconception #4: It Works the Same for Everyone',
        accentColor: Color(0xFF9C27B0),
        body:
            'Another mistake is assuming everyone will see the same results.\n\n'
            'In reality, results depend on several factors:\n'
            '* Age\n'
            '* Genetics\n'
            '* Bone structure\n'
            '* Consistency of practice\n\n'
            'Younger individuals usually see better outcomes because their bones are still more adaptable.\n\n'
            'Everyone\'s results will be unique to their situation. Understanding your own limitations helps you maintain realistic expectations.',
      ),
      GuideSection(
        emoji: '⚠️',
        title: 'Common Pitfalls',
        accentColor: Color(0xFFFF5722),
        body:
            '**1. Inconsistent Practice**\n'
            'Many people start strong but lose consistency after a few weeks.\n\n'
            '**2. Poor Technique**\n'
            'Proper technique matters. When mewing, the **back third of the tongue** should engage with the palate. When performing zygomatic pushing, pressure must remain even to avoid imbalances.\n\n'
            '**3. Mouth Breathing**\n'
            'Many people unknowingly mouth breathe — especially during sleep. This can counteract progress.\n\n'
            '**4. Ignoring Overall Health**\n'
            'Poor diet, bad posture, and lack of exercise can all limit your results. Your overall health plays a huge role in how your body adapts.',
      ),
      GuideSection(
        emoji: '✅',
        title: 'How to Avoid These Pitfalls',
        accentColor: Color(0xFF4CAF50),
        body:
            'To get the best results:\n'
            '* Learn the correct techniques\n'
            '* Track your progress\n'
            '* Focus on nasal breathing\n'
            '* Improve posture and overall health\n'
            '* Be patient and consistent\n\n'
            'Remember, this is a **long-term process.** Think of it as gradual structural optimization rather than a fast transformation.',
      ),
    ],
  ),
  GuideArticle(
    id: 'fresh_breath',
    title: 'Maintain Fresh Breath',
    subtitle: 'Keep your breath fresh and confident all day long',
    emoji: '🫁',
    isPremium: true,
    keyRule: 'Fresh breath is a small detail that makes a huge difference. It reflects good hygiene, confidence, and overall health. Build these habits consistently and fresh breath will become effortless.',
    sections: [
      GuideSection(
        emoji: '📖',
        title: 'Why Fresh Breath Matters',
        accentColor: Color(0xFF2196F3),
        body:
            'Fresh breath isn\'t just about hygiene — it\'s a huge part of your overall attractiveness. It directly affects how people perceive you.\n\n'
            'Fresh breath signals cleanliness, confidence, and good health. On the other hand, bad breath (also called **halitosis**) is usually caused by bacteria buildup in the mouth.\n\n'
            'By mastering a solid oral hygiene routine, you can make sure your breath stays fresh all day, every day.',
      ),
      GuideSection(
        emoji: '🪥',
        title: 'Foundation #1: Brush Properly',
        accentColor: Color(0xFF4CAF50),
        body:
            'The most common cause of bad breath is food particles trapped on and between your teeth.\n\n'
            'To prevent this:\n'
            '* Brush **twice a day**\n'
            '* Brush for **at least two minutes**\n'
            '* Clean both the outer and inner surfaces of your teeth\n\n'
            'And don\'t forget your tongue — see the next section.',
      ),
      GuideSection(
        emoji: '👅',
        title: 'Foundation #2: Clean Your Tongue',
        accentColor: Color(0xFF9C27B0),
        body:
            'Your tongue is one of the biggest sources of odor-causing bacteria.\n\n'
            'That\'s why **tongue scraping** should be part of your daily routine.\n\n'
            'Each time you brush your teeth:\n'
            '* Use a tongue scraper\n'
            '* Gently scrape from the back toward the front\n'
            '* Rinse the scraper between passes\n\n'
            'If it\'s your first time trying this, you might be surprised at how much buildup comes off.',
      ),
      GuideSection(
        emoji: '🦷',
        title: 'Foundation #3: Floss Every Day',
        accentColor: Color(0xFF00BCD4),
        body:
            'Food particles stuck between teeth can rot over time and create bad breath.\n\n'
            'Flossing removes these hidden particles that brushing alone can\'t reach.\n\n'
            'Use dental floss or floss picks. Make it a daily habit.',
      ),
      GuideSection(
        emoji: '💧',
        title: 'Boost #1: Mouthwash',
        accentColor: Color(0xFF2196F3),
        body:
            'Mouthwash helps kill bacteria and reach areas your toothbrush might miss.\n\n'
            'For best results:\n'
            '* Choose **alcohol-free mouthwash** to avoid dryness\n'
            '* Look for ingredients like **chlorhexidine or zinc compounds** for stronger odor control\n\n'
            'You can use mouthwash after brushing or after meals.',
      ),
      GuideSection(
        emoji: '🍬',
        title: 'Boost #2: Sugar-Free Gum or Mints',
        accentColor: Color(0xFFFF9800),
        body:
            'Chewing sugar-free gum or mints does more than freshen breath. It also **stimulates saliva production**, which helps:\n'
            '* Wash away bacteria\n'
            '* Neutralize acids in your mouth\n\n'
            'If possible, choose gum with **xylitol**, which also helps prevent cavities.',
      ),
      GuideSection(
        emoji: '💦',
        title: 'Boost #3: Stay Hydrated',
        accentColor: Color(0xFF42A5F5),
        body:
            'Dry mouth is one of the biggest causes of bad breath.\n\n'
            'Drink **2–3 liters of water per day** to keep saliva production healthy.',
      ),
      GuideSection(
        emoji: '🍎',
        title: 'Foods That Help vs. Hurt',
        accentColor: Color(0xFF4CAF50),
        body:
            '**Foods that improve breath:**\n'
            'Crunchy fruits and vegetables naturally help clean your mouth by stimulating saliva and removing odor-causing particles:\n'
            '* Apples\n'
            '* Carrots\n'
            '* Celery\n\n'
            '**Foods that make breath worse:**\n'
            'If you\'re going to be around people — like on a date or at a meeting — avoid:\n'
            '* Garlic\n'
            '* Onions\n'
            '* Sugary snacks\n'
            '* Excess dairy',
      ),
      GuideSection(
        emoji: '🔧',
        title: 'Tools That Improve Oral Hygiene',
        accentColor: Color(0xFF7C5CBF),
        body:
            '**Electric Toothbrush**\n'
            'Electric toothbrushes remove plaque more effectively than manual ones. If you haven\'t switched yet, it\'s definitely worth considering.\n\n'
            '**Water Flosser**\n'
            'A water flosser helps clean difficult areas between teeth and along the gums. A great addition to your oral care routine.\n\n'
            '**Replace Your Toothbrush Regularly**\n'
            'Old toothbrushes can harbor bacteria and become less effective. Replace your toothbrush **every three months.**',
      ),
      GuideSection(
        emoji: '🌙',
        title: 'Fixing Morning Breath',
        accentColor: Color(0xFF607D8B),
        body:
            'Your body produces less saliva during sleep, which is why many people wake up with morning breath.\n\n'
            'To reduce this:\n'
            '* Brush and floss before bed\n'
            '* Rinse with **salt water** before sleeping (a natural antibacterial rinse)\n'
            '* Maintain proper tongue posture during sleep if possible\n\n'
            'These habits can significantly reduce overnight odor.',
      ),
    ],
  ),
  GuideArticle(
    id: 'lymphatic_drainage',
    title: 'Lymphatic Drainage',
    subtitle: 'Reduce puffiness and reveal your natural facial structure',
    emoji: '💆',
    isPremium: true,
    keyRule: 'Sometimes the lean, defined face you\'re trying to achieve is already there — it\'s just being hidden by fluid retention. Improve your lymphatic flow, stay consistent, and let your natural structure show.',
    sections: [
      GuideSection(
        emoji: '📖',
        title: 'What Is Lymphatic Drainage?',
        accentColor: Color(0xFF2196F3),
        body:
            'If you want your face to look **slimmer, less bloated, and more defined** — and you\'ve already tried getting lean and balancing your sodium and potassium levels — then it might be time to consider **lymphatic drainage massage.**\n\n'
            'Lymphatic drainage is a technique used to stimulate your **lymphatic system**, which is responsible for removing waste and toxins from the body.\n\n'
            'The lymphatic system is a network of vessels and nodes that works like a drainage system for your body. When this system becomes sluggish, fluid can accumulate in your tissues — leading to **puffiness**, especially in the face.',
      ),
      GuideSection(
        emoji: '✨',
        title: 'How It Improves Your Appearance',
        accentColor: Color(0xFF4CAF50),
        body:
            'Improving lymphatic flow can:\n'
            '* Reduce facial puffiness\n'
            '* Define facial features\n'
            '* Improve skin tone\n'
            '* Support skin detoxification\n\n'
            'All of these contribute to a sharper, healthier appearance.',
      ),
      GuideSection(
        emoji: '🤲',
        title: 'How to Perform the Massage',
        accentColor: Color(0xFF9C27B0),
        body:
            'Lymphatic drainage for the face should always be **gentle.** It\'s a simple manual technique anyone can perform at home.\n\n'
            '**Step 1 — Start With Clean Skin**\n'
            'Wash your face and apply a facial oil or serum to allow smooth movement during the massage.\n\n'
            '**Step 2 — Stimulate the Neck First**\n'
            'The lymphatic system begins in the neck, so clearing this area first is important. Using your fingers, start at the base of your ears and gently massage downward toward your collarbone. Repeat **5–10 times on each side.**\n\n'
            '**Step 3 — Massage the Jawline**\n'
            'Place your fingers underneath your chin and sweep outward along the jawline toward your ears. Repeat **5–10 times on each side.**\n\n'
            '**Step 4 — Focus on the Cheeks**\n'
            'Start at the sides of your nose and gently sweep outward toward your ears. This helps reduce puffiness in the cheek area.\n\n'
            '**Step 5 — Depuff the Eye Area**\n'
            'Use your **ring finger**, since it applies the least pressure. Gently sweep underneath your eyes from the inner corner outward toward the temples. Repeat **5–10 times.**\n\n'
            '**Step 6 — Clear the Forehead**\n'
            'Start in the middle of your forehead and sweep outward toward your temples.\n\n'
            '**Step 7 — Finish With a Final Neck Sweep**\n'
            'Repeat the same downward strokes on the neck that you performed at the beginning. This helps complete the drainage process.\n\n'
            'You can perform this massage using your fingers, a jade roller, or a gua sha tool.',
      ),
      GuideSection(
        emoji: '📅',
        title: 'How Often Should You Do It?',
        accentColor: Color(0xFFFF9800),
        body:
            'Consistency is key.\n\n'
            '* If you frequently experience facial puffiness — do it **daily**\n'
            '* For general maintenance — **2–3 times per week** is enough\n\n'
            'You can do it:\n'
            '* **In the morning** to reduce puffiness\n'
            '* **In the evening** to relax and support detoxification',
      ),
      GuideSection(
        emoji: '🌿',
        title: 'Ways to Improve Lymphatic Flow Naturally',
        accentColor: Color(0xFF4CAF50),
        body:
            'Lymphatic massage works even better when combined with supportive habits.\n\n'
            '**Stay Hydrated**\n'
            'Drink **2–3 liters of water per day.**\n\n'
            '**Exercise Regularly**\n'
            'Activities like walking, yoga, and stretching help stimulate lymph flow.\n\n'
            '**Neck and Shoulder Movement**\n'
            'Simple neck stretches and shoulder rolls activate lymph nodes in the upper body.\n\n'
            '**Cold Therapy**\n'
            'Cold water splashes or chilled spoons can temporarily enhance lymphatic circulation.\n\n'
            '**Reduce Excess Sodium**\n'
            'Too much salt causes fluid retention, which can counteract the benefits of lymphatic drainage.',
      ),
      GuideSection(
        emoji: '📈',
        title: 'What Results Can You Expect?',
        accentColor: Color(0xFF00BCD4),
        body:
            'With consistent practice, many people notice:\n'
            '* Reduced puffiness\n'
            '* A slimmer-looking face\n'
            '* More defined facial features\n\n'
            'Sometimes even **after a single session.**\n\n'
            'Long-term benefits may include:\n'
            '* Brighter skin\n'
            '* Healthier glow\n'
            '* Improved jawline definition',
      ),
      GuideSection(
        emoji: '❌',
        title: 'Mistakes to Avoid',
        accentColor: Color(0xFFE53935),
        body:
            '**Using Too Much Pressure**\n'
            'The lymphatic system sits close to the surface of the skin. Gentle pressure works best.\n\n'
            '**Skipping the Neck**\n'
            'Always start with the neck to ensure proper drainage.\n\n'
            '**Being Inconsistent**\n'
            'Consistency is necessary for visible and lasting improvements.',
      ),
    ],
  ),
  GuideArticle(
    id: 'master_hygiene',
    title: 'Master Hygiene for Perfect Skin',
    subtitle: 'Daily habits that make skincare products actually work',
    emoji: '🧼',
    isPremium: true,
    keyRule: 'Master your hygiene, and you master your skin. Clear skin isn\'t just about products — it\'s about habits, discipline, and consistency. Build the right routine, maintain proper hygiene, and your skin will reflect it.',
    sections: [
      GuideSection(
        emoji: '📖',
        title: 'Why Hygiene Matters for Your Skin',
        accentColor: Color(0xFF2196F3),
        body:
            'Your skincare routine isn\'t just about the products you use — it\'s about your **daily habits and hygiene.** Even the best skincare products won\'t work if your hygiene is poor.\n\n'
            'Your skin is constantly exposed to bacteria, dirt, oil, and sweat. If these build up on your skin, they clog your pores and lead to breakouts.\n\n'
            'That\'s why hygiene is the **foundation of clear skin.**',
      ),
      GuideSection(
        emoji: '🖐️',
        title: 'Stop Touching Your Face',
        accentColor: Color(0xFFE53935),
        body:
            'First rule: **keep your hands off your face.**\n\n'
            'Your hands touch dozens of surfaces throughout the day, collecting bacteria, oil, and dirt. Every time you touch your face, you transfer those contaminants directly onto your skin — clogging pores and triggering acne.\n\n'
            'If you catch yourself doing it constantly, train yourself to stop. Breaking this habit alone can **significantly improve your skin.**',
      ),
      GuideSection(
        emoji: '🚿',
        title: 'Wash Your Face Properly',
        accentColor: Color(0xFF4CAF50),
        body:
            'Wash your face **twice a day** — morning and night. This is non-negotiable. Also wash your face **after exercising**, since sweat can clog pores.\n\n'
            'When washing your face:\n'
            '* Use **lukewarm water**, not hot water\n'
            '* Apply a **gentle cleanser** suited to your skin type\n'
            '* Avoid harsh soaps\n'
            '* Use **clean hands and your fingertips**, not a washcloth\n\n'
            'Washcloths can trap bacteria and transfer it back onto your skin.\n\n'
            'If you wear makeup or sunscreen during the day, consider **double cleansing at night:**\n'
            '* Cleanse once to remove surface buildup\n'
            '* Rinse\n'
            '* Cleanse again to properly clean the skin',
      ),
      GuideSection(
        emoji: '🛏️',
        title: 'Keep Your Bedding Clean',
        accentColor: Color(0xFF9C27B0),
        body:
            'Your pillowcase and bedding collect oils, sweat, and bacteria — all of which transfer to your face while you sleep.\n\n'
            'To prevent this:\n'
            '* Wash pillowcases **at least once per week**\n'
            '* If you\'re acne-prone, wash them **every 2–3 days**\n'
            '* Wash bed sheets **weekly**\n\n'
            'If possible, use **silk or bamboo pillowcases.** These materials reduce friction and prevent oils from transferring onto your skin as easily.',
      ),
      GuideSection(
        emoji: '🧻',
        title: 'Be Careful With Towels',
        accentColor: Color(0xFFFF9800),
        body:
            'Towels are a commonly overlooked source of bacteria.\n\n'
            '* Use a **separate towel for your face and body**\n'
            '* Use a **clean towel each time you wash your face**\n'
            '* **Pat your skin dry** — don\'t rub\n\n'
            'Body towels should be washed **every 3–4 days.**',
      ),
      GuideSection(
        emoji: '💇',
        title: 'Maintain Good Hair Hygiene',
        accentColor: Color(0xFF00BCD4),
        body:
            'Your hair can transfer oils and dirt to your skin — especially around your forehead and hairline. If your hair sits on your forehead, it can contribute to acne.\n\n'
            'Try to:\n'
            '* Keep hair away from your face when possible\n'
            '* Be cautious with products like hairspray or styling gels\n\n'
            'These products can easily clog pores if they reach your skin.',
      ),
      GuideSection(
        emoji: '🧖',
        title: 'Clean Your Skincare Tools',
        accentColor: Color(0xFF607D8B),
        body:
            'If you use tools like gua sha, facial rollers, or lymphatic massage tools — clean them **after every use.**\n\n'
            'These tools can quickly accumulate bacteria. Rubbing them on your face without cleaning them can cause breakouts.',
      ),
      GuideSection(
        emoji: '🚿',
        title: 'Optimize Your Shower Routine',
        accentColor: Color(0xFF42A5F5),
        body:
            '* **Shower after sweating** — even if it\'s just a quick rinse, remove sweat from your skin\n'
            '* Avoid long, very hot showers — they strip your skin\'s natural oils\n'
            '* Never use **body soap on your face** — it\'s too harsh',
      ),
      GuideSection(
        emoji: '🚫',
        title: 'Avoid Picking Pimples',
        accentColor: Color(0xFFE53935),
        body:
            'Never pick or squeeze blemishes with dirty hands.\n\n'
            'This can:\n'
            '* Introduce bacteria\n'
            '* Worsen inflammation\n'
            '* Cause permanent scarring\n\n'
            'Also keep your nails **short and clean** to reduce bacteria buildup.',
      ),
      GuideSection(
        emoji: '💧',
        title: 'Hydration Matters',
        accentColor: Color(0xFF4CAF50),
        body:
            'Drink **2–3 liters of water daily.** Hydration helps maintain healthy skin and supports your skin barrier.\n\n'
            'If you live in a dry environment, consider using a **humidifier.**\n\n'
            'When skin becomes too dry, your body can actually produce more oil to compensate — which can lead to breakouts.',
      ),
    ],
  ),
  GuideArticle(
    id: 'hyoid_bone_training',
    title: 'Hyoid Bone Training',
    subtitle: 'Train the most overlooked muscle group for a sharper jawline',
    emoji: '🦷',
    isPremium: true,
    keyRule: 'Training the muscles around your hyoid bone improves posture, neck strength, facial structure, and overall confidence. Small daily habits compound over time. Start training today, stay consistent, and watch the progress build.',
    sections: [
      GuideSection(
        emoji: '📖',
        title: 'Introduction',
        accentColor: Color(0xFF2196F3),
        body:
            'If you want that sharp, defined **Chad jawline**, you need to understand something most people ignore.\n\n'
            'It\'s not just about training your **masseters** or getting lean.\n\n'
            'You also need to train your **hyoid muscles.**\n\n'
            'A strong jawline can completely transform your appearance — taking someone from average-looking to extremely attractive. One of the most overlooked factors in achieving that look is the **position and strength of the hyoid bone and surrounding muscles.**',
      ),
      GuideSection(
        emoji: '🦴',
        title: 'What Is the Hyoid Bone?',
        accentColor: Color(0xFF9C27B0),
        body:
            'The **hyoid bone** is a small U-shaped bone located in your throat, just beneath your jawline.\n\n'
            'What makes it unique is that it **does not connect to any other bone** in your body. Instead, it is suspended entirely by **muscles and ligaments.**\n\n'
            'Because of this, its position can change depending on how strong or weak the surrounding muscles are.',
      ),
      GuideSection(
        emoji: '💎',
        title: 'Why It Matters for Your Jawline',
        accentColor: Color(0xFFFF9800),
        body:
            'The hyoid supports the tongue and plays an important role in swallowing, speaking, and breathing. But it also has a major impact on your appearance.\n\n'
            'A **low-set hyoid bone** can make even a lean person look like they have a double chin, hiding their jaw definition.\n\n'
            'A **higher hyoid position** lifts the neck area and makes the jawline appear sharper and more defined.\n\n'
            'When the muscles around the hyoid are properly trained, they help tighten the neck and improve the overall facial profile.',
      ),
      GuideSection(
        emoji: '✅',
        title: 'Benefits of Training the Hyoid',
        accentColor: Color(0xFF4CAF50),
        body:
            'Beyond aesthetics, hyoid training also improves functionality and posture.\n\n'
            '**1. A sharper jawline**\n'
            'Strengthening the surrounding muscles helps lift the hyoid bone.\n\n'
            '**2. Better posture**\n'
            'Weak hyoid muscles often contribute to forward head posture, which makes the jaw appear recessed.\n\n'
            '**3. Improved neck profile**\n'
            'Stronger neck muscles tighten the area under the jaw and reduce sagging.',
      ),
      GuideSection(
        emoji: '💪',
        title: 'The Muscles Involved',
        accentColor: Color(0xFF607D8B),
        body:
            'To train the hyoid effectively, you need to target the muscles connected to it:\n\n'
            '* **Suprahyoid muscles** — lift the hyoid bone\n'
            '* **Infrahyoid muscles** — stabilize the hyoid and support neck posture\n'
            '* **Platysma** — a superficial neck muscle that affects skin tightness',
      ),
      GuideSection(
        emoji: '🏋️',
        title: 'Exercise #1: Tongue Press',
        accentColor: Color(0xFF2196F3),
        body:
            'Sit or stand upright with your mouth closed.\n\n'
            'Press your tongue firmly against the roof of your mouth and hold for **10 seconds.** You should feel tension under your jaw.\n\n'
            'Release and repeat **10 times.**',
      ),
      GuideSection(
        emoji: '🏋️',
        title: 'Exercise #2: McKenzie Chin Tucks',
        accentColor: Color(0xFF00BCD4),
        body:
            'Stand or sit with a **neutral spine.** Keep your eyes forward, shoulders back, and chest up.\n\n'
            'Pull your head straight backward to create a **double chin.**\n\n'
            '**Important:** Don\'t tilt your head downward — move it **straight back.** This activates the **infrahyoid muscles.**',
      ),
      GuideSection(
        emoji: '🏋️',
        title: 'Exercise #3: Swallowing Jawline Lift',
        accentColor: Color(0xFF4CAF50),
        body:
            'Tilt your head slightly upward and look toward the ceiling.\n\n'
            'Press your tongue against the roof of your mouth and swallow slowly.\n\n'
            'Perform **10 controlled repetitions.** This exercise strongly activates the muscles under the jaw.',
      ),
      GuideSection(
        emoji: '🏋️',
        title: 'Exercise #4: Humming Exercise',
        accentColor: Color(0xFF9C27B0),
        body:
            'Sit upright and hum at a low pitch. You should feel vibration and resistance beneath your jaw.\n\n'
            'Hold for **10–15 seconds**, rest, then repeat **five times.**\n\n'
            'This activates deep muscles around the hyoid and vocal structures.',
      ),
      GuideSection(
        emoji: '🏋️',
        title: 'Exercise #5: Mewing',
        accentColor: Color(0xFFFF9800),
        body:
            'Mewing involves resting the **entire tongue** on the roof of your mouth with your teeth lightly touching.\n\n'
            'Proper tongue posture may help improve facial posture and support forward growth during development.\n\n'
            'Consistency is key.',
      ),
      GuideSection(
        emoji: '🧍',
        title: 'The Role of Posture',
        accentColor: Color(0xFFE53935),
        body:
            'Posture is extremely important. Poor posture can undo all of your progress.\n\n'
            'If your head constantly sits forward, the hyoid muscles weaken and the jawline appears less defined.\n\n'
            'Correct posture by:\n'
            '* Keeping your **ears aligned with your shoulders**\n'
            '* Keeping your **chin parallel to the floor**\n'
            '* Maintaining an **upright posture** throughout the day',
      ),
      GuideSection(
        emoji: '🏋️',
        title: 'Neck Strengthening',
        accentColor: Color(0xFF607D8B),
        body:
            'If you train at the gym, consider **neck curls.**\n\n'
            'Lie at the edge of a bench and gently curl your head forward to create a double chin.\n\n'
            'You don\'t need weights — your neck muscles already provide enough resistance. Focus on slow, controlled movement.',
      ),
      GuideSection(
        emoji: '🌿',
        title: 'Supporting Habits for Better Results',
        accentColor: Color(0xFF4CAF50),
        body:
            'To maximize your results:\n'
            '* Stay hydrated\n'
            '* Maintain a healthy diet\n'
            '* Get good sleep\n'
            '* Use tools like **gua sha or facial rollers** for lymphatic drainage\n\n'
            'These habits help reduce puffiness and improve facial definition.',
      ),
      GuideSection(
        emoji: '📈',
        title: 'Expected Results',
        accentColor: Color(0xFFFFD700),
        body:
            'With consistent training and good posture, noticeable improvements can appear within **four to six weeks.**\n\n'
            'Just remember not to push too hard. If you feel excessive strain, ease off.',
      ),
    ],
  ),
  GuideArticle(
    id: 'mewing',
    title: 'Mewing',
    subtitle: 'The truth about the most popular looksmaxing technique',
    emoji: '👅',
    isPremium: true,
    keyRule: 'Mewing remains one of the simplest habits that can support better facial posture and overall health. Start with normal mewing, and once you\'re comfortable, experiment with hard mewing in short sessions. Like any habit, consistency is what matters most.',
    sections: [
      GuideSection(
        emoji: '📖',
        title: 'Introduction',
        accentColor: Color(0xFF2196F3),
        body:
            'If you haven\'t been living under a rock, you\'ve probably heard of **mewing.**\n\n'
            'It\'s a simple yet powerful technique that has gained a lot of attention — and for good reason.\n\n'
            'Recently, some people have started saying mewing doesn\'t work, or that it\'s just a trend or fraud.\n\n'
            'Short answer: **no.**\n\n'
            'Mewing remains one of the foundational habits for improving your jawline, supporting better maxilla development, and improving your overall health — which is a huge part of what people call looksmaxing. In reality, a lot of that is simply **health optimization.**',
      ),
      GuideSection(
        emoji: '🔍',
        title: 'What Is Mewing?',
        accentColor: Color(0xFF9C27B0),
        body:
            'Mewing is the practice of maintaining **proper tongue posture.**\n\n'
            'This means resting your tongue against the **roof of your mouth** — not just lightly touching it, but engaging the **entire tongue**, especially the back third.\n\n'
            'The idea was popularized by **Dr. Mike Mew**, an orthodontist who believed proper tongue posture can influence facial development over time.\n\n'
            'By applying upward pressure with your tongue against the roof of your mouth, you apply pressure to the **maxilla** (the upper jaw). Over long periods, this pressure can influence how the midface develops.\n\n'
            'A wider palate can contribute to:\n'
            '* Wider cheekbones\n'
            '* Stronger midface projection\n'
            '* Improved facial harmony',
      ),
      GuideSection(
        emoji: '⚙️',
        title: 'How Mewing Works (Biomechanics)',
        accentColor: Color(0xFFFF9800),
        body:
            '**1. Upward Pressure**\n'
            'When your tongue presses against the roof of your mouth, it applies gentle upward pressure to the maxilla. Over time, this may encourage the maxilla to sit slightly **forward and upward.**\n\n'
            '**2. Facial Symmetry**\n'
            'Correct tongue posture helps balance muscular forces across both sides of the face — reducing imbalances caused by poor habits like mouth breathing or uneven chewing.\n\n'
            '**3. Jawline Definition**\n'
            'Mewing encourages **nasal breathing** and keeps the mouth closed. This activates muscles in the neck and under the jaw, which can improve jawline appearance.\n\n'
            '**4. Improved Posture**\n'
            'Maintaining correct tongue posture often encourages better **head and neck alignment**, improving overall posture.',
      ),
      GuideSection(
        emoji: '✅',
        title: 'Benefits of Mewing',
        accentColor: Color(0xFF4CAF50),
        body:
            'When practiced consistently, potential benefits include:\n'
            '* Sharper jawline appearance\n'
            '* Improved cheekbone projection\n'
            '* Better midface structure\n'
            '* Greater facial symmetry\n'
            '* Improved nasal breathing\n\n'
            'Nasal breathing also reduces risks associated with mouth breathing, such as snoring or sleep-related breathing issues.',
      ),
      GuideSection(
        emoji: '💪',
        title: 'What Is Hard Mewing?',
        accentColor: Color(0xFFFF5722),
        body:
            'Hard mewing is a more intense version of regular mewing where you apply stronger tongue pressure to the roof of your mouth.\n\n'
            'The goal is still the same:\n'
            '* Engage the **entire tongue**, especially the back third\n'
            '* Maintain **constant pressure**\n'
            '* Keep the mouth closed\n'
            '* Keep the teeth lightly touching\n\n'
            'However, too much pressure for long periods can cause jaw soreness, tension, and possible alignment issues if done incorrectly. You should also avoid **clenching your teeth**, which many people accidentally do when attempting hard mewing.\n\n'
            'Hard mewing is best suited for people who are **already comfortable with normal mewing.** If you\'re new, focus on mastering the basics first.',
      ),
      GuideSection(
        emoji: '📋',
        title: 'How to Start Mewing (Step-by-Step)',
        accentColor: Color(0xFF2196F3),
        body:
            '* Press the **entire surface of your tongue** against the roof of your mouth\n'
            '* Position your tongue so you can still breathe comfortably through your nose\n'
            '* The tip of your tongue should rest **just behind your front teeth**, not touching them\n'
            '* Your teeth should be **lightly touching**, without clenching\n'
            '* Maintain good posture — head upright, shoulders back, chest up\n'
            '* Be consistent\n\n'
            'Whenever you are **not eating, talking, or exercising**, your tongue should ideally be resting in this position.',
      ),
      GuideSection(
        emoji: '📈',
        title: 'What Results Can You Expect?',
        accentColor: Color(0xFF4CAF50),
        body:
            'Mewing is a **long-term habit**, not a quick fix.\n\n'
            '**1–3 months:**\n'
            'Subtle improvements in jaw definition and reduction of under-chin appearance.\n\n'
            '**6–12 months:**\n'
            'Possible improvements in facial symmetry and slight cheekbone projection.\n\n'
            '**1–2 years:**\n'
            'More noticeable improvements in facial harmony, particularly if started during teenage years.\n\n'
            'The best age to begin is during **development years (around 13–16)** when facial bones are still growing.',
      ),
      GuideSection(
        emoji: '❓',
        title: 'Why Some People Say Mewing Is Fake',
        accentColor: Color(0xFF607D8B),
        body:
            'Recently, some people claimed mewing was just a trick used in photos.\n\n'
            'When you press your tongue against your palate, the **hyoid bone lifts** — tightening the neck area and making the jawline appear sharper instantly.\n\n'
            'Because of this, some assumed it was just a photo trick.\n\n'
            'In reality, this immediate effect does not mean the practice itself has no long-term benefits. It simply means posture and muscle activation can influence appearance **right away.**',
      ),
    ],
  ),
  GuideArticle(
    id: 'mpr',
    title: 'MPR',
    subtitle: 'Mental Protuberance Resistance for a defined jawline',
    emoji: '🫦',
    isPremium: true,
    keyRule: 'MPR is a simple exercise that, when combined with good posture, proper tongue posture, and healthy habits, can contribute to a stronger and more defined appearance over time. Start slowly, stay consistent, and let progress build naturally.',
    sections: [
      GuideSection(
        emoji: '📖',
        title: 'What Is MPR?',
        accentColor: Color(0xFF2196F3),
        body:
            'MPR stands for **Mental Protuberance Resistance.** It\'s an exercise designed to help improve **hyoid positioning, neck strength, posture, and facial symmetry** — all of which can contribute to a more defined jawline.\n\n'
            'While MPR alone won\'t magically give you a wider palate or dramatic forward facial growth, it can help correct **muscular imbalances in the neck**, improve posture, and strengthen the muscles that support your jawline and throat area.',
      ),
      GuideSection(
        emoji: '🤲',
        title: 'How to Perform MPR',
        accentColor: Color(0xFF4CAF50),
        body:
            'The name comes from the **mental protuberance** — the anatomical term for the front of your chin. The exercise works by applying resistance to this area while opening and closing the jaw.\n\n'
            '* Place your **thumbs underneath your chin**\n'
            '* For stability, place the base of your index fingers against the front of your chin\n'
            '* Apply **gentle resistance upward** with your thumbs\n'
            '* Slowly **open and close your mouth** while maintaining that resistance\n\n'
            'Each repetition should be controlled and smooth.',
      ),
      GuideSection(
        emoji: '💪',
        title: 'What Muscles Does It Train?',
        accentColor: Color(0xFF9C27B0),
        body:
            'This exercise primarily targets the **suprahyoid muscles**, which sit above the hyoid bone.\n\n'
            'Strengthening these muscles has two main effects:\n'
            '* The muscles become stronger\n'
            '* They become tighter and more supportive\n\n'
            'Over time, stronger suprahyoid muscles can help support the position of the hyoid bone and improve the overall tension in the neck area — contributing to a sharper appearance under the jaw.',
      ),
      GuideSection(
        emoji: '📋',
        title: 'How Many Repetitions?',
        accentColor: Color(0xFFFF9800),
        body:
            'If you\'re just starting out:\n'
            '* Use **light resistance**\n'
            '* Perform about **20 repetitions per set**\n'
            '* Rest **1 minute between sets**\n'
            '* Complete **5–8 sets**\n\n'
            'As the muscles get stronger over time, gradually increase:\n'
            '* Resistance\n'
            '* Number of reps\n'
            '* Total sets\n\n'
            'This gradual progression helps strengthen the muscles safely.',
      ),
      GuideSection(
        emoji: '⚠️',
        title: 'Important Safety Note',
        accentColor: Color(0xFFE53935),
        body:
            'If you experience **jaw clicking, popping, or pain**, stop immediately.\n\n'
            'These can be early signs of **TMJ (temporomandibular joint stress)**, which can lead to long-term problems if ignored.\n\n'
            'Always listen to your body.',
      ),
      GuideSection(
        emoji: '🔗',
        title: 'How MPR Fits Into Jawline Development',
        accentColor: Color(0xFF00BCD4),
        body:
            'MPR itself doesn\'t directly cause forward facial growth.\n\n'
            'Forward development is more closely related to **overall facial development, posture, and proper tongue posture.**\n\n'
            'However, strengthening the muscles around the hyoid bone can make it easier to maintain proper tongue posture and improve neck support.\n\n'
            'These factors together can improve the **appearance of the jawline and facial profile.**',
      ),
      GuideSection(
        emoji: '📅',
        title: 'Consistency Matters',
        accentColor: Color(0xFF4CAF50),
        body:
            'Like any muscle training, results come from **consistent practice over time.**\n\n'
            'When starting this exercise, you may feel activation in muscles you\'ve never trained before.\n\n'
            'Take it slowly, focus on controlled movement, and gradually increase the intensity as your strength improves.',
      ),
      GuideSection(
        emoji: '💡',
        title: 'Extra Tips',
        accentColor: Color(0xFFFFD700),
        body:
            'To get the best results:\n'
            '* Warm up your neck muscles before training\n'
            '* Avoid overtraining\n'
            '* Stretch your neck gently throughout the day\n'
            '* Focus on maintaining good posture\n\n'
            'These habits support healthier muscle function and reduce injury risk.',
      ),
    ],
  ),
  GuideArticle(
    id: 'oil_pulling_whitening',
    title: 'Oil Pulling & Teeth Whitening',
    subtitle: 'Two powerful methods for a brighter, cleaner smile',
    emoji: '🦷',
    isPremium: true,
    keyRule: 'Your smile is one of your biggest assets. By combining oil pulling with whitening strips, you can naturally improve both the health and brightness of your teeth. With consistent care and good habits, you can maintain a clean, confident smile for the long term.',
    sections: [
      GuideSection(
        emoji: '📖',
        title: 'Why White Teeth Matter',
        accentColor: Color(0xFF2196F3),
        body:
            'Your smile is one of the first things people notice about you. A bright, clean smile can dramatically enhance your appearance.\n\n'
            'A clean, white smile isn\'t just about oral hygiene — it plays a major role in how attractive and youthful your face appears.\n\n'
            'White teeth can:\n'
            '* Brighten your overall appearance\n'
            '* Make your skin tone look more radiant\n'
            '* Signal good health and vitality\n\n'
            'Your health and attractiveness often go hand in hand, and your smile is a big part of that.',
      ),
      GuideSection(
        emoji: '🫙',
        title: 'Method 1: Oil Pulling — What Is It?',
        accentColor: Color(0xFF4CAF50),
        body:
            'Oil pulling is an ancient oral health practice where you swish oil around in your mouth to help remove bacteria and improve oral hygiene.\n\n'
            'The oil binds to harmful bacteria in your mouth — and when you spit it out, those bacteria are removed with it.\n\n'
            'Over time, this can help:\n'
            '* Reduce plaque\n'
            '* Freshen breath\n'
            '* Improve gum health\n'
            '* Make teeth appear cleaner and slightly whiter',
      ),
      GuideSection(
        emoji: '📋',
        title: 'How to Do Oil Pulling',
        accentColor: Color(0xFF4CAF50),
        body:
            '**1. Choose the right oil**\n'
            'Use a natural cold-pressed oil such as coconut oil or sesame oil. Many people prefer coconut oil because of the taste.\n\n'
            '**2. Take about one tablespoon**\n'
            'Place it in your mouth and swish it around for **15–20 minutes.**\n\n'
            '**3. Do not swallow the oil**\n'
            'It contains bacteria that you\'re removing from your mouth.\n\n'
            '**4. Spit it out properly**\n'
            'Avoid spitting it down the sink since oil can clog pipes. Spit it into a tissue or trash instead.\n\n'
            '**5. Rinse and brush your teeth**\n'
            'Rinse your mouth with warm water and brush your teeth normally afterward.',
      ),
      GuideSection(
        emoji: '📈',
        title: 'Oil Pulling — Results to Expect',
        accentColor: Color(0xFF4CAF50),
        body:
            '**Short term:**\n'
            'You\'ll immediately notice fresher breath and a cleaner feeling mouth.\n\n'
            '**Long term:**\n'
            'Regular practice can improve gum health and gradually make teeth appear brighter.',
      ),
      GuideSection(
        emoji: '🪥',
        title: 'Method 2: Whitening Strips — What Are They?',
        accentColor: Color(0xFFFFD700),
        body:
            'Whitening strips are thin flexible plastic strips coated with a **peroxide-based whitening gel.**\n\n'
            'They work by penetrating the enamel and breaking down stains caused by:\n'
            '* Coffee\n'
            '* Tea\n'
            '* Red wine\n'
            '* Soda',
      ),
      GuideSection(
        emoji: '📋',
        title: 'How to Use Whitening Strips',
        accentColor: Color(0xFFFFD700),
        body:
            '**1. Follow the instructions on your product**\n'
            'Most require **15–30 minutes per use** over a **1–2 week period.**\n\n'
            '**2. Brush your teeth gently beforehand**\n'
            'Clean teeth allow the strips to adhere better. Avoid brushing too aggressively to reduce sensitivity.\n\n'
            '**3. Dry your teeth**\n'
            'Dry teeth help the strips stick properly.\n\n'
            '**4. Apply the strips carefully**\n'
            'Place them along your teeth and fold them around the back for a secure fit.\n\n'
            '**5. Remove after the recommended time**\n'
            'Then rinse your mouth thoroughly to remove any remaining gel.',
      ),
      GuideSection(
        emoji: '📈',
        title: 'Whitening Strips — Results to Expect',
        accentColor: Color(0xFFFFD700),
        body:
            '**Short term:**\n'
            'Some sensitivity may occur during the first 1–2 weeks. However, visible whitening can appear in **as little as 2–3 days.**\n\n'
            '**Long term:**\n'
            'After **2–3 weeks**, you can see significant whitening. If maintained properly, the results can last for months.',
      ),
      GuideSection(
        emoji: '🔗',
        title: 'Combining Both Methods',
        accentColor: Color(0xFF9C27B0),
        body:
            'You don\'t have to choose between oil pulling and whitening strips — they actually work well together.\n\n'
            '* **Oil pulling** supports overall oral health\n'
            '* **Whitening strips** target stains and brightness\n\n'
            'A simple routine could be:\n\n'
            '**Morning:** Oil pulling before brushing your teeth\n'
            '**Evening:** Whitening strips during the treatment period after brushing\n\n'
            'This combination supports both **oral health and cosmetic whitening.**',
      ),
      GuideSection(
        emoji: '❌',
        title: 'Common Mistakes to Avoid',
        accentColor: Color(0xFFE53935),
        body:
            '**Overusing Whitening Strips**\n'
            'Using them too often can cause tooth sensitivity and enamel damage. Always follow the recommended usage.\n\n'
            '**Inconsistent Oil Pulling**\n'
            'Oil pulling only works when done consistently. Aim for **daily use or at least 4–5 times per week.**\n\n'
            '**Neglecting Hydration**\n'
            'Dehydration can make teeth appear dull. Drink **2–3 liters of water per day** to help maintain healthy enamel.',
      ),
      GuideSection(
        emoji: '💡',
        title: 'Additional Tips for Whiter Teeth',
        accentColor: Color(0xFF00BCD4),
        body:
            'To keep your smile bright:\n'
            '* Limit stain-causing drinks like coffee, wine, and soda\n'
            '* Rinse your mouth with water after meals\n'
            '* Use a **soft-bristle toothbrush** to protect enamel\n'
            '* **Floss daily** to remove debris and prevent discoloration',
      ),
    ],
  ),
  GuideArticle(
    id: 'orbicularis_oculi',
    title: 'Orbicularis Oculi Training',
    subtitle: 'Strengthen your eye muscles for a more dominant, confident look',
    emoji: '👁️',
    isPremium: true,
    keyRule: 'Your eyes play a major role in your presence, confidence, and communication. By improving control of the muscles around your eyes, you can enhance the way your expressions are perceived. Start slowly, stay consistent, and observe how your expressions naturally evolve over time.',
    sections: [
      GuideSection(
        emoji: '📖',
        title: 'Introduction',
        accentColor: Color(0xFF2196F3),
        body:
            'A person can go from looking weak, tired, or submissive to looking confident, intense, and dominant just through the way their eyes look and move.\n\n'
            'Your eye area is one of the most important parts of your face — it\'s the first place people look when they meet you. The way you control and present your eyes plays a huge role in how you\'re perceived.\n\n'
            'One way to improve this is through **orbicularis oculi training** — a technique used to strengthen and gain control over the muscles around your eyes. With consistent practice, it can improve facial expressions, eye contact, and overall confidence.',
      ),
      GuideSection(
        emoji: '🔍',
        title: 'What Is the Orbicularis Oculi?',
        accentColor: Color(0xFF9C27B0),
        body:
            'The **orbicularis oculi** is the circular muscle that surrounds your eyes.\n\n'
            'It controls:\n'
            '* Blinking\n'
            '* Squinting\n'
            '* Facial expressions around the eyes\n\n'
            'When this muscle is stronger and more controlled, you can express emotions more effectively — shifting from a warm, friendly expression to a sharper, more focused look when needed.\n\n'
            'That intense, focused eye expression some people naturally have often comes from having strong control over this muscle.',
      ),
      GuideSection(
        emoji: '✅',
        title: 'Why Training This Muscle Matters',
        accentColor: Color(0xFF4CAF50),
        body:
            'Training the orbicularis oculi isn\'t just about appearance — it also affects how people respond to you in social situations.\n\n'
            '**Better facial symmetry**\n'
            'Facial symmetry is strongly linked with perceived attractiveness.\n\n'
            '**More expressive facial communication**\n'
            'When you have better control of your eye muscles, you can convey emotions more naturally.\n\n'
            '**Improved eye contact**\n'
            'Strong eye contact often makes people appear more confident and charismatic. Your presence in conversations can change dramatically when your eye contact improves.',
      ),
      GuideSection(
        emoji: '🏋️',
        title: 'Exercise #1: Controlled Squint',
        accentColor: Color(0xFF2196F3),
        body:
            'Throughout the day, practice a **subtle squint.**\n\n'
            'The goal is to slightly engage the muscles around the eyes without creating wrinkles on the forehead.\n\n'
            'Your eyes should not look overly wide and empty — but also not overly squeezed.\n\n'
            'You\'re aiming for a **natural, focused look.**',
      ),
      GuideSection(
        emoji: '🏋️',
        title: 'Exercise #2: Eye Squeeze With Resistance',
        accentColor: Color(0xFFFF9800),
        body:
            'Close your eyes tightly while placing your fingers near the **outer corners of your eyes.**\n\n'
            'Apply gentle upward resistance with your fingers while squeezing your eyes shut.\n\n'
            'Repeat this several times until you feel mild muscle fatigue.\n\n'
            'You can do this exercise with one eye at a time or both simultaneously.',
      ),
      GuideSection(
        emoji: '🏋️',
        title: 'Exercise #3: Expression Control Practice',
        accentColor: Color(0xFF00BCD4),
        body:
            'Muscle strength alone isn\'t enough.\n\n'
            'Practice facial expressions **in the mirror.**\n\n'
            'Try smiling while slightly squinting your eyes. You should notice your cheeks lifting and the outer corners of your eyes tightening slightly.\n\n'
            'This creates a more **natural and engaging expression.**',
      ),
      GuideSection(
        emoji: '👂',
        title: 'The Role of the Auricularis Posterior',
        accentColor: Color(0xFF607D8B),
        body:
            'There is also a muscle behind the ear called the **auricularis posterior.**\n\n'
            'Some people can activate it by moving or "wiggling" their ears.\n\n'
            'Engaging this muscle can slightly affect the appearance of the eyelids and may influence the perceived angle of the eyes — making the eye shape appear more lifted for some people.\n\n'
            'However, results vary from person to person, and it\'s important to experiment and see what works best for your own facial proportions.',
      ),
      GuideSection(
        emoji: '📈',
        title: 'Expected Results Timeline',
        accentColor: Color(0xFF4CAF50),
        body:
            '**1–2 weeks:**\n'
            'Improved facial awareness and better muscle control.\n\n'
            '**1–2 months:**\n'
            'Your eye expression becomes more natural and subconscious.\n\n'
            '**Around 6 months:**\n'
            'Your eye area may appear sharper, more expressive, and more youthful.',
      ),
      GuideSection(
        emoji: '❌',
        title: 'Common Mistakes to Avoid',
        accentColor: Color(0xFFE53935),
        body:
            '**Overexerting the muscles**\n'
            'Too much strain can create unnecessary tension or wrinkles.\n\n'
            '**Ignoring other facial muscles**\n'
            'Facial balance is important. Don\'t focus only on the eyes.\n\n'
            '**Inconsistent practice**\n'
            'Like any training, results require consistency. Even **5–10 minutes per day** can make a difference over time.',
      ),
    ],
  ),
  GuideArticle(
    id: 'positive_eyebrow_tilt',
    title: 'Positive Eyebrow Tilt',
    subtitle: 'Control your brow muscles for a sharper, more focused expression',
    emoji: '🤨',
    isPremium: true,
    keyRule: 'Facial attractiveness is heavily influenced by facial harmony. There isn\'t one perfect expression that works for everyone. Experiment, observe what suits your features best, and focus on maintaining relaxed and balanced facial expressions.',
    sections: [
      GuideSection(
        emoji: '📖',
        title: 'Introduction',
        accentColor: Color(0xFF2196F3),
        body:
            'Your eyebrows are more than just a facial feature. They play a huge role in your facial expressions and overall attractiveness.\n\n'
            'This guide focuses on controlling the muscles around the eyebrows so you can influence **brow position and brow tilt** — helping create a sharper, more focused eye area.',
      ),
      GuideSection(
        emoji: '🔍',
        title: 'Why a Low Brow Ridge & Positive Tilt Matters',
        accentColor: Color(0xFFFF9800),
        body:
            'A **low-set brow ridge** means your eyebrows sit closer to your eyes. This creates a more focused and grounded appearance.\n\n'
            'A **positive brow tilt** means the outer ends of the eyebrows sit slightly higher than the inner ends. When eyebrows tilt upward slightly toward the sides, it tends to give the face a more confident and composed appearance.\n\n'
            'A positive tilt can help:\n'
            '* Balance facial proportions\n'
            '* Frame the eyes better\n'
            '* Create a stronger and more focused expression',
      ),
      GuideSection(
        emoji: '💪',
        title: 'Muscles That Control Eyebrow Position',
        accentColor: Color(0xFF9C27B0),
        body:
            '**Frontalis Muscle**\n'
            'This muscle lifts the eyebrows. Overusing it can cause your brows to sit too high and create an overly surprised expression. The goal is to **relax this muscle as much as possible.**\n\n'
            '**Orbicularis Oculi**\n'
            'This circular muscle surrounds the eyes. It helps anchor the inner portion of the eyebrow closer to the eye area and contributes to a more grounded appearance.\n\n'
            '**Temporalis Muscle**\n'
            'This muscle sits on the sides of the head. It helps pull the outer ends of the eyebrows slightly upward and backward, contributing to the appearance of positive tilt.\n\n'
            '**Occipitalis Muscle**\n'
            'Located at the back of the head, this muscle works together with the temporalis. It helps create a subtle backward pull that keeps eyebrow positioning looking natural and balanced.',
      ),
      GuideSection(
        emoji: '🏋️',
        title: 'Exercise #1: Frontalis Relaxation',
        accentColor: Color(0xFF2196F3),
        body:
            'Stand in front of a mirror. Make sure your forehead remains **relaxed.**\n\n'
            'Using your middle fingers, gently pull the outer ends of your eyebrows upward to create a slight positive tilt.\n\n'
            'The goal is to engage the surrounding muscles **without activating the frontalis muscle.**\n\n'
            'Practicing in front of a mirror helps ensure your brow stays low and relaxed.',
      ),
      GuideSection(
        emoji: '🏋️',
        title: 'Exercise #2: Temporalis Engagement',
        accentColor: Color(0xFF4CAF50),
        body:
            'Try activating the muscle behind your ears known as the **auricularis posterior.**\n\n'
            'Some people can activate this muscle by slightly pulling their ears backward.\n\n'
            'Hold this contraction for **about 5 seconds**, then relax.\n\n'
            'Repeat **10–15 times daily.**\n\n'
            'For extra feedback, you can gently press your palms against the sides of your head while engaging the muscle.',
      ),
      GuideSection(
        emoji: '🏋️',
        title: 'Exercise #3: Occipitalis Activation',
        accentColor: Color(0xFF00BCD4),
        body:
            'Sit upright and focus on tightening the muscles at the **back of your scalp.**\n\n'
            'It should feel like your scalp is moving slightly backward.\n\n'
            'Hold the contraction for **5 seconds**, then relax.\n\n'
            'Repeat **10–12 times daily.**\n\n'
            'This helps create the subtle backward tension that supports natural brow positioning.',
      ),
      GuideSection(
        emoji: '🪞',
        title: 'Practice Facial Control',
        accentColor: Color(0xFF607D8B),
        body:
            'Over time, practicing these movements can help you develop better control over your eyebrow positioning.\n\n'
            'Practice in front of a mirror to check for symmetry and avoid unnecessary tension.\n\n'
            'Pay attention to daily habits. Try to avoid:\n'
            '* Constantly raising your eyebrows\n'
            '* Furrowing your brows excessively\n'
            '* Creating deep forehead tension',
      ),
      GuideSection(
        emoji: '🌍',
        title: 'Applying It in Daily Life',
        accentColor: Color(0xFFFF9800),
        body:
            'As you gain control, practice maintaining a relaxed brow position with a subtle tilt during normal activities such as conversations or photos.\n\n'
            'With time and repetition, these positions can start to feel **natural** and require less conscious effort.',
      ),
      GuideSection(
        emoji: '📈',
        title: 'Expected Results',
        accentColor: Color(0xFF4CAF50),
        body:
            '**1–2 weeks**\n'
            'You\'ll likely notice improved facial awareness and control.\n\n'
            '**Long-term practice**\n'
            'Your eyebrows may naturally settle into a more relaxed and balanced position that better frames your eyes.',
      ),
    ],
  ),
  GuideArticle(
    id: 'shredding_pitfalls',
    title: 'Shredding Pitfalls',
    subtitle: 'Mistakes to avoid when cutting body fat for a lean face',
    emoji: '🔥',
    isPremium: true,
    keyRule: 'Shredding requires balance and patience. Focus on sustainable calorie deficits, proper nutrition, strength training, hydration, and quality sleep. These habits will help you achieve results that are healthy, balanced, and maintainable long term.',
    sections: [
      GuideSection(
        emoji: '📖',
        title: 'Introduction',
        accentColor: Color(0xFF2196F3),
        body:
            'Shredding, or lowering your body fat, is all about achieving a lean and defined look. But if you do it the wrong way, it can actually make your face look **older, unhealthy, or unbalanced.**\n\n'
            'Here are the biggest mistakes people make when trying to cut body fat — and how to avoid them.',
      ),
      GuideSection(
        emoji: '❌',
        title: 'Mistake #1: Cutting Calories Too Aggressively',
        accentColor: Color(0xFFE53935),
        body:
            'Trying to lose fat as fast as possible by drastically cutting calories often leads to **muscle loss as well** — including muscle in your face. Instead of sharp cheekbones, you can end up with a **gaunt, hollow look** that makes you appear older and less healthy.\n\n'
            'Aggressive cutting can also lead to **dehydration**, which leaves your skin looking dry and dull.\n\n'
            '**What to do instead:**\n'
            'Aim for a sustainable calorie deficit of **300–500 calories per day.** This allows steady fat loss while preserving as much muscle as possible. Stay hydrated: **2–3 liters of water per day.**',
      ),
      GuideSection(
        emoji: '❌',
        title: 'Mistake #2: Ignoring Nutrient Intake',
        accentColor: Color(0xFFFF9800),
        body:
            'Many people focus only on reducing calories and forget about nutrition. Lacking essential nutrients like Vitamin A, Vitamin C, Vitamin E, and Zinc can leave your skin looking **pale, dull, and lifeless.**\n\n'
            'Low protein intake can also contribute to **collagen breakdown**, which may make your skin appear looser and more wrinkled.\n\n'
            '**What to do instead:**\n'
            'Prioritize **nutrient-dense foods** such as leafy greens, antioxidant-rich fruits, nuts and seeds, and avocados. Healthy fats are especially important for maintaining skin health. If you\'re dieting aggressively, some people also choose to add a **collagen supplement** to help support skin elasticity.',
      ),
      GuideSection(
        emoji: '❌',
        title: 'Mistake #3: Doing Too Much Cardio',
        accentColor: Color(0xFFFF5722),
        body:
            'Excessive cardio can cause **muscle loss**, including muscle around the face. Overtraining also raises **cortisol levels**, which can increase water retention and facial puffiness — ironically, you may be leaner but still look bloated in the face.\n\n'
            '**What to do instead:**\n'
            'Balance cardio with **strength training.** Strength training helps preserve muscle while losing fat. For cardio, aim for **moderate sessions 3–4 times per week.** High-intensity interval training (**HIIT**) can also be effective.',
      ),
      GuideSection(
        emoji: '❌',
        title: 'Mistake #4: Ignoring Sodium & Potassium Balance',
        accentColor: Color(0xFF9C27B0),
        body:
            'Too much sodium causes **water retention and facial puffiness.** Too little sodium, especially with low potassium, can leave you looking **dehydrated and flat.**\n\n'
            '**What to do instead:**\n'
            'Maintain a healthy balance. Foods rich in potassium include bananas, spinach, and potatoes. Balancing sodium and potassium helps regulate fluid balance in the body.',
      ),
      GuideSection(
        emoji: '❌',
        title: 'Mistake #5: Neglecting Sleep',
        accentColor: Color(0xFF607D8B),
        body:
            'Poor sleep raises **cortisol**, which increases water retention and can make your face appear more puffy. Lack of sleep also affects your skin\'s ability to **repair and regenerate**, making you look more tired and aged.\n\n'
            '**What to do instead:**\n'
            'Aim for **7–9 hours of quality sleep every night.** Using softer pillowcase materials like **silk or bamboo** may also help reduce skin irritation.',
      ),
      GuideSection(
        emoji: '❌',
        title: 'Mistake #6: Losing Fat Without Supporting Jawline Structure',
        accentColor: Color(0xFF00BCD4),
        body:
            'Many people assume that simply losing fat will automatically give them a strong jawline. But fat loss can actually reveal **muscle imbalances in the neck and jaw.**\n\n'
            'Without proper muscle development and posture, the jawline may not appear as defined as expected.\n\n'
            'Supporting neck strength and maintaining good posture can help improve overall facial balance.',
      ),
      GuideSection(
        emoji: '❌',
        title: 'Mistake #7: Poor Hydration',
        accentColor: Color(0xFF2196F3),
        body:
            'Some people intentionally drink less water while cutting because they think it will make them look leaner. In reality, dehydration often causes the body to **retain more water**, which can increase facial puffiness. It also reduces skin elasticity, making your skin look less healthy.\n\n'
            '**What to do instead:**\n'
            'Stay consistently hydrated. Aim for **2–3 liters of water per day.**',
      ),
      GuideSection(
        emoji: '❌',
        title: 'Mistake #8: Obsessing Over the Scale',
        accentColor: Color(0xFFFF9800),
        body:
            'Weight alone does not reflect **body composition.** You might be losing fat while gaining muscle, which means the scale may not change much even though your physique is improving.\n\n'
            '**What to do instead:**\n'
            'Track progress using:\n'
            '* Progress photos\n'
            '* Body fat percentage\n'
            '* Visual changes\n\n'
            'Taking photos **once per week in the same lighting and location** can help you clearly see progress over time.',
      ),
      GuideSection(
        emoji: '❌',
        title: 'Mistake #9: Poor Posture While Leaning Down',
        accentColor: Color(0xFF4CAF50),
        body:
            'As you get leaner, your neck muscles become more visible. If you have poor posture or constant tension in your neck and jaw, these imbalances can become more noticeable.\n\n'
            '**What to do instead:**\n'
            'Focus on maintaining good posture throughout the day. Exercises that strengthen the neck and improve posture can help maintain a balanced appearance.',
      ),
      GuideSection(
        emoji: '✅',
        title: 'Final Summary',
        accentColor: Color(0xFF4CAF50),
        body:
            'If done correctly, shredding can significantly improve both your physique and facial appearance. But rushing the process or cutting corners can lead to the opposite result.\n\n'
            'Focus on:\n'
            '* Sustainable calorie deficits\n'
            '* Proper nutrition\n'
            '* Strength training\n'
            '* Hydration\n'
            '* Quality sleep',
      ),
    ],
  ),
  GuideArticle(
    id: 'skincare_pitfalls',
    title: 'Skincare Pitfalls',
    subtitle: 'Common mistakes that are making your skin worse',
    emoji: '🧴',
    isPremium: true,
    keyRule: 'Good skincare isn\'t about using more products — it\'s about using the right ones and building healthy habits. By avoiding these common mistakes and focusing on a simple, balanced routine, you can significantly improve your skin. Often, less really is more.',
    sections: [
      GuideSection(
        emoji: '📖',
        title: 'Introduction',
        accentColor: Color(0xFF2196F3),
        body:
            'Sometimes the things we believe are helping our skin are actually **making it worse.**\n\n'
            'Here are the most common skincare pitfalls — and what you should be doing instead.',
      ),
      GuideSection(
        emoji: '❌',
        title: 'Mistake #1: Using Too Many Products',
        accentColor: Color(0xFFE53935),
        body:
            'Using too many products — especially active ingredients like **retinol, AHAs, or BHAs** — can damage your skin barrier. Overuse strips away your skin\'s natural oils, leading to dryness, irritation, and increased oil production. Your skin may actually start producing **more oil to compensate.**\n\n'
            '**What to do instead:**\n'
            'Keep your routine simple. A strong basic routine includes a cleanser, moisturizer, and sunscreen. When trying new products, introduce them **one at a time** so your skin can adjust.',
      ),
      GuideSection(
        emoji: '❌',
        title: 'Mistake #2: Using Harsh Scrubs on Acne',
        accentColor: Color(0xFFFF5722),
        body:
            'Gritty physical scrubs can actually **irritate inflamed skin** and worsen redness. They can also increase the risk of **scarring.** Scrubs don\'t address the real causes of acne like bacteria or clogged pores.\n\n'
            '**What to do instead:**\n'
            'Use chemical exfoliants like **salicylic acid.** These work deeper in the pores and help clear acne without causing physical irritation.',
      ),
      GuideSection(
        emoji: '❌',
        title: 'Mistake #3: Picking at Pimples',
        accentColor: Color(0xFFFF9800),
        body:
            'Squeezing or picking at pimples can damage your skin barrier and introduce bacteria — increasing the risk of scarring, prolonged inflammation, and worsening breakouts.\n\n'
            '**What to do instead:**\n'
            'Use targeted treatments such as **benzoyl peroxide** or **tea tree oil,** and use a gentle cleanser suited to your skin type.',
      ),
      GuideSection(
        emoji: '❌',
        title: 'Mistake #4: Washing Your Face Too Often',
        accentColor: Color(0xFF9C27B0),
        body:
            'Washing your face multiple times a day or using strong cleansers for that "squeaky clean" feeling can damage your skin barrier and remove natural oils — leading to dryness, irritation, and increased oil production.\n\n'
            '**What to do instead:**\n'
            'Wash your face **no more than twice per day** — once in the morning and once at night.',
      ),
      GuideSection(
        emoji: '❌',
        title: 'Mistake #5: Skipping Moisturizer for Oily Skin',
        accentColor: Color(0xFF607D8B),
        body:
            'When your skin becomes dehydrated, it may produce **even more oil** to compensate — making oily skin worse.\n\n'
            '**What to do instead:**\n'
            'Use a **lightweight, non-comedogenic moisturizer.** Gel-based formulas are often great for oily skin.',
      ),
      GuideSection(
        emoji: '❌',
        title: 'Mistake #6: Using the Wrong Acne Treatment',
        accentColor: Color(0xFF00BCD4),
        body:
            'Not all acne is the same — different types require different treatments.\n\n'
            '* **Clogged pores or blackheads** → Salicylic acid works well\n'
            '* **Red, inflamed acne** → Benzoyl peroxide may be more effective\n\n'
            'For severe acne like **cystic acne**, it\'s best to consult a dermatologist.',
      ),
      GuideSection(
        emoji: '❌',
        title: 'Mistake #7: Skipping Sunscreen',
        accentColor: Color(0xFFFF9800),
        body:
            'UV exposure happens **every day**, even indoors. Sunlight can pass through windows and cause long-term skin damage — accelerating skin aging, wrinkles, and uneven pigmentation.\n\n'
            '**What to do instead:**\n'
            'Use a **broad-spectrum sunscreen with at least SPF 30.** If you\'re outdoors, reapply **every 2–3 hours.**',
      ),
      GuideSection(
        emoji: '❌',
        title: 'Mistake #8: Washing With Very Hot Water',
        accentColor: Color(0xFF2196F3),
        body:
            'Pores **don\'t open or close.** Hot water simply strips the skin of natural oils, which can trigger more oil production and irritation.\n\n'
            '**What to do instead:**\n'
            'Always wash your face with **lukewarm water.**',
      ),
      GuideSection(
        emoji: '❌',
        title: 'Mistake #9: Not Changing Your Pillowcase',
        accentColor: Color(0xFF4CAF50),
        body:
            'Your pillowcase collects oil, bacteria, sweat, and dirt. Every night your face presses against it, transferring all of that back onto your skin.\n\n'
            '**What to do instead:**\n'
            'Change pillowcases regularly. Using **silk or bamboo pillowcases** can help reduce friction and irritation. Changing them every **2–3 days** can make a noticeable difference for acne-prone skin.',
      ),
      GuideSection(
        emoji: '❌',
        title: 'Mistake #10: Neglecting Hydration',
        accentColor: Color(0xFF42A5F5),
        body:
            'Skincare products alone won\'t help much if your body is dehydrated. Internal hydration plays a huge role in skin health.\n\n'
            '**What to do:**\n'
            'Drink around **2–3 liters of water per day.** Proper hydration helps maintain skin elasticity and overall skin health.',
      ),
    ],
  ),
  GuideArticle(
    id: 'spine_decompression',
    title: 'Spine Decompression Secrets',
    subtitle: 'Relieve spinal compression and stand at your true height',
    emoji: '🦴',
    isPremium: true,
    keyRule: 'Spine decompression is a simple yet effective way to support spinal health and improve posture. While height changes are mostly temporary, maintaining good spinal habits can help you stand taller and feel better overall. Try these exercises consistently for a few weeks and see how your body responds.',
    sections: [
      GuideSection(
        emoji: '📖',
        title: 'Introduction',
        accentColor: Color(0xFF2196F3),
        body:
            'Did you know that poor posture and compressed spinal discs can actually make you appear **shorter than your true height?**\n\n'
            'Over time, gravity, poor posture, and even certain workouts can compress your spine. This compression can temporarily reduce your height by **one to two centimeters**, making you look shorter than you actually are.',
      ),
      GuideSection(
        emoji: '🔍',
        title: 'What Is Spine Decompression?',
        accentColor: Color(0xFF9C27B0),
        body:
            'Spine decompression is a technique used to relieve pressure on the **discs in your spine.** These discs act as cushions between your vertebrae.\n\n'
            'Throughout the day, gravity compresses these discs slightly — temporarily reducing your height.\n\n'
            'For some people, long-term poor posture or chronic compression can make this effect more persistent. However, with the right habits and exercises, you can reduce this pressure and improve spinal health.',
      ),
      GuideSection(
        emoji: '✅',
        title: 'Why Spine Decompression Is Helpful',
        accentColor: Color(0xFF4CAF50),
        body:
            'Practicing spine decompression can provide several benefits:\n'
            '* Helps restore your natural height\n'
            '* Reduces back pain and tension\n'
            '* Improves flexibility and mobility\n'
            '* Increases circulation to spinal discs\n\n'
            'Better circulation allows the discs to stay **hydrated and nourished**, supporting long-term spinal health. It may also reduce the risk of issues like **disc injuries** in the future.',
      ),
      GuideSection(
        emoji: '🏋️',
        title: 'Exercise #1: Hanging From a Bar',
        accentColor: Color(0xFF2196F3),
        body:
            'Grab a pull-up bar and let your body hang freely. Allow gravity to stretch your spine and decompress the lower back.\n\n'
            '* Hang for **20–30 seconds**\n'
            '* Repeat **3–5 times**\n\n'
            'Try to keep your body relaxed and avoid swinging.',
      ),
      GuideSection(
        emoji: '🏋️',
        title: 'Exercise #2: Cat–Cow Stretch',
        accentColor: Color(0xFF4CAF50),
        body:
            'This movement helps improve spinal mobility and release tension.\n\n'
            '* Start on all fours\n'
            '* Arch your back upward (the **cat** position)\n'
            '* Slowly lower and extend your spine downward (the **cow** position)\n\n'
            'Perform **10–15 repetitions**, about **twice per day.**',
      ),
      GuideSection(
        emoji: '🏋️',
        title: 'Exercise #3: Child\'s Pose',
        accentColor: Color(0xFF00BCD4),
        body:
            'A common yoga stretch that helps relieve pressure in the lower back.\n\n'
            '* Sit back on your heels\n'
            '* Stretch your arms forward\n'
            '* Lower your torso toward the floor\n\n'
            'Hold for **30–60 seconds** and repeat **2–3 times.**',
      ),
      GuideSection(
        emoji: '🏋️',
        title: 'Exercise #4: Inversion Position',
        accentColor: Color(0xFFFF9800),
        body:
            'Using an inversion table allows your body to hang upside down, helping decompress the spine.\n\n'
            'If you don\'t have an inversion table, you can use a sturdy surface and allow your upper body to hang downward.\n\n'
            'Start with **1–2 minutes**, focusing on slow breathing.\n\n'
            '⚠️ Avoid this exercise if you have **high blood pressure or frequent headaches**, as blood flow increases toward the head.',
      ),
      GuideSection(
        emoji: '🏋️',
        title: 'Exercise #5: Foam Rolling',
        accentColor: Color(0xFF7C5CBF),
        body:
            'Foam rolling helps release tension along the spine and surrounding muscles.\n\n'
            'Lie on a foam roller and slowly roll along your back.\n\n'
            'Spend around **5–10 minutes daily** for best results.',
      ),
      GuideSection(
        emoji: '❌',
        title: 'Mistakes to Avoid',
        accentColor: Color(0xFFE53935),
        body:
            '**Overstretching**\n'
            'Trying to progress too quickly can strain muscles or worsen existing injuries.\n\n'
            '**Ignoring discomfort**\n'
            'If you feel sharp pain, stop immediately and adjust your movements.\n\n'
            '**Inconsistency**\n'
            'Short daily sessions are far more effective than occasional intense sessions.\n\n'
            '**Ignoring medical conditions**\n'
            'If you have existing back problems, consult a medical professional before starting these exercises.',
      ),
      GuideSection(
        emoji: '📈',
        title: 'What Results Can You Expect?',
        accentColor: Color(0xFF4CAF50),
        body:
            'Immediately after a decompression session, some people may temporarily measure **up to 1–2 centimeters taller** due to reduced disc compression.\n\n'
            '**After 2–4 weeks**\n'
            'You may notice improved flexibility and reduced back tension.\n\n'
            '**After several months**\n'
            'You may experience better spinal mobility, fewer aches, and improved posture — helping maintain your natural height more consistently.',
      ),
      GuideSection(
        emoji: '💡',
        title: 'Additional Tips',
        accentColor: Color(0xFFFFD700),
        body:
            'To get the best results:\n'
            '* Warm up before stretching\n'
            '* Maintain proper form during exercises\n'
            '* Practice consistently\n'
            '* Address any underlying posture issues',
      ),
    ],
  ),
  GuideArticle(
    id: 'testosterone_maxing',
    title: 'Testosterone Maxing',
    subtitle: 'The ultimate guide to naturally boosting your testosterone',
    emoji: '⚡',
    isPremium: true,
    keyRule: 'Testosterone influences far more than just physical strength — it affects energy, confidence, mood, and overall vitality. The goal isn\'t quick fixes. It\'s building sustainable habits that help you become a stronger, healthier version of yourself.',
    sections: [
      GuideSection(
        emoji: '📖',
        title: 'Why Testosterone Matters',
        accentColor: Color(0xFFFF9800),
        body:
            'Testosterone isn\'t just about building muscle. It affects your **energy, confidence, vitality, bone density, mood, and overall drive.** When it comes to male attractiveness and performance, testosterone is a major foundation.\n\n'
            'Testosterone is the primary male hormone responsible for:\n'
            '* Muscle growth\n'
            '* Fat metabolism\n'
            '* Mood and motivation\n'
            '* Libido\n'
            '* Energy levels\n\n'
            'Optimizing testosterone isn\'t about shortcuts. It\'s about aligning your **diet, training, and lifestyle** so your body can perform at its best.',
      ),
      GuideSection(
        emoji: '🥗',
        title: 'Nutrition: The Foundation',
        accentColor: Color(0xFF4CAF50),
        body:
            '**Healthy Fats**\n'
            'Testosterone is produced from cholesterol, so healthy fats are essential. Include eggs, avocados, olive oil, fatty fish, nuts, and grass-fed butter.\n\n'
            '**Zinc-Rich Foods**\n'
            'Zinc plays an important role in testosterone production. Good sources: oysters, red meat, pumpkin seeds, chickpeas.\n\n'
            '**Magnesium-Rich Foods**\n'
            'Magnesium helps support hormone balance and reduce stress. Sources: spinach, almonds, cashews, dark chocolate.\n\n'
            '**Vitamin D**\n'
            'Vitamin D functions similarly to a hormone and is strongly connected to testosterone production. Sources: fatty fish, egg yolks, liver, sunlight. Spend **15–30 minutes in sunlight daily.**\n\n'
            '**Cruciferous Vegetables**\n'
            'Broccoli, kale, cauliflower, and Brussels sprouts can help support healthy hormone balance.\n\n'
            '**Testosterone-Supporting Foods**\n'
            'Raw honey (contains boron), dark chocolate (magnesium and antioxidants), and beef liver (vitamin A and zinc) are often highlighted for hormone health.',
      ),
      GuideSection(
        emoji: '🚫',
        title: 'Foods to Limit',
        accentColor: Color(0xFFE53935),
        body:
            'Certain foods may negatively affect hormone balance if consumed excessively.\n\n'
            'Try to limit:\n'
            '* Heavily processed foods\n'
            '* Excessive alcohol\n'
            '* Foods high in trans fats\n\n'
            'Focus instead on **whole, nutrient-dense foods.**',
      ),
      GuideSection(
        emoji: '🏋️',
        title: 'Training for Higher Testosterone',
        accentColor: Color(0xFF2196F3),
        body:
            'Exercise is one of the most powerful natural ways to support testosterone production.\n\n'
            '**Strength Training**\n'
            'Compound exercises are particularly effective: squats, deadlifts, pull-ups, bench press. Train **3–5 times per week** with challenging weights.\n\n'
            '**High-Intensity Interval Training (HIIT)**\n'
            'HIIT involves short bursts of intense effort followed by rest. Example: 30 seconds sprinting, 60 seconds rest — repeated several times.\n\n'
            '**Avoid Overtraining**\n'
            'Too much training without recovery increases **cortisol**, which can interfere with testosterone balance. Include **rest and recovery days.**',
      ),
      GuideSection(
        emoji: '😴',
        title: 'Quality Sleep',
        accentColor: Color(0xFF7C5CBF),
        body:
            'Testosterone production peaks during sleep.\n\n'
            'Aim for **7–9 hours of quality sleep per night.**\n\n'
            'To improve sleep quality:\n'
            '* Keep your room cool and dark\n'
            '* Reduce screen exposure before bed\n'
            '* Maintain a consistent sleep schedule',
      ),
      GuideSection(
        emoji: '🧘',
        title: 'Stress Management',
        accentColor: Color(0xFF00BCD4),
        body:
            'Chronic stress increases cortisol levels, which can negatively affect hormone balance.\n\n'
            'Helpful stress-reducing activities include:\n'
            '* Meditation\n'
            '* Deep breathing\n'
            '* Spending time in nature\n'
            '* Regular relaxation practices',
      ),
      GuideSection(
        emoji: '🚿',
        title: 'Cold Exposure & Outdoors',
        accentColor: Color(0xFF42A5F5),
        body:
            '**Cold Exposure**\n'
            'Cold showers or cold water exposure may help improve circulation and recovery. Some people include **2–3 cold showers per week** as part of their routine.\n\n'
            '**Spending Time Outdoors**\n'
            'Walking outdoors and getting sunlight exposure can support mental health and physical well-being. Time in nature can also help reduce stress.',
      ),
      GuideSection(
        emoji: '☀️',
        title: 'Sunlight & Vitamin D',
        accentColor: Color(0xFFFFD700),
        body:
            'Sunlight plays a key role in vitamin D production.\n\n'
            'Try to spend **15–30 minutes outdoors daily** when possible.\n\n'
            'If sunlight exposure is limited, some people consider **vitamin D supplementation** after consulting with a healthcare professional.',
      ),
      GuideSection(
        emoji: '👕',
        title: 'Clothing & Environmental Factors',
        accentColor: Color(0xFF607D8B),
        body:
            'Wearing **loose, breathable fabrics** can help maintain comfort and temperature regulation.\n\n'
            'Some people also choose to reduce exposure to environmental chemicals found in plastics or certain personal care products.',
      ),
      GuideSection(
        emoji: '🌿',
        title: 'Environmental Toxins',
        accentColor: Color(0xFF4CAF50),
        body:
            'Some environmental chemicals may interfere with hormone balance.\n\n'
            'To reduce exposure:\n'
            '* Use glass or stainless steel containers when possible\n'
            '* Wash fruits and vegetables thoroughly\n'
            '* Choose simple personal care products when available',
      ),
      GuideSection(
        emoji: '💊',
        title: 'Supplement Options',
        accentColor: Color(0xFF9C27B0),
        body:
            'Lifestyle and nutrition should always come first. However, some supplements people commonly explore for general health include:\n'
            '* Zinc\n'
            '* Magnesium\n'
            '* Ashwagandha\n'
            '* Vitamin D\n\n'
            'Always research supplements carefully and consult a professional if needed.',
      ),
      GuideSection(
        emoji: '💧',
        title: 'Hydration',
        accentColor: Color(0xFF2196F3),
        body:
            'Hydration supports overall bodily functions, including hormonal balance.\n\n'
            'Aim for **2–3 liters of water per day.**\n\n'
            'Including electrolytes from foods like fruit, vegetables, or coconut water can also help maintain balance.',
      ),
    ],
  ),
  GuideArticle(
    id: 'no_shampoo',
    title: 'No Shampoo',
    subtitle: 'How to maintain clean, healthy hair without shampoo',
    emoji: '🚿',
    isPremium: true,
    keyRule: 'Going shampoo-free isn\'t for everyone. The key is patience during the transition period and maintaining good scalp hygiene. Experiment with different natural methods and see what works best for your hair type.',
    sections: [
      GuideSection(
        emoji: '📖',
        title: 'Introduction',
        accentColor: Color(0xFF2196F3),
        body:
            'Ditching shampoo doesn\'t mean your hair has to look greasy or smell bad.\n\n'
            'In fact, many shampoos strip your hair of its natural oils on purpose. This can trap you in a cycle where your hair becomes dry, so you feel like you need to use even more shampoo and products.\n\n'
            'But your hair doesn\'t actually need that cycle. Here\'s how you can maintain clean, healthy hair **without relying on shampoo.**',
      ),
      GuideSection(
        emoji: '🔍',
        title: 'Why Some People Skip Shampoo',
        accentColor: Color(0xFF9C27B0),
        body:
            'Many shampoos contain **sulfates** — cleansing agents that remove oils from your scalp. While they clean effectively, they can also strip away natural oils that protect your hair.\n\n'
            'When your scalp loses these oils, it may produce **even more oil** to compensate. Over time, this creates a cycle of over-washing and dryness.\n\n'
            'A shampoo-free routine may allow your scalp to **balance its natural oil production.** Many people also report that avoiding harsh products can help reduce:\n'
            '* Dryness\n'
            '* Frizz\n'
            '* Breakage\n\n'
            '⚠️ **Added Tip:** No shampoo is only recommended for people who live in a **very clean environment with very low AQI (around 10 or lower)** and who don\'t use any kind of hair products. If you live in a polluted area or use styling products, sticking with shampoo is the smarter choice.',
      ),
      GuideSection(
        emoji: '🥚',
        title: 'Alternative #1: Egg Wash',
        accentColor: Color(0xFFFF9800),
        body:
            'Eggs contain proteins and nutrients that can help condition hair.\n\n'
            '* Whisk one or two eggs in a bowl\n'
            '* Apply the mixture to damp hair\n'
            '* Leave it for about **five minutes**\n'
            '* Rinse with **cool water**\n\n'
            'Cool water is important to prevent the egg from cooking in your hair.',
      ),
      GuideSection(
        emoji: '🌿',
        title: 'Alternative #2: Aloe Vera',
        accentColor: Color(0xFF4CAF50),
        body:
            'Aloe vera can gently cleanse and hydrate the scalp.\n\n'
            '* Apply fresh aloe vera gel to your hair and scalp\n'
            '* Leave it for about **10 minutes**\n'
            '* Rinse thoroughly with water',
      ),
      GuideSection(
        emoji: '🌱',
        title: 'Alternative #3: Herbal Rinses',
        accentColor: Color(0xFF4CAF50),
        body:
            'Certain herbs can help nourish the scalp and add a natural scent. Common options include chamomile, rosemary, and nettle.\n\n'
            'To make a rinse:\n'
            '* Brew a strong herbal tea\n'
            '* Let it cool\n'
            '* Use it as a rinse after washing your hair',
      ),
      GuideSection(
        emoji: '🌊',
        title: 'The Benefits of Salt Water',
        accentColor: Color(0xFF00BCD4),
        body:
            'If you live near the ocean, salt water can naturally affect your hair. Salt water may help:\n'
            '* Absorb excess oil\n'
            '* Gently exfoliate the scalp\n'
            '* Add natural texture and volume\n\n'
            'Many people notice that ocean water creates a **natural textured "beach" look.**\n\n'
            '**Making a Sea Salt Rinse at Home:**\n'
            'Mix **1 tablespoon sea salt** with **1 cup warm water** and use it to rinse your hair. Sunlight can enhance the texture effect, which is why many people notice stronger results at the beach.',
      ),
      GuideSection(
        emoji: '💡',
        title: 'How to Keep Hair Fresh Without Shampoo',
        accentColor: Color(0xFF2196F3),
        body:
            '**Rinse Your Hair Daily**\n'
            'When showering, rinse your hair with warm water and gently massage your scalp with your fingertips. This helps remove dirt and excess oil.\n\n'
            '**Use Essential Oils**\n'
            'Essential oils like tea tree oil and lavender oil can add a fresh scent and support scalp health when used in small amounts.\n\n'
            '**Brush Your Hair Regularly**\n'
            'Using a natural brush such as a **boar bristle brush** helps distribute your scalp\'s natural oils from root to tip — keeping hair moisturized and balanced.',
      ),
      GuideSection(
        emoji: '🥗',
        title: 'Nutrition & Hydration for Healthy Hair',
        accentColor: Color(0xFFFF9800),
        body:
            'Hair health is also influenced by your diet and hydration.\n\n'
            'Drink enough water — around **2–3 liters per day.**\n\n'
            'Also focus on nutrients like:\n'
            '* Zinc\n'
            '* Biotin\n'
            '* Omega-3 fatty acids\n\n'
            'These nutrients support hair health from the inside.',
      ),
      GuideSection(
        emoji: '⏳',
        title: 'The Transition Phase',
        accentColor: Color(0xFF607D8B),
        body:
            'When you stop using shampoo, your scalp often goes through an **adjustment period.**\n\n'
            'During the first few weeks, your hair may feel **oilier than usual.** This happens because your scalp is adjusting its natural oil production.\n\n'
            'With time and consistency, many people find their scalp eventually balances itself. During this phase, regular rinsing and gentle scalp massages can help manage excess oil.',
      ),
    ],
  ),
  GuideArticle(
    id: 'hair_product_guide',
    title: 'Hair Product Guide',
    subtitle: 'Find the right product for your hair type and style',
    emoji: '💈',
    isPremium: true,
    keyRule: 'Healthy hair isn\'t just about appearance — it also boosts confidence and overall grooming. Know your hair type, use the right products, and handle your hair gently for the best long-term results.',
    sections: [
      GuideSection(
        emoji: '🔍',
        title: 'Step 1: Identify Your Hair Type',
        accentColor: Color(0xFF2196F3),
        body:
            'Before choosing any product, you need to understand your hair type. Different hair textures require different types of products.\n\n'
            '**Straight hair**\n'
            'Needs lightweight products that provide control and shine without weighing the hair down.\n\n'
            '**Wavy hair**\n'
            'Benefits from products that define the waves and reduce frizz.\n\n'
            '**Curly hair**\n'
            'Requires products that provide deep moisture and curl definition.\n\n'
            '**Coily hair**\n'
            'Needs intense hydration and stronger hold to maintain structure and definition.',
      ),
      GuideSection(
        emoji: '✨',
        title: 'Pomade',
        accentColor: Color(0xFF9C27B0),
        body:
            'Pomade provides **medium to high shine** and creates a sleek, polished look.\n\n'
            'It works best for **straight or slightly wavy hair**, especially for styles like slick backs, side parts, and classic polished styles.\n\n'
            '**Pro tip:** Water-based pomades wash out more easily, while oil-based pomades provide longer-lasting hold.',
      ),
      GuideSection(
        emoji: '🪨',
        title: 'Hair Wax',
        accentColor: Color(0xFF607D8B),
        body:
            'Wax provides **medium hold with a natural matte finish.** It\'s great for **straight or wavy hair** and works especially well for messy or textured hairstyles.\n\n'
            '**Tip:** Warm the wax between your hands for about **10 seconds before applying.** This softens the product and makes it distribute much more evenly through your hair.',
      ),
      GuideSection(
        emoji: '🏺',
        title: 'Hair Clay',
        accentColor: Color(0xFFFF9800),
        body:
            'Hair clay provides **strong hold with a matte finish.** It works well for **fine to medium-thick hair**, especially with short to medium hairstyles.\n\n'
            '**Pro tip:** Apply clay mainly to the **roots** if you want more lift and volume.',
      ),
      GuideSection(
        emoji: '🧴',
        title: 'Hair Cream',
        accentColor: Color(0xFF4CAF50),
        body:
            'Hair cream offers **light hold, moisture, and a slight natural shine.** It works best for wavy, curly, or coarse hair — ideal for **longer or more natural-looking hairstyles.**\n\n'
            'For softer styles, apply it to **slightly damp hair.**',
      ),
      GuideSection(
        emoji: '💧',
        title: 'Hair Gel',
        accentColor: Color(0xFF2196F3),
        body:
            'Hair gel provides **strong hold and high shine**, locking your hairstyle in place for long periods. It works best for **straight or thick hair** that needs maximum control.\n\n'
            '**Tip:** Use gel sparingly to avoid a crunchy or stiff look.',
      ),
      GuideSection(
        emoji: '🌊',
        title: 'Sea Salt Spray',
        accentColor: Color(0xFF00BCD4),
        body:
            'Sea salt spray adds **texture, volume, and a natural beachy look.** It\'s best for **straight or wavy hair** and works well for casual, slightly messy styles.\n\n'
            '**Pro tip:** Apply it to damp hair and lightly scrunch your hair with a towel to enhance texture and wave definition.',
      ),
      GuideSection(
        emoji: '🫙',
        title: 'Hair Oil',
        accentColor: Color(0xFFFFD700),
        body:
            'Hair oil adds **shine, hydration, and frizz control.** It\'s especially helpful for dry, curly, or coily hair.\n\n'
            'When applying, focus on the **ends of your hair**, not the roots, to avoid making your hair look greasy.',
      ),
      GuideSection(
        emoji: '🌿',
        title: 'Leave-In Conditioner & Hair Masks',
        accentColor: Color(0xFF4CAF50),
        body:
            '**Leave-In Conditioner**\n'
            'Provides hydration, detangling, and protection from damage. Works for most hair types but is particularly helpful for **dry or damaged hair.**\n\n'
            '**Hair Masks**\n'
            'Designed to deeply condition and repair hair. If your hair feels brittle, dry, or lifeless, adding a hair mask to your routine can help restore moisture and strength.',
      ),
      GuideSection(
        emoji: '🔧',
        title: 'How to Revive Damaged Hair',
        accentColor: Color(0xFFE53935),
        body:
            'Hair can become **dry, brittle, and damaged** from excessive heat styling, chemical treatments, or over-styling.\n\n'
            'To improve hair health, consider adding:\n'
            '* Deep conditioning masks\n'
            '* Hair oils\n'
            '* Leave-in conditioners\n'
            '* Protein treatments\n\n'
            'Protein treatments help strengthen hair, especially those containing **hydrolyzed proteins.** However, avoid too much protein — excess protein can make hair stiff and brittle. Alternate between **protein treatments and moisturizing products.**',
      ),
      GuideSection(
        emoji: '🛡️',
        title: 'Preventing Hair Damage',
        accentColor: Color(0xFF607D8B),
        body:
            'To keep your hair healthy:\n'
            '* Minimize heat styling when possible\n'
            '* Avoid harsh chemical treatments\n'
            '* Handle your hair gently\n\n'
            'Even aggressive towel drying can cause unnecessary breakage, so dry your hair carefully.',
      ),
      GuideSection(
        emoji: '🛒',
        title: 'Product Recommendations',
        accentColor: Color(0xFFFFD700),
        body:
            '🛒 **My Personal Recommendations**\n'
            'If you want to buy the products I personally use and recommend, you can check the **Shop tab inside the app** where I\'ve listed the exact ones I use.',
      ),
    ],
  ),
  GuideArticle(
    id: 'unlocking_igf1',
    title: 'Unlocking IGF-1',
    subtitle: 'Naturally support the hormone behind muscle growth and recovery',
    emoji: '💪',
    isPremium: true,
    keyRule: 'Supporting healthy IGF-1 levels isn\'t about quick fixes. It comes from building strong habits around nutrition, strength training, quality sleep, recovery, and stress management. Consistent habits lead to long-term progress.',
    sections: [
      GuideSection(
        emoji: '📖',
        title: 'What Is IGF-1 and Why Does It Matter?',
        accentColor: Color(0xFF2196F3),
        body:
            'IGF-1, or **Insulin-Like Growth Factor 1**, is one of the most important hormones for muscle growth, recovery, and overall physical performance.\n\n'
            'IGF-1 is produced primarily in the **liver** in response to growth hormone. It plays a major role in:\n'
            '* Muscle growth\n'
            '* Fat metabolism\n'
            '* Tissue repair\n'
            '* Bone density\n'
            '* Recovery\n\n'
            'IGF-1 helps stimulate **protein synthesis**, improve metabolic efficiency, and support the repair and growth of tissues. Supporting healthy IGF-1 levels is mainly about **optimizing your lifestyle habits, nutrition, and training.**',
      ),
      GuideSection(
        emoji: '🥗',
        title: 'Nutrition for Healthy IGF-1 Levels',
        accentColor: Color(0xFF4CAF50),
        body:
            '**Protein-Rich Foods**\n'
            'Protein intake plays an important role in supporting IGF-1 production. Focus on high-quality sources: eggs, fish, lean meats, Greek yogurt, and legumes. Complete protein sources provide amino acids that support muscle repair and growth.\n\n'
            '**Healthy Fats**\n'
            'Healthy fats support hormone production and overall metabolic health: avocados, olive oil, nuts, seeds, and fatty fish.\n\n'
            '**Balanced Carbohydrates**\n'
            'Carbohydrates influence insulin levels, which interact with IGF-1 signaling. Focus on complex carbohydrates: oats, brown rice, sweet potatoes, and fruits like berries and bananas. Balanced meals that include **protein, fats, and carbohydrates** help maintain stable energy and hormone balance.\n\n'
            '**Nutrient-Dense Foods**\n'
            'Foods often included in recovery-focused diets: bone broth (contains collagen and amino acids), fermented dairy products, and whole foods rich in vitamins and minerals.',
      ),
      GuideSection(
        emoji: '🚫',
        title: 'Foods to Limit',
        accentColor: Color(0xFFE53935),
        body:
            'Certain dietary patterns may negatively affect overall hormone health if consumed excessively.\n\n'
            'Try to limit:\n'
            '* Refined sugars\n'
            '* Highly processed foods\n'
            '* Excessive alcohol\n\n'
            'Focus instead on **whole, nutrient-dense foods.**',
      ),
      GuideSection(
        emoji: '🏋️',
        title: 'Training for IGF-1 Support',
        accentColor: Color(0xFFFF9800),
        body:
            '**Strength Training**\n'
            'Compound exercises stimulate multiple muscle groups and support muscle development: squats, deadlifts, bench press, pull-ups. Training with challenging weights and progressive overload can support muscle growth and recovery.\n\n'
            '**High-Intensity Interval Training (HIIT)**\n'
            'HIIT involves short bursts of intense effort followed by rest. Example: 30 seconds sprint, 60 seconds rest, repeated several times. HIIT supports cardiovascular fitness and overall performance.\n\n'
            '**Progressive Overload**\n'
            'Gradually increasing training intensity over time helps stimulate muscle growth and adaptation. Consistency and gradual progression are key.',
      ),
      GuideSection(
        emoji: '😴',
        title: 'The Importance of Sleep',
        accentColor: Color(0xFF7C5CBF),
        body:
            'Sleep is one of the most important factors for hormone balance. Growth hormone, which influences IGF-1 production, is released primarily during **deep sleep.**\n\n'
            'Aim for **7–9 hours of quality sleep per night.**\n\n'
            'Helpful sleep habits:\n'
            '* Sleep in a dark room\n'
            '* Maintain a regular sleep schedule\n'
            '* Limit screen exposure before bed',
      ),
      GuideSection(
        emoji: '⚖️',
        title: 'Hormonal Balance & IGF-1',
        accentColor: Color(0xFF9C27B0),
        body:
            'IGF-1 works alongside other hormones in the body. Supporting overall hormone balance through proper nutrition, sleep, and exercise helps maintain healthy IGF-1 activity.\n\n'
            'Insulin sensitivity and growth hormone levels both interact with IGF-1 signaling.',
      ),
      GuideSection(
        emoji: '🧊',
        title: 'Cold and Heat Therapy',
        accentColor: Color(0xFF00BCD4),
        body:
            '**Cold Exposure**\n'
            'Cold showers or ice baths may help reduce inflammation and support recovery after workouts.\n\n'
            '**Heat Exposure**\n'
            'Saunas can improve circulation and promote relaxation. Some people include **15–20 minutes of sauna use several times per week** as part of recovery routines.',
      ),
      GuideSection(
        emoji: '⚠️',
        title: 'Habits That May Reduce Hormonal Balance',
        accentColor: Color(0xFFFF5722),
        body:
            'Certain lifestyle factors may negatively impact recovery and hormone regulation:\n'
            '* Chronic stress\n'
            '* Sedentary lifestyle\n'
            '* Excessive training without recovery\n\n'
            'Balancing training, recovery, and stress management is important.',
      ),
      GuideSection(
        emoji: '💊',
        title: 'Supplement Considerations',
        accentColor: Color(0xFF607D8B),
        body:
            'Lifestyle habits should always come first. However, some supplements commonly used for general recovery and health include:\n'
            '* Creatine\n'
            '* Zinc\n'
            '* Magnesium\n'
            '* Adaptogens such as ashwagandha\n\n'
            'Always research supplements carefully and consult professionals if needed.',
      ),
      GuideSection(
        emoji: '💧',
        title: 'Hydration and Electrolytes',
        accentColor: Color(0xFF2196F3),
        body:
            'Proper hydration supports muscle function and overall performance.\n\n'
            'Aim for **2–3 liters of water per day.**\n\n'
            'Electrolytes from sources like fruit, coconut water, or mineral salts may also help support hydration.',
      ),
    ],
  ),
  GuideArticle(
    id: 'upturned_smile_smirk',
    title: 'Upturned Smile & Smirk',
    subtitle: 'Train your facial muscles to project confidence and charm',
    emoji: '😏',
    isPremium: true,
    keyRule: 'The way you control your facial expressions influences how others perceive your emotions and confidence. With time, these expressions may begin to feel natural and help you communicate warmth, confidence, and engagement more effectively.',
    sections: [
      GuideSection(
        emoji: '📖',
        title: 'Why These Expressions Work',
        accentColor: Color(0xFF2196F3),
        body:
            'The **upturned smile** and the **smirk** are two facial expressions that naturally project confidence, charm, and approachability. These subtle movements can completely change how your face is perceived.\n\n'
            'An **upturned smile** tends to create a warmer and more approachable appearance. Even if you feel happy, a naturally downturned smile can sometimes make your expression appear more neutral or serious than intended. Learning to slightly lift the corners of your mouth can make your smile look more open and positive.\n\n'
            'The **smirk** communicates a slightly different energy. A subtle smirk often gives the impression of quiet confidence and playfulness. Because it\'s asymmetrical and restrained, it can appear more intriguing than a full smile.\n\n'
            'Both expressions can make interactions feel more engaging when used naturally.',
      ),
      GuideSection(
        emoji: '💪',
        title: 'Muscles Involved',
        accentColor: Color(0xFF9C27B0),
        body:
            '**Zygomaticus Major & Minor**\n'
            'These muscles lift the corners of the mouth upward and are responsible for creating a natural-looking smile. They play a major role in producing an upturned smile.\n\n'
            '**Orbicularis Oris**\n'
            'This circular muscle surrounds the mouth and helps shape different mouth expressions. It contributes to both smiling and smirking.\n\n'
            '**Risorius**\n'
            'The risorius pulls the corners of the mouth outward and helps create the asymmetry that forms a smirk.\n\n'
            '**Buccinator**\n'
            'Located in the cheeks, the buccinator stabilizes facial movements and helps maintain smooth, controlled expressions.',
      ),
      GuideSection(
        emoji: '🏋️',
        title: 'Smile Exercise #1: Smile Lift',
        accentColor: Color(0xFF4CAF50),
        body:
            'Stand in front of a mirror.\n\n'
            'Gently lift the corners of your mouth into a smile while focusing on engaging the muscles around the mouth.\n\n'
            'Hold the smile for about **5 seconds**, then relax.\n\n'
            'Repeat **10–15 times per session**, ideally once in the morning and once in the evening.',
      ),
      GuideSection(
        emoji: '🏋️',
        title: 'Smile Exercise #2: Cheek Resistance',
        accentColor: Color(0xFF4CAF50),
        body:
            'Place your fingers lightly on the corners of your mouth.\n\n'
            'Smile upward while applying gentle resistance with your fingers. This activates the zygomaticus muscles.\n\n'
            'Hold for **5 seconds** and repeat **10 times.**\n\n'
            'Practicing in front of a mirror helps you see how small changes in expression can alter how your face appears.',
      ),
      GuideSection(
        emoji: '🏋️',
        title: 'Smirk Exercise #1: Single-Side Smile',
        accentColor: Color(0xFFFF9800),
        body:
            'The smirk relies more on **asymmetrical control.**\n\n'
            'In front of a mirror, practice lifting **one side of your mouth** while keeping the other side relaxed.\n\n'
            'Hold the smirk for **5–10 seconds.**\n\n'
            'Repeat **10–15 times per session.**',
      ),
      GuideSection(
        emoji: '🏋️',
        title: 'Smirk Exercise #2: Resistance Smirk',
        accentColor: Color(0xFFFF9800),
        body:
            'Place a finger against one side of your mouth.\n\n'
            'Try to form a smirk against the resistance.\n\n'
            'Repeat **10 times per side.**\n\n'
            'Training both sides helps develop balanced control.',
      ),
      GuideSection(
        emoji: '✨',
        title: 'Additional Expression Control',
        accentColor: Color(0xFF00BCD4),
        body:
            'Some people combine mouth expressions with subtle eyebrow positioning or eye expressions.\n\n'
            'These combined expressions can create a more engaging overall facial appearance.\n\n'
            'Like any muscle control skill, this improves with **consistent practice and awareness.**',
      ),
      GuideSection(
        emoji: '📈',
        title: 'Expected Results',
        accentColor: Color(0xFF4CAF50),
        body:
            '**1–2 weeks**\n'
            'You may notice improved awareness of your facial muscles.\n\n'
            '**1–2 months**\n'
            'Expressions begin to feel more natural and controlled.\n\n'
            '**Around 6 months**\n'
            'Facial expressions may become more refined and natural without requiring conscious effort.',
      ),
      GuideSection(
        emoji: '❌',
        title: 'Common Mistakes to Avoid',
        accentColor: Color(0xFFE53935),
        body:
            '**Overexerting the muscles**\n'
            'Facial muscles are delicate. Gentle, consistent practice works better than forcing movements.\n\n'
            '**Ignoring balance**\n'
            'Even though a smirk is asymmetrical, it\'s important to train both sides of the face.\n\n'
            '**Inconsistent practice**\n'
            'Like any skill, occasional practice won\'t create noticeable improvement.\n\n'
            '**Not allowing relaxation**\n'
            'Give your facial muscles time to relax between exercises.',
      ),
    ],
  ),
  GuideArticle(
    id: 'control_cortisol',
    title: 'Control Cortisol',
    subtitle: 'How stress is changing your face — and how to fix it',
    emoji: '😤',
    isPremium: true,
    keyRule: 'Cortisol is not the enemy. It is a necessary hormone that helps regulate energy, alertness, and performance. The key is managing stress so cortisol rises and falls at the right times. When you support your body\'s natural rhythm, you\'ll feel better, recover better, and your appearance may improve as well.',
    sections: [
      GuideSection(
        emoji: '📖',
        title: 'What Is Cortisol?',
        accentColor: Color(0xFF2196F3),
        body:
            'The amount of **stress** you experience can directly influence how your face looks.\n\n'
            'Cortisol, often called the **stress hormone**, affects much more than just your mood. When cortisol levels are poorly managed, they can show visible effects on your skin, facial structure, and overall appearance.\n\n'
            'Cortisol is a hormone released by your **adrenal glands** in response to stress or low blood sugar. It plays several important roles:\n'
            '* Regulating energy levels\n'
            '* Improving alertness and focus\n'
            '* Controlling inflammation\n'
            '* Maintaining the sleep-wake cycle\n\n'
            'Cortisol itself is not harmful. Problems begin when cortisol levels stay **too high for too long** or become poorly regulated.',
      ),
      GuideSection(
        emoji: '😮',
        title: 'What Is "Cortisol Face"?',
        accentColor: Color(0xFFFF5722),
        body:
            'When cortisol levels remain elevated over long periods, it can affect your appearance in several ways.\n\n'
            '**Facial Puffiness**\n'
            'High cortisol can lead to **fluid retention**, causing swelling and puffiness — especially around the cheeks and jaw.\n\n'
            '**Skin Damage**\n'
            'Chronically elevated cortisol breaks down **collagen and elastin**, essential for firm and youthful skin. Over time this may lead to wrinkles, sagging skin, and a dull or tired complexion.\n\n'
            '**Fat Redistribution**\n'
            'Excess cortisol may encourage fat storage in the **face and neck**, creating a more rounded appearance.\n\n'
            '**Acne and Breakouts**\n'
            'Cortisol increases oil production and inflammation in the skin, both of which can contribute to acne.\n\n'
            '**Dark Circles and Eye Bags**\n'
            'Stress and disrupted sleep caused by cortisol imbalance can contribute to dark circles and under-eye bags.\n\n'
            '✅ **The Good News:** These changes are **not permanent.** When stress is properly managed and cortisol returns to a healthy rhythm, many of these effects can improve.',
      ),
      GuideSection(
        emoji: '🌅',
        title: 'Your Morning Cortisol Spike',
        accentColor: Color(0xFFFF9800),
        body:
            'Cortisol naturally rises in the morning through something called the **Cortisol Awakening Response (CAR).** This spike helps you feel alert and energized at the start of the day.\n\n'
            '**Morning Sunlight**\n'
            'Exposure to natural sunlight shortly after waking helps regulate your circadian rhythm and supports healthy cortisol timing. Try spending **5–10 minutes outside** soon after waking. Even on cloudy days, natural light still signals the body to wake up.\n\n'
            '**Delay Screen Exposure**\n'
            'Immediately checking your phone or computer can disrupt your natural wake-up routine. Allow your body to wake naturally before diving into screens.\n\n'
            '**Gentle Morning Activity**\n'
            'Light movement, stretching, or walking outside can help your body transition into the day and regulate stress hormones.',
      ),
      GuideSection(
        emoji: '📈',
        title: 'Effects of Chronic High Cortisol',
        accentColor: Color(0xFFE53935),
        body:
            'When stress remains high for long periods, it can disrupt processes that maintain healthy skin and facial structure.\n\n'
            'Possible effects include:\n'
            '* Collagen breakdown\n'
            '* Puffiness and redness\n'
            '* Increased facial fat storage\n'
            '* Acne and inflammation',
      ),
      GuideSection(
        emoji: '📉',
        title: 'Low Cortisol Problems',
        accentColor: Color(0xFF607D8B),
        body:
            'Cortisol that is too low can also cause issues.\n\n'
            'Low cortisol may lead to:\n'
            '* Fatigue\n'
            '* Pale or dull skin\n'
            '* Slower healing\n\n'
            'Healthy cortisol regulation is about **balance**, not elimination.',
      ),
      GuideSection(
        emoji: '⚖️',
        title: 'How to Manage Cortisol',
        accentColor: Color(0xFF9C27B0),
        body:
            'The goal is to allow cortisol to rise when needed and fall during recovery periods.\n\n'
            '**When Cortisol Should Rise**\n'
            'Short bursts of cortisol can be helpful for performance and energy:\n'
            '* Morning wake-up response\n'
            '* Physical exercise\n\n'
            '**When Cortisol Should Fall**\n'
            'During rest and recovery, cortisol should naturally decrease. Helpful habits include:\n'
            '* Quality sleep\n'
            '* Relaxation techniques\n'
            '* Balanced meals\n'
            '* Limiting excessive caffeine\n'
            '* Reducing chronic stress',
      ),
      GuideSection(
        emoji: '🌿',
        title: 'Daily Lifestyle Habits That Help',
        accentColor: Color(0xFF4CAF50),
        body:
            'Several daily habits can help support healthy cortisol balance:\n'
            '* Regular sleep schedule\n'
            '* Daily sunlight exposure\n'
            '* Moderate exercise\n'
            '* Hydration\n'
            '* Limiting constant screen exposure\n'
            '* Relaxation practices such as breathing exercises or meditation',
      ),
      GuideSection(
        emoji: '✅',
        title: 'What Happens When You Manage Stress',
        accentColor: Color(0xFF4CAF50),
        body:
            'When cortisol returns to a balanced rhythm, many people notice improvements such as:\n'
            '* Reduced facial puffiness\n'
            '* Clearer skin\n'
            '* Improved facial definition\n'
            '* Better energy levels',
      ),
    ],
  ),
  GuideArticle(
    id: 'zygomatic_pushing',
    title: 'Zygomatic Pushing',
    subtitle: 'Can controlled pressure increase cheekbone prominence?',
    emoji: '🦴',
    isPremium: true,
    keyRule: 'Zygomatic pushing is a low-risk technique, but it should not be seen as a guaranteed way to change your facial structure. At best, results are likely to be subtle and gradual. Maintaining realistic expectations is important if you decide to try it.',
    sections: [
      GuideSection(
        emoji: '📖',
        title: 'What Is Zygomatic Pushing?',
        accentColor: Color(0xFF2196F3),
        body:
            'If you want **higher, more prominent cheekbones without surgery**, zygomatic pushing is a technique that has recently gained attention.\n\n'
            'The idea comes from **joint suture theory**, which suggests that consistent pressure over time might lead to subtle changes in facial structure.\n\n'
            'Zygomatic pushing involves applying **controlled pressure to the zygomatic bones** — the bones that form your cheekbones. The goal is to stimulate the **facial sutures**, the joints where bones in the skull connect.\n\n'
            'The theory suggests that even in adulthood, these sutures retain a **small degree of flexibility**, meaning that consistent pressure might influence bone positioning over long periods.',
      ),
      GuideSection(
        emoji: '🔬',
        title: 'What Does the Evidence Say?',
        accentColor: Color(0xFF9C27B0),
        body:
            '**Anthropological Observations**\n'
            'Studies of ancient populations show that people who consumed **tough diets requiring heavy chewing** often developed wider, more robust facial structures including stronger zygomatic arches. This suggests that external mechanical forces can influence facial bone development during growth.\n\n'
            '**Modern Scientific Understanding**\n'
            'There is some biological logic behind bone remodeling — for example, **orthodontic treatments** use sustained pressure to slowly move teeth by influencing bone structure. However, the key difference is **age.** The flexibility of cranial sutures decreases significantly as people get older, making the potential for noticeable changes much smaller in adulthood.\n\n'
            '**Who Might See the Most Effect?**\n'
            'If any effect exists, it would likely occur most in teenagers and young adults in early developmental stages. After the mid-20s, the potential for structural change becomes extremely limited.\n\n'
            '**Bottom Line:** There is some theoretical basis, but scientific evidence is limited. Most claims are anecdotal, and any results — if they occur — are likely to be **very subtle**, especially in adults.',
      ),
      GuideSection(
        emoji: '🤲',
        title: 'How to Perform Zygomatic Pushing',
        accentColor: Color(0xFF4CAF50),
        body:
            '**Step 1 — Wash Your Hands**\n'
            'Always start with clean hands to avoid transferring bacteria to your skin.\n\n'
            '**Step 2 — Locate the Zygomatic Bones**\n'
            'Find the bony ridge along your cheekbones — this is the **zygomatic arch.**\n\n'
            '**Step 3 — Apply Gentle Pressure**\n'
            'Using your thumbs or index fingers, apply gentle pressure under the cheekbones and push **upward toward the temples.** Some people perform the technique from **inside the mouth**, pressing upward against the underside of the cheekbone through the inner cheek.\n\n'
            '**Step 4 — Hold the Pressure**\n'
            'Hold the pressure for **30–60 seconds**, then release. Repeat **2–3 times per session.**\n\n'
            '**Step 5 — Practice in Moderation**\n'
            'Perform the technique **once or twice per day.** Applying excessive pressure will not speed up results and may cause soreness or irritation. Maintain **good posture** while performing the technique, keeping your spine straight and your head aligned.',
      ),
      GuideSection(
        emoji: '📈',
        title: 'What Results Can You Expect?',
        accentColor: Color(0xFFFF9800),
        body:
            '**Younger Individuals**\n'
            'Some people may notice a slight improvement in cheekbone prominence and minor improvements in facial symmetry. This could take **3–6 months or longer.**\n\n'
            '**Adults**\n'
            'For adults, noticeable changes are unlikely. If any effect occurs, it would likely be **very subtle and gradual**, potentially taking years.',
      ),
      GuideSection(
        emoji: '⚠️',
        title: 'Important Precautions',
        accentColor: Color(0xFFE53935),
        body:
            'If you choose to try this method, keep these points in mind:\n'
            '* Avoid applying excessive pressure\n'
            '* Keep pressure even on both sides of the face\n'
            '* Stop if you feel pain or irritation\n'
            '* Avoid the technique if you have **TMJ or jaw-related conditions**\n\n'
            'For people over 30, structural changes are unlikely due to reduced suture flexibility.',
      ),
    ],
  ),
];