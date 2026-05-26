"""From-scratch AST-only build of the graphify knowledge graph.

Запускается из setup-graphify.{sh,ps1} на свежей машине, где ещё нет
`graphify-out/`. В отличие от `graphify.watch._rebuild_code` (он
инкрементальный — обновляет существующий граф), здесь полный проход:
detect -> AST extract -> build -> cluster -> report/html/json -> manifest.

Семантику (LLM-экстракцию доков, INFERRED-рёбра) НЕ делает — это
дорого и требует Claude-оркестрации. Для богатого графа потом
запусти `/graphify . --mode deep` из Claude Code. Этого AST-графа
достаточно, чтобы хуки начали его поддерживать и MCP-сервер ожил.

Вызов: python tools/_graphify_bootstrap.py   (из корня проекта)
"""
from pathlib import Path


def main() -> int:
    from graphify.detect import detect, save_manifest
    from graphify.extract import collect_files, extract
    from graphify.build import build_from_json
    from graphify.cluster import cluster, score_all
    from graphify.analyze import god_nodes, surprising_connections, suggest_questions
    from graphify.report import generate
    from graphify.export import to_json, to_html

    root = Path(".")
    Path("graphify-out").mkdir(exist_ok=True)

    detection = detect(root)
    code_files = []
    for f in detection.get("files", {}).get("code", []):
        p = Path(f)
        code_files.extend(collect_files(p) if p.is_dir() else [p])

    if not code_files:
        print("[bootstrap] No code files detected — nothing to build.")
        return 1

    ast = extract(code_files, cache_root=root)
    graph = build_from_json(ast)
    if graph.number_of_nodes() == 0:
        print("[bootstrap] Extraction produced 0 nodes — aborting.")
        return 1

    communities = cluster(graph)
    cohesion = score_all(graph, communities)
    gods = god_nodes(graph)
    surprises = surprising_connections(graph, communities)
    labels = {cid: f"Community {cid}" for cid in communities}
    questions = suggest_questions(graph, communities, labels)

    report = generate(
        graph, communities, cohesion, labels, gods, surprises,
        detection, {"input": 0, "output": 0}, ".",
        suggested_questions=questions,
    )
    Path("graphify-out/GRAPH_REPORT.md").write_text(report)
    to_json(graph, communities, "graphify-out/graph.json")
    if graph.number_of_nodes() <= 5000:
        to_html(graph, communities, "graphify-out/graph.html", community_labels=labels)

    save_manifest(detection["files"])
    print(
        f"[bootstrap] AST graph built: {graph.number_of_nodes()} nodes, "
        f"{graph.number_of_edges()} edges, {len(communities)} communities"
    )
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
