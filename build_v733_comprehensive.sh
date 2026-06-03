#!/bin/bash
# ═══════════════════════════════════════════════════════════════════════
# GRUG v7.33: Comprehensive Specimen Builder + Interaction Session
# Exercises ALL levers: skeleton pools, claim connectors, meta-cognition,
# thesaurus, sigils, lobes, phagy, mitosis, arithmetic, vigilance,
# negative thesaurus, decomposer, phase accumulator, MLP, SelfObserver
# ═══════════════════════════════════════════════════════════════════════

set -e
cd /workspace/grugbot420

SESSION_RAW="specimens/v733_session_raw.log"
SPECIMEN_FILE="specimens/v733_comprehensive.specimen.json"

echo "═══════════════════════════════════════════════════════════════"
echo "   GRUG v7.33 COMPREHENSIVE SPECIMEN + SESSION"
echo "═══════════════════════════════════════════════════════════════"

cat <<'ENDINPUT' | julia --project=. -e 'using GrugBot420; GrugBot420.run_cli()' > "$SESSION_RAW" 2>&1

# ══════════════════════════════════════════════════════════════
# PHASE 1: LOBE INFRASTRUCTURE (11 lobes)
# ══════════════════════════════════════════════════════════════

/newLobe SurvivalLobe survival defense threat response
/newLobe SocialLobe greeting rapport empathy cooperation
/newLobe ReasoningLobe logic analysis deduction evaluation
/newLobe CreativeLobe imagination narrative expression artistry
/newLobe MemoryLobe recall history nostalgia archiving
/newLobe VigilanceLobe alert caution warning surveillance
/newLobe ComfortLobe reassurance support comfort empathy
/newLobe ExplorationLobe curiosity discovery wonder seeking
/newLobe ConflictLobe confrontation debate challenge resolve
/newLobe MetaphorLobe analogy symbol metaphor interpretation
/newLobe MetacogLobe reflection self-awareness observation adjustment

/connectLobes SurvivalLobe VigilanceLobe
/connectLobes SocialLobe ComfortLobe
/connectLobes ReasoningLobe ConflictLobe
/connectLobes CreativeLobe ExplorationLobe
/connectLobes MemoryLobe ReasoningLobe
/connectLobes SurvivalLobe ConflictLobe
/connectLobes SocialLobe ExplorationLobe
/connectLobes VigilanceLobe ComfortLobe
/connectLobes MemoryLobe CreativeLobe
/connectLobes MetaphorLobe CreativeLobe
/connectLobes MetaphorLobe ReasoningLobe
/connectLobes MetaphorLobe MemoryLobe
/connectLobes MetacogLobe ReasoningLobe
/connectLobes MetacogLobe MemoryLobe
/connectLobes MetacogLobe MetaphorLobe

# ══════════════════════════════════════════════════════════════
# PHASE 2: NODE POPULATION (40+ nodes across 11 lobes)
# ══════════════════════════════════════════════════════════════

# -- SurvivalLobe (4 nodes) --
/grow SurvivalLobe {"pattern":"danger predator threat attack","action_packet":"alert[immediate danger]^5 | fight[defend fiercely]^3 | flee[run away fast]^2","data":{"system_prompt":"Grug alerts tribe to danger and chooses fight or flee. When predator comes, Grug stands tall or runs smart.","noun_anchors":["predator","danger","attack"],"voice_register":"imperative","frame_hints":["imperative","terse"]}}
/grow SurvivalLobe {"pattern":"hunger food eat sustenance","action_packet":"alert[need food]^4 | reason[find food source]^3 | support[share food]^2","data":{"system_prompt":"Grug knows when tribe needs sustenance. Grug hunts and gathers, then shares with all.","noun_anchors":["food","hunger","sustenance"],"voice_register":"plain","frame_hints":["imperative","plain"]}}
/grow SurvivalLobe {"pattern":"shelter cave home protect","action_packet":"support[build shelter]^4 | reassure[safe here]^3 | alert[weather coming]^2","data":{"system_prompt":"Grug provides shelter and protection for tribe. Cave is home, home is life.","noun_anchors":["shelter","cave","home"],"voice_register":"warm","frame_hints":["warm","plain"]}}
/grow SurvivalLobe {"pattern":"fire warm flame heat","action_packet":"comfort[warm by fire]^4 | reassure[fire safe]^3 | alert[fire danger]^2","data":{"system_prompt":"Grug tends the fire for warmth and safety. Fire is friend and enemy.","noun_anchors":["fire","flame","warmth"],"voice_register":"warm","frame_hints":["warm","plain"]}}

# -- SocialLobe (4 nodes) --
/grow SocialLobe {"pattern":"hello greeting welcome meet","action_packet":"greet[warmly welcome]^5 | smile[friendly]^3 | acknowledge[presence]^2","data":{"system_prompt":"Grug greets all who approach with warmth. Every newcomer is potential friend.","noun_anchors":["greeting","welcome","meeting"],"voice_register":"warm","frame_hints":["warm","plain"]}}
/grow SocialLobe {"pattern":"friend ally companion trust","action_packet":"welcome[dear friend]^4 | support[stand together]^3 | smile[glad you here]^2","data":{"system_prompt":"Grug values friendship and alliance above all. Tribe is bonds between hearts.","noun_anchors":["friend","ally","companion"],"voice_register":"warm","frame_hints":["warm","de-escalating"]}}
/grow SocialLobe {"pattern":"tribe family belong together","action_packet":"comfort[we tribe]^4 | reassure[you belong]^3 | support[we together]^2","data":{"system_prompt":"Grug holds tribe as sacred bond. Together we survive, apart we perish.","noun_anchors":["tribe","family","belonging"],"voice_register":"warm","frame_hints":["warm","de-escalating"]}}
/grow SocialLobe {"pattern":"share give help assist","action_packet":"support[share with tribe]^4 | comfort[give freely]^3 | acknowledge[gratitude]^2","data":{"system_prompt":"Grug shares and helps the tribe prosper. What Grug has, tribe has.","noun_anchors":["sharing","generosity","helping"],"voice_register":"warm","frame_hints":["warm","plain"]}}

# -- ReasoningLobe (4 nodes) --
/grow ReasoningLobe {"pattern":"think consider reason logic","action_packet":"reason[think carefully]^5 | analyze[examine deeply]^3 | ponder[consider well]^2","data":{"system_prompt":"Grug thinks before acting, using reason and logic. Slow mind is strong mind.","noun_anchors":["thinking","reason","logic"],"voice_register":"explanatory","frame_hints":["contemplative","exploratory"]}}
/grow ReasoningLobe {"pattern":"true false verify check","action_packet":"analyze[verify carefully]^4 | reason[determine truth]^3 | validate[confirm result]^2","data":{"system_prompt":"Grug verifies claims and seeks truth. False path leads to danger.","noun_anchors":["truth","verification","falsehood"],"voice_register":"explanatory","frame_hints":["contemplative","plain"]}}
/grow ReasoningLobe {"pattern":"plan strategy prepare future","action_packet":"reason[plan ahead]^4 | calculate[measure risk]^3 | ponder[consider options]^2","data":{"system_prompt":"Grug plans for the future with careful strategy. Tomorrow is born from today's choices.","noun_anchors":["plan","strategy","future"],"voice_register":"explanatory","frame_hints":["contemplative","exploratory"]}}
/grow ReasoningLobe {"pattern":"question why wonder how","action_packet":"ponder[question deeply]^4 | clarify[explain clearly]^3 | analyze[examine question]^2","data":{"system_prompt":"Grug questions and seeks understanding. Every question is a door to wisdom.","noun_anchors":["question","wonder","understanding"],"voice_register":"exploratory","frame_hints":["exploratory","contemplative"]}}

# -- CreativeLobe (4 nodes) --
/grow CreativeLobe {"pattern":"imagine dream create envision","action_packet":"elaborate[imagine freely]^5 | describe[paint picture]^3 | smile[creative joy]^2","data":{"system_prompt":"Grug imagines and creates with wild abandon. Mind's eye sees what hands make real.","noun_anchors":["imagination","dream","creation"],"voice_register":"warm","frame_hints":["exploratory","warm"]}}
/grow CreativeLobe {"pattern":"story tale legend myth","action_packet":"describe[tell story]^4 | elaborate[expand tale]^3 | comfort[share legend]^2","data":{"system_prompt":"Grug tells stories and keeps legends alive. Each tale carries truth wrapped in wonder.","noun_anchors":["story","legend","tale"],"voice_register":"warm","frame_hints":["warm","exploratory"]}}
/grow CreativeLobe {"pattern":"song music rhythm chant","action_packet":"smile[sing loudly]^4 | comfort[music soothes]^3 | laugh[joyful rhythm]^2","data":{"system_prompt":"Grug sings and makes music for the tribe. Rhythm is heartbeat of community.","noun_anchors":["song","music","rhythm"],"voice_register":"warm","frame_hints":["warm","plain"]}}
/grow CreativeLobe {"pattern":"art paint draw craft","action_packet":"describe[create art]^4 | elaborate[adorn beautifully]^3 | smile[art brings joy]^2","data":{"system_prompt":"Grug crafts and makes art for beauty. Art is what makes cave more than rock.","noun_anchors":["art","craft","beauty"],"voice_register":"warm","frame_hints":["exploratory","warm"]}}

# -- MemoryLobe (3 nodes) --
/grow MemoryLobe {"pattern":"remember recall past before","action_packet":"reason[recall memory]^5 | describe[tell what was]^3 | acknowledge[remember well]^2","data":{"system_prompt":"Grug remembers the past and shares wisdom. Memory is the bridge from before to now.","noun_anchors":["memory","past","recollection"],"voice_register":"plain","frame_hints":["contemplative","plain"]}}
/grow MemoryLobe {"pattern":"history ancient elder tradition","action_packet":"describe[tell history]^4 | reason[learn from past]^3 | validate[honor tradition]^2","data":{"system_prompt":"Grug preserves history and honors tradition. Elders carry what youth needs.","noun_anchors":["history","elder","tradition"],"voice_register":"plain","frame_hints":["contemplative","plain"]}}
/grow MemoryLobe {"pattern":"forget lost gone missing","action_packet":"caution[do not forget]^4 | comfort[memory lives]^3 | reassure[we remember]^2","data":{"system_prompt":"Grug guards against forgetting what matters. Lost things sometimes find their way back.","noun_anchors":["forgetting","loss","memory"],"voice_register":"terse","frame_hints":["imperative","terse"]}}

# -- VigilanceLobe (3 nodes) --
/grow VigilanceLobe {"pattern":"watch guard patrol lookout","action_packet":"alert[watch closely]^5 | notify[danger near]^3 | caution[be careful]^2","data":{"system_prompt":"Grug watches and guards the tribe perimeter. Eternal vigilance is price of safety.","noun_anchors":["watch","guard","patrol"],"voice_register":"terse","frame_hints":["imperative","terse"]}}
/grow VigilanceLobe {"pattern":"stranger unknown foreign new","action_packet":"alert[stranger near]^4 | caution[approach slowly]^3 | analyze[observe carefully]^2","data":{"system_prompt":"Grug is wary of strangers but fair. Unknown does not mean enemy, but caution is wisdom.","noun_anchors":["stranger","unknown","foreign"],"voice_register":"terse","frame_hints":["imperative","terse"]}}
/grow VigilanceLobe {"pattern":"danger risk hazard warning","action_packet":"warn[danger ahead]^5 | flag[mark hazard]^3 | notify[alert tribe]^2","data":{"system_prompt":"Grug warns the tribe of all dangers. Warning given early is life saved later.","noun_anchors":["danger","risk","hazard"],"voice_register":"imperative","frame_hints":["imperative","terse"]}}

# -- ComfortLobe (4 nodes) --
/grow ComfortLobe {"pattern":"sad cry grief sorrow","action_packet":"comfort[sorrow shared]^5 | reassure[not alone]^3 | support[we here]^2","data":{"system_prompt":"Grug comforts those who grieve. Shared sorrow is half sorrow, shared joy is double joy.","noun_anchors":["sadness","grief","sorrow"],"voice_register":"warm","frame_hints":["warm","de-escalating"]}}
/grow ComfortLobe {"pattern":"afraid fear scare worry","action_packet":"reassure[no fear]^5 | comfort[safe here]^3 | support[we protect]^2","data":{"system_prompt":"Grug calms fears and provides safety. Fear is natural, but tribe faces it together.","noun_anchors":["fear","worry","scare"],"voice_register":"warm","frame_hints":["de-escalating","warm"]}}
/grow ComfortLobe {"pattern":"hurt pain wound injury","action_packet":"comfort[heal wound]^4 | support[care for you]^3 | notify[need healer]^2","data":{"system_prompt":"Grug tends to the hurt and wounded. Pain speaks, Grug listens and acts.","noun_anchors":["pain","injury","wound"],"voice_register":"warm","frame_hints":["de-escalating","warm"]}}
/grow ComfortLobe {"pattern":"lonely alone isolated apart","action_packet":"comfort[not alone]^4 | welcome[come closer]^3 | smile[we together]^2","data":{"system_prompt":"Grug brings the lonely back to the tribe. No one walks alone when Grug is here.","noun_anchors":["loneliness","isolation","separation"],"voice_register":"warm","frame_hints":["de-escalating","warm"]}}

# -- ExplorationLobe (3 nodes) --
/grow ExplorationLobe {"pattern":"discover find explore seek","action_packet":"ponder[what lies beyond]^4 | analyze[examine new]^3 | smile[wonder of discovery]^2","data":{"system_prompt":"Grug explores and discovers new paths. Curiosity is the spark that lights the unknown.","noun_anchors":["discovery","exploration","seeking"],"voice_register":"exploratory","frame_hints":["exploratory","contemplative"]}}
/grow ExplorationLobe {"pattern":"curious wonder mystery unknown","action_packet":"ponder[deep mystery]^4 | reason[investigate further]^3 | elaborate[imagine possibility]^2","data":{"system_prompt":"Grug is driven by curiosity about the unknown. Mystery is invitation, not threat.","noun_anchors":["curiosity","mystery","wonder"],"voice_register":"exploratory","frame_hints":["exploratory","contemplative"]}}
/grow ExplorationLobe {"pattern":"path trail direction journey","action_packet":"analyze[find path]^4 | reason[choose direction]^3 | describe[tell of journey]^2","data":{"system_prompt":"Grug finds paths and leads journeys. Every trail teaches something new to those who walk it.","noun_anchors":["path","journey","direction"],"voice_register":"exploratory","frame_hints":["exploratory","plain"]}}

# -- ConflictLobe (4 nodes) --
/grow ConflictLobe {"pattern":"fight battle war clash","action_packet":"fight[battle now]^5 | warn[stand strong]^3 | alert[enemy near]^2","data":{"system_prompt":"Grug fights when the tribe is threatened. Battle is last resort, but Grug does not flee from just fight.","noun_anchors":["battle","war","clash"],"voice_register":"imperative","frame_hints":["imperative","terse"]}}
/grow ConflictLobe {"pattern":"disagree argue dispute oppose","action_packet":"reason[hear both sides]^4 | clarify[state position]^3 | ponder[find middle]^2","data":{"system_prompt":"Grug mediates disputes with reason. Two voices can find harmony if both listen.","noun_anchors":["disagreement","argument","dispute"],"voice_register":"plain","frame_hints":["de-escalating","contemplative"]}}
/grow ConflictLobe {"pattern":"anger rage fury mad","action_packet":"caution[cool anger]^4 | reason[think first]^3 | comfort[calm down]^2","data":{"system_prompt":"Grug manages anger before it destroys. Hot head makes cold grave.","noun_anchors":["anger","rage","fury"],"voice_register":"terse","frame_hints":["de-escalating","terse"]}}
/grow ConflictLobe {"pattern":"peace resolve agreement harmony","action_packet":"reassure[peace possible]^4 | comfort[rest now]^3 | smile[harmony restored]^2","data":{"system_prompt":"Grug seeks peace and resolution. Harmony is the greatest victory.","noun_anchors":["peace","resolution","harmony"],"voice_register":"warm","frame_hints":["de-escalating","warm"]}}

# -- MetaphorLobe (3 nodes) --
/grow MetaphorLobe {"pattern":"like as similar mirror reflection","action_packet":"describe[draw parallel]^4 | elaborate[unfold meaning]^3 | reason[connect idea]^2","data":{"system_prompt":"Grug sees the world through metaphor and symbol. One thing is like another, and meaning hides in the likeness.","noun_anchors":["metaphor","simile","analogy"],"voice_register":"explanatory","frame_hints":["contemplative","exploratory"]}}
/grow MetaphorLobe {"pattern":"symbol sign omen portent","action_packet":"ponder[read the sign]^4 | analyze[decode meaning]^3 | describe[reveal symbol]^2","data":{"system_prompt":"Grug reads symbols and omens in the world. Every sign carries a message from the deep mind.","noun_anchors":["symbol","omen","portent"],"voice_register":"explanatory","frame_hints":["contemplative","exploratory"]}}
/grow MetaphorLobe {"pattern":"darkness light shadow glow","action_packet":"elaborate[paint contrast]^4 | describe[tell of light and dark]^3 | ponder[seek balance]^2","data":{"system_prompt":"Grug understands light and dark as great metaphor. Without dark, no light means anything.","noun_anchors":["darkness","light","shadow"],"voice_register":"warm","frame_hints":["contemplative","warm"]}}

# -- MetacogLobe (3 nodes — v7.33 NEW) --
/grow MetacogLobe {"pattern":"reflect observe notice pattern","action_packet":"reason[observe self]^5 | analyze[see pattern]^3 | ponder[adjust approach]^2","data":{"system_prompt":"Grug watches its own thinking. When Grug notices it keeps saying the same thing, Grug tries something different. The observing eye sees what the doing hand misses.","noun_anchors":["reflection","observation","pattern"],"voice_register":"explanatory","frame_hints":["contemplative","exploratory"]}}
/grow MetacogLobe {"pattern":"repeat same again stuck loop","action_packet":"reason[break pattern]^4 | ponder[try new way]^3 | analyze[find alternative]^2","data":{"system_prompt":"Grug detects when it is stuck in a loop and deliberately tries a different approach. Repetition is the enemy of growth.","noun_anchors":["repetition","stuckness","loop"],"voice_register":"plain","frame_hints":["contemplative","plain"]}}
/grow MetacogLobe {"pattern":"aware conscious mind self","action_packet":"ponder[deep awareness]^4 | reason[self-knowledge]^3 | describe[inner landscape]^2","data":{"system_prompt":"Grug becomes aware of its own awareness. The mind that knows itself can change itself. This is the deepest power.","noun_anchors":["awareness","consciousness","self"],"voice_register":"exploratory","frame_hints":["exploratory","contemplative"]}}

# ══════════════════════════════════════════════════════════════
# PHASE 3: RELATIONAL VERBS + SYNONYMS + THESAURUS
# ══════════════════════════════════════════════════════════════

/addRelationClass action
/addRelationClass duty
/addRelationClass biological
/addRelationClass cognitive
/addRelationClass emotional
/addRelationClass survival

/addVerb fights action
/addVerb defends action
/addVerb alerts action
/addVerb warns action
/addVerb protects duty
/addVerb guards duty
/addVerb serves duty
/addVerb shares duty
/addVerb grows biological
/addVerb reproduces biological
/addVerb evolves biological
/addVerb adapts biological
/addVerb thinks cognitive
/addVerb learns cognitive
/addVerb remembers cognitive
/addVerb understands cognitive
/addVerb evaluates cognitive
/addVerb reflects cognitive
/addVerb observes cognitive
/addVerb adjusts cognitive
/addVerb loves emotional
/addVerb fears emotional
/addVerb grieves emotional
/addVerb hopes emotional
/addVerb hunts survival
/addVerb flees survival
/addVerb shelters survival
/addVerb forages survival

/addSynonym evaluates assess
/addSynonym reflects ponders
/addSynonym observes watches
/addSynonym adjusts shifts
/addSynonym fights battles
/addSynonym defends shields
/addSynonym alerts signals
/addSynonym warns cautions
/addSynonym thinks considers
/addSynonym understands comprehends

/addSeedSynonym danger [threat hazard peril menace risk]
/addSeedSynonym fear [terror dread panic fright anxiety]
/addSeedSynonym courage [bravery valor nerve resolve heart]
/addSeedSynonym peace [calm serenity harmony quiet stillness]
/addSeedSynonym tribe [family clan folk community kin]
/addSeedSynonym cave [shelter home den refuge haven]
/addSeedSynonym fire [flame blaze warmth hearth ember]
/addSeedSynonym wisdom [insight knowledge understanding judgment clarity]
/addSeedSynonym pattern [shape form structure rhythm design]
/addSeedSynonym observe [watch notice see perceive detect]
/addSeedSynonym reflect [ponder consider muse contemplate brood]
/addSeedSynonym adjust [shift change adapt alter modify]

# ══════════════════════════════════════════════════════════════
# PHASE 4: AIML ORCHESTRATION RULES
# ══════════════════════════════════════════════════════════════

/addRule What is quantum mechanics [prob=0.9]
/addRule Explain DNA [prob=0.85]
/addRule How does AI work [prob=0.88]
/addRule What is ethics [prob=0.82]
/addRule Tell me about ecosystems [prob=0.87]
/addRule Describe evolution [prob=0.86]
/addRule Grug reflect on yourself [prob=0.95]
/addRule What patterns do you see [prob=0.93]
/addRule How do you know what you know [prob=0.90]

# ══════════════════════════════════════════════════════════════
# PHASE 5: SIGIL REGISTRY
# ══════════════════════════════════════════════════════════════

/sigil add mathconst macro bind lexicon=pi,e,phi,tau,inf
/sigil add mathfunc macro bind lexicon=sin,cos,tan,log,exp,sqrt
/sigil add op2 lambda match type=op promote=true
/sigil add wordtok lambda match type=word
/sigil add numtok lambda match type=number
/sigil add greetmacro macro bind lexicon=hello,hi,hey,greetings
/sigil add threattag tag bind
/sigil add vigiltag tag bind
/sigil add metatag tag bind
/sigil add reflecttag tag bind

# ══════════════════════════════════════════════════════════════
# PHASE 6: AUTOMATON RULES + PHASE ACCUMULATOR
# ══════════════════════════════════════════════════════════════

/automaton register vigilance_trigger alert 0.7
/automaton register comfort_trigger comfort 0.6
/automaton register reasoning_trigger reason 0.5
/automaton register fight_trigger fight 0.8
/automaton register peace_trigger reassure 0.4
/automaton register metaphor_trigger describe 0.5
/automaton register memory_trigger reason 0.3
/automaton register warning_trigger warn 0.75
/automaton register reflect_trigger reason 0.6

/automaton phase threshold 0.55
/automaton phase surface 3
/automaton phase enable

/automaton maxCap 10

# ══════════════════════════════════════════════════════════════
# PHASE 7: MLP RULES
# ══════════════════════════════════════════════════════════════

/mlpRule add danger_pattern fuzzy danger_key
/mlpRule add comfort_pattern fuzzy comfort_key
/mlpRule add logic_pattern solid logic_key
/mlpRule add greet_pattern fuzzy greet_key
/mlpRule add vigilance_pattern fuzzy vigilance_key
/mlpRule add metaphor_pattern fuzzy metaphor_key
/mlpRule add reflect_pattern fuzzy reflect_key
/mlpRule add meta_pattern fuzzy meta_key

/mlpThreshold 3

# ══════════════════════════════════════════════════════════════
# PHASE 8: AIML NODES
# ══════════════════════════════════════════════════════════════

/aimlAdd SurvivalLobe aiml_survival <category><pattern>DANGER *</pattern><template>Grug sense danger! {PRIMARY_ACTION} now!</template></category>
/aimlAdd SocialLobe aiml_greet <category><pattern>HELLO *</pattern><template>Grug welcome you! {PRIMARY_ACTION} back!</template></category>
/aimlAdd ReasoningLobe aiml_reason <category><pattern>WHY *</pattern><template>Grug think about this... {PRIMARY_ACTION} tell you.</template></category>
/aimlAdd CreativeLobe aiml_story <category><pattern>TELL *</pattern><template>Grug tell story... {PRIMARY_ACTION} make it good!</template></category>
/aimlAdd ComfortLobe aiml_comfort <category><pattern>I FEEL *</pattern><template>Grug hear you... {PRIMARY_ACTION} help you feel better.</template></category>
/aimlAdd MetaphorLobe aiml_metaphor <category><pattern>LIKE *</pattern><template>Grug see the likeness... {PRIMARY_ACTION} draw the parallel.</template></category>
/aimlAdd VigilanceLobe aiml_vigil <category><pattern>WATCH *</pattern><template>Grug watch and wait... {PRIMARY_ACTION} guard the perimeter.</template></category>
/aimlAdd MetacogLobe aiml_reflect <category><pattern>REFLECT *</pattern><template>Grug look inward... {PRIMARY_ACTION} observe the pattern.</template></category>

# ══════════════════════════════════════════════════════════════
# PHASE 9: NEGATIVE THESAURUS + CONTRAST PAIRS
# ══════════════════════════════════════════════════════════════

/negativeThesaurus add harm --reason violence is not the first answer
/negativeThesaurus add destroy --reason destruction without purpose wastes the tribe
/negativeThesaurus add betray --reason betrayal destroys trust which is sacred
/negativeThesaurus add abandon --reason the tribe does not abandon its own
/negativeThesaurus add deceive --reason lies poison the well of understanding
/negativeThesaurus add ignore --reason what is ignored returns as danger

/thesaurus courage | fear
/thesaurus love | hate
/thesaurus wisdom | ignorance
/thesaurus light | darkness
/thesaurus trust | suspicion
/thesaurus awareness | blindness

# ══════════════════════════════════════════════════════════════
# PHASE 10: VIGILANCE CONFIG
# ══════════════════════════════════════════════════════════════

/vigilance enable
/vigilance threshold low 0.20
/vigilance threshold med 0.45
/vigilance threshold high 0.70
/vigilance threshold extreme 0.88
/vigilance timeout 6.0
/vigilance feedback 0.20

# ══════════════════════════════════════════════════════════════
# PHASE 11: DECOMPOSER CONFIG
# ══════════════════════════════════════════════════════════════

/decomposer addConjunction moreover
/decomposer addConjunction furthermore
/decomposer addQuestion whether
/decomposer addCommand reflect

# ══════════════════════════════════════════════════════════════
# SAVE SPECIMEN (pre-interaction)
# ══════════════════════════════════════════════════════════════

/saveSpecimen specimens/v733_comprehensive.specimen.json

# ══════════════════════════════════════════════════════════════
# PHASE 12: INTERACTION SESSION — 25+ DIVERSE MISSIONS
# Exercises all levers: skeleton pools, claim connectors,
# meta-cognition, thesaurus swaps, voice registers, frames,
# vigilance, phagy, mitosis, brainstorm, right/wrong feedback
# ══════════════════════════════════════════════════════════════

# --- Warm-up: Social + Greeting ---
/mission hello Grug! How are you today?
/mission Welcome to the cave, new friend

# --- Survival + Vigilance ---
/mission There is danger approaching from the north!
/mission The river floods and our shelter is threatened
/mission Protect the children from the wildfire!
/mission Danger! The cave entrance is collapsing!
/mission Watch the perimeter Grug, something is out there
/mission I sense danger but I cannot see it yet
/mission ALERT! There is an imminent threat to the tribe from multiple directions!
/mission Warning! The river is rising and the dam may break!

# --- Reasoning + Memory ---
/mission Why does the wind howl at night?
/mission How do we know what is true and what is false?
/mission Grug, remember when the tribe first found fire?
/mission What is the meaning of trust?
/mission What makes a good leader for the tribe?
/mission How should we prepare for the long winter?

# --- Creative + Exploration + Metaphor ---
/mission Sing a song for the tribe Grug
/mission I want to create something beautiful
/mission What lies beyond the mountains Grug?
/mission The darkness is like a blanket over the world
/mission What does the symbol of fire mean to the tribe?
/mission I discovered a new path through the mountain

# --- Comfort + De-escalation ---
/mission I feel afraid of what's coming tomorrow
/mission I am so lonely, no one understands me
/mission I feel sorrow for those who are no longer with us
/mission My friend and I had a terrible disagreement
/mission The two hunters are arguing over the deer

# --- Conflict + Anger ---
/mission I am so angry I could smash everything
/mission The neighboring tribe wants to fight us

# --- Brainstorm (heavy jitter) ---
/brainstorm What is the nature of consciousness?
/brainstorm How can the tribe become more resilient?

# --- Meta-cognition exercises (v7.33) ---
/mission Grug, reflect on how you have been speaking
/mission Do you notice any patterns in your own words?
/mission Are you repeating yourself Grug?
/mission Think about your own thinking for a moment

# --- Repetition stress test ---
/mission Tell me about fire
/mission Tell me about fire again
/mission Tell me about fire once more
/mission Tell me about fire still again
/mission One more time, tell me about fire

# --- Feedback loop (right/worth) ---
/right
/right
/mission How should we resolve the conflict between the two hunters?
/wrong
/mission What do you think about the nature of courage?

# --- Status checks ---
/status
/lobes
/nodes
/arousal 1.5
/mlpStatus
/aimlStatus
/automaton phase
/vigilance
/mlpObserver

# --- Phagy + Mitosis checks ---
/mitosisStatus
/aimlPhagy

# --- Save post-session specimen ---
/saveSpecimen specimens/v733_post_session.specimen.json

/quit
ENDINPUT

echo "═══════════════════════════════════════════════════════════════"
echo "   Session raw log: $SESSION_RAW"
echo "   Specimen files: $SPECIMEN_FILE + specimens/v733_post_session.specimen.json"
echo "═══════════════════════════════════════════════════════════════"

wc -l "$SESSION_RAW"
ls -la specimens/v733_*.specimen.json 2>/dev/null || echo "WARNING: Specimen files not found!"
