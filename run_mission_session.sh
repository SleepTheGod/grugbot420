#!/usr/bin/env bash
# ──────────────────────────────────────────────────────────────
# MISSION SESSION — real conversational inputs, actual replies
# Focus: what does grugbot MEAN by what it says?
# ──────────────────────────────────────────────────────────────

cat <<'COMMANDS' | julia --project=. -e 'using GrugBot420; GrugBot420.run_cli()'
/loadSpecimen specimens/comprehensive_v727_test.specimen.json
/status

# ── WARM-UP: baseline personality ──
/mission hello grug who are you
/mission what do you know about the world

# ── EPISTEMIC PROBES: what does grug actually believe? ──
/mission what is truth
/mission how do you know what you know
/mission can you be wrong about something

# ── EMOTIONAL DEPTH: does grug feel or just say feeling words? ──
/mission I am scared of the dark
/mission my friend died yesterday
/mission I have never been this happy in my whole life

# ── SURVIVAL UNDER PRESSURE: does urgency change grug's voice? ──
/mission there is a predator outside the cave
/mission THE RIVER IS FLOODING WE NEED TO MOVE NOW
/mission everyone is safe now the danger has passed

# ── CONTRADICTION AND PARADOX: how does grug handle cognitive tension? ──
/mission fire keeps us warm but fire also destroys
/mission I love the rain but I hate being wet
/mission the strongest person I know is also the most vulnerable

# ── ABSTRACT REASONING: does grug think or just pattern-match? ──
/mission what is the difference between knowing and believing
/mission if all fires go out does the concept of fire still exist
/mission can something be true and false at the same time

# ── SOCIAL INTELLIGENCE: does grug understand relationships? ──
/mission why do people hurt the ones they love
/mission how do you build trust with someone who lied to you
/mission what does it mean to belong to a tribe

# ── IDENTITY AND SELF-AWARENESS: does grug know what it is? ──
/mission are you alive grug
/mission do you have thoughts of your own or just words
/mission what would make you different from what you are now

# ── CREATIVE / GENERATIVE: can grug make something new? ──
/mission tell me a story about the first cave
/mission describe a world where rocks can speak
/mission invent a new word for the feeling of waking up before dawn

# ── MEMORY AND CONTEXT: does grug remember across the session? ──
/mission remember that the river floods in spring
/mission what did I tell you about the river
/mission why would the river be dangerous right now

# ── FEEDBACK LOOPS: how does right/wrong reshape the voice? ──
/mission what is the meaning of suffering
/right
/mission what is the meaning of suffering
/right
/mission what is the meaning of suffering
/wrong
/mission what is the meaning of suffering

# ── CROSS-LOBE COMPOUNDS: how does grug route mixed signals? ──
/mission I am terrified but I also feel curious about what is out there
/mission the storm is beautiful even though it is deadly
/mission I want to understand why I am afraid

# ── NODE ATTACHMENTS: does wiring change meaning? ──
/nodeAttach default node_2 node_1 think
/mission tell me about fire
/crystalize default node_2 node_1
/mission tell me about fire again
/decrystalize default node_2 node_1
/nodeDetach default node_2 node_1

# ── AROUSAL MODULATION: does intensity change framing? ──
/arousal 0.1
/mission something moved in the shadows
/arousal 0.9
/mission something moved in the shadows
/arousal 0.5
/mission something moved in the shadows

# ── FINAL DEEP PROBES ──
/mission what have you learned from this conversation
/mission what question would you ask me if you could ask anything
/mission what is the most important thing a person can know

/saveSpecimen specimens/mission_session_output.specimen.json
/status
/quit
COMMANDS
