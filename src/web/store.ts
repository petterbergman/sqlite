// Same IndexedDB layout jeep-sqlite wrote through localforage, so databases it saved still open
const IDB_NAME = 'jeepSqliteStore';
const IDB_STORE = 'databases';

/**
 * Keeps each database file as a Uint8Array in IndexedDB, keyed by file name.
 */
export class WebStore {
  private idb: IDBDatabase | null = null;

  get isOpen(): boolean {
    return this.idb !== null;
  }

  async open(): Promise<void> {
    if (this.idb) return;
    let idb = await openIdb();
    if (!idb.objectStoreNames.contains(IDB_STORE)) {
      // created by something else without our object store: add it in a version upgrade
      const version = idb.version + 1;
      idb.close();
      idb = await openIdb(version);
    }
    this.idb = idb;
  }

  async get(fileName: string): Promise<Uint8Array | null> {
    const data = await this.request<Uint8Array | null | undefined>('readonly', (s) => s.get(fileName));
    return data ?? null;
  }

  async set(fileName: string, data: Uint8Array): Promise<void> {
    await this.request('readwrite', (s) => s.put(data, fileName));
  }

  async remove(fileName: string): Promise<void> {
    await this.request('readwrite', (s) => s.delete(fileName));
  }

  async has(fileName: string): Promise<boolean> {
    const data = await this.get(fileName);
    // An opened but empty database is a single page: the header and an empty schema
    return data !== null && data.length > pageSize(data);
  }

  private request<T>(mode: IDBTransactionMode, fn: (store: IDBObjectStore) => IDBRequest): Promise<T> {
    if (!this.idb) {
      return Promise.reject(new Error('WebStore is not open yet. You have to call "initWebStore()" first.'));
    }
    const store = this.idb.transaction(IDB_STORE, mode).objectStore(IDB_STORE);
    return new Promise((resolve, reject) => {
      const req = fn(store);
      req.onsuccess = () => resolve(req.result);
      req.onerror = () => reject(req.error);
    });
  }
}

/**
 * The page size from the SQLite file header, 0 when there is no header.
 */
function pageSize(data: Uint8Array): number {
  if (data.length < 18) return 0;
  const size = (data[16] << 8) | data[17];
  return size === 1 ? 65536 : size;
}

function openIdb(version?: number): Promise<IDBDatabase> {
  return new Promise((resolve, reject) => {
    const req = indexedDB.open(IDB_NAME, version);
    req.onupgradeneeded = () => {
      if (!req.result.objectStoreNames.contains(IDB_STORE)) req.result.createObjectStore(IDB_STORE);
    };
    req.onsuccess = () => resolve(req.result);
    req.onerror = () => reject(req.error);
  });
}
