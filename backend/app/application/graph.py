"""Minimal directed-graph utilities for the scheduling engine.

The CPM engine only needs topological ordering, cycle detection and a node's
predecessors/successors. Implementing those in ~50 lines of pure Python keeps the
core engine dependency-free, so it installs instantly, runs fully offline, and is
trivial to unit-test. (A drop-in ``networkx`` backend could replace this module
without touching the engine.)
"""

from __future__ import annotations

from collections import deque
from collections.abc import Hashable, Iterable


class DiGraph:
    """A tiny directed graph with optional per-node and per-edge attributes."""

    def __init__(self) -> None:
        self._succ: dict[Hashable, dict[Hashable, dict]] = {}
        self._pred: dict[Hashable, dict[Hashable, dict]] = {}
        self._node: dict[Hashable, dict] = {}

    # --- construction ----------------------------------------------------
    def add_node(self, node: Hashable, **attrs) -> None:
        self._node.setdefault(node, {}).update(attrs)
        self._succ.setdefault(node, {})
        self._pred.setdefault(node, {})

    def add_edge(self, u: Hashable, v: Hashable, **attrs) -> None:
        self.add_node(u)
        self.add_node(v)
        self._succ[u][v] = attrs
        self._pred[v][u] = attrs

    # --- access ----------------------------------------------------------
    def __contains__(self, node: Hashable) -> bool:
        return node in self._node

    @property
    def nodes(self) -> Iterable[Hashable]:
        return list(self._node.keys())

    def node_attr(self, node: Hashable) -> dict:
        return self._node[node]

    def edge_attr(self, u: Hashable, v: Hashable) -> dict:
        return self._succ[u][v]

    def predecessors(self, node: Hashable) -> list[Hashable]:
        return list(self._pred.get(node, {}).keys())

    def successors(self, node: Hashable) -> list[Hashable]:
        return list(self._succ.get(node, {}).keys())

    # --- algorithms ------------------------------------------------------
    def find_cycle(self) -> list[Hashable] | None:
        """Return one cycle as an ordered node list, or ``None`` if acyclic."""
        WHITE, GREY, BLACK = 0, 1, 2
        color = {n: WHITE for n in self._node}
        stack: list[Hashable] = []
        on_stack: set[Hashable] = set()

        def visit(start: Hashable) -> list[Hashable] | None:
            work = [(start, iter(self._succ[start]))]
            color[start] = GREY
            stack.append(start)
            on_stack.add(start)
            while work:
                node, it = work[-1]
                advanced = False
                for nxt in it:
                    if color[nxt] == GREY:  # back-edge -> cycle
                        idx = stack.index(nxt)
                        return stack[idx:] + [nxt]
                    if color[nxt] == WHITE:
                        color[nxt] = GREY
                        stack.append(nxt)
                        on_stack.add(nxt)
                        work.append((nxt, iter(self._succ[nxt])))
                        advanced = True
                        break
                if not advanced:
                    color[node] = BLACK
                    on_stack.discard(node)
                    stack.pop()
                    work.pop()
            return None

        for n in self._node:
            if color[n] == WHITE:
                found = visit(n)
                if found:
                    return found
        return None

    def topological_sort(self) -> list[Hashable]:
        """Kahn's algorithm. Raises ``ValueError`` if the graph has a cycle."""
        indeg = {n: len(self._pred[n]) for n in self._node}
        queue = deque(sorted((n for n, d in indeg.items() if d == 0), key=str))
        order: list[Hashable] = []
        while queue:
            n = queue.popleft()
            order.append(n)
            for m in self._succ[n]:
                indeg[m] -= 1
                if indeg[m] == 0:
                    queue.append(m)
        if len(order) != len(self._node):
            raise ValueError("Graph contains a cycle; topological sort impossible")
        return order
