# test_bug011_group_inhibition.jl
# BUG-011: group inhibition is per-node-type, auto-growth-facing, and excludes antimatch.

using Test
using GrugBot420

function _snapshot_engine_state()
    return (
        node_map = deepcopy(GrugBot420.NODE_MAP),
        group_map = deepcopy(GrugBot420.GROUP_MAP),
        node_to_group = deepcopy(GrugBot420.NODE_TO_GROUP),
    )
end

function _restore_engine_state!(snap)
    lock(GrugBot420.NODE_LOCK) do
        empty!(GrugBot420.NODE_MAP)
        merge!(GrugBot420.NODE_MAP, snap.node_map)
    end
    lock(GrugBot420.GROUP_LOCK) do
        empty!(GrugBot420.GROUP_MAP)
        merge!(GrugBot420.GROUP_MAP, snap.group_map)
        empty!(GrugBot420.NODE_TO_GROUP)
        merge!(GrugBot420.NODE_TO_GROUP, snap.node_to_group)
    end
    if isdefined(GrugBot420, :GROUP_INHIBITION_BY_TYPE)
        empty!(GrugBot420.GROUP_INHIBITION_BY_TYPE)
    end
end

@testset "BUG-011 group inhibition per type and antimatch exclusion" begin
    snap = _snapshot_engine_state()
    try
        lock(GrugBot420.NODE_LOCK) do
            empty!(GrugBot420.NODE_MAP)
        end
        lock(GrugBot420.GROUP_LOCK) do
            empty!(GrugBot420.GROUP_MAP)
            empty!(GrugBot420.NODE_TO_GROUP)
        end
        if isdefined(GrugBot420, :GROUP_INHIBITION_BY_TYPE)
            empty!(GrugBot420.GROUP_INHIBITION_BY_TYPE)
        end

        voter_id = GrugBot420.create_node("alpha voter organic", "voter_action", Dict{String,Any}(), String[])
        time_id = GrugBot420.create_node("clock temporal organic", "time_action", Dict{String,Any}("time_node" => true), String[])
        anti_id = GrugBot420.create_node("forbidden antimatch token", "anti_action", Dict{String,Any}(), String[]; is_antimatch_node=true)

        grp = GrugBot420.NodeGroup("bug011_group", voter_id, "mixed centroid")
        push!(grp.members, time_id)
        push!(grp.members, anti_id)
        grp.inhibition_dirty = true

        GrugBot420.refresh_inhibition_tokens!(grp; node_map=GrugBot420.NODE_MAP, node_lock=GrugBot420.NODE_LOCK, thesaurus_fn=(tok -> tok == "alpha" ? ["synalpha"] : String[]))

        @test !grp.inhibition_dirty
        @test GrugBot420.is_inhibited("alpha", grp; node_type=:voter, threshold=1.0, node_map=GrugBot420.NODE_MAP, node_lock=GrugBot420.NODE_LOCK)
        @test GrugBot420.is_inhibited("synalpha", grp; node_type=:voter, threshold=1.0, node_map=GrugBot420.NODE_MAP, node_lock=GrugBot420.NODE_LOCK)
        @test !GrugBot420.is_inhibited("alpha", grp; node_type=:time, threshold=1.0, node_map=GrugBot420.NODE_MAP, node_lock=GrugBot420.NODE_LOCK)

        @test GrugBot420.is_inhibited("clock", grp; node_type=:time, threshold=1.0, node_map=GrugBot420.NODE_MAP, node_lock=GrugBot420.NODE_LOCK)
        @test !GrugBot420.is_inhibited("clock", grp; node_type=:voter, threshold=1.0, node_map=GrugBot420.NODE_MAP, node_lock=GrugBot420.NODE_LOCK)

        @test !GrugBot420.is_inhibited("forbidden", grp; node_type=:voter, threshold=1.0, node_map=GrugBot420.NODE_MAP, node_lock=GrugBot420.NODE_LOCK)
        @test !GrugBot420.is_inhibited("antimatch", grp; node_type=:time, threshold=1.0, node_map=GrugBot420.NODE_MAP, node_lock=GrugBot420.NODE_LOCK)

        @test "alpha" in grp.inhibition_tokens
        @test "clock" in grp.inhibition_tokens
        @test !("forbidden" in grp.inhibition_tokens)
    finally
        _restore_engine_state!(snap)
    end
end
