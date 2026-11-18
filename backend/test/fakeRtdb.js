// In-memory stand-in for the Realtime Database Admin API used by the
// backend: ref(path).get/set/update/remove/transaction, multi-path updates,
// and snapshots with exists()/val().
export class FakeRtdb {
  constructor() {
    this.root = {};
  }

  ref(path = '') {
    return new Ref(this, path.split('/').filter(Boolean));
  }

  _get(parts) {
    let node = this.root;
    for (const p of parts) {
      if (node === null || typeof node !== 'object' || !(p in node)) return undefined;
      node = node[p];
    }
    return node;
  }

  _set(parts, value) {
    if (parts.length === 0) {
      this.root = value == null ? {} : structuredClone(value);
      return;
    }
    let node = this.root;
    for (const p of parts.slice(0, -1)) {
      if (node[p] === undefined || node[p] === null || typeof node[p] !== 'object') node[p] = {};
      node = node[p];
    }
    const last = parts[parts.length - 1];
    if (value === null || value === undefined) delete node[last];
    else node[last] = structuredClone(value);
    this._prune(this.root);
  }

  _prune(node) {
    for (const k of Object.keys(node)) {
      const v = node[k];
      if (v && typeof v === 'object') {
        this._prune(v);
        if (Object.keys(v).length === 0) delete node[k];
      }
    }
  }
}

class Snapshot {
  constructor(value) {
    this._v = value;
  }

  exists() {
    return this._v !== undefined && this._v !== null;
  }

  val() {
    return this._v === undefined ? null : structuredClone(this._v);
  }
}

class Ref {
  constructor(db, parts) {
    this.db = db;
    this.parts = parts;
  }

  async get() {
    return new Snapshot(this.db._get(this.parts));
  }

  async set(value) {
    this.db._set(this.parts, value);
  }

  async remove() {
    this.db._set(this.parts, null);
  }

  async update(obj) {
    for (const [k, v] of Object.entries(obj)) {
      this.db._set([...this.parts, ...k.split('/').filter(Boolean)], v);
    }
  }

  async transaction(fn) {
    const current = this.db._get(this.parts);
    const next = fn(current === undefined ? null : structuredClone(current));
    if (next === undefined) return { committed: false, snapshot: new Snapshot(current) };
    this.db._set(this.parts, next);
    return { committed: true, snapshot: new Snapshot(this.db._get(this.parts)) };
  }
}
