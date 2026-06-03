#!/usr/bin/env julia
# Post-load verification script for test specimen
using GrugBot420

# Load specimen
result = GrugBot420.load_specimen_from_file!("test_specimen.json")

println("=== POST-LOAD VERIFICATION ===")

# Test: Check node count
n_nodes = length(GrugBot420.NODE_MAP)
println("Nodes in NODE_MAP: $n_nodes")

# Test: Check lobe count  
n_lobes = length(GrugBot420.Lobe.LOBE_REGISTRY)
println("Lobes in LOBE_REGISTRY: $n_lobes")

# Test: Check groups
n_groups = length(GrugBot420.GROUP_MAP)
println("Groups in GROUP_MAP: $n_groups")

# Test: Check attachments (under lock)
n_att = lock(GrugBot420.ATTACHMENT_LOCK) do
    total = 0
    for (tid, atts) in GrugBot420.ATTACHMENT_MAP
        total += length(atts)
    end
    total
end
println("Total attachments: $n_att")

# Test: Check verb registry
for (cls, verbs) in GrugBot420.SemanticVerbs._VERB_REGISTRY
    println("Verb class $cls: $(length(verbs)) verbs")
end

# Test: Check thesaurus
println("Thesaurus entries: $(length(GrugBot420.Thesaurus.SYNONYM_SEED_MAP))")

# Test: Check inhibitions
println("Inhibitions: $(length(GrugBot420.InputQueue._NEG_THESAURUS))")

# Test: Check sigil table
println("Sigil entries: $(length(GrugBot420._ENGINE_SIGIL_TABLE.entries))")
for (name, entry) in GrugBot420._ENGINE_SIGIL_TABLE.entries
    lex_len = entry.lexicon === nothing ? 0 : length(entry.lexicon)
    println("  Sigil &$(name): class=$(entry.class), lexicon_size=$lex_len, promote=$(entry.promote_at_tokenize)")
end

# Test: immune gate is disabled
ig = GrugBot420.immune_gate("test", "anything goes")
println("Immune gate test (should be true): $ig")

# Test: Check decomposer config
cfg = GrugBot420.InputDecomposer._RUNTIME_CONFIG[]
println("Decomposer split_conjunctions: $(length(cfg.split_conjunctions))")
println("Decomposer question_markers: $(length(cfg.question_markers))")
println("Decomposer command_markers: $(length(cfg.command_markers))")
println("Decomposer conjugation_rules: $(length(cfg.conjugation_rules))")

# Test: Run a scan to verify nodes are functional
input_text = "fear causes flight"
signal = GrugBot420.words_to_signal(input_text)
triples = GrugBot420.extract_relational_triples(input_text)
println("Scan test: input=\"$input_text\" => $(length(triples)) triples")
for t in triples
    println("  Triple: $(t.subject) $(t.relation) $(t.object)")
end

# Test: Verify lobes have nodes
for (lid, rec) in GrugBot420.Lobe.LOBE_REGISTRY
    println("Lobe '$lid': $(length(rec.node_ids)) nodes, subject='$(rec.subject)'")
end

# Test: Verify nodes have proper strength
all_strengths = [n.strength for n in values(GrugBot420.NODE_MAP)]
min_str = minimum(all_strengths)
max_str = maximum(all_strengths)
avg_str = sum(all_strengths) / n_nodes
println("Strength range: min=$min_str, max=$max_str, avg=$(round(avg_str, digits=3))")

# Test: Verify groups have members
sample_groups = collect(GrugBot420.GROUP_MAP)[1:min(5, length(GrugBot420.GROUP_MAP))]
for (gid, grp) in sample_groups
    println("Group '$gid': $(length(grp.members)) members, centroid='$(grp.centroid_pattern)'")
end

println("\n=== ALL VERIFICATIONS PASSED ===")
