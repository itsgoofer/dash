import 'dart:math';

/// A single particle on the brain surface. [notePath] is reserved for a future
/// functional mode where a node maps to a real note (null while decorative).
class BrainNode {
  BrainNode(this.x, this.y, this.z, this.size, this.phase, this.pulses, {this.notePath});
  final double x, y, z, size, phase;
  final bool pulses;
  String? notePath;
}

/// Static, seeded brain: ~300 nodes on a noisy two-lobe surface plus precomputed
/// nearest-neighbour edges. Built once; the painter only transforms it.
class BrainModel {
  BrainModel(this.nodes, this.edges, this.glow)
      : adj = List.generate(nodes.length, (_) => <int>[]) {
    for (var e = 0; e < edges.length; e++) {
      adj[edges[e].$1].add(e);
      adj[edges[e].$2].add(e);
    }
  }
  final List<BrainNode> nodes;
  final List<(int, int)> edges; // (lo, hi) index pairs, deduped
  final Set<int> glow; // brightest node indices that get an additive blur
  final List<List<int>> adj; // node index -> incident edge indices (for cascades)

  factory BrainModel.generate({int nodeCount = 300, int seed = 7}) {
    final rnd = Random(seed);
    final nodes = <BrainNode>[];
    const lobe = 0.6; // x offset of each hemisphere centre

    for (var i = 0; i < nodeCount; i++) {
      final side = i.isEven ? -1.0 : 1.0;
      // Uniform direction on a unit sphere.
      final u = rnd.nextDouble() * 2 - 1;
      final t = rnd.nextDouble() * 2 * pi;
      final r = sqrt(1 - u * u);
      final rad = 0.82 * (1 + _gauss(rnd) * 0.07); // gaussian surface jitter
      final x = (side * lobe + r * cos(t) * rad) * 0.9; // squash x so lobes fuse
      final y = r * sin(t) * rad * 1.05;
      final z = u * rad;
      nodes.add(BrainNode(x, y, z, 1.5 + rnd.nextDouble() * 1.5, rnd.nextDouble() * 2 * pi, rnd.nextDouble() < 0.1));
    }

    // Brightest ~20 nodes (largest) get the blur glow — capped for perf.
    final order = List.generate(nodeCount, (i) => i)..sort((a, b) => nodes[b].size.compareTo(nodes[a].size));
    return BrainModel(nodes, _knnEdges(nodes, 3, 450), order.take(20).toSet());
  }
}

/// Sum-of-uniforms approximation of a standard normal (mean 0, std ~0.58).
double _gauss(Random r) => r.nextDouble() + r.nextDouble() + r.nextDouble() + r.nextDouble() - 2;

List<(int, int)> _knnEdges(List<BrainNode> nodes, int k, int cap) {
  final n = nodes.length;
  final seen = <int>{};
  final edges = <(int, int)>[];
  final d = List<double>.filled(n, 0);
  for (var i = 0; i < n; i++) {
    final a = nodes[i];
    for (var j = 0; j < n; j++) {
      final b = nodes[j];
      final dx = a.x - b.x, dy = a.y - b.y, dz = a.z - b.z;
      d[j] = dx * dx + dy * dy + dz * dz;
    }
    final idx = List<int>.generate(n, (j) => j)..sort((p, q) => d[p].compareTo(d[q]));
    for (var m = 1; m <= k && m < n; m++) {
      final j = idx[m];
      final lo = i < j ? i : j, hi = i < j ? j : i;
      if (seen.add(lo * 100000 + hi)) edges.add((lo, hi));
    }
  }
  if (edges.length > cap) edges.removeRange(cap, edges.length);
  return edges;
}
