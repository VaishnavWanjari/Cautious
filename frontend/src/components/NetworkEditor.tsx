import { useCallback, useEffect, useMemo, useState } from "react";
import ReactFlow, {
  Background,
  Controls,
  Handle,
  MiniMap,
  Position,
  ReactFlowProvider,
  addEdge,
  applyNodeChanges,
  type Connection,
  type Edge,
  type Node,
  type NodeChange,
  type NodeProps,
} from "reactflow";
import { api } from "../api/client";
import type { NetworkData } from "../types";

interface Props {
  projectId: number | null;
  version: number;
  onChanged: () => void;
}

type ActivityData = NetworkData["nodes"][number]["data"];

/** Custom node card showing the activity's schedule fields. */
function ActivityNodeCard({ data }: NodeProps<ActivityData>) {
  return (
    <div className={`rf-node ${data.isCritical ? "critical" : ""}`}>
      <Handle type="target" position={Position.Left} />
      <div className="rf-head">
        <span>{data.activityId}</span>
        <span>{data.duration}d</span>
      </div>
      <div className="rf-body">
        <div className="col-span-2 font-semibold text-slate-700 truncate">{data.name}</div>
        <div className="lbl">Start</div>
        <div>{data.startDate ?? "—"}</div>
        <div className="lbl">Finish</div>
        <div>{data.finishDate ?? "—"}</div>
        <div className="lbl">Float</div>
        <div>{data.totalFloat ?? "—"}</div>
        <div className="lbl">Disc.</div>
        <div className="truncate">{data.discipline || "—"}</div>
      </div>
      <Handle type="source" position={Position.Right} />
    </div>
  );
}

function EditorInner({ projectId, version, onChanged }: Props) {
  const [nodes, setNodes] = useState<Node<ActivityData>[]>([]);
  const [edges, setEdges] = useState<Edge[]>([]);
  const nodeTypes = useMemo(() => ({ activity: ActivityNodeCard }), []);

  const load = useCallback(async () => {
    if (projectId == null) return;
    const net = await api.getNetwork(projectId);
    setNodes(
      net.nodes.map((n) => ({
        id: n.id,
        type: "activity",
        position: n.position,
        data: n.data,
      }))
    );
    setEdges(
      net.edges.map((e) => ({
        id: e.id,
        source: e.source,
        target: e.target,
        label: e.label,
        animated: e.animated,
        style: { stroke: "#64748b" },
        labelStyle: { fontSize: 10, fill: "#475569" },
      }))
    );
  }, [projectId]);

  useEffect(() => {
    load();
  }, [load, version]);

  const onNodesChange = useCallback(
    (changes: NodeChange[]) => setNodes((ns) => applyNodeChanges(changes, ns)),
    []
  );

  // Persist a node position when the user finishes dragging it.
  const onNodeDragStop = useCallback(
    async (_e: unknown, node: Node) => {
      await api.updatePosition(Number(node.id), Math.round(node.position.x), Math.round(node.position.y));
    },
    []
  );

  // Drawing an arrow auto-creates a Finish-to-Start relationship.
  const onConnect = useCallback(
    async (conn: Connection) => {
      if (!conn.source || !conn.target || conn.source === conn.target || projectId == null) return;
      setEdges((es) => addEdge({ ...conn, label: "FS" }, es));
      try {
        await api.createRelationship(projectId, {
          predecessor_id: Number(conn.source),
          successor_id: Number(conn.target),
          rel_type: "FS",
          lag: 0,
        });
        onChanged();
      } catch (e) {
        alert((e as Error).message);
        load();
      }
    },
    [projectId, onChanged, load]
  );

  // Deleting an edge removes the relationship (id encodes pred-succ).
  const onEdgesDelete = useCallback(
    async (deleted: Edge[]) => {
      if (projectId == null) return;
      const rels = await api.listRelationships(projectId);
      for (const e of deleted) {
        const [pred, succ] = e.id.split("-").map(Number);
        const match = rels.find((r) => r.predecessor_id === pred && r.successor_id === succ);
        if (match) await api.deleteRelationship(match.id);
      }
      onChanged();
    },
    [projectId, onChanged]
  );

  if (projectId == null) return <div className="p-8 text-slate-500">No project selected.</div>;

  return (
    <div className="h-full flex flex-col">
      <div className="px-5 py-2 border-b border-slate-200 bg-white flex items-center gap-4 text-sm">
        <span className="font-medium text-slate-700">Visual Logic Network</span>
        <span className="text-slate-400">
          Drag from a node's right handle to another node to create a Finish-to-Start link.
        </span>
        <div className="flex-1" />
        <span className="flex items-center gap-1 text-xs text-slate-500">
          <span className="text-critical">●</span> Critical path
        </span>
        <button onClick={load} className="text-xs text-epc-700 underline">
          ↻ Reload
        </button>
      </div>
      <div className="flex-1">
        <ReactFlow
          nodes={nodes}
          edges={edges}
          nodeTypes={nodeTypes}
          onNodesChange={onNodesChange}
          onNodeDragStop={onNodeDragStop}
          onConnect={onConnect}
          onEdgesDelete={onEdgesDelete}
          fitView
          proOptions={{ hideAttribution: true }}
        >
          <Background color="#cbd5e1" gap={18} />
          <MiniMap nodeColor={(n) => ((n.data as ActivityData)?.isCritical ? "#e4572e" : "#1f4e78")} />
          <Controls />
        </ReactFlow>
      </div>
    </div>
  );
}

export default function NetworkEditor(props: Props) {
  return (
    <ReactFlowProvider>
      <EditorInner {...props} />
    </ReactFlowProvider>
  );
}
