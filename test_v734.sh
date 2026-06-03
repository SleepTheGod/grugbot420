#!/bin/bash
# GRUG v7.34: Quick decoherence fix verification session
# Tests: (1) No [Directives: ...] in output, (2) No dangling connectors,
#        (3) Comment lines don't cause errors, (4) /aimlPhagy doesn't crash

cd /workspace/grugbot420

# Build a small specimen for testing
julia --project=. -e 'using GrugBot420; GrugBot420.run_cli()' <<'GRUGEOF'
# This is a comment line - should be silently skipped in v7.34
# --- Section: Setup ---
/newLobe SocialLobe grug social friend tribe
/newLobe VigilanceLobe danger risk hazard warning
/newLobe SurvivalLobe shelter cave food fire
/connectLobes SocialLobe VigilanceLobe
/connectLobes SocialLobe SurvivalLobe
/grow SocialLobe {"pattern":"hello friend welcome","action_packet":"greet","data":{"system_prompt":"Every newcomer is potential friend. Grug always happy to meet new tribe member.","noun_anchors":["friend","newcomer"],"voice_register":"warm"}}
/grow SocialLobe {"pattern":"share give help","action_packet":"acknowledge","data":{"system_prompt":"Sharing is the heart of tribe. Together we are stronger.","noun_anchors":["sharing","tribe"],"voice_register":"warm"}}
/grow VigilanceLobe {"pattern":"danger risk hazard","action_packet":"warn","data":{"system_prompt":"Warning given early is life saved later. Vigilance keeps the tribe safe.","noun_anchors":["danger","warning"],"voice_register":"terse"}}
/grow VigilanceLobe {"pattern":"watch guard lookout","action_packet":"flag","data":{"system_prompt":"Eyes open, ears sharp. The perimeter must be watched.","noun_anchors":["perimeter","watch"],"voice_register":"terse"}}
/grow SurvivalLobe {"pattern":"shelter cave home","action_packet":"alert","data":{"system_prompt":"Cave is home, home is life. Protect the shelter at all costs.","noun_anchors":["cave","shelter"],"voice_register":"plain"}}
/grow SurvivalLobe {"pattern":"fire burn warm","action_packet":"support","data":{"system_prompt":"Fire is both friend and foe. Respect the flame.","noun_anchors":["fire","flame"],"voice_register":"warm"}}
/addRule "Grug reflect on yourself"
/addRule "What patterns do you see"
/addRelationClass social
/addVerb greet social
/addVerb warn social
/addVerb support social
/addVerb acknowledge social
/addVerb alert social
/addVerb flag social
# --- Section: Test Missions ---
/mission hello Grug! How are you today?
/mission Welcome to the cave, new friend
/mission There is danger approaching from the north!
/mission The river floods and our shelter is threatened
/mission Watch the perimeter Grug, something is out there
/mission Protect the children from the wildfire!
/mission Danger! The cave entrance is collapsing!
/mission Fire keeps us warm but also burns
/mission Grug, tell me about friendship
/mission What do you think about danger?
# --- Section: Test /aimlPhagy (was crashing) ---
/aimlPhagy
# --- Section: Wrap up ---
/saveSpecimen v734_test
/quit
GRUGEOF
