#!/usr/bin/env python3
"""Independent static/numeric audit; this does NOT execute MATLAB or train PPO.

Usage: python3 tools/current_semantics_audit.py --output verification/current_semantics/audit.json
Requires NumPy and SciPy. Physical-unit equations are checked against the
rational construction, and analytic feature derivatives against differences.
Native MATLAB selfTest/smokeTest remain mandatory before training.
"""
from __future__ import annotations

import argparse
import hashlib
import json
import re
from pathlib import Path

import numpy as np
from scipy.special import betaincinv
from scipy.stats import t


ROOT = Path(__file__).resolve().parents[1]
ALG = ROOT / "src/algorithms/+landing2d/+current_semantics"
ORCH = ROOT / "src/orchestration/+landing2d/+current_semantics"
SCALES = np.array([3., 8., 10., 10., 1.5, 1., 1., np.pi / 2, 1., 1.])
SLOPE = np.tan(np.pi / 6)
CONTACT = np.array([.5, .35, .30, np.deg2rad(5), np.deg2rad(10)])


def soft(x, scale=1.):
    return x / (np.abs(x) + scale)


def physical_features(o):
    """Direct physical-unit definition plus its analytic Jacobian, independent of AD."""
    count = o.shape[1]
    u = o.copy()
    jac = np.broadcast_to(np.eye(10)[:, :, None], (10, 10, count)).copy()
    for j in [0, 1, 2, 3, 4, 7]:
        u[j] = SCALES[j] * o[j] / (1 - np.abs(o[j]))
        jac[j, j] = SCALES[j] / (1 - np.abs(o[j])) ** 2
    positive = u[1] > 0
    ea = u[0] - SLOPE * np.maximum(u[1], 0)
    va = u[2] - SLOPE * u[4] * positive
    jea = jac[0] - SLOPE * jac[1] * positive
    jva = jac[2] - SLOPE * jac[4] * positive
    theta = np.arctan2(o[5], o[6])
    jt = np.zeros((10, count))
    den = o[5] ** 2 + o[6] ** 2
    jt[5], jt[6] = o[6] / den, -o[5] / den
    channels, derivatives = [], []

    def original(j):
        channels.append(o[j]); derivative = np.zeros((10, count)); derivative[j] = 1
        derivatives.append(derivative)

    def bounded(x, derivative, scale):
        channels.append(soft(x, scale))
        derivatives.append(derivative * scale / (np.abs(x) + scale) ** 2)

    for j in [8, 9, 0, 1, 2, 3]:
        original(j)
    bounded(u[3] - u[2], jac[3] - jac[2], 10.)
    for j in [4, 5, 6, 7]:
        original(j)
    bounded(ea, jea, 3.)
    bounded(va, jva, 1.)
    bounded(ea * va, jea * va + jva * ea, 3.)
    for x, derivative, scale in zip(
        [u[0], u[2], u[4], theta, u[7]],
        [jac[0], jac[2], jac[4], jt, jac[7]], CONTACT
    ):
        bounded(x, derivative, scale)
    return np.array(channels), np.array(derivatives)


def rational_features(o):
    """Independent NumPy evaluation of the registered bounded rational form."""
    d = 1 - np.abs(o)
    ratio = lambda n, den, scale: n / (np.abs(n) + scale * den)
    positive = o[1] > 0
    en = np.where(positive, 3 * o[0] * d[1] - SLOPE * 8 * o[1] * d[0], 3 * o[0])
    ed = np.where(positive, d[0] * d[1], d[0])
    vn = np.where(positive, 10 * o[2] * d[4] - SLOPE * 1.5 * o[4] * d[2], 10 * o[2])
    vd = np.where(positive, d[2] * d[4], d[2])
    return np.vstack([
        o[8:10], o[0:2], o[2:4],
        ratio(o[3] * d[2] - o[2] * d[3], d[2] * d[3], 1),
        o[4:8], ratio(en, ed, 3), ratio(vn, vd, 1), ratio(en * vn, ed * vd, 3),
        ratio(3 * o[0], d[0], CONTACT[0]),
        ratio(10 * o[2], d[2], CONTACT[1]),
        ratio(1.5 * o[4], d[4], CONTACT[2]),
        soft(np.arctan2(o[5], o[6]), CONTACT[3]),
        ratio((np.pi / 2) * o[7], d[7], CONTACT[4]),
    ])


def numeric_checks():
    rng = np.random.default_rng(20261027)
    o = rng.uniform(-.85, .85, (10, 10000))
    theta = rng.uniform(-.3, .3, o.shape[1])
    o[5], o[6] = np.sin(theta), np.cos(theta)
    o[8] = rng.integers(0, 2, o.shape[1])
    o[9] = np.where(o[8] == 1, 0, rng.uniform(.001, 1, o.shape[1]))
    expected, _ = physical_features(o)
    actual = rational_features(o)
    error = float(np.max(np.abs(expected - actual)))
    assert error < 1e-12
    assert actual.shape == (19, 10000) and np.isfinite(actual).all()
    assert np.max(np.abs(actual)) <= 1
    # Full 19-by-10 Jacobians away from h=0 and the atan2 branch cut.
    probe = o[:, :64].copy()
    _, jac = physical_features(probe)
    eps = 1e-6
    finite = np.zeros_like(jac)
    for j in range(10):
        delta = np.zeros_like(probe); delta[j] = eps
        finite[:, j] = (rational_features(probe + delta) - rational_features(probe - delta)) / (2 * eps)
    derivative_error = float(np.max(np.abs(finite - jac) / (1 + np.abs(jac))))
    assert derivative_error < 1e-6
    # The approach line must use physical scales (x scale 3 differs from height scale 8).
    h = np.linspace(.1, 15, 100)
    on_line = np.zeros((10, 100)); on_line[6] = 1
    on_line[0], on_line[1] = soft(SLOPE * h, 3), soft(h, 8)
    on_line[4] = soft(-.4, 1.5); on_line[2] = soft(SLOPE * -.4, 10)
    aligned = rational_features(on_line)
    assert np.max(np.abs(aligned[11:14])) < 1e-12
    # Near-saturation valid inputs and the initial zero/age-one observation remain finite.
    edge = np.zeros((10, 4)); edge[6] = 1; edge[9] = 1
    edge[0, 1:] = [1 - 1e-12, -1 + 1e-12, .99]
    edge[1, 1:] = [.99, -.99, 1 - 1e-12]
    edge[2:5, 1:] = [[.8, -.8, .9], [-.7, .7, -.9], [.8, -.8, .7]]
    assert np.isfinite(rational_features(edge)).all()
    # Current-state equality is unaffected by evaluating other inputs between calls.
    first = rational_features(probe)
    rational_features(o[:, ::-1])
    assert np.array_equal(first, rational_features(probe))
    return {"random_current_observations": 10000,
            "physical_vs_rational_max_absolute_error": error,
            "jacobian_observations": 64, "jacobian_entries": int(jac.size),
            "jacobian_max_scaled_error": derivative_error,
            "approach_line_cases": 100, "boundary_cases": 4}


def parse_vector(text, field):
    value = re.search(r"s\." + field + r"\s*=\s*\[([^\]]+)\]", text).group(1)
    result = []
    for item in value.split():
        if ":" in item:
            a, b = map(int, item.split(":")); result.extend(range(a, b + 1))
        else:
            result.append(int(item))
    return np.array(result)


def structural_checks():
    schema = (ALG / "schema.m").read_text()
    src, dst = parse_vector(schema, "src") - 1, parse_vector(schema, "dst") - 1
    assert len(src) == len(dst) == 16
    assert np.array_equal(src[-7:], np.arange(7)) and np.array_equal(dst[-7:], np.arange(7))
    adjacency = np.zeros((7, 7), dtype=int)
    adjacency[src, dst] = 1
    assert np.all((adjacency @ adjacency)[0:4, 6] > 0)
    indices = parse_vector(schema, "activeLinearIndices") - 1
    assert len(indices) == 19 and len(set(indices)) == 19 and np.all(indices < 36)
    assert not set(indices).intersection(range(5, 42, 6))
    # Every primitive raw channel has an exact copy in the flat comparator.
    o = np.arange(10, dtype=float)[:, None] / 20
    o[5], o[6] = .1, np.sqrt(.99)
    phi = rational_features(o)
    primitive = [2, 3, 4, 5, 7, 8, 9, 10, 0, 1]
    assert np.array_equal(phi[primitive], o)
    flat = np.zeros((42, 1)); flat[indices] = phi
    flat[5::6] = np.arange(1, 8)[:, None] / 7
    assert np.array_equal(flat[indices], phi) and np.all(flat[36:41] == 0)
    mlp = lambda inputs, width, outputs: (inputs + 1) * width + (width + 1) * outputs
    encoder = lambda relations: 6 * 8 + 8 + relations * 8 * 8 + (16 + relations) + 8 * 8 + 8
    common = mlp(10, 55, 1) + 2
    counts = [mlp(10, 110, 2) + common, mlp(19, 65, 2) + common,
              encoder(2) + mlp(18, 55, 2) + common, encoder(5) + mlp(18, 46, 2) + common]
    assert counts == [2095, 2095, 2094, 2100]
    registry = (ORCH / "registry.m").read_text()
    assert re.search(r"widths\s*=\s*\[110,\s*65,\s*55,\s*46\]", registry)
    new_files = sorted(ALG.glob("*.m")) + sorted(ORCH.glob("*.m"))
    missing = []
    for file in new_files:
        for dotted in set(re.findall(r"\blanding2d(?:\.[A-Za-z]\w*){2,}", file.read_text())):
            parts = dotted.split(".")
            relative = Path(*("+" + name for name in parts[:-1])) / (parts[-1] + ".m")
            if not any((ROOT / "src" / layer / relative).is_file()
                       for layer in ["algorithms", "simulations", "orchestration"]):
                missing.append(f"{file.name}: {dotted}")
    assert not missing, missing
    # No duplicate function implementation across the three package roots.
    definitions = [p.name for p in new_files]
    assert len(definitions) == len(set(definitions))
    return {"nodes": 7, "edges_including_self": 16, "primitive_to_landing_max_hops": 2,
            "flat_feature_dimension": 19, "parameter_counts": counts,
            "max_count_spread_percent": (max(counts) - min(counts)) / min(counts) * 100,
            "new_matlab_functions": len(new_files), "unresolved_package_calls": missing}


def interval_checks():
    worst = 0.
    for n in [5, 20]:
        for coverage in [.95, .975]:
            q = betaincinv((n - 1) / 2, .5, 1 - coverage)
            native_formula = np.sqrt((n - 1) * (1 - q) / q)
            reference = t.ppf((1 + coverage) / 2, n - 1)
            worst = max(worst, abs(native_formula - reference))
    assert worst < 1e-9
    return {"training_seed_counts": [5, 20], "coverages": [.95, .975],
            "t_critical_max_difference_vs_scipy": worst}


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--output", type=Path)
    args = parser.parse_args()
    report = {"test_only": True, "executes_matlab": False,
              "training_or_performance_evidence": False,
              "scope": "Independent equations, topology, capacity, statistics, and package-call resolution only.",
              "numeric": numeric_checks(), "structural": structural_checks(),
              "statistics": interval_checks(), "passed": True}
    sources = sorted(ALG.glob("*.m")) + sorted(ORCH.glob("*.m"))
    report["inspected_source_sha256"] = {str(p.relative_to(ROOT)): hashlib.sha256(p.read_bytes()).hexdigest()
                                           for p in sources}
    output = json.dumps(report, indent=2, ensure_ascii=False) + "\n"
    if args.output:
        args.output.parent.mkdir(parents=True, exist_ok=True)
        args.output.write_text(output)
    visible = dict(report); visible.pop("inspected_source_sha256")
    print(json.dumps(visible, indent=2, ensure_ascii=False))


if __name__ == "__main__":
    main()
