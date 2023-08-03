# Compute a topological ordering of a set of nodes reachable from the given
# roots by the given successor function.
function topological_sort(successors::Function, roots::AbstractVector{N}) where { N }
    # Compute pred_counts, the number of predecessors of each node
    pred_counts = OrderedDict{N, Int}()
    counted = Set{N}()
    to_count = Vector{N}(roots)
    while !isempty(to_count)
        node = pop!(to_count)
        node in counted && continue
        push!(counted, node)
        get!(pred_counts, node, 0)
        for succ::N in reverse(successors(node))
            push!(to_count, succ)
            pred_counts[succ] = get(pred_counts, succ, 0) + 1
        end
    end

    # Prepare a ready set of nodes to output that have no predecessors
    ready = N[k for (k, v) in pred_counts if v == 0]
    result = N[]
    sizehint!(result, length(pred_counts))
    while !isempty(ready)
        node::N = pop!(ready)
        push!(result, node)

        # remove the node by decrementing the predecessor counts of its successors
        for succ::N in reverse(successors(node))
            count = pred_counts[succ]
            @assert count > 0
            count -= 1
            pred_counts[succ] = count
            count == 0 && push!(ready, succ)
        end
    end

    # all of the nodes should have been output by now.  Otherwise there was a cycle.
    if length(pred_counts) != length(result)
        error("graph had a cycle involving ", N[k for (k, v) in pred_counts if v != 0], ".")
    end

    result
end
