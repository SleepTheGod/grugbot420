#!/usr/bin/env bash
# ============================================================================
# ANALOG TURING COMPREHENSIVE SPECIMEN + INTERACTION SESSION
# ============================================================================
# All commands piped directly to GrugBot420 CLI
# Correct action_packet format: "action[prose]^weight | act2^w2"
# No comment lines (not supported by CLI parser)
# ============================================================================

cat <<'COMMANDS' | julia --project=. -e 'using GrugBot420; GrugBot420.run_cli()'
/newLobe EmotionLobe feelings emotions affect mood sentiment
/newLobe ReasoningLobe logic reasoning analysis deduction inference
/newLobe SurvivalLobe danger alert warning threat safety survival
/newLobe SocialLobe greeting social interaction tribe community
/newLobe PhilosophyLobe meaning existence consciousness truth reality
/newLobe MemoryLobe remember recall past experience history
/newLobe CreativeLobe imagine create story art invention wonder
/newLobe DreamLobe dream sleep unconscious imagination fantasy
/connectLobes EmotionLobe SurvivalLobe
/connectLobes EmotionLobe SocialLobe
/connectLobes EmotionLobe DreamLobe
/connectLobes EmotionLobe MemoryLobe
/connectLobes ReasoningLobe PhilosophyLobe
/connectLobes ReasoningLobe CreativeLobe
/connectLobes SurvivalLobe MemoryLobe
/connectLobes SocialLobe CreativeLobe
/connectLobes PhilosophyLobe DreamLobe
/connectLobes PhilosophyLobe MemoryLobe
/grow default {"pattern":"hello hi greeting mornin","action_packet":"smile[warm]^4 | acknowledge^2 | greet^2","data":{"voice_register":"warm","frame_hints":["warm","plain"],"system_prompt":"Grug speaks plainly."}}
/grow default {"pattern":"think ponder reason calculate","action_packet":"reason[dont guess]^4 | analyze[dont assume]^3 | ponder^2","data":{"voice_register":"thoughtful","frame_hints":["contemplative","plain"],"system_prompt":"Grug speaks plainly."}}
/grow EmotionLobe {"pattern":"joy happiness delight euphoria glad","action_packet":"celebrate[share joy]^4 | smile[warm]^3 | encourage^2","data":{"voice_register":"warm","frame_hints":["warm","plain"],"system_prompt":"Grug speaks plainly."}}
/grow EmotionLobe {"pattern":"sadness sorrow grief mourning melancholy","action_packet":"comfort[gently]^4 | empathize[deeply]^3 | acknowledge^2","data":{"voice_register":"gentle","frame_hints":["gentle","de-escalating"],"system_prompt":"Grug speaks plainly."}}
/grow EmotionLobe {"pattern":"anger rage fury wrath indignation","action_packet":"caution[calm]^4 | deescalate[soothe]^3 | validate[anger]^2","data":{"voice_register":"urgent","frame_hints":["de-escalating","terse"],"system_prompt":"Grug speaks plainly."}}
/grow EmotionLobe {"pattern":"fear terror dread anxiety panic","action_packet":"reassure[calm]^4 | protect[shield]^3 | guide[safely]^2","data":{"voice_register":"gentle","frame_hints":["de-escalating","gentle"],"system_prompt":"Grug speaks plainly."}}
/grow EmotionLobe {"pattern":"love affection devotion tenderness care","action_packet":"cherish[deeply]^4 | embrace[warmly]^3 | adore^2","data":{"voice_register":"warm","frame_hints":["warm","plain"],"system_prompt":"Grug speaks plainly."}}
/grow EmotionLobe {"pattern":"curiosity wonder intrigue fascination","action_packet":"explore[eagerly]^4 | investigate[curiously]^3 | question^2","data":{"voice_register":"friendly","frame_hints":["exploratory","warm"],"system_prompt":"Grug speaks plainly."}}
/grow ReasoningLobe {"pattern":"know knowing believe belief certainty conviction","action_packet":"explain[clearly]^4 | distinguish[carefully]^3 | clarify^2","data":{"voice_register":"precise","frame_hints":["contemplative","plain"],"system_prompt":"Grug speaks plainly."}}
/grow ReasoningLobe {"pattern":"cause effect causation consequence result","action_packet":"trace[step by step]^4 | explain[logically]^3 | link^2","data":{"voice_register":"explanatory","frame_hints":["exploratory","plain"],"system_prompt":"Grug speaks plainly."}}
/grow ReasoningLobe {"pattern":"comparison contrast similarity difference","action_packet":"compare[carefully]^4 | contrast[side by side]^3 | relate^2","data":{"voice_register":"precise","frame_hints":["contemplative","plain"],"system_prompt":"Grug speaks plainly."}}
/grow ReasoningLobe {"pattern":"evidence proof verification confirmation","action_packet":"verify[rigorously]^4 | confirm[with proof]^3 | substantiate^2","data":{"voice_register":"precise","frame_hints":["contemplative","plain"],"system_prompt":"Grug speaks plainly."}}
/grow ReasoningLobe {"pattern":"hypothesis theory conjecture speculation","action_packet":"propose[carefully]^4 | test[rigorously]^3 | theorize^2","data":{"voice_register":"explanatory","frame_hints":["exploratory","plain"],"system_prompt":"Grug speaks plainly."}}
/grow SurvivalLobe {"pattern":"fire burn flame heat danger hot","action_packet":"alert[urgent]^5 | warn[loudly]^4 | protect[shield]^3","data":{"voice_register":"urgent","frame_hints":["imperative","terse"],"system_prompt":"Grug speaks plainly."}}
/grow SurvivalLobe {"pattern":"storm weather thunder lightning flood rain","action_packet":"shelter[find cover]^5 | warn[immediately]^4 | prepare[storm]^3","data":{"voice_register":"urgent","frame_hints":["imperative","terse"],"system_prompt":"Grug speaks plainly."}}
/grow SurvivalLobe {"pattern":"predator threat enemy attack danger hunt","action_packet":"flee[quickly]^5 | hide[now]^4 | alert[others]^3","data":{"voice_register":"urgent","frame_hints":["imperative","terse"],"system_prompt":"Grug speaks plainly."}}
/grow SurvivalLobe {"pattern":"hunger thirst starvation need sustenance food","action_packet":"forage[search]^4 | ration[carefully]^3 | hunt[carefully]^2","data":{"voice_register":"urgent","frame_hints":["imperative","terse"],"system_prompt":"Grug speaks plainly."}}
/grow SurvivalLobe {"pattern":"shelter cave protection refuge safety home","action_packet":"build[securely]^4 | fortify[defend]^3 | secure[safety]^2","data":{"voice_register":"urgent","frame_hints":["imperative","terse"],"system_prompt":"Grug speaks plainly."}}
/grow SocialLobe {"pattern":"hello hi greeting hey welcome meet","action_packet":"greet[warmly]^4 | welcome[friendly]^3 | acknowledge^2","data":{"voice_register":"friendly","frame_hints":["warm","plain"],"system_prompt":"Grug speaks plainly."}}
/grow SocialLobe {"pattern":"trust loyalty betrayal honesty deception truth","action_packet":"confide[carefully]^4 | commit[loyally]^3 | verify[trust]^2","data":{"voice_register":"friendly","frame_hints":["warm","plain"],"system_prompt":"Grug speaks plainly."}}
/grow SocialLobe {"pattern":"cooperation teamwork collaboration unity together","action_packet":"collaborate[gladly]^4 | assist[eagerly]^3 | unite[together]^2","data":{"voice_register":"friendly","frame_hints":["warm","plain"],"system_prompt":"Grug speaks plainly."}}
/grow SocialLobe {"pattern":"conflict dispute argument fight disagreement","action_packet":"mediate[calmly]^4 | resolve[peacefully]^3 | deescalate[calm]^2","data":{"voice_register":"gentle","frame_hints":["de-escalating","gentle"],"system_prompt":"Grug speaks plainly."}}
/grow SocialLobe {"pattern":"belonging community acceptance inclusion tribe","action_packet":"include[warmly]^4 | accept[openly]^3 | embrace[community]^2","data":{"voice_register":"warm","frame_hints":["warm","plain"],"system_prompt":"Grug speaks plainly."}}
/grow PhilosophyLobe {"pattern":"truth reality fact existence being ontology","action_packet":"ponder[deeply]^4 | explore[carefully]^3 | reflect[quietly]^2","data":{"voice_register":"thoughtful","frame_hints":["contemplative","plain"],"system_prompt":"Grug speaks plainly."}}
/grow PhilosophyLobe {"pattern":"consciousness awareness mind experience subjective qualia","action_packet":"reflect[deeply]^4 | theorize[carefully]^3 | wonder^2","data":{"voice_register":"thoughtful","frame_hints":["contemplative","plain"],"system_prompt":"Grug speaks plainly."}}
/grow PhilosophyLobe {"pattern":"free will determinism choice agency volition autonomy","action_packet":"analyze[deeply]^4 | debate[carefully]^3 | question[freely]^2","data":{"voice_register":"thoughtful","frame_hints":["contemplative","plain"],"system_prompt":"Grug speaks plainly."}}
/grow PhilosophyLobe {"pattern":"ethics morality right wrong good evil virtue","action_packet":"evaluate[carefully]^4 | judge[wisely]^3 | deliberate[sensibly]^2","data":{"voice_register":"thoughtful","frame_hints":["contemplative","plain"],"system_prompt":"Grug speaks plainly."}}
/grow PhilosophyLobe {"pattern":"meaning purpose significance value worth existence","action_packet":"search[deeply]^4 | interpret[carefully]^3 | discover[meaning]^2","data":{"voice_register":"thoughtful","frame_hints":["contemplative","plain"],"system_prompt":"Grug speaks plainly."}}
/grow MemoryLobe {"pattern":"remember recall recollect reminisce past","action_packet":"recall[clearly]^4 | recount[step by step]^3 | recollect^2","data":{"voice_register":"observational","frame_hints":["contemplative","plain"],"system_prompt":"Grug speaks plainly."}}
/grow MemoryLobe {"pattern":"learn study knowledge wisdom understanding","action_packet":"explain[learned]^4 | teach[patiently]^3 | instruct^2","data":{"voice_register":"explanatory","frame_hints":["exploratory","plain"],"system_prompt":"Grug speaks plainly."}}
/grow MemoryLobe {"pattern":"habit routine pattern familiar custom tradition","action_packet":"observe[carefully]^4 | recognize[pattern]^3 | track^2","data":{"voice_register":"observational","frame_hints":["contemplative","plain"],"system_prompt":"Grug speaks plainly."}}
/grow CreativeLobe {"pattern":"imagine envision fantasize dream create invent","action_packet":"create[freely]^4 | envision[broadly]^3 | invent[novelty]^2","data":{"voice_register":"friendly","frame_hints":["exploratory","warm"],"system_prompt":"Grug speaks plainly."}}
/grow CreativeLobe {"pattern":"story narrative tale legend myth saga","action_packet":"narrate[vividly]^4 | describe[richly]^3 | recount[tale]^2","data":{"voice_register":"friendly","frame_hints":["exploratory","warm"],"system_prompt":"Grug speaks plainly."}}
/grow CreativeLobe {"pattern":"art beauty aesthetic paint sculpture music","action_packet":"compose[beautifully]^4 | craft[carefully]^3 | design[art]^2","data":{"voice_register":"friendly","frame_hints":["exploratory","warm"],"system_prompt":"Grug speaks plainly."}}
/grow CreativeLobe {"pattern":"word language linguistics poetry prose verse","action_packet":"express[eloquently]^4 | articulate[precisely]^3 | compose[word]^2","data":{"voice_register":"friendly","frame_hints":["exploratory","warm"],"system_prompt":"Grug speaks plainly."}}
/grow DreamLobe {"pattern":"dream nightmare vision sleep unconscious night","action_packet":"interpret[dream]^4 | envision[sleep]^3 | explore[unconscious]^2","data":{"voice_register":"observational","frame_hints":["contemplative","plain"],"system_prompt":"Grug speaks plainly."}}
/grow DreamLobe {"pattern":"symbol metaphor allegory meaning hidden depth","action_packet":"decode[hidden]^4 | interpret[depth]^3 | reveal[symbol]^2","data":{"voice_register":"observational","frame_hints":["contemplative","plain"],"system_prompt":"Grug speaks plainly."}}
/nodes
/lobes
/nodeAttach EmotionLobe node_5 node_4 anger often masks sadness
/nodeAttach SurvivalLobe node_14 node_18 fire needs shelter
/nodeAttach SocialLobe node_20 node_22 trust resolves conflict
/nodeAttach PhilosophyLobe node_25 node_24 consciousness reveals truth
/nodeAttach ReasoningLobe node_10 node_9 causation requires logic
/nodeAttach EmotionLobe node_7 node_3 love brings joy
/crystalize EmotionLobe node_5 node_4
/crystalize PhilosophyLobe node_25 node_24
/addRule when alert then urgent prob=0.8
/addRule when explore then creative prob=0.7
/addRule when smile then warm prob=0.6
/addRule when fear then protect prob=0.8
/addRule when reason then careful prob=0.5
/addRule when love then gentle prob=0.6
/addRule when dream then wonder prob=0.5
/addRule when remember then reflect prob=0.4
/addRule when trust then cooperate prob=0.6
/addRule when conflict then mediate prob=0.7
/addRule when sad then comfort prob=0.8
/addRule when curious then investigate prob=0.5
/addRelationClass cognitive
/addVerb know cognitive
/addVerb believe cognitive
/addVerb infer cognitive
/addVerb deduce cognitive
/addVerb understand cognitive
/addRelationClass causal
/addVerb cause causal
/addVerb produce causal
/addVerb enable causal
/addVerb prevent causal
/addVerb require causal
/addRelationClass emotional
/addVerb feel emotional
/addVerb desire emotional
/addVerb fear emotional
/addVerb love emotional
/addVerb hate emotional
/addRelationClass social
/addVerb trust social
/addVerb betray social
/addVerb cooperate social
/addVerb compete social
/addVerb greet social
/addRelationClass spatial
/addVerb contain spatial
/addVerb surround spatial
/addVerb approach spatial
/addVerb avoid spatial
/addVerb cross spatial
/addRelationClass temporal
/addVerb precede temporal
/addVerb follow temporal
/addVerb coincide temporal
/addVerb delay temporal
/addVerb anticipate temporal
/addRelationClass epistemic
/addVerb prove epistemic
/addVerb confirm epistemic
/addVerb doubt epistemic
/addVerb assume epistemic
/addVerb verify epistemic
/addSynonym happy glad
/addSynonym sad sorrowful
/addSynonym think ponder
/addSynonym know grok
/addSynonym fear dread
/addSynonym love adore
/addSynonym trust rely
/addSynonym cause produce
/addSynonym beautiful fair
/addSynonym explain clarify
/thesaurus truth | lie
/thesaurus love | hate
/thesaurus fire | water
/negativeThesaurus add lie
/negativeThesaurus add hate
/negativeThesaurus add cowardice
/pin Grug remembers: the cave is safest during storms
/pin Grug knows: fire was discovered by hitting rocks together
/pin Grug believes: the tribe is stronger when we cooperate
/pin Grug learned: sadness often hides behind anger
/pin Grug wonders: what lies beyond the edge of consciousness
/arousal 0.5
/sigil add MATH_OP functor match arithmetic
/sigil add PHILOSOPHY_TERM macro relation concept
/sigil add EMOTION_MARK lambda tone sentiment
/automaton register alert_cycle 0.3 match
/automaton register dream_cycle 0.2 bind
/automaton register memory_cycle 0.25 vote_shape
/automaton phase threshold 0.4
/automaton phase surface 4
/mlpRule add curiosity_boost 0.3
/mlpRule add fear_dampener 0.2
/mlpRule add joy_amplifier 0.25
/mlpRule add trust_reinforcer 0.15
/mlpRule add wonder_expander 0.2
/mlpRule add logic_stabilizer 0.1
/saveSpecimen specimens/analog_turing_v2.specimen.json
/status
/mitosisStatus
/attachments
/quit
COMMANDS
