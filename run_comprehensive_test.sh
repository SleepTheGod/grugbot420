#!/usr/bin/env bash
# ═══════════════════════════════════════════════════════════════════════
# FULLY COMPREHENSIVE v7.27 test session — EVERY LEVER PULLED
# All nodeAttach calls respect lobe boundaries (same-lobe only)
# ═══════════════════════════════════════════════════════════════════════

cat <<'COMMANDS' | julia --project=. -e 'using GrugBot420; GrugBot420.run_cli()'
/loadSpecimen specimens/comprehensive_v727_test.specimen.json
/status
/nodes
/lobes
/automaton phase status
/listVerbs
/attachments
/aimlStatus
/mlpStatus
/decomposer
/sigil list
/mission hello grug
/mission what is the meaning of life
/mission tell me about fire
/mission FIRE IN THE HOLE EVERYONE OUT
/mission calculate two plus three
/mission I feel sad and lonely
/mission I feel happy today
/mission reason about why things exist
/mission warn the group about the storm
/mission describe the nature of consciousness
/right
/mission describe the nature of consciousness
/right
/mission describe the nature of consciousness
/wrong
/mission describe the nature of consciousness
/aimlRight
/mission explain quantum mechanics
/aimlWrong
/brainstorm explore the depths of cognition and reality
/automaton phase status
/explicit describe [node_8] explain the concept of entropy in detail
/explicit alert [node_16] there is a fire in the cave
/grow PhilosophyLobe {"pattern":"consciousness","action_packet":"ponder[deeply]^5 | reason[carefully]^3 | analyze^2","json_data":{"system_prompt":"Grug think about consciousness. Grug wonder what it means to be aware and experience things.","lobe_hint":"PhilosophyLobe","voice_register":"thoughtful","frame_hints":["contemplative","exploratory"],"noun_anchors":["consciousness","awareness"]}}
/grow EmotionLobe {"pattern":"angry","action_packet":"comfort[calm]^4 | support[steady]^3 | reassure^2","json_data":{"system_prompt":"Grug understand anger. Grug help calm the fire inside before it burns the tribe.","lobe_hint":"EmotionLobe","voice_register":"gentle","frame_hints":["warm","de-escalating"],"noun_anchors":["anger","calm"]}}
/grow SurvivalLobe {"pattern":"storm","action_packet":"alert[urgent]^5 | warn[immediate]^4 | hide^3","json_data":{"system_prompt":"Grug see storm coming. Grug warn tribe to seek shelter before the sky falls.","lobe_hint":"SurvivalLobe","voice_register":"urgent","frame_hints":["imperative","terse"],"noun_anchors":["storm","danger"]}}
/pin Grug remembers: the cave is safest during storms
/pin Grug knows: fire was discovered by hitting rocks together
/addRelationClass epistemic
/addVerb know epistemic
/addVerb believe epistemic
/addVerb infer epistemic
/addSynonym know grok
/addSynonym believe trust
/listVerbs
/newLobe DreamLobe dreams and imagination and sleep
/connectLobes DreamLobe PhilosophyLobe
/connectLobes DreamLobe EmotionLobe
/lobes
/grow DreamLobe {"pattern":"dream","action_packet":"describe[mystical]^4 | ponder[dreamlike]^3 | elaborate^1","json_data":{"system_prompt":"Grug dream big. In sleep the mind wanders where waking fears to go.","lobe_hint":"DreamLobe","voice_register":"observational","frame_hints":["contemplative","exploratory"],"noun_anchors":["dream","sleep","imagination"]}}
/tableStatus PhilosophyLobe
/tableStatus SocialLobe
/thesaurus fire | water
/thesaurus happy | sad
/thesaurus reason | believe
/negativeThesaurus list
/negativeThesaurus add hate --reason toxic negativity
/negativeThesaurus check hate
/negativeThesaurus remove hate
/negativeThesaurus list
/nodeAttach default node_2 node_1 think
/nodeAttach default node_2 node_0 hello
/attachments
/mission tell me about fire
/mission fire is warm
/crystalize default node_2 node_1
/attachments
/mission tell me about fire
/decrystalize default node_2 node_1
/attachments
/nodeDetach default node_2 node_0
/attachments
/mission fire is dangerous
/nodeAttach SocialLobe node_3 node_greet_hi hi
/nodeAttach SocialLobe node_3 node_greet_hey hey
/attachments
/mission hello there
/nodeAttach EmotionLobe node_13 node_14 smile
/attachments
/mission I feel sad but happy
/nodeAttach SurvivalLobe node_16 node_danger_help help
/attachments
/mission danger is everywhere
/arousal 0.3
/mission something is happening
/arousal 0.9
/mission EMERGENCY DANGER NOW
/arousal 0.5
/aimlStatus
/aimlList PhilosophyLobe
/aimlCycle
/aimlPhagy
/mlpStatus
/mlpObserver
/mlpThreshold 3
/mlpRule list
/automaton phase status
/automaton phase threshold 0.35
/automaton phase surface 4
/automaton phase status
/mission what is consciousness
/automaton phase status
/mission reason about time and existence
/automaton phase status
/automaton phase disable
/mission test without phase crystal
/automaton phase enable
/automaton phase status
/mission ponder the infinite
/automaton phase status
/decomposer addConjunction however
/decomposer addCompound ice cream
/decomposer addQuestion whether
/decomposer addCommand investigate investigates investigated
/decomposer
/decomposer removeConjunction however
/decomposer removeCompound ice cream
/decomposer removeQuestion whether
/decomposer removeCommand investigate
/decomposer
/sigil list
/sigil add MATH_OP functor match type=op lexicon=+,−,×,÷,=
/sigil list
/sigil remove MATH_OP
/sigil list
/addRule when {PRIMARY_ACTION} is alert then {SURE_ACTIONS} must be urgent prob=0.8
/status
/mission what is truth
/mission what is truth
/mission what is truth
/right
/mission what is truth
/automaton phase status
/mission I feel sad but I also wonder why we exist
/mission calculate the meaning of happiness plus truth
/mission warn everyone that the storm of consciousness is coming
/saveSpecimen specimens/test_comprehensive_output.specimen.json
/status
/automaton phase status
/nodes
/attachments
/aimlStatus
/loadSpecimen specimens/test_comprehensive_output.specimen.json
/status
/automaton phase status
/nodes
/attachments
/lobes
/listVerbs
/mission hello after reload
/mission what is truth after reload
/automaton phase status
/saveSpecimen specimens/test_comprehensive_final.specimen.json
/status
/quit
COMMANDS
