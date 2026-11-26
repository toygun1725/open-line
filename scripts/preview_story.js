function applyEffects(effects, vars, manifest) {
  if (!effects || !manifest) return;
  const defs = manifest.variables || {};
  for (const eff of effects) {
    const spec = defs[eff.var];
    if (eff.op === "set") {
      vars[eff.var] = eff.value;
    } else if (eff.op === "add") {
      vars[eff.var] = (Number(vars[eff.var]) || 0) + (Number(eff.value) || 0);
    }
    if (spec && spec.type === "int") {
      let v = Math.round(Number(vars[eff.var]) || 0);
      if (spec.min !== undefined) v = Math.max(spec.min, v);
      if (spec.max !== undefined) v = Math.min(spec.max, v);
      vars[eff.var] = v;
    }
  }
}

function evalCondition(cond, vars) {
  if (!cond) return true;
  if (cond.all) return cond.all.every((c) => evalCondition(c, vars));
  if (cond.any) return cond.any.some((c) => evalCondition(c, vars));
  const actual = vars[cond.var];
  const expected = cond.value;
  switch (cond.op) {
    case "eq":
      return actual === expected;
    case "neq":
      return actual !== expected;
    case "gt":
      return Number(actual) > Number(expected);
    case "gte":
      return Number(actual) >= Number(expected);
    case "lt":
      return Number(actual) < Number(expected);
    case "lte":
      return Number(actual) <= Number(expected);
    default:
      return false;
  }
}

function flattenItems(items, vars) {
  const out = [];
  for (const item of items || []) {
    if (item.type === "conditional") {
      if (evalCondition(item.condition, vars)) {
        out.push(...flattenItems(item.thenItems, vars));
      } else if (item.elseItems) {
        out.push(...flattenItems(item.elseItems, vars));
      }
    } else {
      out.push(item);
    }
  }
  return out;
}

function newRun(id, now, endings = []) {
  const manifest = BUNDLE.stories[id].manifest;
  const vars = Object.fromEntries(Object.entries(manifest.variables).map(([k, v]) => [k, v.default]));
  const run = { id, session: crypto.randomUUID(), vars, events: [], endings: [...endings] };
  enqueue(run, manifest.startNodeId, now);
  return run;
}
function enqueue(run, nodeID, at) {
  const story = BUNDLE.stories[run.id];
  while (nodeID) {
    const node = story.nodes[nodeID];
    applyEffects(node.effects, run.vars, story.manifest);
    for (const item of flattenItems(node.items, run.vars)) {
      const isMessage = item.type === "message";
      at += isMessage
        ? 1000 *
          (item.typingDelaySec ?? Math.min(4.2, Math.max(1.1, 0.8 + item.text[state.lang].length * 0.022)))
        : 450;
      run.events.push({ kind: item.type, at, text: item.text, vars: { ...run.vars } });
    }
    const t = node.transition;
    switch (t.type) {
      case "next":
        nodeID = t.target;
        break;
      case "conditionalNext":
        nodeID = t.branches.find((b) => evalCondition(b.condition, run.vars))?.target ?? t.fallback;
        break;
      case "delay":
        run.events.push({ kind: "delay", at, until: at + t.seconds * 1000, spec: t.liveActivity });
        at += t.seconds * 1000;
        nodeID = t.target;
        break;
      case "actBreak":
        if (state.paid || run.events.some((event) => event.kind === "gate" && event.completedAct === t.completedAct && event.cleared)) {
          nodeID = t.target;
          break;
        }
        run.events.push({ kind: "gate", at: at + 350, ...t });
        return;
      case "choice":
        run.events.push({ kind: "choice", at: at + 350, options: t.options });
        return;
      case "ending":
        run.events.push({ kind: "ending", at: at + 600, ...t });
        return;
      default:
        throw Error("Unknown transition " + t.type);
    }
  }
}
function answer(run, index, option, now) {
  const e = run.events[index];
  if (
    index !== run.events.length - 1 ||
    e?.kind !== "choice" ||
    e.at > now ||
    e.chosen != null ||
    !e.options[option]
  )
    return false;
  e.chosen = option;
  const chosen = e.options[option];
  applyEffects(chosen.effects, run.vars, BUNDLE.stories[run.id].manifest);
  enqueue(run, chosen.target, now);
  return true;
}
function clearGate(run, now) {
  const e = run.events.at(-1);
  if (e?.kind !== "gate" || e.at > now || e.cleared) return;
  e.cleared = true;
  enqueue(run, e.target, now);
}
function reachedEnd(run, now) {
  const last = run?.events.at(-1);
  return last?.kind === "ending" && last.at <= now ? last : null;
}
