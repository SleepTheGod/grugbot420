#!/usr/bin/env bash
# Comprehensive v7.27 test session — pipe into grugbot REPL
# All levers exercised, conversation logged
# Tests: phase crystal growth, learning with /right /wrong, threshold tuning, brainstorm

cat <<'COMMANDS' | julia --project=. -e 'using GrugBot420; GrugBot420.run_cli()'
/loadSpecimen specimens/comprehensive_v727_test.specimen.json
/automaton phase status
/status
/mission hello grug
/automaton phase status
/mission what is the meaning of life
/automaton phase status
/mission FIRE IN THE HOLE EVERYONE OUT
/automaton phase status
/mission contemplate the nature of consciousness
/mission calculate two plus three
/automaton phase status
/mission tell me about thinking
/right
/mission tell me about thinking
/right
/mission tell me about thinking
/automaton phase status
/wrong
/mission tell me about thinking
/automaton phase status
/mlpStatus
/mission what is truth
/automaton phase status
/automaton phase threshold 0.4
/automaton phase surface 3
/automaton phase status
/mission I feel happy today
/automaton phase status
/mission I feel sad and lonely
/automaton phase status
/automaton phase disable
/mission test without phase crystal
/automaton phase enable
/automaton phase status
/mission what is truth
/automaton phase status
/brainstorm explore the depths of cognition
/automaton phase status
/mission I feel happy today
/mission I feel happy today
/automaton phase status
/mission define consciousness
/right
/mission define consciousness
/automaton phase status
/mission warn the group about danger
/wrong
/mission warn the group about danger
/automaton phase status
/mission reason about the nature of time
/mission ponder existence
/automaton phase status
/saveSpecimen specimens/test_session_output_v3.specimen.json
/automaton phase status
/status
/quit
COMMANDS
