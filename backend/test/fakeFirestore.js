// A tiny in-memory stand-in for the Firestore Admin API surface the backend
// uses: collection/doc/get/set/update, orderBy/limit queries, transactions.
export class FakeFirestore {
  constructor() {
    this.docs = new Map(); // path -> data
  }

  collection(name) {
    return new Collection(this, name);
  }

  async runTransaction(fn) {
    const writes = [];
    const tx = {
      get: (ref) => ref.get(),
      set: (ref, data) => writes.push(() => ref._write(data)),
      update: (ref, data) => writes.push(() => ref._update(data)),
    };
    const result = await fn(tx);
    for (const w of writes) await w();
    return result;
  }
}

class Collection {
  constructor(db, path) {
    this.db = db;
    this.path = path;
    this._order = [];
    this._limit = Infinity;
  }

  doc(id) {
    return new Doc(this.db, `${this.path}/${id}`);
  }

  orderBy(field, dir = 'asc') {
    const c = this._clone();
    c._order.push([field, dir]);
    return c;
  }

  limit(n) {
    const c = this._clone();
    c._limit = n;
    return c;
  }

  _clone() {
    const c = new Collection(this.db, this.path);
    c._order = [...this._order];
    c._limit = this._limit;
    return c;
  }

  async get() {
    const prefix = `${this.path}/`;
    let docs = [...this.db.docs.entries()]
      .filter(([p]) => p.startsWith(prefix) && !p.slice(prefix.length).includes('/'))
      .map(([p, data]) => ({ id: p.slice(prefix.length), data: () => structuredClone(data), exists: true }));
    for (const [field, dir] of [...this._order].reverse()) {
      docs.sort((a, b) => {
        const x = a.data()[field];
        const y = b.data()[field];
        const r = x < y ? -1 : x > y ? 1 : 0;
        return dir === 'desc' ? -r : r;
      });
    }
    docs = docs.slice(0, this._limit);
    return { docs, size: docs.length, empty: docs.length === 0 };
  }
}

class Doc {
  constructor(db, path) {
    this.db = db;
    this.path = path;
    this.id = path.split('/').pop();
  }

  collection(name) {
    return new Collection(this.db, `${this.path}/${name}`);
  }

  async get() {
    const data = this.db.docs.get(this.path);
    return { exists: data !== undefined, id: this.id, data: () => (data === undefined ? undefined : structuredClone(data)) };
  }

  async set(data) {
    this._write(data);
  }

  async update(data) {
    this._update(data);
  }

  _write(data) {
    this.db.docs.set(this.path, structuredClone(data));
  }

  _update(data) {
    const existing = this.db.docs.get(this.path);
    if (existing === undefined) throw new Error(`No document to update: ${this.path}`);
    this.db.docs.set(this.path, { ...existing, ...structuredClone(data) });
  }
}
