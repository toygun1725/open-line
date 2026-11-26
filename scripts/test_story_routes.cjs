const { test } = require("node:test");
const assert = require("node:assert/strict");
const { readFileSync } = require("node:fs");
const path = require("node:path");
const vm = require("node:vm");
const { webcrypto } = require("node:crypto");

const root = path.join(__dirname, "..", "OpenLine", "Resources", "Story");
const json = (file) => JSON.parse(readFileSync(file, "utf8"));
const catalog = json(path.join(root, "catalog.json"));
const stories = {};
for (const entry of catalog.stories) {
  const dir = path.join(root, entry.folder);
  const nodes = [1, 2, 3].flatMap((act) => json(path.join(dir, "act" + act + ".json")).nodes);
  stories[entry.id] = {
    nodes: Object.fromEntries(nodes.map((node) => [node.id, node])),
    manifest: json(path.join(dir, "manifest.json")),
  };
}
const engine = vm.createContext({ BUNDLE: { catalog, stories }, state: { paid: false, lang: "tr" }, crypto: webcrypto });
vm.runInContext(readFileSync(path.join(__dirname, "preview_story.js"), "utf8"), engine);

for (const entry of catalog.stories) {
  test(entry.id + " reaches every ending with real waits", () => {
    const endings = new Set();
    const secondDates = new Set();
    function visit(run) {
      const event = run.events.at(-1);
      if (event.kind === "ending") {
        endings.add(event.endingId);
        if (entry.isFree) {
          const gates = run.events.filter((e) => e.kind === "gate");
          assert.equal(gates.length, 2);
          const confession = run.events.findIndex((e) =>
            e.kind === "choice" && e.options.some((option) => option.id === "opt_confess_open_line"));
          assert.ok(confession >= 0 && confession < run.events.indexOf(gates[1]));
        }
        const waits = run.events.filter((e) => e.kind === "delay");
        const seconds = waits.reduce((sum, e) => sum + (e.until - e.at) / 1000, 0);
        assert.ok(seconds >= 36000 && seconds <= 120000);
        if (event.endingId === "second_date") secondDates.add(run.vars.walked_home);
        return;
      }
      if (event.kind === "gate") {
        engine.clearGate(run, event.at);
        visit(run);
        return;
      }
      assert.equal(event.kind, "choice");
      for (const i of [0, 1]) {
        const branch = { ...run, vars: { ...run.vars }, events: [...run.events.slice(0, -1), { ...event }] };
        const choiceIndex = branch.events.length - 1;
        assert.ok(engine.answer(branch, choiceIndex, i, event.at));
        assert.equal(engine.answer(branch, choiceIndex, 1 - i, event.at), false);
        visit(branch);
      }
    }
    visit(engine.newRun(entry.id, 0));
    assert.deepEqual(endings, new Set(Object.keys(entry.endings)));
    if (entry.id === "masa_7") assert.deepEqual(secondDates, new Set([true, false]));
  });
}
