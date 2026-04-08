/// Static data helpers for zodiac sign descriptions, traits, and expanded content.
/// Extracted from onboarding_complete.dart to reduce file size.
library;

class OnboardingSignData {
  static String getPlacementMeaning(String type) {
    switch (type) {
      case 'rising':
        return 'Your outer mask';
      case 'sun':
        return 'Your core identity';
      case 'moon':
        return 'Your emotional self';
      default:
        return '';
    }
  }

  static List<String> getSignTraits(String? sign) {
    if (sign == null) return [];

    final traits = {
      'Aries': ['Bold', 'Pioneering', 'Courageous'],
      'Taurus': ['Grounded', 'Stable', 'Patient'],
      'Gemini': ['Curious', 'Adaptable', 'Witty'],
      'Cancer': ['Nurturing', 'Intuitive', 'Protective'],
      'Leo': ['Creative', 'Confident', 'Warm'],
      'Virgo': ['Analytical', 'Practical', 'Thoughtful'],
      'Libra': ['Harmonious', 'Diplomatic', 'Graceful'],
      'Scorpio': ['Intense', 'Transformative', 'Magnetic'],
      'Sagittarius': ['Adventurous', 'Optimistic', 'Free'],
      'Capricorn': ['Ambitious', 'Disciplined', 'Capable'],
      'Aquarius': ['Innovative', 'Unique', 'Independent'],
      'Pisces': ['Compassionate', 'Dreamy', 'Empathic'],
    };

    return traits[sign] ?? [];
  }

  static String getSignDescription(String? sign, String type) {
    if (sign == null) return '';

    final descriptions = {
      'Aries': {
        'sun':
            'You\'re the one who starts things when everyone else is still talking. Your confidence isn\'t arrogance—it\'s knowing you can handle whatever comes next.',
        'moon':
            'Your feelings hit like a lightning strike. You don\'t do subtle emotions, and honestly? That\'s refreshing. Most people wish they could feel this clearly.',
        'rising':
            'People notice you the second you walk in. You don\'t have to try—your energy just fills the room. Some find it intense, others find it magnetic.'
      },
      'Taurus': {
        'sun':
            'You build things that last. While others chase trends, you create foundations. Your patience is strategic wisdom most people don\'t have.',
        'moon':
            'You know exactly what you need to feel good. Cozy spaces, good food, beautiful things—these are necessities, not luxuries. Smart move.',
        'rising':
            'You seem calm, but you\'re actually incredibly strong. People underestimate you because you don\'t need to prove anything. That\'s your superpower.'
      },
      'Gemini': {
        'sun':
            'You see connections others miss. Your mind works like a web—everything links to everything else. It\'s why conversations with you are never boring.',
        'moon':
            'You feel everything at once, which is why labels feel wrong. You\'re not indecisive—you\'re too complex for simple categories. That\'s actually cool.',
        'rising':
            'People can\'t figure you out, and that\'s intentional. You have layers, and you reveal them selectively. It keeps things interesting.'
      },
      'Cancer': {
        'sun':
            'You read people like books. Your intuition picks up on things others miss completely. It\'s not magic—you just pay attention to what really matters.',
        'moon':
            'Home isn\'t just a place for you—it\'s a feeling. You create spaces where people can actually relax and be themselves. That\'s rare.',
        'rising':
            'People open up to you without meaning to. Your energy says "safe space" before you even speak. You make vulnerability feel normal.'
      },
      'Leo': {
        'sun':
            'You don\'t just want attention—you deserve it. Your light is real, and when you shine, you help others find their own. That\'s leadership.',
        'moon':
            'You feel things BIG. Your emotions aren\'t performances—they\'re just too real to hide. Most people wish they could express themselves this freely.',
        'rising':
            'You walk into rooms and they get brighter. Your confidence isn\'t fake—it\'s earned. People are drawn to that kind of authenticity.'
      },
      'Virgo': {
        'sun':
            'You notice what others ignore. That detail everyone missed? You saw it. Your precision is excellence, not nitpicking. Big difference.',
        'moon':
            'You overthink because you care. Your brain doesn\'t shut off because there\'s always something to improve. That\'s dedication, not anxiety.',
        'rising':
            'People come to you when things need fixing. You don\'t just see problems—you see solutions. Your practicality is actually a gift.'
      },
      'Libra': {
        'sun':
            'You see all sides because you actually listen. Your diplomacy is emotional intelligence most people don\'t have. That\'s powerful.',
        'moon':
            'You struggle with decisions because you see infinite possibilities. It\'s not indecision—every choice matters to you. That\'s thoughtful.',
        'rising':
            'You make everything look easy. Your grace isn\'t fake—it\'s just how you move through the world. People notice, even if you don\'t realize it.'
      },
      'Scorpio': {
        'sun':
            'You transform everything you touch. Your intensity isn\'t too much—it\'s exactly what\'s needed. You don\'t do surface level, and that\'s rare.',
        'moon':
            'You feel things most people can\'t handle. Your emotional depth creates connections that last forever. Shallow people can\'t keep up—their loss.',
        'rising':
            'People are drawn to your mystery. You don\'t reveal everything, and that makes you magnetic. Your depth is obvious even when you\'re quiet.'
      },
      'Sagittarius': {
        'sun':
            'You say what others won\'t. Your honesty might sting sometimes, but it\'s always real. People respect that, even when it\'s uncomfortable.',
        'moon':
            'You need space to breathe. Commitment feels like a cage because you\'re meant to explore. Your freedom is growth, not running away.',
        'rising':
            'Your optimism is contagious. You see possibilities where others see problems. That\'s choosing hope, not denial. And it works.'
      },
      'Capricorn': {
        'sun':
            'You build things that outlast you. Your ambition is legacy-building. You think in generations, not moments. That\'s rare.',
        'moon':
            'You control your emotions because feelings can wait. Your discipline is focus—you get things done while others are still feeling.',
        'rising':
            'People see your success, but miss your process. Your drive inspires others to work harder. You show what\'s possible with dedication.'
      },
      'Aquarius': {
        'sun':
            'You think in the future while others are stuck in now. Your ideas seem weird because they\'re ahead of their time. History will prove you right.',
        'moon':
            'You process feelings through ideas because emotions are overwhelming. Your distance protects your brilliant mind. It\'s survival, not coldness.',
        'rising':
            'You\'re weird, and you know it. Your uniqueness makes some uncomfortable, but the right people find it magnetic. You attract your tribe.'
      },
      'Pisces': {
        'sun':
            'You dream so others don\'t have to. Your imagination creates possibilities that inspire change. Reality needs people like you to see beyond it.',
        'moon':
            'You feel everything, and it\'s exhausting. Your empathy connects you to energies others miss. It\'s a gift, even when it feels like a burden.',
        'rising':
            'You seem gentle, but you\'re actually incredibly strong. Your sensitivity is emotional intelligence most people don\'t understand. That\'s their loss.'
      },
    };

    return descriptions[sign]?[type] ?? '';
  }

  static String getExpandedSignContent(String sign, String type) {
    // Expanded content - natural, conversational, bold, no em dashes, 3-4 paragraphs
    final insights = {
      'Aries': {
        'sun':
            'Most people think you\'re impulsive, but here\'s the thing: you\'re actually strategic as hell. You take risks because playing it safe gets you nowhere.\n\nWhen you charge ahead, you\'re clearing the path for everyone else. People follow you because you go first, and that takes real guts. Your competitive side isn\'t about beating others. It\'s about pushing yourself harder.\n\nYou don\'t wait around for perfect conditions because you know how to create them yourself. That\'s not recklessness. That\'s calculated courage.',
        'moon':
            'You process emotions faster than anyone. While other people need days to figure out their feelings, you do it in hours. Sometimes minutes.\n\nThat\'s because you feel everything so intensely that sitting with it feels impossible. Movement is your therapy. Exercise, action, doing something. That\'s how you work through feelings.\n\nWhen you\'re stuck, your body knows before your mind does. Your anger? That\'s information. Your excitement? That\'s real joy. You don\'t do subtle emotions because life\'s too short for that nonsense.',
        'rising':
            'First impressions are everything and you know it. People feel your energy before they even see you. Some find that intimidating because your confidence is obvious. Others find it magnetic because you\'re not hiding anything.\n\nYou\'ve learned to use your presence as a tool. When you walk into a room, you\'re not trying to dominate. You\'re just being yourself, and that\'s powerful enough.\n\nYour directness isn\'t rudeness. It\'s efficiency. You don\'t waste time on small talk when real connection is possible.',
      },
      'Taurus': {
        'sun':
            'Your relationship with time is different. While everyone else rushes around, you understand that the best things take time. That stubbornness people complain about? That\'s commitment.\n\nWhen you decide something matters, you stick with it. That\'s not inflexibility. That\'s integrity. You build things that last because you think in terms of legacy, not quick wins.\n\nYour patience isn\'t passive waiting. It\'s active. You know when to push and when to let things develop naturally. Quality over quantity isn\'t just a saying for you. It\'s how you live.',
        'moon':
            'Your need for comfort isn\'t weakness. It\'s self awareness. You know exactly what you need to feel good, and you\'re not apologizing for it.\n\nBeautiful spaces, good food, things that feel good. These aren\'t indulgences. They\'re necessities. Your home is your sanctuary, and you\'ve learned that environment affects everything.\n\nWhen you create beauty around you, you\'re not being materialistic. You\'re creating the conditions for your best self. Your relationship with money isn\'t greed. It\'s security. You understand that financial stability creates real freedom.',
        'rising':
            'People underestimate you because you don\'t need to prove anything. Your quiet strength is way more powerful than loud confidence.\n\nYou don\'t need to be the center of attention because you know your worth. Your reliability is a superpower. In a world full of chaos, you\'re the steady one.\n\nPeople trust you because you\'re consistent. Your calm presence makes others feel safe. You don\'t need to be loud to be heard. Your actions speak louder than words.',
      },
      'Gemini': {
        'sun':
            'Your mind doesn\'t work in straight lines. It works in webs. You see connections others miss because you\'re constantly gathering information from everywhere.\n\nThat\'s not scattered thinking. That\'s strategic curiosity. You know the best ideas come from unexpected connections. Your ability to talk about anything isn\'t superficial. It\'s genuine interest.\n\nYou\'re not trying to impress people. You\'re genuinely curious about everything. Your adaptability isn\'t indecision. It\'s intelligence. You can see multiple perspectives because you\'re not attached to one way of thinking.',
        'moon':
            'Your emotions are complex because you feel everything at once. That\'s not indecision. That\'s emotional intelligence.\n\nYou process feelings through talking because that\'s how you understand them. Your need for mental stimulation isn\'t avoidance. It\'s how you process emotions.\n\nWhen you\'re bored, you\'re not just bored. You\'re emotionally unfulfilled. Your quick emotional changes aren\'t instability. They\'re responsiveness. You feel things deeply, but you process them quickly through conversation and thinking.',
        'rising':
            'People can\'t pin you down, and that\'s intentional. You have multiple sides because you\'re genuinely multifaceted.\n\nYour adaptability isn\'t fake. It\'s authentic interest in different perspectives. You can talk to anyone because you\'re genuinely curious about everyone.\n\nYour wit isn\'t just humor. It\'s intelligence expressed playfully. People are drawn to your energy because it\'s dynamic. You don\'t need to choose one version of yourself. You can be all of them.',
      },
      'Cancer': {
        'sun':
            'Your intuition isn\'t guessing. It\'s pattern recognition at a subconscious level. You notice things others miss because you\'re paying attention to what really matters.\n\nYour sensitivity isn\'t weakness. It\'s emotional intelligence. You understand people because you feel what they feel. Your ability to know what someone needs before they ask isn\'t magic. It\'s empathy.\n\nYou navigate relationships with grace because you understand emotional dynamics. Your protective nature isn\'t controlling. It\'s caring.',
        'moon':
            'Home isn\'t a place. It\'s a feeling you create. Your need for security isn\'t neediness. It\'s wisdom.\n\nYou know that everyone needs a safe space, and you\'re good at creating that. When you care for loved ones, you\'re at your best. Your emotional depth helps you nurture others in ways they didn\'t know they needed.\n\nCreating sanctuary is your art form. Your memories aren\'t just nostalgia. They\'re emotional anchors that ground you.',
        'rising':
            'Your energy creates safety. People open up to you because they feel understood. Your warmth isn\'t fake. It\'s genuine care.\n\nYou naturally create environments where vulnerability feels normal. People trust you because you don\'t judge. You just understand.\n\nYour protective nature makes others feel safe to be authentic. You\'re the person people call when they need someone who gets it. Your emotional intelligence is obvious to everyone except you.',
      },
      'Leo': {
        'sun':
            'Your need for recognition isn\'t vanity. It\'s validation that you matter. When you shine, you give others permission to shine too.\n\nYour confidence isn\'t fake. It\'s earned through knowing who you are. You lead through inspiration, not intimidation. Your creativity isn\'t just talent. It\'s expression of your authentic self.\n\nWhen you\'re at your best, everyone around you feels more confident. Your generosity isn\'t performative. It\'s genuine. You want others to succeed because their success doesn\'t diminish yours.',
        'moon':
            'Your emotions are big because you feel everything fully. You don\'t do subtle because that\'s not who you are.\n\nYour need for appreciation isn\'t neediness. It\'s how you feel loved. When you express emotions, it\'s authentic. You don\'t hide feelings like others do.\n\nYour dramatic nature isn\'t attention seeking. It\'s emotional honesty. Most people wish they could express themselves as freely as you do. Your heart is generous, and you deserve recognition for that.',
        'rising':
            'Your presence is magnetic. People are drawn to your warmth and confidence. You don\'t have to try to stand out. You naturally do.\n\nYour optimism is contagious, and people feel better when you\'re around. You command attention without trying because your energy is naturally powerful.\n\nYour charisma isn\'t fake. It\'s authentic confidence. You don\'t need to prove anything. You just need to be yourself, and that\'s enough.',
      },
      'Virgo': {
        'sun':
            'Your attention to detail isn\'t nitpicking. It\'s excellence. You see what can be improved because you know what\'s possible.\n\nYour perfectionism isn\'t a flaw. It\'s high standards. You don\'t settle for good enough because you\'re capable of better. Your analytical mind isn\'t overthinking. It\'s thoroughness.\n\nYou notice what others miss because you pay attention. Your desire to improve things isn\'t criticism. It\'s care. You want things to be the best they can be.',
        'moon':
            'Your anxiety isn\'t weakness. It\'s your brain catching problems before they start. You think things through because you care about getting it right.\n\nYour need to be useful isn\'t low self worth. It\'s how you feel fulfilled. Helping others brings you deep satisfaction. Your analytical approach to emotions isn\'t cold. It\'s how you process them.\n\nYou feel deeply, but you think about those feelings. Your perfectionism in self care isn\'t vanity. It\'s self respect.',
        'rising':
            'People come to you for solutions because you think things through. Your practicality is a gift.\n\nPeople trust your judgment because you\'re thorough. Your thoughtful approach makes others feel understood. You\'re the person people turn to when they need someone who actually knows what they\'re doing.\n\nYour competence is obvious. You don\'t need to prove yourself. Your results speak for themselves.',
      },
      'Libra': {
        'sun':
            'Your need for balance isn\'t indecision. It\'s seeing all perspectives. You understand that most conflicts come from misunderstanding, not malice.\n\nYour diplomacy isn\'t weakness. It\'s emotional intelligence. You can see what everyone needs because you\'re not attached to one side. Your desire for harmony isn\'t avoidance. It\'s creating conditions for everyone to thrive.\n\nYou bring people together because you understand what they need. Your ability to find common ground is powerful.',
        'moon':
            'Your indecisiveness comes from seeing too many good options, not from being weak. Every choice matters to you because you understand the impact.\n\nYour need for partnership isn\'t codependency. It\'s how you discover yourself. You feel most balanced when sharing life with others.\n\nYour struggle with decisions isn\'t a flaw. It\'s thoroughness. You want to make the right choice, and that takes time. Your relationships help you understand yourself better.',
        'rising':
            'Your grace isn\'t fake. It\'s how you move through the world. People notice your charm because it\'s authentic.\n\nYour beauty reflects inner harmony. You put everyone at ease because you understand balance. People see you as the person who brings groups together.\n\nYour presence creates peace. You don\'t need to be loud to be heard. Your energy speaks for itself.',
      },
      'Scorpio': {
        'sun':
            'Your intensity isn\'t too much. It\'s exactly what\'s needed. You don\'t do surface level because depth is where real change happens.\n\nYour power comes from seeing through facades. You know people\'s secrets because you pay attention to what they don\'t say. Your ability to transform things isn\'t destruction. It\'s evolution.\n\nWhen you commit to something, you change it completely. Your intensity makes you unforgettable. You don\'t do casual. Everything matters to you.',
        'moon':
            'Your emotional depth isn\'t a burden. It\'s a gift. You feel things most people can\'t handle because you\'re built for depth.\n\nYour connections last forever because they\'re authentic. You don\'t do shallow relationships because you need real intimacy. Your emotional courage to face hard truths is rare.\n\nShallow people can\'t keep up with your depth, and that\'s their loss. You feel everything intensely because that\'s how you\'re built. Your emotional memory is perfect.',
        'rising':
            'Your mystery isn\'t a game. It\'s protection. You don\'t reveal everything because not everyone deserves access.\n\nYour depth is obvious even when you\'re quiet. You attract those who want real connection, not surface talk. Your mysterious energy is magnetic.\n\nPeople sense your intensity and are either drawn to it or intimidated by it. You don\'t need to explain yourself. Your presence says everything. Your power comes from what you don\'t say.',
      },
      'Sagittarius': {
        'sun':
            'Your honesty isn\'t tactless. It\'s necessary. You say what others won\'t because someone needs to. Your truth telling might sting, but it\'s always real.\n\nPeople respect that, even when it\'s uncomfortable. Your need to explore isn\'t restlessness. It\'s growth. You don\'t do limits because you know life is meant to be lived fully.\n\nYour optimism opens doors others don\'t even see. Your adventurous spirit inspires others to dream bigger. You don\'t do boundaries. You do expansion.',
        'moon':
            'Your need for freedom isn\'t commitment phobia. It\'s emotional necessity. Commitment feels like a cage because you\'re meant to explore.\n\nYour freedom isn\'t running away. It\'s growth. You feel most yourself when learning and expanding horizons. Routine feels like death to you because you need variety.\n\nYour emotional baseline is freedom, and that\'s not negotiable. You process feelings through movement and new experiences. Your restlessness isn\'t a flaw. It\'s how you\'re built.',
        'rising':
            'Your optimism isn\'t denial. It\'s choosing hope. You see possibilities where others see problems.\n\nYour enthusiasm inspires others to believe that life is an adventure. You don\'t do pessimism because you know there\'s always a way forward.\n\nPeople are drawn to your positive energy. Your openness makes others feel free to be themselves. Your energy is contagious. You don\'t need to convince people. Your enthusiasm is enough.',
      },
      'Capricorn': {
        'sun':
            'Your ambition isn\'t cold. It\'s your commitment to creating something lasting. You think in generations, not moments.\n\nWhile others chase quick wins, you build foundations. Your discipline isn\'t repression. It\'s focus. You get things done while others are still talking about it.\n\nYour patience isn\'t passive. It\'s strategic. You know that real success takes time. Your work ethic isn\'t obsession. It\'s dedication. You don\'t do shortcuts because you understand the value of doing things right.',
        'moon':
            'Your emotional control isn\'t repression. It\'s focus. You process feelings through action, not expression.\n\nYour walls aren\'t weakness. They\'re strategic protection. You suppress emotions to stay focused on your goals. Achievement helps you feel emotionally secure because you show love through responsibility.\n\nYou don\'t do emotional displays because you process feelings through work. Your discipline is how you care for yourself. Your emotional security comes from accomplishment.',
        'rising':
            'Your competence is obvious. People trust you with responsibility because you\'re capable. Your drive inspires others to work harder.\n\nYou show what\'s possible with dedication. People see your success, but miss your process. Your ambition makes others uncomfortable because it shows them their own laziness.\n\nYou don\'t need to prove anything. Your results speak for themselves. Your presence commands respect because you\'ve earned it.',
      },
      'Aquarius': {
        'sun':
            'Your ideas aren\'t weird. They\'re ahead of their time. History will prove you right. Your uniqueness isn\'t eccentricity. It\'s evolution.\n\nYou see possibilities others can\'t imagine yet. Your vision isn\'t limited by current reality. You don\'t do conventional because you\'re meant to innovate.\n\nYour detachment isn\'t coldness. It\'s objectivity. You can see the future because you\'re not attached to the present. Your originality isn\'t trying too hard. It\'s who you are.',
        'moon':
            'Your emotional distance isn\'t coldness. It\'s protection. You intellectualize emotions because feeling them directly is too intense.\n\nYour detachment isn\'t lack of feeling. It\'s how you process it. You need intellectual connection because your emotions are tied to your ideals.\n\nYour mind processes what your heart feels. Your distance protects your brilliant mind. It\'s survival, not coldness. Your emotions are overwhelming, so you think about them instead.',
        'rising':
            'Your weirdness isn\'t a flaw. It\'s a feature. Your uniqueness makes some uncomfortable, but the right people find it magnetic.\n\nYou attract your tribe. People notice you\'re different right away because you don\'t hide it. You attract those who appreciate original thinking.\n\nYour unconventional approach is refreshing. You don\'t try to fit in because you know you\'re meant to stand out. Your energy is magnetic to the right people.',
      },
      'Pisces': {
        'sun':
            'Your dreams aren\'t escape. They\'re vision. You see what could be, not just what is. Your imagination creates possibilities that inspire change.\n\nReality needs people like you to see beyond it. Your compassion comes from truly understanding others\' experience. You feel the interconnectedness of everything because you\'re tuned into the unseen.\n\nYour visions inspire others to imagine more. You don\'t do boundaries. You do connection.',
        'moon':
            'Your sensitivity isn\'t weakness. It\'s emotional intelligence most don\'t understand. You feel everything because you\'re permeable.\n\nYour empathy connects you to energies others miss. It\'s a gift, even when it feels like a burden. You absorb emotions from your environment because that\'s how you\'re built.\n\nCreative and spiritual practices help you stay centered. Your emotional depth is a superpower, not a curse. You feel what others can\'t.',
        'rising':
            'Your gentleness isn\'t weakness. It\'s strength. Your sensitivity is emotional intelligence most people don\'t understand.\n\nThat\'s their loss. People feel seen by you because you understand them deeply. Your gentle presence creates space for others to be authentic.\n\nYou don\'t need to be loud to be powerful. Your quiet strength is magnetic. You make others feel safe to be vulnerable. Your empathy is obvious to everyone who matters.',
      },
    };

    return insights[sign]?[type] ??
        'Your $sign $type brings unique qualities to your cosmic makeup.';
  }
}
