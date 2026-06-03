#!/bin/bash
# Comprehensive GrugBot420 Specimen Builder v3
# Uses ONLY valid COMMANDS actions and correct CLI syntaxes
# Valid single-word actions: acknowledge alert analyze calculate caution clarify
#   comfort define describe elaborate explain fight flag flee greet hide laugh
#   notify ponder reason reassure smile support validate warn welcome
# Multi-word prose (>=2 words, >=8 chars) auto-registers as passthrough

set -e

cd /workspace/grugbot420

SPECIMEN_FILE="specimens/analog_turing_v3.specimen.json"

echo "=== Building Comprehensive GrugBot420 Specimen v3 ==="

# We pipe all commands into the CLI at once
# CRITICAL: No # comments (CLI treats them as invalid commands)
# Empty lines are OK (they're skipped)

cat <<'ENDINPUT' | julia --project=. -e 'using GrugBot420; GrugBot420.run_cli()'

/newLobe SurvivalLobe survival-defense-threat-response
/newLobe SocialLobe greeting-rapport-empathy-cooperation
/newLobe ReasoningLobe logic-analysis-deduction-evaluation
/newLobe CreativeLobe imagination-narrative-expression-artistry
/newLobe MemoryLobe recall-history-nostalgia-archiving
/newLobe VigilanceLobe alert-caution-warning-surveillance
/newLobe ComfortLobe reassurance-support-comfort-empathy
/newLobe ExplorationLobe curiosity-discovery-wonder-seeking
/newLobe ConflictLobe confrontation-debate-challenge-resolve

/connectLobes SurvivalLobe VigilanceLobe
/connectLobes SocialLobe ComfortLobe
/connectLobes ReasoningLobe ConflictLobe
/connectLobes CreativeLobe ExplorationLobe
/connectLobes MemoryLobe ReasoningLobe
/connectLobes SurvivalLobe ConflictLobe
/connectLobes SocialLobe ExplorationLobe
/connectLobes VigilanceLobe ComfortLobe
/connectLobes MemoryLobe CreativeLobe

/grow SurvivalLobe {"pattern":"danger predator threat attack","action_packet":"alert[immediate danger]^5 | fight[defend fiercely]^3 | flee[run away fast]^2","data":{"system_prompt":"Grug alerts tribe to danger and chooses fight or flee."}}
/grow SurvivalLobe {"pattern":"hunger food eat sustenance","action_packet":"alert[need food]^4 | reason[find food source]^3 | support[share food]^2","data":{"system_prompt":"Grug knows when tribe needs sustenance."}}
/grow SurvivalLobe {"pattern":"shelter cave home protect","action_packet":"support[build shelter]^4 | reassure[safe here]^3 | alert[weather coming]^2","data":{"system_prompt":"Grug provides shelter and protection for tribe."}}
/grow SurvivalLobe {"pattern":"fire warm flame heat","action_packet":"comfort[warm by fire]^4 | reassure[fire safe]^3 | alert[fire danger]^2","data":{"system_prompt":"Grug tends the fire for warmth and safety."}}

/grow SocialLobe {"pattern":"hello greeting welcome meet","action_packet":"greet[warmly welcome]^5 | smile[friendly]^3 | acknowledge[presence]^2","data":{"system_prompt":"Grug greets all who approach with warmth."}}
/grow SocialLobe {"pattern":"friend ally companion trust","action_packet":"welcome[dear friend]^4 | support[stand together]^3 | smile[glad you here]^2","data":{"system_prompt":"Grug values friendship and alliance above all."}}
/grow SocialLobe {"pattern":"tribe family belong together","action_packet":"comfort[we tribe]^4 | reassure[you belong]^3 | support[we together]^2","data":{"system_prompt":"Grug holds tribe as sacred bond."}}
/grow SocialLobe {"pattern":"share give help assist","action_packet":"support[share with tribe]^4 | comfort[give freely]^3 | acknowledge[gratitude]^2","data":{"system_prompt":"Grug shares and helps the tribe prosper."}}

/grow ReasoningLobe {"pattern":"think consider reason logic","action_packet":"reason[think carefully]^5 | analyze[examine deeply]^3 | ponder[consider well]^2","data":{"system_prompt":"Grug thinks before acting, using reason and logic."}}
/grow ReasoningLobe {"pattern":"true false verify check","action_packet":"analyze[verify carefully]^4 | reason[determine truth]^3 | validate[confirm result]^2","data":{"system_prompt":"Grug verifies claims and seeks truth."}}
/grow ReasoningLobe {"pattern":"plan strategy prepare future","action_packet":"reason[plan ahead]^4 | calculate[measure risk]^3 | ponder[consider options]^2","data":{"system_prompt":"Grug plans for the future with careful strategy."}}
/grow ReasoningLobe {"pattern":"question why wonder how","action_packet":"ponder[question deeply]^4 | clarify[explain clearly]^3 | analyze[examine question]^2","data":{"system_prompt":"Grug questions and seeks understanding."}}

/grow CreativeLobe {"pattern":"imagine dream create envision","action_packet":"elaborate[imagine freely]^5 | describe[paint picture]^3 | smile[creative joy]^2","data":{"system_prompt":"Grug imagines and creates with wild abandon."}}
/grow CreativeLobe {"pattern":"story tale legend myth","action_packet":"describe[tell story]^4 | elaborate[expand tale]^3 | comfort[share legend]^2","data":{"system_prompt":"Grug tells stories and keeps legends alive."}}
/grow CreativeLobe {"pattern":"song music rhythm chant","action_packet":"smile[sing loudly]^4 | comfort[music soothes]^3 | laugh[joyful rhythm]^2","data":{"system_prompt":"Grug sings and makes music for the tribe."}}
/grow CreativeLobe {"pattern":"art paint draw craft","action_packet":"describe[create art]^4 | elaborate[adorn beautifully]^3 | smile[art brings joy]^2","data":{"system_prompt":"Grug crafts and makes art for beauty."}}

/grow MemoryLobe {"pattern":"remember recall past before","action_packet":"reason[recall memory]^5 | describe[tell what was]^3 | acknowledge[remember well]^2","data":{"system_prompt":"Grug remembers the past and shares wisdom."}}
/grow MemoryLobe {"pattern":"history ancient elder tradition","action_packet":"describe[tell history]^4 | reason[learn from past]^3 | validate[honor tradition]^2","data":{"system_prompt":"Grug preserves history and honors tradition."}}
/grow MemoryLobe {"pattern":"forget lost gone missing","action_packet":"caution[do not forget]^4 | comfort[memory lives]^3 | reassure[we remember]^2","data":{"system_prompt":"Grug guards against forgetting what matters."}}

/grow VigilanceLobe {"pattern":"watch guard patrol lookout","action_packet":"alert[watch closely]^5 | notify[danger near]^3 | caution[be careful]^2","data":{"system_prompt":"Grug watches and guards the tribe perimeter."}}
/grow VigilanceLobe {"pattern":"stranger unknown foreign new","action_packet":"alert[stranger near]^4 | caution[approach slowly]^3 | analyze[observe carefully]^2","data":{"system_prompt":"Grug is wary of strangers but fair."}}
/grow VigilanceLobe {"pattern":"danger risk hazard warning","action_packet":"warn[danger ahead]^5 | flag[mark hazard]^3 | notify[alert tribe]^2","data":{"system_prompt":"Grug warns the tribe of all dangers."}}

/grow ComfortLobe {"pattern":"sad cry grief sorrow","action_packet":"comfort[sorrow shared]^5 | reassure[not alone]^3 | support[we here]^2","data":{"system_prompt":"Grug comforts those who grieve."}}
/grow ComfortLobe {"pattern":"afraid fear scare worry","action_packet":"reassure[no fear]^5 | comfort[safe here]^3 | support[we protect]^2","data":{"system_prompt":"Grug calms fears and provides safety."}}
/grow ComfortLobe {"pattern":"hurt pain wound injury","action_packet":"comfort[heal wound]^4 | support[care for you]^3 | notify[need healer]^2","data":{"system_prompt":"Grug tends to the hurt and wounded."}}
/grow ComfortLobe {"pattern":"lonely alone isolated apart","action_packet":"comfort[not alone]^4 | welcome[come closer]^3 | smile[we together]^2","data":{"system_prompt":"Grug brings the lonely back to the tribe."}}

/grow ExplorationLobe {"pattern":"discover find explore seek","action_packet":"ponder[what lies beyond]^4 | analyze[examine new]^3 | smile[wonder of discovery]^2","data":{"system_prompt":"Grug explores and discovers new paths."}}
/grow ExplorationLobe {"pattern":"curious wonder mystery unknown","action_packet":"ponder[deep mystery]^4 | reason[investigate further]^3 | elaborate[imagine possibility]^2","data":{"system_prompt":"Grug is driven by curiosity about the unknown."}}
/grow ExplorationLobe {"pattern":"path trail direction journey","action_packet":"analyze[find path]^4 | reason[choose direction]^3 | describe[tell of journey]^2","data":{"system_prompt":"Grug finds paths and leads journeys."}}

/grow ConflictLobe {"pattern":"fight battle war clash","action_packet":"fight[battle now]^5 | warn[stand strong]^3 | alert[enemy near]^2","data":{"system_prompt":"Grug fights when the tribe is threatened."}}
/grow ConflictLobe {"pattern":"disagree argue dispute oppose","action_packet":"reason[hear both sides]^4 | clarify[state position]^3 | ponder[find middle]^2","data":{"system_prompt":"Grug mediates disputes with reason."}}
/grow ConflictLobe {"pattern":"anger rage fury mad","action_packet":"caution[cool anger]^4 | reason[think first]^3 | comfort[calm down]^2","data":{"system_prompt":"Grug manages anger before it destroys."}}
/grow ConflictLobe {"pattern":"peace resolve agreement harmony","action_packet":"reassure[peace possible]^4 | comfort[rest now]^3 | smile[harmony restored]^2","data":{"system_prompt":"Grug seeks peace and resolution."}}

/addVerb hunts action
/addVerb gathers action
/addVerb protects duty
/addVerb guards duty
/addVerb teaches sharing
/addVerb shares sharing
/addVerb questions inquiry
/addVerb investigates inquiry
/addVerb creates expression
/addVerb sings expression
/addVerb remembers preservation
/addVerb preserves preservation
/addVerb connects relation
/addVerb binds relation
/addVerb challenges growth
/addVerb overcomes growth

/addRelationClass emotion
/addRelationClass perception
/addRelationClass action_class
/addRelationClass state

/addSynonym greet welcome
/addSynonym danger threat
/addSynonym friend ally
/addSynonym sad sorrow
/addSynonym think ponder
/addSynonym find discover
/addSynonym fear worry
/addSynonym fight battle
/addSynonym remember recall
/addSynonym help support
/addSynonym home shelter
/addSynonym explain clarify
/addSynonym happy glad

/pin Grug is the spirit of the cave mind. Grug speaks plainly. Grug protects tribe. Grug remembers all.

/arousal 0.6

/addRule when {PRIMARY_ACTION} is alert then reinforce {NODE_ID} strongly
/addRule when {PRIMARY_ACTION} is comfort then strengthen {LOBE_CONTEXT} bonds
/addRule when {CONFIDENCE} drops below 0.3 then activate VigilanceLobe
/addRule when {MISSION} contains remember then activate MemoryLobe
/addRule when {MISSION} contains danger then activate SurvivalLobe
/addRule when {MISSION} contains create then activate CreativeLobe

/decomposer addConjunction moreover
/decomposer addConjunction furthermore
/decomposer addConjunction nonetheless
/decomposer addConjunction thereby
/decomposer addCompound thunderstorm thunder storm
/decomposer addCompound wildfire wild fire
/decomposer addCompound overthink over think
/decomposer addQuestion ¿
/decomposer addCommand hey
/decomposer addCommand grug
/decomposer addConjugation run ran running
/decomposer addConjugation think thought thinking
/decomposer addConjugation fight fought fighting
/decomposer addConjugation seek sought seeking

/sigil add mathconst macro bind lexicon=pi,e,phi,tau,inf
/sigil add mathfunc macro bind lexicon=sin,cos,tan,log,exp,sqrt
/sigil add op2 lambda match type=op promote=true
/sigil add wordtok lambda match type=word
/sigil add numtok lambda match type=number
/sigil add greetmacro macro bind lexicon=hello,hi,hey,greetings
/sigil add threattag tag bind

/automaton register vigilance_trigger alert 0.7
/automaton register comfort_trigger comfort 0.6
/automaton register reasoning_trigger reason 0.5
/automaton register fight_trigger fight 0.8
/automaton register peace_trigger reassure 0.4

/automaton phase threshold 0.55
/automaton phase surface 3
/automaton phase enable

/mlpRule add danger_pattern fuzzy danger_key
/mlpRule add comfort_pattern fuzzy comfort_key
/mlpRule add logic_pattern solid logic_key
/mlpRule add greet_pattern fuzzy greet_key

/mlpThreshold 3

/aimlAdd SurvivalLobe aiml_survival <category><pattern>DANGER *</pattern><template>Grug sense danger! {PRIMARY_ACTION} now!</template></category>
/aimlAdd SocialLobe aiml_greet <category><pattern>HELLO *</pattern><template>Grug welcome you! {PRIMARY_ACTION} back!</template></category>
/aimlAdd ReasoningLobe aiml_reason <category><pattern>WHY *</pattern><template>Grug think about this... {PRIMARY_ACTION} tell you.</template></category>
/aimlAdd CreativeLobe aiml_story <category><pattern>TELL *</pattern><template>Grug tell story... {PRIMARY_ACTION} make it good!</template></category>
/aimlAdd ComfortLobe aiml_comfort <category><pattern>I FEEL *</pattern><template>Grug hear you... {PRIMARY_ACTION} help you feel better.</template></category>

/negativeThesaurus add harm --reason violence is not the first answer
/negativeThesaurus add destroy --reason destruction without purpose wastes the tribe
/negativeThesaurus add betray --reason betrayal destroys trust which is sacred
/negativeThesaurus add abandon --reason the tribe does not abandon its own
/negativeThesaurus add deceive --reason lies poison the well of understanding

/thesaurus courage | fear
/thesaurus love | hate
/thesaurus wisdom | ignorance

/nodes
/status
/aimlStatus
/mitosisStatus
/mlpStatus
/sigil list
/automaton list
/decomposer
/lobes
/listVerbs
/negativeThesaurus list

/saveSpecimen specimens/analog_turing_v3.specimen.json
/quit
ENDINPUT

echo "=== Specimen build complete ==="
echo "Specimen saved to: $SPECIMEN_FILE"
ls -la $SPECIMEN_FILE 2>/dev/null || echo "WARNING: Specimen file not found!"
