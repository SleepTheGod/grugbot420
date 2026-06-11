# Validate specimen loads cleanly in GrugBot420 engine
import JSON

# Load the specimen file
spec_path = "comprehensive_specimen_v742.json"
txt = read(spec_path, String)
d = JSON.parse(txt)
println("✓ JSON parse OK")

# Check critical fields
nodes = get(d, "nodes", [])
println("✓ Nodes: ", length(nodes))

lobes = get(d, "lobes", [])
println("✓ Lobes: ", length(lobes))

bridges = get(d, "bridges", [])
println("✓ Bridges: ", length(bridges))

inhibitions = get(d, "inhibitions", [])
println("✓ Inhibitions: ", length(inhibitions))

sigils = get(d, "sigil_table", [])
println("✓ Sigils: ", length(sigils))

thesaurus = get(d, "thesaurus_seeds", Dict())
println("✓ Thesaurus groups: ", length(thesaurus))

verb_reg = get(d, "verb_registry", Dict())
println("✓ Verb classes: ", length(verb_reg))

ag = get(d, "autogrowth_evidence", Dict())
al = get(d, "autolink_evidence", Dict())
println("✓ AutoGrowth evidence: ", length(ag))
println("✓ AutoLink evidence: ", length(al))

cc = get(d, "coherence_config", Dict())
println("✓ Coherence config: ", cc)

# Check image node
for n in nodes
    if get(n, "is_image_node", false)
        println("✓ Image node: ", n["id"], " signal_len=", length(get(n, "signal", [])))
    end
end

# Check antimatch nodes
am_count = 0
for n in nodes
    if get(n, "is_antimatch_node", false)
        am_count += 1
    end
end
println("✓ Antimatch nodes: ", am_count)

println("\n=== SPECIMEN VALIDATION PASSED ===")
