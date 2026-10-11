// A small D1 stand-in on node:sqlite, enough for the queries in src/db.js.
import { DatabaseSync } from "node:sqlite";
import { readFileSync, readdirSync } from "node:fs";
import { join, dirname } from "node:path";
import { fileURLToPath } from "node:url";

const migrations = join(dirname(fileURLToPath(import.meta.url)), "..", "migrations");

class Stmt {
  constructor(db, sql, args = []) { this.db = db; this.sql = sql; this.args = args; }
  bind(...args) { return new Stmt(this.db, this.sql, args); }
  runSync() {
    const r = this.db.prepare(this.sql).run(...this.args);
    return { success: true, meta: { changes: Number(r.changes) } };
  }
  async run() { return this.runSync(); }
  async all() { return { success: true, results: this.db.prepare(this.sql).all(...this.args).map((r) => ({ ...r })) }; }
  async first() { const r = this.db.prepare(this.sql).get(...this.args); return r ? { ...r } : null; }
}

export class FakeD1 {
  constructor() {
    this.db = new DatabaseSync(":memory:");
    for (const f of readdirSync(migrations).sort()) this.db.exec(readFileSync(join(migrations, f), "utf8"));
  }
  prepare(sql) { return new Stmt(this.db, sql); }
  async batch(stmts) {
    this.db.exec("BEGIN");
    try {
      const out = stmts.map((s) => s.runSync());
      this.db.exec("COMMIT");
      return out;
    } catch (e) {
      this.db.exec("ROLLBACK");
      throw e;
    }
  }
  rows(sql, ...args) { return this.db.prepare(sql).all(...args).map((r) => ({ ...r })); }
}
